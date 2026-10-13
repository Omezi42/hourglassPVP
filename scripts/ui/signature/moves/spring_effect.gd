extends SignatureMove
## スプリングの落砂(GameDesign.md 9章):駒から対象へ金色のばねが伸び、対象の側へ縮みきって
## 弾む(砂が1粒上へ戻る)。

const STRETCH := 0.34
const RECOIL := 0.18
const BOUNCE := 0.32
const TURNS := 9
const COIL_RADIUS := 8.0
## 縮みきったときのばねの長さと、弾んで浮く高さ。
const REST := 18.0
const HOP := 22.0


func impact_at() -> float:
	return STRETCH + RECOIL


func duration() -> float:
	return impact_at() + BOUNCE


func draw(item: CanvasItem, t: float) -> void:
	if targets.is_empty():
		return
	var target := targets[0]
	var dir := (target - from).normalized() if target != from else Vector2.RIGHT
	var head := from.lerp(target, ease(phase(t, 0.0, STRETCH), 0.4))
	var tail := from.lerp(target - dir * REST, ease(phase(t, STRETCH, RECOIL), 2.4))
	var bounce := phase(t, impact_at(), BOUNCE)
	var lift := Vector2(0.0, -HOP * sin(bounce * PI))
	var alpha := fade_alpha(t)
	SignaturePaint.coil(item, tail + lift, head + lift, TURNS, COIL_RADIUS, alpha)
	SignaturePaint.boon_ring(item, target, bounce, alpha)
