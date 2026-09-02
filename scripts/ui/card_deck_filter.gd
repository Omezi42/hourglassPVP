class_name CardDeckFilter
extends Control
## デッキ編集の一覧を絞り込むモーダルダイアログ(GameDesign.md 9章)。
##
## コスト・キーワード・名前の3条件をここで合成し、画面側は `changed` を受けて
## 並べ直すだけにする。**コストの選択肢はプールに実在するコストから作る**ため、
## カードが増えて新しいコスト帯が出てもここへ書き足す作業は発生しない。

signal changed

const SCREEN_SIZE := Vector2(1280, 720)
const PANEL_WIDTH := 600.0
const PANEL_STYLE := "res://resources/theme/content_panel.tres"
const CHIP_HEIGHT := 36.0
const COST_CHIP_WIDTH := 44.0
const ALL_CHIP_WIDTH := 68.0
const KEYWORD_CHIP_WIDTH := 68.0
const BUTTON_SIZE := Vector2(120, 44)
const KIND_CHIP_WIDTH := 88.0
const KIND_ALL := 0
const KIND_UNIT := 1
const KIND_SPELL := 2

## 0 は「すべて」。それ以外はそのコストだけを通す。
var _cost := 0
## -1 は指定なし。それ以外は `CardEnums.Keyword` の値。
var _keyword := -1
## カードの種類。0=すべて / 1=砂時計だけ / 2=砂術だけ(GameDesign.md 6章)。
var _kind := 0
var _query := ""
var _search_input: LineEdit
var _cost_buttons: Dictionary = {}
var _keyword_buttons: Dictionary = {}
var _kind_buttons: Dictionary = {}


func _ready() -> void:
	visible = false
	mouse_filter = Control.MOUSE_FILTER_STOP
	size = SCREEN_SIZE
	_build()


func open() -> void:
	visible = true


func close() -> void:
	visible = false


func matches(card: CardData) -> bool:
	if _cost > 0 and card.cost != _cost:
		return false
	if _kind == KIND_UNIT and card.is_spell:
		return false
	if _kind == KIND_SPELL and not card.is_spell:
		return false
	if _keyword >= 0 and not card.keywords.has(_keyword):
		return false
	if not _query.is_empty() and not card.display_name.containsn(_query):
		return false
	return true


## 現在適用されている絞り込み条件の数。ボタンのバッジ表示に使う。
func active_filter_count() -> int:
	var count := 0
	if _cost > 0:
		count += 1
	if _keyword >= 0:
		count += 1
	if _kind > 0:
		count += 1
	if not _query.is_empty():
		count += 1
	return count


func reset_filters() -> void:
	_cost = 0
	_keyword = -1
	_kind = 0
	_query = ""
	if _search_input != null:
		_search_input.text = ""
	_mark_selected(_cost_buttons, _cost)
	_mark_selected(_keyword_buttons, _keyword)
	_mark_selected(_kind_buttons, _kind)
	changed.emit()


func _build() -> void:
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.65)
	dim.size = SCREEN_SIZE
	dim.mouse_filter = Control.MOUSE_FILTER_STOP
	dim.gui_input.connect(_on_dim_input)
	add_child(dim)

	var center := CenterContainer.new()
	center.size = SCREEN_SIZE
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(center)

	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(PANEL_WIDTH, 0)
	panel.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var style: StyleBox = load(PANEL_STYLE)
	if style != null:
		panel.add_theme_stylebox_override("panel", style)
	center.add_child(panel)

	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 14)
	panel.add_child(column)

	# ヘッダー(タイトル + 閉じるボタン)
	var header_row := HBoxContainer.new()
	column.add_child(header_row)
	var title := Label.new()
	title.text = "カードの絞り込みと検索"
	title.add_theme_font_size_override("font_size", 22)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header_row.add_child(title)
	var close_icon := CodedButton.make_icon("✕", Vector2(36, 36))
	close_icon.pressed.connect(close)
	header_row.add_child(close_icon)

	# 種類選択(砂時計 / 砂術。GameDesign.md 6章)
	var kind_label := Label.new()
	kind_label.text = "種類"
	kind_label.add_theme_font_size_override("font_size", 16)
	kind_label.add_theme_color_override("font_color", UiPalette.BRASS_HIGHLIGHT)
	column.add_child(kind_label)

	var kind_row := HBoxContainer.new()
	kind_row.add_theme_constant_override("separation", 6)
	column.add_child(kind_row)
	_add_kind_chip(kind_row, "すべて", KIND_ALL)
	_add_kind_chip(kind_row, "砂時計", KIND_UNIT)
	_add_kind_chip(kind_row, "砂術", KIND_SPELL)

	# コスト選択
	var cost_label := Label.new()
	cost_label.text = "コスト"
	cost_label.add_theme_font_size_override("font_size", 16)
	cost_label.add_theme_color_override("font_color", UiPalette.BRASS_HIGHLIGHT)
	column.add_child(cost_label)

	var cost_row := HBoxContainer.new()
	cost_row.add_theme_constant_override("separation", 6)
	column.add_child(cost_row)
	_add_cost_chip(cost_row, "すべて", 0, ALL_CHIP_WIDTH)
	for cost in _pool_costs():
		_add_cost_chip(cost_row, str(cost), cost, COST_CHIP_WIDTH)

	# キーワード選択
	var keyword_label := Label.new()
	keyword_label.text = "キーワード"
	keyword_label.add_theme_font_size_override("font_size", 16)
	keyword_label.add_theme_color_override("font_color", UiPalette.BRASS_HIGHLIGHT)
	column.add_child(keyword_label)

	var keyword_row := HBoxContainer.new()
	keyword_row.add_theme_constant_override("separation", 6)
	column.add_child(keyword_row)
	for keyword in CardEnums.NAMED:
		var button := CodedButton.make(
			CardEnums.keyword_name(keyword), Vector2(KEYWORD_CHIP_WIDTH, CHIP_HEIGHT)
		)
		button.toggle_mode = true
		button.pressed.connect(_on_keyword_pressed.bind(keyword))
		keyword_row.add_child(button)
		_keyword_buttons[keyword] = button

	# 名前検索
	var name_label := Label.new()
	name_label.text = "名前検索"
	name_label.add_theme_font_size_override("font_size", 16)
	name_label.add_theme_color_override("font_color", UiPalette.BRASS_HIGHLIGHT)
	column.add_child(name_label)

	_search_input = LineEdit.new()
	_search_input.placeholder_text = "名前で探す"
	_search_input.custom_minimum_size = Vector2(PANEL_WIDTH - 48, 40)
	_search_input.text_changed.connect(_on_query_changed)
	column.add_child(_search_input)

	# フッターボタン
	var footer_row := HBoxContainer.new()
	footer_row.add_theme_constant_override("separation", 12)
	footer_row.alignment = BoxContainer.ALIGNMENT_END
	column.add_child(footer_row)

	var reset_button := CodedButton.make("リセット", BUTTON_SIZE)
	reset_button.pressed.connect(reset_filters)
	footer_row.add_child(reset_button)

	var confirm_button := CodedButton.make("閉じる", BUTTON_SIZE)
	confirm_button.pressed.connect(close)
	footer_row.add_child(confirm_button)


## プールに実在するコストだけを昇順で返す。
func _pool_costs() -> Array[int]:
	var costs: Array[int] = []
	for card in CardLibrary.all_cards():
		if not costs.has(card.cost):
			costs.append(card.cost)
	costs.sort()
	return costs


func _add_cost_chip(parent: Control, label: String, cost: int, width: float) -> void:
	var button := CodedButton.make(label, Vector2(width, CHIP_HEIGHT))
	button.toggle_mode = true
	button.button_pressed = cost == _cost
	button.pressed.connect(_on_cost_pressed.bind(cost))
	parent.add_child(button)
	_cost_buttons[cost] = button


func _add_kind_chip(parent: Control, label: String, kind: int) -> void:
	var button := CodedButton.make(label, Vector2(KIND_CHIP_WIDTH, CHIP_HEIGHT))
	button.toggle_mode = true
	button.button_pressed = kind == _kind
	button.pressed.connect(_on_kind_pressed.bind(kind))
	parent.add_child(button)
	_kind_buttons[kind] = button


func _on_kind_pressed(kind: int) -> void:
	_kind = KIND_ALL if kind == _kind else kind
	_mark_selected(_kind_buttons, _kind)
	changed.emit()


func _on_cost_pressed(cost: int) -> void:
	# 押されているものをもう一度押したら「すべて」へ戻す。
	_cost = 0 if cost == _cost else cost
	_mark_selected(_cost_buttons, _cost)
	changed.emit()


func _on_keyword_pressed(keyword: int) -> void:
	_keyword = -1 if keyword == _keyword else keyword
	_mark_selected(_keyword_buttons, _keyword)
	changed.emit()


## 選択中のチップは、凹んだ見た目だけでは弱いため文字色も琥珀へ変える。
func _mark_selected(buttons: Dictionary, selected: int) -> void:
	for key in buttons:
		var button: Button = buttons[key]
		button.button_pressed = key == selected
		# 押されている間は `font_pressed_color` が使われるため、両方を差し替える。
		for slot in ["font_color", "font_pressed_color", "font_hover_pressed_color"]:
			if key == selected:
				button.add_theme_color_override(slot, UiPalette.GLOW_AMBER)
			else:
				button.remove_theme_color_override(slot)


func _on_query_changed(text: String) -> void:
	_query = text.strip_edges()
	changed.emit()


func _on_dim_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		var click := event as InputEventMouseButton
		if click.pressed and click.button_index == MOUSE_BUTTON_LEFT:
			close()


func _unhandled_input(event: InputEvent) -> void:
	if not visible:
		return
	if event.is_action_pressed("ui_cancel"):
		close()
		get_viewport().set_input_as_handled()
