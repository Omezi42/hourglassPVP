extends SignatureMove
## ウォールの登場(GameDesign.md 9章):通常より高くから重く落ちて卓が揺れ、着地した足元から石畳のひびが
## 四方へ走る(総量11の重さ)。

const CRACK := 0.3
const HOLD := 0.24
## ひびの本数と長さ(卓の奥行きに合わせて縦を潰す)、折れ曲がりの数と幅。
const RAYS := 7
const REACH := 74.0
const SQUASH := 0.32
const KINKS := 4
const JAG := 6.0
const CRACK_COLOR := Color(0.16, 0.12, 0.09, 1.0)


func impact_at() -> float:
	return CardUnitFx.LAND_DURATION


func duration() -> float:
	return impact_at() + CRACK + HOLD + FADE


func heavy_land() -> bool:
	return true


func draw(item: CanvasItem, t: float) -> void:
	if t < impact_at():
		return
	var ci := item.get_canvas_item()
	var alpha := fade_alpha(t)
	var crack := ease(phase(t, impact_at(), CRACK), 0.4)
	for i in range(RAYS):
		var angle := TAU * (float(i) + SignaturePaint.jitter(i, 151) * 0.5) / float(RAYS)
		var dir := Vector2(cos(angle), sin(angle) * SQUASH)
		var length := REACH * (0.6 + 0.4 * SignaturePaint.jitter(i, 152)) * crack
		var points := PackedVector2Array([from + dir * CardView.PEDESTAL_RADIUS.x * 0.9])
		for k in range(1, KINKS + 1):
			var s := float(k) / float(KINKS)
			var side := (
				dir.orthogonal().normalized() * (SignaturePaint.jitter(i * 7 + k, 153) - 0.5) * JAG
			)
			points.append(points[0] + dir * length * s + side * Vector2(1.0, SQUASH))
		ShapePaint.polyline(ci, points, Color(CRACK_COLOR, alpha * 0.85), 2.0, true)
		ShapePaint.polyline(ci, points, Color(SignaturePaint.SAND, alpha * 0.25), 0.8, true)
