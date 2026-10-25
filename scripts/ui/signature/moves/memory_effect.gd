extends SignatureMove
## メモリーの落砂(GameDesign.md 9章):駒の上に思い出の泡が浮かび、中で光の札がゆらめいてから、泡ごと
## 自分の情報帯へ漂っていく(ドロー)。

const RISE := 0.2
const HOLD := 0.16
const DRIFT := 0.38
## 泡が止まる高さ(駒の中心から上へ)と大きさ、漂う揺れの幅・回数、札の大きさ、はじけた輪。
const LIFT := 64.0
const BUBBLE := 15.0
const SWAY := 14.0
const WAVES := 1.5
const CARD := 6.0
const POP := 30.0
const FILM := Color(0.86, 0.9, 1.0, 1.0)


func impact_at() -> float:
	return RISE + HOLD + DRIFT


func draw(item: CanvasItem, t: float) -> void:
	if targets.is_empty():
		return
	var ci := item.get_canvas_item()
	var alpha := fade_alpha(t)
	var rise := ease(phase(t, 0.0, RISE), 0.6)
	var hover := from - Vector2(0.0, LIFT * rise)
	var drift := phase(t, RISE + HOLD, DRIFT)
	if drift < 1.0:
		var s := ease(drift, 1.2)
		var at := hover.lerp(targets[0], s)
		at.x += sin(drift * PI * WAVES) * SWAY * (1.0 - s)
		var size := BUBBLE * (0.3 + 0.7 * rise) * (1.0 - 0.3 * s)
		ShapePaint.circle(ci, at, size, Color(FILM, alpha * 0.18))
		ShapePaint.arc(ci, at, size, 0.0, TAU, 28, Color(FILM, alpha * 0.9), 1.6, true)
		ShapePaint.arc(
			ci, at, size * 0.7, PI * 1.1, PI * 1.45, 6, Color(1, 1, 1, alpha * 0.8), 1.6, true
		)
		var wobble := sin(t * 18.0) * 0.25
		SignaturePaint.card_glint(item, at, CARD * rise * (1.0 - 0.3 * s), wobble, alpha)
		return
	var pop := phase(t, impact_at(), FADE)
	ShapePaint.arc(
		ci, targets[0], POP * ease(pop, 0.4), 0.0, TAU, 32, Color(FILM, 1.0 - pop), 2.0, true
	)
