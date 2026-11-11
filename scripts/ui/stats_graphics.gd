class_name StatsGraphics
extends RefCounted
## 戦績の画面(GameDesign.md 19章「画面」)の絵の部品。数字の表に添える輪・札・横棒・砂時計の絵。
## どれも開いたときに1回描くだけにする(Web版は描き直すたびにGLの番号を消費するため。Pitfalls.md)。

## 勝ちの割合は緑の砂、負けの割合は朱(色の意味は全画面で1つ)。輪の溝は彫り込みと同じ沈め方。
const WIN_LIGHT := UiPalette.GOOD
const WIN_DEEP := Color(0.22, 0.48, 0.30)
const LOSS_LIGHT := UiPalette.FOE
const LOSS_DEEP := Color(0.55, 0.16, 0.15)
const TRACK := UiKit.WELL_TOP
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
const RING_CAPTION_SIZE := UiPalette.T_SMALL
const RING_BASE_DIAMETER := 150.0
const TILE_SIZE := Vector2(100, 112)
const TILE_RADIUS := 10.0
const TILE_VALUE_SIZE := UiPalette.T_TITLE
const TILE_CAPTION_SIZE := UiPalette.T_SMALL
const TILE_UNIT_SIZE := UiPalette.T_BODY
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
			ShapePaint.arc(ci, center, radius, 0.0, TAU, RING_SEGMENTS, TRACK, RING_WIDTH, true)
			if rate > 0.0:
				ShapePaint.arc(
					ci,
					center,
					radius,
					start,
					start + TAU * rate,
					RING_SEGMENTS,
					WIN_LIGHT,
					RING_WIDTH,
					true
				)
	)
	var column := _centered_column(box)
	var value := label("%.1f%%" % (100.0 * rate), roundi(diameter * RING_TEXT_RATIO))
	value.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	column.add_child(value)
	var caption := label(
		"勝率", roundi(RING_CAPTION_SIZE * diameter / RING_BASE_DIAMETER), UiPalette.MUTED
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
			UiKit.well(ci, Rect2(Vector2.ZERO, box.size), TILE_RADIUS)
	)
	var column := _centered_column(box)
	var head := label(caption, roundi(TILE_CAPTION_SIZE * text_scale), UiPalette.MUTED)
	head.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	column.add_child(head)
	var line := HBoxContainer.new()
	line.alignment = BoxContainer.ALIGNMENT_CENTER
	line.add_theme_constant_override("separation", 2)
	line.mouse_filter = Control.MOUSE_FILTER_IGNORE
	column.add_child(line)
	line.add_child(label(value, roundi(TILE_VALUE_SIZE * text_scale)))
	var tail := label(unit, roundi(TILE_UNIT_SIZE * text_scale), UiPalette.MUTED)
	tail.size_flags_vertical = Control.SIZE_SHRINK_END
	line.add_child(tail)
	return box


## 勝ちと負けの数の比を示す横棒。幅は行の残りいっぱい(全行で同じになる)。
static func split_bar(rate: float) -> Control:
	var bar := _bar(rate, false, true)
	bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	return bar


## 勝率の横棒。0〜100%を同じ幅で、50%の位置に細い目盛り。
static func rate_bar(rate: float, width: float) -> Control:
	var bar := _bar(rate, true, false)
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


static func label(text: String, font_size: int, color := UiPalette.IVORY) -> Label:
	var line := Label.new()
	line.text = text
	line.add_theme_font_size_override("font_size", font_size)
	line.add_theme_color_override("font_color", color)
	line.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	line.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return line


static func _bar(rate: float, tick: bool, split: bool) -> Control:
	var bar := Control.new()
	bar.custom_minimum_size.y = BAR_HEIGHT
	bar.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bar.draw.connect(
		func() -> void:
			var ci := bar.get_canvas_item()
			var rect := Rect2(Vector2.ZERO, bar.size)
			if split:
				_draw_split(ci, rect, rate)
			else:
				UiKit.sand_bar(ci, rect, rate, WIN_LIGHT, WIN_DEEP)
			if tick:
				var w := bar.size.x
				bar.draw_line(
					Vector2(w * 0.5, -TICK_OVERHANG),
					Vector2(w * 0.5, bar.size.y + TICK_OVERHANG),
					TICK,
					TICK_WIDTH
				)
	)
	return bar


## 溝の中に、負けの朱の砂を全幅に敷き、その上へ勝ちの緑の砂を割合だけ溜める。
static func _draw_split(ci: RID, rect: Rect2, rate: float) -> void:
	UiKit.well(ci, rect, rect.size.y * 0.5)
	var inner := rect.grow(-UiKit.SAND_INSET)
	var radius := inner.size.y * 0.5
	UiKit.vgrad(ci, UiKit.rr(inner, radius), [[0.0, LOSS_LIGHT], [1.0, LOSS_DEEP]], true)
	if rate <= 0.0:
		return
	inner.size.x = maxf(inner.size.x * clampf(rate, 0.0, 1.0), inner.size.y)
	UiKit.vgrad(ci, UiKit.rr(inner, radius), [[0.0, WIN_LIGHT], [1.0, WIN_DEEP]], true)


static func _centered_column(parent: Control) -> VBoxContainer:
	var column := VBoxContainer.new()
	column.anchor_right = 1.0
	column.anchor_bottom = 1.0
	column.alignment = BoxContainer.ALIGNMENT_CENTER
	column.add_theme_constant_override("separation", 0)
	column.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(column)
	return column
