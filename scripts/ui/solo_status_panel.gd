class_name SoloStatusPanel
extends Control
## 遠征(ソロモード)の状態パネル(GameDesign.md 27章「画面」)。作戦名・HPのバー・
## 勝った数・山札の一覧(コスト順・スクロール)を出す。右下の「遠征をやめる」は
## 確認を挟む(呼び出し側が持つ)。見た目は承認済みのモック(`tools/tmp_mock_solo.gd`)のとおり。

signal abandon_requested

const PADDING := 22.0
const THEME_FONT_SIZE := 20
const WINS_FONT_SIZE := 16
const DECK_LABEL_FONT_SIZE := 14
const ROW_HEIGHT := 30.0
const ROW_INNER_GAP := 4.0
const HP_BAR_HEIGHT := 26.0
const HP_TOP_GAP := 40.0
const HP_FONT_SIZE := 14
const WINS_GAP := 8.0
const LIST_GAP := 44.0
const LIST_LABEL_HEIGHT := 22.0
const BUTTON_SIZE := Vector2(180, 44)
const CARD_NAME_FONT_SIZE := 15
const CARD_COST_FONT_SIZE := 14

var _panel_canvas: Control
var _theme_label: Label
var _hp_canvas: Control
var _wins_label: Label
var _list_label: Label
var _scroll: ScrollContainer
var _list_box: VBoxContainer
var _abandon_button: Button
var _hp := 0
var _max_hp := MatchState.INITIAL_HP


func _ready() -> void:
	_panel_canvas = Control.new()
	_panel_canvas.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_panel_canvas.draw.connect(
		func() -> void:
			SoloUiPaint.paint_panel(
				_panel_canvas.get_canvas_item(), Rect2(Vector2.ZERO, size), false
			)
	)
	add_child(_panel_canvas)

	_theme_label = _make_label(THEME_FONT_SIZE, UiPalette.BRASS_HIGHLIGHT)
	add_child(_theme_label)

	_hp_canvas = Control.new()
	_hp_canvas.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_hp_canvas.draw.connect(_draw_hp_bar)
	add_child(_hp_canvas)

	_wins_label = _make_label(WINS_FONT_SIZE, UiPalette.TEXT_OFFWHITE)
	add_child(_wins_label)

	_list_label = _make_label(DECK_LABEL_FONT_SIZE, UiPalette.TEXT_MUTED)
	add_child(_list_label)

	_scroll = ScrollContainer.new()
	TouchScroll.enable(_scroll)
	_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	add_child(_scroll)
	_list_box = VBoxContainer.new()
	_list_box.add_theme_constant_override("separation", 2)
	_list_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_scroll.add_child(_list_box)

	_abandon_button = CodedButton.make("遠征をやめる", BUTTON_SIZE)
	_abandon_button.pressed.connect(func() -> void: abandon_requested.emit())
	add_child(_abandon_button)

	resized.connect(_layout)
	_layout()


## 作戦名・HP・勝った数・山札の一覧を出し直す。
func show_data(theme_id: String, hp: int, max_hp: int, wins: int, deck_ids: Array[String]) -> void:
	_theme_label.text = "作戦「%s」" % CardCpuDecks.name_of(theme_id)
	_hp = hp
	_max_hp = max_hp
	_hp_canvas.queue_redraw()
	_wins_label.text = "%d勝" % wins
	_list_label.text = "山札 %d枚" % deck_ids.size()
	_rebuild_list(deck_ids)
	_layout()


func _rebuild_list(deck_ids: Array[String]) -> void:
	for child in _list_box.get_children():
		_list_box.remove_child(child)
		child.queue_free()
	for row in _deck_rows(deck_ids):
		_list_box.add_child(_deck_row(row["card"], row["count"]))


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


func _deck_row(card: CardData, count: int) -> Control:
	var row := Control.new()
	row.custom_minimum_size = Vector2(0, ROW_HEIGHT - ROW_INNER_GAP)
	row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.draw.connect(
		func() -> void:
			var ci := row.get_canvas_item()
			var gem_radius := (ROW_HEIGHT - ROW_INNER_GAP) * 0.5
			var gem_center := Vector2(gem_radius, gem_radius)
			UiPaint.fill_circle(ci, gem_center, gem_radius * 0.85, UiPalette.OUTLINE_DARK, 20)
			UiPaint.fill_circle(ci, gem_center, gem_radius * 0.72, CardView.MANA_BLUE, 20)
			var font := row.get_theme_default_font()
			if font == null:
				return
			var cost_text := str(card.cost)
			var cw := (
				font
				. get_string_size(cost_text, HORIZONTAL_ALIGNMENT_LEFT, -1, CARD_COST_FONT_SIZE)
				. x
			)
			row.draw_string(
				font,
				gem_center - Vector2(cw * 0.5, -5.0),
				cost_text,
				HORIZONTAL_ALIGNMENT_LEFT,
				-1,
				CARD_COST_FONT_SIZE,
				Color.WHITE
			)
			row.draw_string(
				font,
				Vector2(gem_radius * 2.0 + 10.0, (ROW_HEIGHT - ROW_INNER_GAP) * 0.72),
				"%s ×%d" % [card.display_name, count],
				HORIZONTAL_ALIGNMENT_LEFT,
				row.size.x - gem_radius * 2.0 - 10.0,
				CARD_NAME_FONT_SIZE,
				UiPalette.TEXT_OFFWHITE
			)
	)
	return row


func _draw_hp_bar() -> void:
	var ci := _hp_canvas.get_canvas_item()
	var local := Rect2(Vector2.ZERO, _hp_canvas.size)
	var track := UiPaint.rounded_rect_points_uniform(local, 8.0, 8)
	UiPaint.fill_gradient_polygon(
		ci, track, local, [[0.0, Color(0.05, 0.04, 0.04, 1.0)], [1.0, Color(0.12, 0.09, 0.08, 1.0)]]
	)
	var ratio := clampf(float(_hp) / float(maxi(_max_hp, 1)), 0.0, 1.0)
	var inner := local.grow(-3.0)
	var fill_rect := Rect2(inner.position, Vector2(inner.size.x * ratio, inner.size.y))
	if fill_rect.size.x > 0.0:
		var fill := UiPaint.rounded_rect_points_uniform(fill_rect, 5.0, 6)
		UiPaint.fill_gradient_polygon(
			ci, fill, fill_rect, [[0.0, UiPalette.GLOW_AMBER], [1.0, UiPalette.BRASS_DARK]]
		)
	var font := _hp_canvas.get_theme_default_font()
	if font == null:
		return
	var text := "%d / %d" % [_hp, _max_hp]
	var w := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, HP_FONT_SIZE).x
	_hp_canvas.draw_string(
		font,
		Vector2(local.get_center().x - w * 0.5, local.get_center().y + 5.0),
		text,
		HORIZONTAL_ALIGNMENT_LEFT,
		-1,
		HP_FONT_SIZE,
		Color.WHITE
	)


func _layout() -> void:
	if _panel_canvas == null:
		return
	_panel_canvas.size = size
	_theme_label.position = Vector2(PADDING, PADDING)
	_theme_label.size = Vector2(size.x - PADDING * 2.0, 28.0)
	var hp_rect := Rect2(PADDING, PADDING + HP_TOP_GAP, size.x - PADDING * 2.0, HP_BAR_HEIGHT)
	_hp_canvas.position = hp_rect.position
	_hp_canvas.size = hp_rect.size
	_wins_label.position = Vector2(PADDING, hp_rect.end.y + WINS_GAP)
	_wins_label.size = Vector2(size.x - PADDING * 2.0, 24.0)
	var list_top := hp_rect.end.y + LIST_GAP
	_list_label.position = Vector2(PADDING, list_top)
	_list_label.size = Vector2(size.x - PADDING * 2.0, LIST_LABEL_HEIGHT)
	var list_top_y := list_top + LIST_LABEL_HEIGHT + 4.0
	var list_rect := Rect2(
		PADDING,
		list_top_y,
		size.x - PADDING * 2.0,
		size.y - PADDING - BUTTON_SIZE.y - 12.0 - list_top_y
	)
	_scroll.position = list_rect.position
	_scroll.size = list_rect.size
	_abandon_button.position = Vector2(
		size.x - PADDING - BUTTON_SIZE.x, size.y - PADDING - BUTTON_SIZE.y
	)


func _make_label(font_size: int, color: Color) -> Label:
	var label := Label.new()
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	return label
