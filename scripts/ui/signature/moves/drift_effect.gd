extends SignatureMove
## ドリフトの余砂(GameDesign.md 9章):砕けた台座に残った銘板から砂がほどけて舞い上がり、
## 風に流されるように自分の情報帯(手札の側)へ漂って消える。

const UNRAVEL := 0.24
const DRIFT := 0.56
const GRAINS := 26
## 銘板から舞い上がる高さと、漂う道の横揺れの幅・回数。
const LIFT := 34.0
const SWAY := 26.0
const WAVES := 2.0
## 粒ごとに出発を遅らせる幅(漂う時間に対する割合)。
const STAGGER := 0.35
const RING := Vector2(40.0, 12.0)


func impact_at() -> float:
	return UNRAVEL + DRIFT


func draw(item: CanvasItem, t: float) -> void:
	if targets.is_empty():
		return
	var alpha := fade_alpha(t)
	var lift := ease(phase(t, 0.0, UNRAVEL), 0.4)
	var start := from - Vector2(0.0, LIFT * lift)
	var drift := phase(t, UNRAVEL, DRIFT)
	var travel := targets[0] - start
	var across := travel.orthogonal().normalized()
	for i in range(GRAINS):
		var spread := (SignaturePaint.jitter(i, 21) - 0.5) * 2.0
		var delay := SignaturePaint.jitter(i, 22) * STAGGER
		var q := clampf((drift - delay) / (1.0 - STAGGER), 0.0, 1.0)
		var loose := start + Vector2(spread * 22.0, SignaturePaint.jitter(i, 23) * 10.0 * lift)
		var wave := sin((q * WAVES + SignaturePaint.jitter(i, 24)) * TAU) * SWAY * sin(q * PI)
		var at := loose.lerp(targets[0], ease(q, 0.7)) + across * wave
		var fade := alpha * (1.0 - q * 0.6) * lift
		var color := SignaturePaint.SAND.lerp(
			SignaturePaint.SAND_DARK, SignaturePaint.jitter(i, 25)
		)
		item.draw_circle(at, 1.4 + SignaturePaint.jitter(i, 26) * 1.2, Color(color, fade))
	var ring := phase(t, impact_at(), FADE)
	if ring > 0.0:
		UiPaint.draw_ellipse_ring(
			item.get_canvas_item(),
			targets[0],
			RING * ease(ring, 0.4),
			Color(SignaturePaint.SAND, 0.7 * (1.0 - ring)),
			1.8,
			32
		)
