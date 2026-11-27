extends SignatureMove
## アクイファー(GameDesign.md 9章):相手の砂が上へ戻るたび、駒の足元に深い青の地層の筋が3本うねって浮かび、
## 地の下から滴が列になって湧き上がって駒へ吸い込まれ、金色の輪が広がる(地の下ではすべての井戸がつながっている)。

const STRATA := 0.14
const RISE := 0.3
const DROPS := 4
## 地層の筋の中心(駒の中心から)・半幅・間隔・うねり、湧き上がる滴の出どころ(駒の中心から)。
const BED := Vector2(0.0, 44.0)
const BED_HALF := 44.0
const BED_GAP := 7.0
const WAVE := 3.0
const SPRING := Vector2(0.0, 64.0)


func impact_at() -> float:
	return STRATA + RISE


func draw(item: CanvasItem, t: float) -> void:
	var ci := item.get_canvas_item()
	var alpha := fade_alpha(t)
	var show := ease(phase(t, 0.0, STRATA), 0.6)
	var bed := from + BED * zoom
	for k in range(3):
		var points := PackedVector2Array()
		for i in range(17):
			var u := float(i) / 16.0 * 2.0 - 1.0
			points.append(
				(
					bed
					+ (
						Vector2(
							u * BED_HALF * show, BED_GAP * float(k) + sin(u * 5.0 + float(k)) * WAVE
						)
						* zoom
					)
				)
			)
		ShapePaint.polyline(
			ci, points, Color(UiPalette.AQUIFER_BLUE, alpha * (0.9 - 0.25 * float(k))), 2.6, true
		)
	var rise := phase(t, STRATA, RISE)
	for i in range(DROPS):
		var s := rise * 1.6 - 0.2 * float(i)
		if s <= 0.0 or s >= 1.0:
			continue
		var x := sin(float(i) * 2.3) * 14.0
		var at := (from + Vector2(x, SPRING.y) * zoom).lerp(from + Vector2(x * 0.3, 0.0), s)
		ShapePaint.circle(ci, at, 4.4 * zoom, Color(UiPalette.INK_950, alpha))
		ShapePaint.circle(ci, at, 3.2 * zoom, Color(UiPalette.AQUIFER_BLUE, alpha))
		ShapePaint.circle(ci, at + Vector2(-1.0, -1.0), 1.1 * zoom, Color(UiPalette.IVORY, alpha))
	SignaturePaint.boon_ring(item, from, phase(t, impact_at(), FADE), alpha)
