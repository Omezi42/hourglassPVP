extends SignatureMove
## ウェルの落砂(GameDesign.md 9章):駒の足元に小さな井戸が現れて釣瓶が上がり、汲み上げた金色の砂が
## 対象へ弧を描いて注がれ、届いたところで金色の輪が広がる(恵与)。

const APPEAR := 0.12
const RAISE := 0.22
const POUR := 0.3
const RING := 0.32
## 井戸の置き場所(駒の足元から、台座の右の縁)と、井戸の口・柱の高さ、釣瓶の大きさ。
const SPOT := Vector2(40.0, 2.0)
const MOUTH := Vector2(13.0, 4.5)
const WALL := 8.0
const POST := 30.0
const BUCKET := Vector2(5.0, 6.0)
## 注ぐ砂粒の数と、弧の高さ、粒ごとに出発を遅らせる幅。
const GRAINS := 16
const ARC := 50.0
const STAGGER := 0.4
const STONE := Color(0.6, 0.57, 0.52, 1.0)
const STONE_DARK := Color(0.34, 0.31, 0.28, 1.0)
const WOOD := Color(0.5, 0.33, 0.2, 1.0)


func impact_at() -> float:
	return APPEAR + RAISE + POUR


func duration() -> float:
	return impact_at() + RING


func draw(item: CanvasItem, t: float) -> void:
	if targets.is_empty():
		return
	var ci := item.get_canvas_item()
	var alpha := fade_alpha(t)
	var a := alpha * ease(phase(t, 0.0, APPEAR), 0.5)
	var base := from + Vector2(0.0, CardView.BOARD_ART_SIDE * 0.5) + SPOT
	item.draw_rect(
		Rect2(base - Vector2(MOUTH.x, WALL), Vector2(MOUTH.x * 2.0, WALL)), Color(STONE, a)
	)
	UiPaint.fill_ellipse(ci, base, MOUTH, Color(STONE, a), 20)
	UiPaint.fill_ellipse(ci, base - Vector2(0.0, WALL), MOUTH, Color(STONE_DARK, a), 20)
	UiPaint.draw_ellipse_ring(ci, base - Vector2(0.0, WALL), MOUTH, Color(STONE, a), 2.0, 20)
	var bar_y := base.y - WALL - POST
	for side: float in [-1.0, 1.0]:
		var x := base.x + side * MOUTH.x
		item.draw_line(Vector2(x, base.y - WALL), Vector2(x, bar_y), Color(WOOD, a), 2.6, true)
	item.draw_line(
		Vector2(base.x - MOUTH.x - 2.0, bar_y),
		Vector2(base.x + MOUTH.x + 2.0, bar_y),
		Color(WOOD, a),
		2.6,
		true
	)
	var raise := ease(phase(t, APPEAR, RAISE), 0.7)
	var bucket := Vector2(base.x, lerpf(base.y - WALL, bar_y + BUCKET.y + 4.0, raise))
	item.draw_line(
		Vector2(base.x, bar_y),
		bucket - Vector2(0.0, BUCKET.y),
		Color(UiPalette.OUTLINE_DARK, a),
		1.0
	)
	var pail := PackedVector2Array(
		[
			bucket + Vector2(-BUCKET.x, -BUCKET.y),
			bucket + Vector2(BUCKET.x, -BUCKET.y),
			bucket + Vector2(BUCKET.x * 0.7, BUCKET.y),
			bucket + Vector2(-BUCKET.x * 0.7, BUCKET.y),
		]
	)
	ShapePaint.colored_polygon(ci, pail, Color(WOOD.lightened(0.15), a * minf(raise * 4.0, 1.0)))
	var pour := phase(t, APPEAR + RAISE, POUR)
	if pour > 0.0 and pour < 1.0:
		var mouth := bucket - Vector2(0.0, BUCKET.y)
		for i in range(GRAINS):
			var delay := SignaturePaint.jitter(i, 111) * STAGGER
			var q := clampf((pour - delay) / (1.0 - STAGGER), 0.0, 1.0)
			if q <= 0.0 or q >= 1.0:
				continue
			var s := ease(q, 1.3)
			var at := mouth.lerp(targets[0], s) - Vector2(0.0, ARC * sin(s * PI))
			ShapePaint.circle(ci, at, 1.8, Color(SignaturePaint.BOON, alpha))
	SignaturePaint.boon_ring(item, targets[0], phase(t, impact_at(), RING), alpha)
