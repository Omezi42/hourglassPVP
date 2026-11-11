class_name SoloDeckList
extends Control
## 遠征(ソロモード)の山札の一覧(GameDesign.md 27章「画面」)。コスト順に
## コストの宝石+名前+枚数の行を並べ、スクロールする。状態パネルと候補オーバーレイの
## 両方で使うため`SoloStatusPanel`から切り出した(Architecture.md 10.15節)。
## `highlight_ids`を渡すと、その札の行を琥珀で光らせる(束・工房で「足したあと/
## 抜いたあと」の変化を示すため)。

const ROW_HEIGHT := 30.0
const ROW_INNER_GAP := 4.0
const CARD_NAME_FONT_SIZE := UiPalette.T_BODY
const GEM_RATIO := 0.85
const HIGHLIGHT_COLOR := UiPalette.SAND_HI
const HIGHLIGHT_BG := Color(UiPalette.SAND_HI, 0.18)

var _scroll: ScrollContainer
var _list_box: VBoxContainer


func _ready() -> void:
	_scroll = ScrollContainer.new()
	TouchScroll.enable(_scroll)
	_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_scroll.position = Vector2.ZERO
	add_child(_scroll)
	_list_box = VBoxContainer.new()
	_list_box.add_theme_constant_override("separation", 2)
	_list_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_scroll.add_child(_list_box)
	resized.connect(_layout)
	_layout()


## 山札をコスト順にまとめ直して並べる。`highlight_ids`に含まれる札の行を光らせる。
func show_data(deck_ids: Array[String], highlight_ids: Array[String] = []) -> void:
	for child in _list_box.get_children():
		_list_box.remove_child(child)
		child.queue_free()
	for row in _deck_rows(deck_ids):
		var highlighted: bool = highlight_ids.has(str(row["card"].id))
		_list_box.add_child(_deck_row(row["card"], row["count"], highlighted))


func _layout() -> void:
	if _scroll == null:
		return
	_scroll.size = size


func _deck_rows(deck_ids: Array[String]) -> Array[Dictionary]:
	var counts := {}
	for id in deck_ids:
		counts[id] = int(counts.get(id, 0)) + 1
	var cards: Array[CardData] = []
	for id in counts:
		var card := CardLibrary.find_by_id(str(id))
		if card != null:
			cards.append(card)
	cards.sort_custom(func(a: CardData, b: CardData) -> bool: return a.cost < b.cost)
	var rows: Array[Dictionary] = []
	for card in cards:
		rows.append({"card": card, "count": int(counts.get(card.id, 1))})
	return rows


func _deck_row(card: CardData, count: int, highlighted: bool) -> Control:
	var row := Control.new()
	row.custom_minimum_size = Vector2(0, ROW_HEIGHT - ROW_INNER_GAP)
	row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.draw.connect(
		func() -> void:
			var ci := row.get_canvas_item()
			if highlighted:
				RenderingServer.canvas_item_add_rect(
					ci, Rect2(Vector2.ZERO, row.size), HIGHLIGHT_BG
				)
			var gem_radius := (ROW_HEIGHT - ROW_INNER_GAP) * 0.5
			var gem_center := Vector2(gem_radius, gem_radius)
			var font := row.get_theme_default_font()
			if font == null:
				return
			UiKit.gem(ci, gem_center, gem_radius * GEM_RATIO, UiPalette.COST, UiPalette.COST_DEEP)
			UiKit.gem_text(ci, font, gem_center, gem_radius * GEM_RATIO, str(card.cost))
			row.draw_string(
				font,
				Vector2(gem_radius * 2.0 + 10.0, (ROW_HEIGHT - ROW_INNER_GAP) * 0.72),
				"%s ×%d" % [card.display_name, count],
				HORIZONTAL_ALIGNMENT_LEFT,
				row.size.x - gem_radius * 2.0 - 10.0,
				CARD_NAME_FONT_SIZE,
				HIGHLIGHT_COLOR if highlighted else UiPalette.IVORY
			)
	)
	return row
