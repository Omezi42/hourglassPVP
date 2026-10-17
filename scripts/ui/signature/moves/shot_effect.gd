extends SignatureMove
## サンドショット(GameDesign.md 9章):情報帯の上で砂粒が寄り集まって弾になり、砂の尾を引いて
## 相手のHPの器へ一直線に撃ち込まれ、当たった所で砂がはじける(打撃)。

const GATHER := 0.22
const FLIGHT := 0.24
const BURST := 0.24
## 弾が固まる位置(情報帯の中心から上へ)と、集まってくる砂粒の数・広がり。
const LIFT := 34.0
const GRAINS := 10
const SPREAD := 34.0
const BULLET := 6.0
## 尾の長さ(進みの割合)と、尾を作る点の数。
const TAIL := 0.26
const TAIL_POINTS := 9
const BURST_REACH := 30.0


func impact_at() -> float:
	return GATHER + FLIGHT


func duration() -> float:
	return impact_at() + BURST


func draw(item: CanvasItem, t: float) -> void:
	if targets.is_empty():
		return
	var alpha := fade_alpha(t)
	var muzzle := from - Vector2(0.0, LIFT)
	var gather := ease(phase(t, 0.0, GATHER), 2.0)
	if gather < 1.0:
		for i in range(GRAINS):
			var angle := TAU * float(i) / float(GRAINS) + SignaturePaint.jitter(i, 3)
			var at := muzzle + Vector2.from_angle(angle) * SPREAD * (1.0 - gather)
			ShapePaint.circle(
				item.get_canvas_item(), at, 2.0, Color(SignaturePaint.SAND, alpha * gather)
			)
		ShapePaint.circle(
			item.get_canvas_item(), muzzle, BULLET * gather, Color(SignaturePaint.SAND, alpha)
		)
		return
	var flight := ease(phase(t, GATHER, FLIGHT), 1.8)
	if t < impact_at():
		for i in range(TAIL_POINTS, 0, -1):
			var q := maxf(flight - TAIL * float(i) / float(TAIL_POINTS), 0.0)
			var size := BULLET * 0.7 * (1.0 - float(i) / float(TAIL_POINTS + 1))
			var color := Color(SignaturePaint.SAND_DARK, alpha * 0.6)
			ShapePaint.circle(item.get_canvas_item(), muzzle.lerp(targets[0], q), size, color)
		var head := muzzle.lerp(targets[0], flight)
		ShapePaint.circle(
			item.get_canvas_item(), head, BULLET + 1.2, Color(UiPalette.OUTLINE_DARK, alpha * 0.7)
		)
		ShapePaint.circle(item.get_canvas_item(), head, BULLET, Color(SignaturePaint.SAND, alpha))
		return
	var burst := phase(t, impact_at(), BURST)
	for i in range(GRAINS):
		var dir := Vector2.from_angle(TAU * float(i) / float(GRAINS) + SignaturePaint.jitter(i, 7))
		var at := targets[0] + dir * BURST_REACH * ease(burst, 0.4)
		ShapePaint.circle(
			item.get_canvas_item(), at, 2.2 * (1.0 - burst), Color(SignaturePaint.SAND, alpha)
		)
