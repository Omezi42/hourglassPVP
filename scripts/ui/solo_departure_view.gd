class_name SoloDepartureView
extends Control
## 遠征(ソロモード)の出発の画面(GameDesign.md 27章「画面」)。作戦の札を3枚
## 横に並べ、押すと出発する。見た目は承認済みのモック(`tools/tmp_mock_solo.gd`)のとおり。

signal theme_chosen(theme_id: String)

const CONTENT_TOP := ScreenHeader.CONTENT_TOP
const CONTENT_HEIGHT := ScreenHeader.CONTENT_HEIGHT
const MARGIN := 24.0
const CARD_GAP := 24.0
const CARD_PADDING := 22.0
const CARDS_TOP_OFFSET := 56.0
const CARDS_BOTTOM_MARGIN := 40.0
const ICON_COLUMNS := 8
const ICON_GAP := 6.0
const ICON_ROW_GAP := 10.0
const ICON_GRID_TOP_OFFSET := 96.0
const HEADING_FONT_SIZE := 26
const NAME_FONT_SIZE := 26
const SUMMARY_FONT_SIZE := 15
const RECORD_FONT_SIZE := 15


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE


## 出発で示す3つの作戦の一覧と、いちばん多く勝った数・踏破回数を出す。
func show_data(theme_ids: Array[String], best_wins: int, clears: int) -> void:
	for child in get_children():
		remove_child(child)
		child.queue_free()
	var width := size.x
	_add_label(
		Rect2(MARGIN, CONTENT_TOP, width - MARGIN * 2.0, 34.0),
		"作戦を選んで出発",
		HEADING_FONT_SIZE,
		UiPalette.TEXT_OFFWHITE,
		HORIZONTAL_ALIGNMENT_CENTER,
		true
	)
	var cards_top := CONTENT_TOP + CARDS_TOP_OFFSET
	var cards_bottom := CONTENT_TOP + CONTENT_HEIGHT - CARDS_BOTTOM_MARGIN
	var card_w: float = (width - MARGIN * 2.0 - CARD_GAP * 2.0) / 3.0
	var card_h := cards_bottom - cards_top
	for i in theme_ids.size():
		var rect := Rect2(MARGIN + float(i) * (card_w + CARD_GAP), cards_top, card_w, card_h)
		_build_card(rect, theme_ids[i])
	_add_label(
		Rect2(MARGIN, cards_bottom + 6.0, width - MARGIN * 2.0, 26.0),
		"いちばん多く勝った数 %d ・ 踏破 %d回" % [best_wins, clears],
		RECORD_FONT_SIZE,
		UiPalette.TEXT_MUTED,
		HORIZONTAL_ALIGNMENT_CENTER
	)


func _build_card(rect: Rect2, theme_id: String) -> void:
	var canvas := Control.new()
	canvas.position = Vector2.ZERO
	canvas.size = size
	canvas.mouse_filter = Control.MOUSE_FILTER_IGNORE
	canvas.draw.connect(
		func() -> void: SoloUiPaint.paint_panel(canvas.get_canvas_item(), rect, false)
	)
	add_child(canvas)
	_add_label(
		Rect2(rect.position.x, rect.position.y + CARD_PADDING, rect.size.x, 34.0),
		CardCpuDecks.name_of(theme_id),
		NAME_FONT_SIZE,
		UiPalette.TEXT_OFFWHITE,
		HORIZONTAL_ALIGNMENT_CENTER,
		true
	)
	_add_label(
		Rect2(
			rect.position.x + CARD_PADDING,
			rect.position.y + CARD_PADDING + 40.0,
			rect.size.x - CARD_PADDING * 2.0,
			40.0
		),
		CardCpuDecks.summary_of(theme_id),
		SUMMARY_FONT_SIZE,
		UiPalette.TEXT_MUTED,
		HORIZONTAL_ALIGNMENT_CENTER
	)
	_build_icons(rect, CardCpuDecks.card_ids_of(theme_id))
	var button := SoloUiPaint.transparent_button()
	button.position = rect.position
	button.size = rect.size
	button.pressed.connect(func() -> void: theme_chosen.emit(theme_id))
	add_child(button)


func _build_icons(rect: Rect2, ids: Array[String]) -> void:
	var grid_top := rect.position.y + CARD_PADDING + ICON_GRID_TOP_OFFSET
	var inner_w: float = rect.size.x - CARD_PADDING * 2.0
	var icon_w: float = (inner_w - float(ICON_COLUMNS - 1) * ICON_GAP) / float(ICON_COLUMNS)
	var icon_h := icon_w * 1.32
	for i in ids.size():
		var col := i % ICON_COLUMNS
		var row := i / ICON_COLUMNS
		var x := rect.position.x + CARD_PADDING + float(col) * (icon_w + ICON_GAP)
		var y := grid_top + float(row) * (icon_h + ICON_GAP + ICON_ROW_GAP)
		_build_icon(Rect2(x, y, icon_w, icon_h), ids[i])


func _build_icon(rect: Rect2, card_id: String) -> void:
	var card: CardData = CardLibrary.find_by_id(card_id)
	if card == null:
		return
	var texture := HourglassArt.texture(card.art_key(), HourglassArt.State.UPRIGHT)
	var box := Control.new()
	box.position = rect.position
	box.size = rect.size
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.draw.connect(
		func() -> void:
			var ci := box.get_canvas_item()
			var foot := Vector2(rect.size.x * 0.5, rect.size.y)
			UiPaint.fill_ellipse(
				ci, foot, Vector2(rect.size.x * 0.4, rect.size.y * 0.09), Color(0, 0, 0, 0.35), 16
			)
			if texture == null:
				return
			var tex_size := texture.get_size()
			var fit: float = minf(rect.size.x / tex_size.x, rect.size.y / tex_size.y)
			var draw_size := tex_size * fit
			box.draw_texture_rect(
				texture,
				Rect2(
					Vector2((rect.size.x - draw_size.x) * 0.5, rect.size.y - draw_size.y), draw_size
				),
				false
			)
	)
	add_child(box)


func _add_label(
	rect: Rect2,
	text: String,
	font_size: int,
	color: Color,
	align := HORIZONTAL_ALIGNMENT_LEFT,
	display := false
) -> void:
	var label := Label.new()
	label.position = rect.position
	label.size = rect.size
	label.horizontal_alignment = align
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	label.text = text
	if display:
		label.add_theme_font_override("font", UiFonts.display_font(label.get_theme_default_font()))
	add_child(label)
