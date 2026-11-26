extends SignatureMove
## ノヴァの余砂(GameDesign.md 9章):砕けた台座で星が一度ぎゅっと縮み、白く膨らんで弾けて菫色の衝撃の輪が卓へ広がり、
## 光芒の先から導火線が相手の駒それぞれへ走って、届いた所で爆ぜて火花が散る(打撃。盤面を揺らす)。

const SHRINK := 0.2
const BLOW := 0.14
const RUN := 0.2
## 星の半径と縮みきった大きさ、光芒の数・長さ、衝撃の輪の広がり、走る導火線の波、届いた所の爆ぜの大きさ。
const STAR := 16.0
const SQUEEZE := 0.45
const RAYS := 8
const RAY := 40.0
const SHOCK := 96.0
const SWAY := 5.0
const BURST := 30.0


func impact_at() -> float:
	return SHRINK + BLOW + RUN


func draw(item: CanvasItem, t: float) -> void:
	if targets.is_empty():
		return
	var ci := item.get_canvas_item()
	var alpha := fade_alpha(t)
	var shrink := phase(t, 0.0, SHRINK)
	var blow := phase(t, SHRINK, BLOW + RUN * 0.5)
	if blow <= 0.0:
		var r := STAR * zoom * lerpf(1.0, SQUEEZE, ease(shrink, 0.6))
		var a := alpha * minf(shrink * 5.0, 1.0)
		ShapePaint.circle(ci, from, r * 2.2, Color(UiPalette.NOVA_VIOLET, a * 0.35))
		_star(ci, from, r, r * 2.0, t * 3.0, a)
	elif blow < 1.0:
		var fade := 1.0 - blow
		var reach := RAY * zoom * ease(blow, 0.3)
		ShapePaint.circle(ci, from, reach * 0.5, Color(SignaturePaint.SPARK_HOT, alpha * fade))
		_star(ci, from, reach * 0.35, reach, 0.0, alpha * fade)
		ShapePaint.arc(
			ci,
			from,
			SHOCK * zoom * ease(blow, 0.4),
			0.0,
			TAU,
			48,
			Color(UiPalette.NOVA_VIOLET, alpha * fade),
			4.0 * fade + 1.0,
			true
		)
	var run := phase(t, SHRINK + BLOW * 0.5, RUN)
	var cord_alpha := alpha * (1.0 - phase(t, impact_at(), FADE * 0.5))
	var land := phase(t, impact_at(), FADE)
	for target in targets:
		if run > 0.0:
			SignaturePaint.fuse_cord(item, from, target, 1.0, run, cord_alpha, SWAY)
		SignaturePaint.powder_burst(item, target, land, BURST, alpha)
		SignaturePaint.sparks(item, target, land, alpha)


## 光芒を持つ星。`inner` は芯、`outer` は長い光芒の先(短い光芒はその半分)。
static func _star(
	ci: RID, center: Vector2, inner: float, outer: float, turn: float, alpha: float
) -> void:
	if alpha <= 0.0:
		return
	var points := PackedVector2Array()
	for i in range(RAYS * 2):
		var a := TAU * float(i) / float(RAYS * 2) + turn
		var r := inner * 0.6
		if i % 2 == 0:
			r = outer if i % 4 == 0 else outer * 0.55
		points.append(center + Vector2.from_angle(a) * r)
	ShapePaint.colored_polygon(ci, points, Color(UiPalette.NOVA_VIOLET, alpha))
	ShapePaint.circle(ci, center, inner, Color(SignaturePaint.SPARK_HOT, alpha))
