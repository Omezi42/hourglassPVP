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
## 押したボタンの位置から膨らんで開く尺(GameDesign.md 9章「手触り」)。
const BULGE_DURATION := 0.22
const BULGE_MIN_SCALE := 0.12
const CHIP_GAP := 6
const SEARCH_INSET := 48.0
## 区画の縦の間隔(余白の刻み)。
const SECTION_GAP := 16
## 拡大後のパネルを画面の上下から離す量。収まらないときはチップの区画だけをスクロールにする。
const SCREEN_MARGIN := 24.0
## チップの折り返しとパネルの大きさが決まるまで待つフレーム数。
const FIT_WAIT_FRAMES := 2

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
var _dim: ColorRect
var _center: CenterContainer
var _panel: PanelContainer
var _body_scroll: ScrollContainer
var _body: VBoxContainer
var _bulge_tween: Tween


func _ready() -> void:
	visible = false
	mouse_filter = Control.MOUSE_FILTER_STOP
	size = SCREEN_SIZE
	_build()
	PortraitModal.watch(
		self,
		func() -> void:
			_layout()
			_fit_body_height()
	)


## `from_rect` を渡すと、そのグローバル矩形(押したボタン)の位置から膨らんで開く
## (GameDesign.md 9章)。省略すればいままでどおり即座に表示するだけ。
## 膨らみは遅らせて始める(組み直した直後はパネルの位置がまだ決まっていないため)。
func open(from_rect: Rect2 = Rect2()) -> void:
	_layout()
	visible = true
	if from_rect.size == Vector2.ZERO:
		_fit_body_height()
		return
	# 高さが決まる前の位置から膨らませると、決まった後の中央からずれる。
	# 決まるまでは透かして待ち、決まってから膨らませる。
	_panel.modulate.a = 0.0
	await _fit_body_height()
	if visible:
		_bulge_from(from_rect)


## 縦(GameDesign.md 9章「縦画面」)は `PortraitModal` の論理幅で組み、中身ごと拡大する。
## チップの列は幅に収まらなければ折り返す。
func _layout() -> void:
	var width := PortraitModal.WIDTH if ScreenOrientation.is_portrait() else PANEL_WIDTH
	size = PortraitModal.screen_size()
	_dim.size = size
	_panel.custom_minimum_size.x = width
	_search_input.custom_minimum_size.x = width - SEARCH_INSET
	PortraitModal.fit(_center)


## 拡大後のパネルが 画面の高さ − 上下の余白 に収まらないときは、見出しと下のボタン行を残して
## チップの区画だけを縦スクロールにする。チップの折り返しが決まってから測る。
func _fit_body_height() -> void:
	for i in FIT_WAIT_FRAMES:
		await get_tree().process_frame
	if _body_scroll == null or not visible:
		return
	var scale := PortraitModal.SCALE if ScreenOrientation.is_portrait() else 1.0
	var limit := (PortraitModal.screen_size().y - SCREEN_MARGIN * 2.0) / scale
	var chrome := _panel.get_combined_minimum_size().y - _body_scroll.get_combined_minimum_size().y
	var body_height := _body.get_combined_minimum_size().y
	_body_scroll.custom_minimum_size.y = minf(body_height, maxf(limit - chrome, 0.0))
	for i in FIT_WAIT_FRAMES:
		await get_tree().process_frame


func close() -> void:
	visible = false
	_panel.modulate.a = 1.0


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
	_dim = ColorRect.new()
	_dim.color = Color(0, 0, 0, 0.65)
	_dim.size = SCREEN_SIZE
	_dim.mouse_filter = Control.MOUSE_FILTER_STOP
	_dim.gui_input.connect(_on_dim_input)
	add_child(_dim)

	# 大きさは代入せず画面へ張る(代入は中身の最小幅で広がったまま戻らない。Pitfalls.md)。
	_center = CenterContainer.new()
	_center.anchor_right = 1.0
	_center.anchor_bottom = 1.0
	_center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_center)

	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(PANEL_WIDTH, 0)
	panel.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var style: StyleBox = load(PANEL_STYLE)
	if style != null:
		panel.add_theme_stylebox_override("panel", style)
	_center.add_child(panel)
	_panel = panel

	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", SECTION_GAP)
	panel.add_child(column)

	# ヘッダー(タイトル + 閉じるボタン)
	var header_row := HBoxContainer.new()
	column.add_child(header_row)
	var title := Label.new()
	title.text = "カードの絞り込みと検索"
	title.add_theme_font_size_override("font_size", UiPalette.T_LEAD)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header_row.add_child(title)
	# **記号は同梱フォントが字形を持つものだけを使う**(Architecture.md 11章)。
	# ✕(U+2715)には字形が無く、書き出した版でだけ豆腐になる。
	# 検出は `python tools/check_font_glyphs.py`。
	var close_icon := CodedButton.make_icon("×", Vector2(36, 36))
	close_icon.pressed.connect(close)
	header_row.add_child(close_icon)

	# 見出しと下のボタン行は動かさず、条件の区画だけをスクロールにできるようにする。
	_body_scroll = ScrollContainer.new()
	_body_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	TouchScroll.enable(_body_scroll)
	column.add_child(_body_scroll)
	_body = VBoxContainer.new()
	_body.add_theme_constant_override("separation", SECTION_GAP)
	_body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_body_scroll.add_child(_body)

	# 種類選択(砂時計 / 砂術。GameDesign.md 6章)
	var kind_label := Label.new()
	kind_label.text = "種類"
	kind_label.add_theme_font_size_override("font_size", UiPalette.T_BODY)
	kind_label.add_theme_color_override("font_color", UiPalette.GOLD)
	_body.add_child(kind_label)

	var kind_row := _chip_row()
	_body.add_child(kind_row)
	_add_kind_chip(kind_row, "すべて", KIND_ALL)
	_add_kind_chip(kind_row, "砂時計", KIND_UNIT)
	_add_kind_chip(kind_row, "砂術", KIND_SPELL)

	# コスト選択
	var cost_label := Label.new()
	cost_label.text = "コスト"
	cost_label.add_theme_font_size_override("font_size", UiPalette.T_BODY)
	cost_label.add_theme_color_override("font_color", UiPalette.GOLD)
	_body.add_child(cost_label)

	var cost_row := _chip_row()
	_body.add_child(cost_row)
	_add_cost_chip(cost_row, "すべて", 0, ALL_CHIP_WIDTH)
	for cost in _pool_costs():
		_add_cost_chip(cost_row, str(cost), cost, COST_CHIP_WIDTH)

	# キーワード選択
	var keyword_label := Label.new()
	keyword_label.text = "キーワード"
	keyword_label.add_theme_font_size_override("font_size", UiPalette.T_BODY)
	keyword_label.add_theme_color_override("font_color", UiPalette.GOLD)
	_body.add_child(keyword_label)

	var keyword_row := _chip_row()
	_body.add_child(keyword_row)
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
	name_label.add_theme_font_size_override("font_size", UiPalette.T_BODY)
	name_label.add_theme_color_override("font_color", UiPalette.GOLD)
	_body.add_child(name_label)

	_search_input = LineEdit.new()
	_search_input.placeholder_text = "名前で探す"
	_search_input.custom_minimum_size = Vector2(PANEL_WIDTH - 48, 40)
	_search_input.text_changed.connect(_on_query_changed)
	MobileTextInput.wire(_search_input, "名前で探す")
	_body.add_child(_search_input)

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


func _chip_row() -> HFlowContainer:
	var row := HFlowContainer.new()
	row.add_theme_constant_override("h_separation", CHIP_GAP)
	row.add_theme_constant_override("v_separation", CHIP_GAP)
	return row


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
				button.add_theme_color_override(slot, UiPalette.SAND)
			else:
				button.remove_theme_color_override(slot)


func _on_query_changed(text: String) -> void:
	_query = text.strip_edges()
	changed.emit()


## パネルの中心を `button_global_rect` の中心へ合わせてから、通常の位置・大きさへ
## Tweenで戻す(GameDesign.md 9章「絞り込みモーダルは、押したボタンの位置から膨らんで開く」)。
## 座標は `_center` の局所へ直す(縦では `_center` ごと拡大しているため、その倍率も割り戻す)。
func _bulge_from(button_global_rect: Rect2) -> void:
	if _panel == null:
		return
	_panel.modulate.a = 1.0
	# **終わりの位置は、中央へ置いたパネルの位置から求める**(コンテナの並べ直しの前に
	# `_panel.position` を読むと、中央から外れた値を拾って上へずれる)。
	var panel_size := _panel.get_combined_minimum_size()
	var pivot := panel_size * 0.5
	_panel.pivot_offset = pivot
	var target_position := (_center.size - panel_size) * 0.5
	var to_center := _center.get_global_transform()
	var button_center: Vector2 = to_center.affine_inverse() * button_global_rect.get_center()
	var button_size := button_global_rect.size / to_center.get_scale()
	var start_scale := (button_size / panel_size).clamp(
		Vector2(BULGE_MIN_SCALE, BULGE_MIN_SCALE), Vector2.ONE
	)
	_panel.scale = start_scale
	_panel.position = button_center - pivot
	if _bulge_tween != null and _bulge_tween.is_valid():
		_bulge_tween.kill()
	_bulge_tween = create_tween()
	_bulge_tween.set_parallel(true)
	(
		_bulge_tween
		. tween_property(_panel, "scale", Vector2.ONE, BULGE_DURATION)
		. set_trans(Tween.TRANS_BACK)
		. set_ease(Tween.EASE_OUT)
	)
	(
		_bulge_tween
		. tween_property(_panel, "position", target_position, BULGE_DURATION)
		. set_trans(Tween.TRANS_SINE)
		. set_ease(Tween.EASE_OUT)
	)


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
