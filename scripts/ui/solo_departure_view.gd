class_name SoloDepartureView
extends Control
## 遠征(ソロモード)の出発の画面(GameDesign.md 27章「画面」)。砂の深さの選択と、
## 作戦の札を3枚横に並べ、押すと出発する。

signal theme_chosen(theme_id: String)
## 砂の深さの矢印を押した(-1/+1)。選べる範囲の判定・保存は呼び出し側が持つ。
signal depth_changed(delta: int)

const MARGIN := 24.0
const CARD_GAP := 24.0
const CARD_PADDING := 22.0
const CARDS_BOTTOM_MARGIN := 40.0
const ICON_COLUMNS := 6
const ICON_ASPECT := 1.32
const ICON_GAP := 6.0
const ICON_ROW_GAP := 10.0
const ICON_GRID_TOP_OFFSET := 96.0
const HEADING_FONT_SIZE := 26
const NAME_FONT_SIZE := 26
const SUMMARY_FONT_SIZE := 15
const RECORD_FONT_SIZE := 15

const DEPTH_ROW_TOP_OFFSET := 44.0
const DEPTH_ARROW_SIZE := Vector2(28, 28)
const DEPTH_LABEL_WIDTH := 200.0
const DEPTH_LABEL_GAP := 8.0
const DEPTH_LABEL_FONT_SIZE := 18
const CONDITION_FONT_SIZE := 13
const CONDITION_LINE_HEIGHT := 18.0
const CONDITION_SEPARATOR := " ・ "
const CONDITIONS_TOP_GAP := 8.0
const CARDS_TOP_GAP := 18.0

const SEAL_RADIUS := 18.0
const SEAL_MARGIN := 14.0
const SEAL_FONT_SIZE := 15


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE


## 出発で示す3つの作戦・砂の深さの選択・記録を出す。`theme_best_depths`は`theme_ids`と
## 同じ並びで、その作戦を踏破したことのある最も深い深さ(未踏破は-1。GameDesign.md 27章)。
func show_data(
	theme_ids: Array[String],
	best_wins: int,
	clears: int,
	depth: int,
	max_depth: int,
	cleared_theme_count: int,
	theme_count: int,
	theme_best_depths: Array[int]
) -> void:
	for child in get_children():
		remove_child(child)
		child.queue_free()
	var width := size.x
	_add_label(
		Rect2(MARGIN, 0.0, width - MARGIN * 2.0, 34.0),
		"作戦を選んで出発",
		HEADING_FONT_SIZE,
		UiPalette.TEXT_OFFWHITE,
		HORIZONTAL_ALIGNMENT_CENTER,
		true
	)
	var depth_top := DEPTH_ROW_TOP_OFFSET
	_build_depth_row(width, depth_top, depth, max_depth)
	var conditions_top := depth_top + DEPTH_ARROW_SIZE.y + CONDITIONS_TOP_GAP
	var conditions := SoloRun.depth_condition_lines(depth)
	_add_label(
		Rect2(MARGIN, conditions_top, width - MARGIN * 2.0, CONDITION_LINE_HEIGHT),
		"条件なし" if conditions.is_empty() else CONDITION_SEPARATOR.join(conditions),
		CONDITION_FONT_SIZE,
		UiPalette.TEXT_MUTED,
		HORIZONTAL_ALIGNMENT_CENTER
	)
	conditions_top += CONDITION_LINE_HEIGHT
	var cards_top := conditions_top + CARDS_TOP_GAP
	var cards_bottom := size.y - CARDS_BOTTOM_MARGIN
	var card_w: float = (width - MARGIN * 2.0 - CARD_GAP * 2.0) / 3.0
	var card_h := cards_bottom - cards_top
	for i in theme_ids.size():
		var rect := Rect2(MARGIN + float(i) * (card_w + CARD_GAP), cards_top, card_w, card_h)
		var best_depth := theme_best_depths[i] if i < theme_best_depths.size() else -1
		_build_card(rect, theme_ids[i], best_depth)
	_add_label(
		Rect2(MARGIN, cards_bottom + 6.0, width - MARGIN * 2.0, 26.0),
		(
			"いちばん多く勝った数 %d ・ 踏破 %d回 ・ 踏破した作戦 %d / %d"
			% [best_wins, clears, cleared_theme_count, theme_count]
		),
		RECORD_FONT_SIZE,
		UiPalette.TEXT_MUTED,
		HORIZONTAL_ALIGNMENT_CENTER
	)


## 「◀ 砂の深さ N ▶」。選べない側の矢印は沈める(disabled)。
func _build_depth_row(width: float, top: float, depth: int, max_depth: int) -> void:
	var center_x := width * 0.5
	var left_button := CodedButton.make_icon("◀", DEPTH_ARROW_SIZE)
	left_button.position = Vector2(
		center_x - DEPTH_LABEL_WIDTH * 0.5 - DEPTH_ARROW_SIZE.x - DEPTH_LABEL_GAP, top
	)
	left_button.disabled = depth <= 0
	left_button.pressed.connect(func() -> void: depth_changed.emit(-1))
	add_child(left_button)
	var right_button := CodedButton.make_icon("▶", DEPTH_ARROW_SIZE)
	right_button.position = Vector2(center_x + DEPTH_LABEL_WIDTH * 0.5 + DEPTH_LABEL_GAP, top)
	right_button.disabled = depth >= max_depth
	right_button.pressed.connect(func() -> void: depth_changed.emit(1))
	add_child(right_button)
	_add_label(
		Rect2(center_x - DEPTH_LABEL_WIDTH * 0.5, top + 2.0, DEPTH_LABEL_WIDTH, DEPTH_ARROW_SIZE.y),
		"砂の深さ %d" % depth,
		DEPTH_LABEL_FONT_SIZE,
		UiPalette.TEXT_OFFWHITE,
		HORIZONTAL_ALIGNMENT_CENTER,
		true
	)


func _build_card(rect: Rect2, theme_id: String, best_depth: int) -> void:
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
	if best_depth >= 0:
		_build_seal(rect, best_depth)
	var button := SoloUiPaint.transparent_button()
	button.position = rect.position
	button.size = rect.size
	button.pressed.connect(func() -> void: theme_chosen.emit(theme_id))
	add_child(button)


## その作戦で踏破したことがあれば、札の右上に真鍮の封蝋の印を押し、中に踏破した
## 最も深い深さの数字を入れる(GameDesign.md 27章「画面」)。
func _build_seal(rect: Rect2, depth: int) -> void:
	var center := (
		rect.position + Vector2(rect.size.x - SEAL_MARGIN - SEAL_RADIUS, SEAL_MARGIN + SEAL_RADIUS)
	)
	var seal := Control.new()
	seal.position = center - Vector2.ONE * SEAL_RADIUS
	seal.size = Vector2.ONE * SEAL_RADIUS * 2.0
	seal.mouse_filter = Control.MOUSE_FILTER_IGNORE
	seal.draw.connect(
		func() -> void:
			var c := Vector2.ONE * SEAL_RADIUS
			seal.draw_circle(c, SEAL_RADIUS, UiPalette.BRASS_DARK)
			seal.draw_circle(c, SEAL_RADIUS - 3.0, UiPalette.BRASS_MID)
			seal.draw_arc(c, SEAL_RADIUS - 5.0, 0, TAU, 32, UiPalette.BRASS_HIGHLIGHT, 1.5)
			var font := seal.get_theme_default_font()
			if font == null:
				return
			var text := str(depth)
			var w := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, SEAL_FONT_SIZE).x
			seal.draw_string(
				font,
				Vector2(c.x - w * 0.5, c.y + 5.0),
				text,
				HORIZONTAL_ALIGNMENT_LEFT,
				-1,
				SEAL_FONT_SIZE,
				UiPalette.NAVY_PANEL_TOP
			)
	)
	add_child(seal)


func _build_icons(rect: Rect2, ids: Array[String]) -> void:
	var grid_top := rect.position.y + CARD_PADDING + ICON_GRID_TOP_OFFSET
	var inner_w: float = rect.size.x - CARD_PADDING * 2.0
	var rows := ceili(float(ids.size()) / float(ICON_COLUMNS))
	var inner_h: float = rect.end.y - CARD_PADDING - grid_top
	# 札の高さに収まる大きさまで絵を広げる(幅と高さの小さいほうで決める)。
	var icon_w: float = minf(
		(inner_w - float(ICON_COLUMNS - 1) * ICON_GAP) / float(ICON_COLUMNS),
		(
			(inner_h - float(maxi(rows - 1, 0)) * (ICON_GAP + ICON_ROW_GAP))
			/ float(maxi(rows, 1))
			/ ICON_ASPECT
		)
	)
	var icon_h := icon_w * ICON_ASPECT
	var grid_left := (
		rect.position.x
		+ (rect.size.x - (icon_w * ICON_COLUMNS + ICON_GAP * (ICON_COLUMNS - 1))) * 0.5
	)
	for i in ids.size():
		var col := i % ICON_COLUMNS
		var row := i / ICON_COLUMNS
		var x := grid_left + float(col) * (icon_w + ICON_GAP)
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
