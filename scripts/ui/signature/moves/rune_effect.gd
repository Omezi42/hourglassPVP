extends SignatureMove
## ルーンの設置(GameDesign.md 9章):駒の頭上に頭の丸いルーン石がせり上がり、刻んだ文字が菫色に灯る。
## 文字が石から抜け出してくすんだ筋を引いて対象へ飛び、対象に押されたところでくすんだ輪が縮む(払拭)。

const RISE := 0.14
const CARVE := 0.2
const FLY := 0.28
## 石の位置(駒の中心から)と半幅・高さ、文字の大きさ。
const STONE_AT := Vector2(0.0, -66.0)
const STONE := Vector2(15.0, 34.0)
const GLYPH := 22.0
## 文字の3画(-0.5〜0.5の箱、y は下向き)。縦の幹から右上へ2本の枝。
const STROKES: Array[PackedVector2Array] = [
	[Vector2(-0.15, 0.5), Vector2(-0.15, -0.5)],
	[Vector2(-0.15, -0.48), Vector2(0.3, -0.2)],
	[Vector2(-0.15, -0.1), Vector2(0.3, 0.18)],
]


func top_extent() -> float:
	return (-STONE_AT.y + STONE.y * 0.5 + 4.0) * zoom


func impact_at() -> float:
	return RISE + CARVE + FLY


func draw(item: CanvasItem, t: float) -> void:
	if targets.is_empty():
		return
	var ci := item.get_canvas_item()
	var alpha := fade_alpha(t)
	var rise := ease(phase(t, 0.0, RISE), 0.5)
	var stone := from + STONE_AT * zoom + Vector2(0.0, (1.0 - rise) * 14.0)
	var stone_alpha := alpha * rise * (1.0 - phase(t, impact_at(), FADE * 0.6))
	_stone(ci, stone, stone_alpha)
	var carve := phase(t, RISE, CARVE)
	var fly := phase(t, RISE + CARVE, FLY)
	var target := targets[0]
	if fly > 0.0:
		var head := stone.lerp(target, ease(fly, 0.8))
		var trail := Color(UiPalette.DRAIN_TRAIL, alpha * 0.6 * (1.0 - fly * 0.5))
		item.draw_line(stone, head, trail, 2.2, true)
	if fly <= 0.0:
		_glyph(item, stone, GLYPH * zoom, carve, UiPalette.RUNE_VIOLET, stone_alpha)
	elif fly < 1.0:
		var at := stone.lerp(target, ease(fly, 0.8))
		var tint := UiPalette.RUNE_VIOLET.lerp(UiPalette.DRAIN_TRAIL, fly)
		_glyph(item, at, GLYPH * zoom * (1.0 + 0.3 * fly), 1.0, tint, alpha)
	for target_at in targets:
		SignaturePaint.drain_ring(item, target_at, phase(t, impact_at(), FADE), alpha)


func _stone(ci: RID, at: Vector2, alpha: float) -> void:
	if alpha <= 0.0:
		return
	var w := STONE.x * zoom
	var h := STONE.y * zoom
	var outline := PackedVector2Array([at + Vector2(-w, h * 0.5), at + Vector2(w, h * 0.5)])
	for i in range(11):
		var a := float(i) / 10.0 * PI
		outline.append(at + Vector2(cos(a) * w, -h * 0.5 + w - sin(a) * w))
	ShapePaint.convex_polygon(
		ci, ForesightPaint.grown(outline, at, 2.0), Color(UiPalette.INK_950, alpha * 0.85)
	)
	ShapePaint.convex_polygon(ci, outline, Color(UiPalette.FLINT, alpha))


static func _glyph(
	item: CanvasItem, at: Vector2, size: float, written: float, color: Color, alpha: float
) -> void:
	if alpha <= 0.0 or written <= 0.0:
		return
	ShapePaint.circle(item.get_canvas_item(), at, size * 0.7, Color(color, alpha * 0.22))
	for i in STROKES.size():
		var part := clampf(written * float(STROKES.size()) - float(i), 0.0, 1.0)
		if part <= 0.0:
			break
		var a := at + STROKES[i][0] * size
		var b := a.lerp(at + STROKES[i][1] * size, part)
		item.draw_line(a, b, Color(UiPalette.INK_950, alpha * 0.6), 4.6, true)
		item.draw_line(a, b, Color(color, alpha), 2.6, true)
		item.draw_line(a, b, Color(SignaturePaint.SPARK_HOT, alpha * 0.7), 1.0, true)
