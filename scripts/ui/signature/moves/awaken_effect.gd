extends SignatureMove
## 目覚めの砂(GameDesign.md 9章):空いた台座へ砂が渦を巻いて集まり、砂時計の輪郭が下から
## 形になっていき、固まったところで駒が現れる(恵与)。

const SWIRL := 0.4
const FORM := 0.34
const GRAINS := 34
## 渦の始まりの半径(卓の奥行きに合わせて縦を潰す)と回る量。
const SWIRL_RADIUS := 90.0
const SQUASH := 0.45
const TURNS := 1.25
## 輪郭の砂時計(駒の中心が原点)。上の口・くびれ・下の口の半幅と高さ。
const GLASS_HALF := Vector2(30.0, 48.0)
const WAIST := 4.0
const STEPS := 16


func impact_at() -> float:
	return SWIRL + FORM


func draw(item: CanvasItem, t: float) -> void:
	if targets.is_empty():
		return
	var alpha := fade_alpha(t)
	var center := targets[0]
	var swirl := phase(t, 0.0, SWIRL + FORM * 0.5)
	for i in range(GRAINS):
		var delay := SignaturePaint.jitter(i, 41) * 0.4
		var q := clampf((swirl - delay) / (1.0 - 0.4), 0.0, 1.0)
		if q <= 0.0 or q >= 1.0:
			continue
		var angle := SignaturePaint.jitter(i, 42) * TAU + q * TURNS * TAU
		var radius := SWIRL_RADIUS * (1.0 - ease(q, 0.6))
		var at := center + Vector2(cos(angle), sin(angle) * SQUASH) * radius
		var color := SignaturePaint.SAND.lerp(
			SignaturePaint.SAND_DARK, SignaturePaint.jitter(i, 43)
		)
		ShapePaint.circle(item.get_canvas_item(), at, 1.8, Color(color, alpha * minf(q * 4.0, 1.0)))
	var form := ease(phase(t, SWIRL, FORM), 0.6)
	if form > 0.0:
		_outline(item, center, form, alpha)
	SignaturePaint.boon_ring(item, center, phase(t, impact_at(), FADE), alpha)


## 砂時計の輪郭を下から `form` の割合まで描く。左右の線を下の口からくびれ、上の口へ伸ばす。
func _outline(item: CanvasItem, center: Vector2, form: float, alpha: float) -> void:
	var count := maxi(int(STEPS * form), 1)
	for side: float in [-1.0, 1.0]:
		var points := PackedVector2Array()
		for i in range(count + 1):
			var s := form * float(i) / float(count)
			var y := GLASS_HALF.y * (1.0 - 2.0 * s)
			var half := lerpf(WAIST, GLASS_HALF.x, absf(1.0 - 2.0 * s))
			points.append(center + Vector2(side * half, y))
		ShapePaint.polyline(
			item.get_canvas_item(), points, Color(SignaturePaint.BOON, alpha * 0.9), 2.2, true
		)
	var foot := center + Vector2(0.0, GLASS_HALF.y)
	item.draw_line(
		foot - Vector2(GLASS_HALF.x, 0.0),
		foot + Vector2(GLASS_HALF.x, 0.0),
		Color(SignaturePaint.BOON, alpha),
		2.6
	)
	if form >= 1.0:
		var head := center - Vector2(0.0, GLASS_HALF.y)
		item.draw_line(
			head - Vector2(GLASS_HALF.x, 0.0),
			head + Vector2(GLASS_HALF.x, 0.0),
			Color(SignaturePaint.BOON, alpha),
			2.6
		)
