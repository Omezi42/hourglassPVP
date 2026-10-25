extends SignatureMove
## エコーの設置(GameDesign.md 9章):駒から音の弧が横へ飛んで跳ね返り、戻ってきたこだまが光の札に
## なって自分の情報帯へ飛ぶ(ドロー)。

const OUT := 0.18
const BACK := 0.18
const FLY := 0.32
## 弧の出る高さ(駒の中心から上へ)と飛ぶ距離・弧の半径、札の大きさ、届いた所の輪。
const LIFT := 30.0
const REACH := 70.0
const WAVE := 16.0
const CARD := 7.0
const GLOW := 30.0


func impact_at() -> float:
	return OUT + BACK + FLY


func draw(item: CanvasItem, t: float) -> void:
	if targets.is_empty():
		return
	var ci := item.get_canvas_item()
	var alpha := fade_alpha(t)
	var origin := from - Vector2(0.0, LIFT)
	var out := phase(t, 0.0, OUT)
	var back := phase(t, OUT, BACK)
	if back <= 0.0:
		var at := origin + Vector2(REACH * ease(out, 0.6), 0.0)
		for k in range(2):
			var r := WAVE * (1.0 + 0.5 * float(k))
			ShapePaint.arc(
				ci,
				at - Vector2(r, 0.0),
				r,
				-0.7,
				0.7,
				12,
				Color(SignaturePaint.BOON, alpha * (1.0 - 0.4 * float(k))),
				2.2,
				true
			)
	elif back < 1.0:
		var at := origin + Vector2(REACH * (1.0 - ease(back, 1.6)), 0.0)
		var r := WAVE * (1.0 - 0.5 * back)
		ShapePaint.arc(
			ci,
			at + Vector2(r, 0.0),
			r,
			PI - 0.7,
			PI + 0.7,
			12,
			Color(SignaturePaint.BOON, alpha),
			2.2,
			true
		)
	var fly := phase(t, OUT + BACK, FLY)
	if fly > 0.0 and fly < 1.0:
		var s := ease(fly, 1.3)
		var at := origin.lerp(targets[0], s) - Vector2(0.0, 30.0 * sin(s * PI))
		SignaturePaint.card_glint(item, at, CARD * minf(fly * 5.0, 1.0), fly * 2.0, alpha)
	var glow := phase(t, impact_at(), FADE)
	if glow > 0.0:
		ShapePaint.arc(
			ci,
			targets[0],
			GLOW * ease(glow, 0.4),
			0.0,
			TAU,
			32,
			Color(SignaturePaint.BOON, 1.0 - glow),
			2.0,
			true
		)
