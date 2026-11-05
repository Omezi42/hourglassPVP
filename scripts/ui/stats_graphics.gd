class_name StatsGraphics
extends RefCounted
## 戦績の画面(GameDesign.md 19章「画面」)の絵の部品。数字の表に添える輪・札・横棒・砂時計の絵。
## どれも開いたときに1回描くだけにする(Web版は描き直すたびにGLの番号を消費するため。Pitfalls.md)。

## 勝ちの割合を塗る琥珀の砂と、残りを沈めた石の色。
const SAND := UiPalette.PEDESTAL_DEFAULT_ACCENT
const STONE := Color(0.24, 0.22, 0.22, 1.0)
## 勝率の横棒の50%の目盛り。
const TICK := Color(0.96, 0.94, 0.89, 0.55)
const TICK_WIDTH := 2.0
const TICK_OVERHANG := 3.0
const BAR_HEIGHT := 14.0
const RING_WIDTH := 16.0
const RING_INSET := 10.0
const RING_SEGMENTS := 96
## 輪の中の勝率の文字は直径に比例させる。
const RING_TEXT_RATIO := 0.2
const RING_CAPTION_SIZE := 15
const RING_BASE_DIAMETER := 150.0
const TILE_SIZE := Vector2(100, 112)
const TILE_RADIUS := 10.0
const TILE_VALUE_SIZE := 38
const TILE_CAPTION_SIZE := 15
const TILE_UNIT_SIZE := 16
const TILE_SHADOW_LAYERS := 4
const TILE_SHADOW_ALPHA := 0.55
const TILE_EDGE_WIDTH := 1.5
const CORNER_SEGMENTS := 6
## 砂時計の絵の縦横比(幅 / 高さ)。
const ICON_ASPECT := 0.8


## 勝率の輪。輪の上を勝ちの割合だけ砂で塗り、中に勝率を大きく出す。
static func ring(rate: float, diameter: float) -> Control:
	var box := Control.new()
	box.custom_minimum_size = Vector2(diameter, diameter)
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.draw.connect(
		func() -> void:
			var center := box.size * 0.5
			var radius := diameter * 0.5 - RING_INSET
			var start := -PI * 0.5
			var ci := box.get_canvas_item()
			ShapePaint.arc(ci, center, radius, 0.0, TAU, RING_SEGMENTS, STONE, RING_WIDTH, true)
			if rate > 0.0:
				ShapePaint.arc(
					ci,
					center,
					radius,
					start,
					start + TAU * rate,
					RING_SEGMENTS,
					SAND,
					RING_WIDTH,
					true
				)
	)
	var column := _centered_column(box)
	var value := label("%.1f%%" % (100.0 * rate), roundi(diameter * RING_TEXT_RATIO))
	value.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	column.add_child(value)
	var caption := label(
		"勝率", roundi(RING_CAPTION_SIZE * diameter / RING_BASE_DIAMETER), UiPalette.TEXT_MUTED
	)
	caption.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	column.add_child(caption)
	return box


## 凹んだ数字の札。数字を大きく、見出しと単位を小さく沈めた色で。
static func tile(caption: String, value: String, unit: String, text_scale: float) -> Control:
	var box := Control.new()
	box.custom_minimum_size = TILE_SIZE * text_scale
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.draw.connect(
		func() -> void:
			var ci := box.get_canvas_item()
			var rect := Rect2(Vector2.ZERO, box.size)
			var points := UiPaint.rounded_rect_points_uniform(rect, TILE_RADIUS, CORNER_SEGMENTS)
			UiPaint.fill_gradient_polygon(
				ci,
				points,
				rect,
				[[0.0, UiPalette.NAMEPLATE_PANEL_TOP], [1.0, UiPalette.NAMEPLATE_PANEL_BOTTOM]]
			)
			UiPaint.draw_inner_shadow(
				ci,
				rect,
				TILE_RADIUS,
				CORNER_SEGMENTS,
				TILE_SHADOW_LAYERS,
				Color.BLACK,
				TILE_SHADOW_ALPHA
			)
			UiPaint.draw_bevel(
				ci, points, UiPalette.OUTLINE_DARK, UiPalette.BRASS_MID, TILE_EDGE_WIDTH, false
			)
	)
	var column := _centered_column(box)
	var head := label(caption, roundi(TILE_CAPTION_SIZE * text_scale), UiPalette.TEXT_MUTED)
	head.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	column.add_child(head)
	var line := HBoxContainer.new()
	line.alignment = BoxContainer.ALIGNMENT_CENTER
	line.add_theme_constant_override("separation", 2)
	line.mouse_filter = Control.MOUSE_FILTER_IGNORE
	column.add_child(line)
	line.add_child(label(value, roundi(TILE_VALUE_SIZE * text_scale)))
	var tail := label(unit, roundi(TILE_UNIT_SIZE * text_scale), UiPalette.TEXT_MUTED)
	tail.size_flags_vertical = Control.SIZE_SHRINK_END
	line.add_child(tail)
	return box


## 勝ちと負けの数の比を示す横棒。幅は行の残りいっぱい(全行で同じになる)。
static func split_bar(rate: float) -> Control:
	var bar := _bar(rate, false)
	bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	return bar


## 勝率の横棒。0〜100%を同じ幅で、50%の位置に細い目盛り。
static func rate_bar(rate: float, width: float) -> Control:
	var bar := _bar(rate, true)
	bar.custom_minimum_size.x = width
	return bar


## 構築の代表の砂時計の絵。いちばんコストの高い砂時計(同じコストなら図鑑の並びで先)。
## 構築を引けないときは同じ幅の空きにする(行の名前の位置をそろえるため)。
static func deck_icon(cards: Array, height: float) -> Control:
	var box := Control.new()
	box.custom_minimum_size = Vector2(height * ICON_ASPECT, height)
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var card := top_card(cards)
	if card == null:
		return box
	var texture := HourglassArt.texture(card.art_key(), HourglassArt.State.UPRIGHT)
	if texture == null:
		return box
	box.draw.connect(
		func() -> void:
			var tex_size := texture.get_size()
			var fit: float = minf(box.size.x / tex_size.x, box.size.y / tex_size.y)
			var draw_size := tex_size * fit
			box.draw_texture_rect(texture, Rect2((box.size - draw_size) * 0.5, draw_size), false)
	)
	return box


static func top_card(cards: Array) -> CardData:
	var order := CardLibrary.all_cards()
	var best: CardData = null
	for card: CardData in cards:
		if card == null or card.is_spell:
			continue
		if best == null or card.cost > best.cost:
			best = card
		elif card.cost == best.cost and order.find(card) < order.find(best):
			best = card
	return best


static func label(text: String, font_size: int, color := UiPalette.TEXT_OFFWHITE) -> Label:
	var line := Label.new()
	line.text = text
	line.add_theme_font_size_override("font_size", font_size)
	line.add_theme_color_override("font_color", color)
	line.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	line.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return line


static func _bar(rate: float, tick: bool) -> Control:
	var bar := Control.new()
	bar.custom_minimum_size.y = BAR_HEIGHT
	bar.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bar.draw.connect(
		func() -> void:
			var w := bar.size.x
			var h := bar.size.y
			bar.draw_rect(Rect2(0, 0, w, h), STONE)
			bar.draw_rect(Rect2(0, 0, w * clampf(rate, 0.0, 1.0), h), SAND)
			if tick:
				bar.draw_line(
					Vector2(w * 0.5, -TICK_OVERHANG),
					Vector2(w * 0.5, h + TICK_OVERHANG),
					TICK,
					TICK_WIDTH
				)
	)
	return bar


static func _centered_column(parent: Control) -> VBoxContainer:
	var column := VBoxContainer.new()
	column.anchor_right = 1.0
	column.anchor_bottom = 1.0
	column.alignment = BoxContainer.ALIGNMENT_CENTER
	column.add_theme_constant_override("separation", 0)
	column.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(column)
	return column
