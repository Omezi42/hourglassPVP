extends SignatureMove
## タイムボムの余砂(GameDesign.md 9章):砕けた台座に時計の文字盤が現れて長針が十二時へ駆け、零時に黒色火薬が
## 大きく爆ぜて、導火線が一息に燃えながら相手の駒それぞれと相手のHPの器へ走り、届いた所で爆ぜて火花が散る(打撃。盤面を揺らす)。

const TICK := 0.3
const BOOM := 0.1
const RUN := 0.2
## 文字盤の半径と長針の出だしの角度、零時の爆ぜの大きさ、走る導火線の波、届いた所の爆ぜの大きさ。
const DIAL := 18.0
const HAND_FROM := -PI * 0.75
const BIG_BURST := 54.0
const SWAY := 5.0
const BURST := 30.0


func impact_at() -> float:
	return TICK + BOOM + RUN


func draw(item: CanvasItem, t: float) -> void:
	if targets.is_empty():
		return
	var ci := item.get_canvas_item()
	var alpha := fade_alpha(t)
	var tick := phase(t, 0.0, TICK)
	var dial_alpha := alpha * minf(tick * 5.0, 1.0) * (1.0 - phase(t, TICK, BOOM))
	if dial_alpha > 0.0:
		ShapePaint.circle(
			ci, from, (DIAL + 5.0) * zoom, Color(UiPalette.DYNAMITE, dial_alpha * 0.35)
		)
		SignaturePaint.clock_dial(
			item, from, DIAL * zoom, HAND_FROM * (1.0 - ease(tick, 0.5)), dial_alpha
		)
	SignaturePaint.powder_burst(
		item, from, phase(t, TICK, BOOM + RUN + FADE), BIG_BURST * zoom, alpha
	)
	var run := phase(t, TICK + BOOM * 0.5, RUN)
	var cord_alpha := alpha * (1.0 - phase(t, impact_at(), FADE * 0.5))
	var land := phase(t, impact_at(), FADE)
	for target in targets:
		if run > 0.0:
			SignaturePaint.fuse_cord(item, from, target, 1.0, run, cord_alpha, SWAY)
		SignaturePaint.powder_burst(item, target, land, BURST, alpha)
		SignaturePaint.sparks(item, target, land, alpha)
