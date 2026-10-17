extends SignatureMove
## ハスクの余砂(GameDesign.md 9章):銘板の上に殻が現れて2つに割れ、中から金色の砂がこぼれて
## 対象へ流れ込み、届いたところで金色の輪が広がる(恵与)。

const APPEAR := 0.12
const CRACK := 0.18
const POUR := 0.34
const RING := 0.32
## 殻の置き場所(銘板から上へ)と大きさ、割れて開く角度と離れる幅。
const LIFT := 30.0
const SHELL := Vector2(15.0, 19.0)
const OPEN_ANGLE := 0.7
const OPEN_GAP := 6.0
## 流れの砂粒の数と、流れの弧の高さ、粒ごとに出発を遅らせる幅。
const GRAINS := 22
const ARC := 40.0
const STAGGER := 0.45
const SHELL_LIGHT := Color(0.78, 0.66, 0.46, 1.0)
const SHELL_DARK := Color(0.45, 0.34, 0.2, 1.0)


func impact_at() -> float:
	return APPEAR + CRACK + POUR


func duration() -> float:
	return impact_at() + RING


func draw(item: CanvasItem, t: float) -> void:
	if targets.is_empty():
		return
	var alpha := fade_alpha(t)
	var center := from - Vector2(0.0, LIFT)
	var appear := ease(phase(t, 0.0, APPEAR), 0.5)
	var crack := back_out(phase(t, APPEAR, CRACK))
	for side: float in [-1.0, 1.0]:
		_half(item, center, side, crack, alpha * appear)
	var pour := phase(t, APPEAR + CRACK * 0.5, POUR + CRACK * 0.5)
	if pour > 0.0 and pour < 1.0:
		for i in range(GRAINS):
			var delay := SignaturePaint.jitter(i, 41) * STAGGER
			var q := clampf((pour - delay) / (1.0 - STAGGER), 0.0, 1.0)
			if q <= 0.0 or q >= 1.0:
				continue
			var s := ease(q, 1.4)
			var spread := (SignaturePaint.jitter(i, 42) - 0.5) * 8.0
			var at := center.lerp(targets[0], s) - Vector2(spread, ARC * sin(s * PI))
			ShapePaint.circle(item.get_canvas_item(), at, 1.8, Color(SignaturePaint.BOON, alpha))
	SignaturePaint.boon_ring(item, targets[0], phase(t, impact_at(), RING), alpha)


## 縦に割れた殻の片方。`open` に応じて外へ傾きながら離れる。
func _half(item: CanvasItem, center: Vector2, side: float, open: float, alpha: float) -> void:
	if alpha <= 0.0:
		return
	var hinge := center + Vector2(side * OPEN_GAP * open, SHELL.y)
	var shape := PackedVector2Array()
	for i in range(13):
		var a := PI * float(i) / 12.0
		var p := Vector2(side * sin(a) * SHELL.x, -cos(a) * SHELL.y - SHELL.y)
		shape.append(hinge + p.rotated(side * OPEN_ANGLE * open))
	var rect := Rect2(
		center - SHELL - Vector2(OPEN_GAP, 0.0), SHELL * 2.0 + Vector2(OPEN_GAP * 2.0, 0.0)
	)
	UiPaint.fill_gradient_polygon(
		item.get_canvas_item(),
		shape,
		rect,
		[[0.0, Color(SHELL_LIGHT, alpha)], [1.0, Color(SHELL_DARK, alpha)]]
	)
	var closed := shape.duplicate()
	closed.append(shape[0])
	ShapePaint.polyline(
		item.get_canvas_item(), closed, Color(UiPalette.OUTLINE_DARK, alpha * 0.8), 1.2, true
	)
