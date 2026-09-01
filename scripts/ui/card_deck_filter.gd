class_name CardDeckFilter
extends HBoxContainer
## デッキ編集の一覧を絞り込む条件(GameDesign.md 9章)。
##
## コスト・キーワード・名前の3条件をここで合成し、画面側は `changed` を受けて
## 並べ直すだけにする。**コストの選択肢はプールに実在するコストから作る**ため、
## カードが増えて新しいコスト帯が出てもここへ書き足す作業は発生しない。

signal changed

## チップは**1行に「すべて + コスト7種 + キーワード4種 + 名前の検索」が収まる**幅にする。
## 以前は合計886pxあり、画面に取れる幅(832px)を超えて右端の検索欄がはみ出していた。
const CHIP_HEIGHT := 34.0
const COST_CHIP_WIDTH := 40.0
const ALL_CHIP_WIDTH := 62.0
const KEYWORD_CHIP_WIDTH := 62.0
const SEARCH_WIDTH := 140.0
const SEPARATION := 5

## 0 は「すべて」。それ以外はそのコストだけを通す。
var _cost := 0
## -1 は指定なし。それ以外は `CardEnums.Keyword` の値。
var _keyword := -1
var _query := ""
var _cost_buttons: Dictionary = {}
var _keyword_buttons: Dictionary = {}


func _ready() -> void:
	add_theme_constant_override("separation", SEPARATION)
	_build()


func matches(card: CardData) -> bool:
	if _cost > 0 and card.cost != _cost:
		return false
	if _keyword >= 0 and not card.keywords.has(_keyword):
		return false
	if not _query.is_empty() and not card.display_name.containsn(_query):
		return false
	return true


func _build() -> void:
	_add_cost_chip("すべて", 0, ALL_CHIP_WIDTH)
	for cost in _pool_costs():
		_add_cost_chip(str(cost), cost, COST_CHIP_WIDTH)
	add_child(_spacer(8.0))
	for keyword in CardEnums.NAMED:
		var button := CodedButton.make(
			CardEnums.keyword_name(keyword), Vector2(KEYWORD_CHIP_WIDTH, CHIP_HEIGHT)
		)
		button.toggle_mode = true
		button.pressed.connect(_on_keyword_pressed.bind(keyword))
		add_child(button)
		_keyword_buttons[keyword] = button
	add_child(_spacer(8.0))
	var search := LineEdit.new()
	search.placeholder_text = "名前で探す"
	search.custom_minimum_size = Vector2(SEARCH_WIDTH, CHIP_HEIGHT)
	search.text_changed.connect(_on_query_changed)
	add_child(search)


## プールに実在するコストだけを昇順で返す。
func _pool_costs() -> Array[int]:
	var costs: Array[int] = []
	for card in CardLibrary.all_cards():
		if not costs.has(card.cost):
			costs.append(card.cost)
	costs.sort()
	return costs


func _add_cost_chip(label: String, cost: int, width: float) -> void:
	var button := CodedButton.make(label, Vector2(width, CHIP_HEIGHT))
	button.toggle_mode = true
	button.button_pressed = cost == _cost
	button.pressed.connect(_on_cost_pressed.bind(cost))
	add_child(button)
	_cost_buttons[cost] = button


func _spacer(width: float) -> Control:
	var gap := Control.new()
	gap.custom_minimum_size = Vector2(width, CHIP_HEIGHT)
	return gap


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
