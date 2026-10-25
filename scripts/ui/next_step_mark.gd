class_name NextStepMark
extends Control
## ホームで次にやってほしい入口1つに掛ける印(GameDesign.md 18章「初回の導線」)。
## 札の縁を琥珀の光でゆっくり脈打たせ、右上の角に真鍮の小札「つぎはここ」を掛ける。
##
## 札(`HomeTile`)の最後の子として重ねる。`Control._draw()` は子より背面に描かれるため、
## 札の中の段位の表示(`RankedEntryInfo`)に隠れないよう、札の描画ではなく独立した子にする。

const LABEL := "つぎはここ"
const PULSE_PERIOD := 1.6
const GLOW_GROW := 3.0
const GLOW_RADIUS := 12.0
const GLOW_WIDTH := 2.5
const HALO_WIDTH := 7.0
const TAG_FONT_SIZE := 14
const TAG_PADDING := Vector2(12.0, 5.0)
const TAG_RADIUS := 5.0
## 小札を札の上端へ半分掛ける量と、右端からの寄せ。
const TAG_OVERHANG := 0.5
const TAG_RIGHT := 18.0
const TAG_TEXT := Color(0.30, 0.20, 0.07)
const TAG_STOPS := [
	[0.0, Color(0.98, 0.86, 0.52)],
	[0.5, Color(0.86, 0.66, 0.30)],
	[1.0, Color(0.62, 0.44, 0.16)],
]

## 札の印の大きさの倍率(縦画面で文字の目安を満たすため。GameDesign.md 9章「縦画面」)。
var tag_scale := 1.0

var _time := 0.0
var _font: Font


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_font = TextGlyphs.ui_font()


func _process(delta: float) -> void:
	_time += delta
	# 掛けた札が向きの切り替えで大きさを変えても輪が追いつくように。
	var tile := get_parent() as Control
	if tile != null and size != tile.size:
		size = tile.size
	queue_redraw()


## 札へ掛ける。`null` なら外す。
func attach_to(tile: Control) -> void:
	if get_parent() != null:
		get_parent().remove_child(self)
	visible = tile != null
	set_process(visible)
	if tile == null:
		return
	tile.add_child(self)
	position = Vector2.ZERO
	size = tile.size


func _draw() -> void:
	var ci := get_canvas_item()
	var pulse := (sin(_time * TAU / PULSE_PERIOD) + 1.0) * 0.5
	var ring := UiPaint.rounded_rect_points_uniform(
		Rect2(Vector2.ZERO, size).grow(GLOW_GROW), GLOW_RADIUS, 6
	)
	ring.append(ring[0])
	ShapePaint.polyline(
		get_canvas_item(), ring, Color(UiPalette.GLOW_AMBER, 0.12 + 0.18 * pulse), HALO_WIDTH, true
	)
	ShapePaint.polyline(
		get_canvas_item(), ring, Color(UiPalette.GLOW_AMBER, 0.45 + 0.5 * pulse), GLOW_WIDTH, true
	)
	_draw_tag(ci)


func _draw_tag(ci: RID) -> void:
	var font_size := roundi(TAG_FONT_SIZE * tag_scale)
	var padding := TAG_PADDING * tag_scale
	var radius := TAG_RADIUS * tag_scale
	var text_size := _font.get_string_size(LABEL, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size)
	var tag_size := Vector2(text_size.x, float(font_size)) + padding * 2.0
	var rect := Rect2(
		Vector2(size.x - tag_size.x - TAG_RIGHT * tag_scale, -tag_size.y * TAG_OVERHANG), tag_size
	)
	var points := UiPaint.rounded_rect_points_uniform(rect, radius, 4)
	ShapePaint.colored_polygon(
		get_canvas_item(),
		UiPaint.rounded_rect_points_uniform(rect.grow(1.5), radius + 1.5, 4),
		UiPalette.OUTLINE_DARK
	)
	UiPaint.fill_gradient_polygon(ci, points, rect, TAG_STOPS)
	UiPaint.draw_bevel(ci, points, UiPalette.BRASS_HIGHLIGHT, UiPalette.BRASS_DARK, 1.5, false)
	var baseline := rect.position + Vector2(padding.x, padding.y + font_size * 0.86)
	draw_string(
		_font,
		baseline + Vector2(0.0, 1.0),
		LABEL,
		HORIZONTAL_ALIGNMENT_LEFT,
		-1,
		font_size,
		Color(1.0, 0.95, 0.8, 0.5)
	)
	draw_string(_font, baseline, LABEL, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, TAG_TEXT)
