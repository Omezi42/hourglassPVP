extends SignatureMove
## ゼロアワーの設置(GameDesign.md 9章):相手の列の上に大きな文字盤が現れ、長針と短針が12時に重なった
## 瞬間、各駒の砂がすべて上へ昇る(砂の昇りは進行役が着弾で出す)。

const APPEAR := 0.18
const TURN := 0.62
## 文字盤の半径と目盛りの数。文字盤は自分の駒と相手の列の中間(盤の中央)に置く。
const RADIUS := 42.0
const TICKS := 12
## 針が回り始める向き(12時から時計回りのラジアン)。長針は1周近く、短針は少しだけ戻ってくる。
const MINUTE_FROM := -TAU * 0.92
const HOUR_FROM := -TAU * 0.16


func impact_at() -> float:
	return APPEAR + TURN


func sound() -> int:
	return SoundBank.Sfx.SIG_ZERO_HOUR


func draw(item: CanvasItem, t: float) -> void:
	if targets.is_empty():
		return
	var alpha := fade_alpha(t) * ease(phase(t, 0.0, APPEAR), 0.5)
	var ci := item.get_canvas_item()
	var row := _row_center()
	var center := Vector2(row.x, (row.y + from.y) * 0.5)
	var r := RADIUS * zoom
	ShapePaint.circle(ci, center, r + 3.0, Color(UiPalette.INK_950, alpha * 0.8))
	ShapePaint.circle(ci, center, r, Color(SignaturePaint.DIAL_FACE, alpha))
	ShapePaint.arc(
		ci, center, r - 2.0, 0.0, TAU, 48, Color(SignaturePaint.SAND_DARK, alpha), 2.0, true
	)
	for i in range(TICKS):
		var dir := Vector2.UP.rotated(TAU * float(i) / float(TICKS))
		var inner := 0.72 if i % 3 == 0 else 0.82
		item.draw_line(
			center + dir * r * inner,
			center + dir * r * 0.92,
			Color(UiPalette.INK_950, alpha),
			2.0,
			true
		)
	var turn := back_out(phase(t, APPEAR, TURN))
	_hand(item, center, lerpf(MINUTE_FROM, 0.0, turn), r * 0.82, 2.4 * zoom, alpha)
	_hand(item, center, lerpf(HOUR_FROM, 0.0, turn), r * 0.55, 4.2 * zoom, alpha)
	ShapePaint.circle(ci, center, 4.0 * zoom, Color(SignaturePaint.DIAL_FACE.darkened(0.4), alpha))
	var landed := phase(t, impact_at(), FADE)
	if landed > 0.0:
		ShapePaint.circle(
			ci,
			center,
			r * (1.0 + landed * 0.6),
			Color(SignaturePaint.DIAL_FACE, alpha * 0.35 * (1.0 - landed))
		)
		for target in targets:
			SignaturePaint.rising_grains(item, target, landed, alpha)


func _hand(
	item: CanvasItem, center: Vector2, angle: float, length: float, width: float, alpha: float
) -> void:
	var tip := center + Vector2.UP.rotated(angle) * length
	item.draw_line(center, tip, Color(UiPalette.INK_950, alpha), width, true)


func _row_center() -> Vector2:
	var sum := Vector2.ZERO
	for target in targets:
		sum += target
	return sum / float(targets.size())
