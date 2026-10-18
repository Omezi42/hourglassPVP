extends SignatureMove
## ダストの余砂(GameDesign.md 9章):銘板から砂ぼこりが巻き上がって丸い砂煙の塊になり、相手の
## HPの器へ投げつけられて、当たった所でぱっと砂煙が広がる(打撃)。

const GATHER := 0.26
const THROW := 0.28
## 巻き上がる粒の数と、塊になる高さ(銘板から上へ)と大きさ、投げる弧の高さ。
const GRAINS := 16
const LIFT := 36.0
const SWIRL := 26.0
const CLOUD := 13.0
const PUFFS := [Vector2(0, 0), Vector2(-8, 3), Vector2(8, 2), Vector2(-3, -6), Vector2(5, -5)]
const ARC := 50.0
const BURST := 46.0


func impact_at() -> float:
	return GATHER + THROW


func draw(item: CanvasItem, t: float) -> void:
	if targets.is_empty():
		return
	var ci := item.get_canvas_item()
	var alpha := fade_alpha(t)
	var core := from - Vector2(0.0, LIFT)
	var gather := phase(t, 0.0, GATHER)
	if gather < 1.0:
		for i in range(GRAINS):
			var angle := TAU * SignaturePaint.jitter(i, 71) + gather * PI * 2.0
			var radius := SWIRL * (1.0 - ease(gather, 0.6))
			var at := (
				from.lerp(core, ease(gather, 0.5)) + Vector2(cos(angle), sin(angle) * 0.5) * radius
			)
			ShapePaint.circle(ci, at, 1.6, Color(SignaturePaint.SAND, alpha))
		_cloud(item, core, CLOUD * ease(gather, 2.0), alpha)
		return
	var throw := phase(t, GATHER, THROW)
	if throw < 1.0:
		var s := ease(throw, 1.5)
		var at := core.lerp(targets[0], s) - Vector2(0.0, ARC * sin(s * PI))
		_cloud(item, at, CLOUD, alpha)
		return
	var burst := phase(t, impact_at(), FADE)
	for i in range(PUFFS.size() * 2):
		var dir := Vector2.RIGHT.rotated(TAU * float(i) / float(PUFFS.size() * 2))
		var at := targets[0] + dir * BURST * ease(burst, 0.4) * Vector2(1.0, 0.6)
		ShapePaint.circle(
			ci, at, 6.0 * (1.0 - burst * 0.5), Color(SignaturePaint.SAND, 0.7 * (1.0 - burst))
		)


## 丸い砂煙の塊。小さな玉を重ねてもこもこさせる。
func _cloud(item: CanvasItem, at: Vector2, size: float, alpha: float) -> void:
	if size <= 1.0:
		return
	var ci := item.get_canvas_item()
	var grow := size / CLOUD
	for p: Vector2 in PUFFS:
		ShapePaint.circle(ci, at + p * grow, size * 0.62, Color(SignaturePaint.SAND_DARK, alpha))
	for p: Vector2 in PUFFS:
		ShapePaint.circle(
			ci, at + p * grow - Vector2(0, 1.5), size * 0.52, Color(SignaturePaint.SAND, alpha)
		)
