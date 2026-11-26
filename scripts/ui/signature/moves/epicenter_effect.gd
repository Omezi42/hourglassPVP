extends SignatureMove
## 爆心(GameDesign.md 9章):味方の駒に照準のような三重の朱の輪が絞られ、真上から垂れた導火線を火の点が駆け下りて、
## 届いた所で大きく爆ぜ、ひと呼吸おいてもう一度爆ぜる(二度鳴る爆弾。打撃で盤面を揺らす)。

const AIM := 0.26
const DROP := 0.2
const ECHO := 0.18
## 輪の数と最初の大きさ、垂れた導火線の長さと波、1度目と2度目の爆ぜの大きさ。
const RINGS := 3
const AIM_REACH := 60.0
const HANG := 70.0
const SWAY := 4.0
const BURST := 44.0
const ECHO_BURST := 58.0


func impact_at() -> float:
	return AIM + DROP


func duration() -> float:
	return impact_at() + ECHO + FADE * 1.4


func draw(item: CanvasItem, t: float) -> void:
	if targets.is_empty():
		return
	var ci := item.get_canvas_item()
	var alpha := fade_alpha(t)
	var aim := phase(t, 0.0, AIM)
	var shown := alpha * minf(aim * 4.0, 1.0)
	var ring_alpha := shown * (1.0 - phase(t, impact_at(), 0.08))
	var burnt := phase(t, AIM, DROP)
	var cord_alpha := shown * (1.0 - phase(t, impact_at(), FADE * 0.5))
	var land := phase(t, impact_at(), FADE)
	var echo := phase(t, impact_at() + ECHO, FADE * 1.3)
	for target in targets:
		if ring_alpha > 0.0:
			for i in range(RINGS):
				var r := AIM_REACH * (1.0 - 0.3 * float(i)) * lerpf(1.0, 0.45, ease(aim, 0.4))
				ShapePaint.arc(
					ci,
					target,
					r,
					0.0,
					TAU,
					40,
					Color(UiPalette.INK_950, ring_alpha * 0.5),
					4.4,
					true
				)
				ShapePaint.arc(
					ci, target, r, 0.0, TAU, 40, Color(UiPalette.DYNAMITE, ring_alpha), 2.2, true
				)
		var top := target - Vector2(0.0, HANG)
		SignaturePaint.fuse_cord(item, top, target, 1.0, burnt, cord_alpha, SWAY)
		SignaturePaint.powder_burst(item, target, land, BURST, alpha)
		SignaturePaint.sparks(item, target, land, alpha)
		SignaturePaint.powder_burst(item, target, echo, ECHO_BURST, alpha)
