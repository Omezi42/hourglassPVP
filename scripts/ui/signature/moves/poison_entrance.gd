extends SignatureMove
## ポイズンの登場(GameDesign.md 9章):着地した足元から紫の泡が3つぶくぶくと立ちのぼり、はじけて紫の
## 飛沫が散る(毒砂=ダメージを与えた砂時計を破壊する印)。

const RISE := 0.34
const LAG := 0.1
const POP := 0.16
## 泡の出る位置(台座の中心から左右へ)と昇る高さ・大きさ、はじけた飛沫の数と広がり。
const SPOTS := [-24.0, 18.0, -2.0]
const CLIMB := [56.0, 72.0, 92.0]
const BUBBLE := 7.0
const DROPS := 6
const SPRAY := 14.0


func impact_at() -> float:
	return CardUnitFx.LAND_DURATION


func duration() -> float:
	return impact_at() + LAG * float(SPOTS.size() - 1) + RISE + POP + FADE * 0.5


func draw(item: CanvasItem, t: float) -> void:
	if t < impact_at():
		return
	var ci := item.get_canvas_item()
	var violet := CardUnitFx.POISON_VIOLET
	for i in range(SPOTS.size()):
		var start := impact_at() + LAG * float(i)
		var rise := phase(t, start, RISE)
		if rise <= 0.0:
			continue
		var climb: float = CLIMB[i]
		var at := from + Vector2(SPOTS[i] + sin(rise * TAU) * 3.0, -climb * ease(rise, 0.8))
		if rise < 1.0:
			var size := BUBBLE * (0.4 + 0.6 * rise)
			ShapePaint.circle(ci, at, size, Color(violet, 0.35))
			ShapePaint.arc(ci, at, size, 0.0, TAU, 20, Color(violet.lightened(0.3), 0.9), 1.6, true)
			ShapePaint.circle(
				ci, at + Vector2(-size * 0.35, -size * 0.35), size * 0.22, Color(1, 1, 1, 0.8)
			)
			continue
		var pop := phase(t, start + RISE, POP)
		if pop >= 1.0:
			continue
		for k in range(DROPS):
			var dir := Vector2.from_angle(TAU * float(k) / float(DROPS) + float(i))
			var drop := at + dir * SPRAY * ease(pop, 0.5) + Vector2(0.0, 10.0 * pop * pop)
			ShapePaint.circle(
				ci, drop, 2.0 * (1.0 - pop * 0.5), Color(violet.lightened(0.2), 1.0 - pop)
			)
