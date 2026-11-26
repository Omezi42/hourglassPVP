extends SignatureMove
## 刻限(GameDesign.md 9章):撃った位置に炎をまとう時計の文字盤が現れて長針が十二時へ駆け、導火線が味方の駒へ伸びて
## 火の点が一息に駆け、届いた所で爆ぜて火花が散る(砂を体力1まで落とす打撃)。続けて攻撃できるようにする恵与では、
## 駒の足元から駆ける火の筋が前へ走り、金色の輪が広がる。

const TICK := 0.24
const LAY := 0.12
const BURN := 0.18
const DASH := 0.24
## 文字盤の半径と長針の出だし、炎の数・高さ・幅、導火線の波、爆ぜの大きさ、足元の火の筋の長さ・太さ・走る距離。
const DIAL := 20.0
const HAND_FROM := -PI * 1.5
const FLAMES := 5
const FLAME := 14.0
const FLAME_WIDTH := 9.0
const SWAY := 6.0
const BURST := 30.0
const COMET := 50.0
const COMET_WIDTH := 9.0
const REACH := 40.0


func impact_at() -> float:
	return DASH if _readying() else TICK + LAY + BURN


func draw(item: CanvasItem, t: float) -> void:
	if targets.is_empty():
		return
	if _readying():
		_draw_ready(item, t)
		return
	var alpha := fade_alpha(t)
	var tick := phase(t, 0.0, TICK)
	var dial_alpha := alpha * minf(tick * 5.0, 1.0) * (1.0 - phase(t, TICK + LAY, BURN))
	if dial_alpha > 0.0:
		for i in range(FLAMES):
			var a := -PI * 0.5 + (float(i) - float(FLAMES - 1) * 0.5) * 0.42
			var base := from + Vector2.from_angle(a) * DIAL * 0.8
			SignaturePaint.flame_tongue(
				item,
				base,
				FLAME * (0.7 + 0.3 * sin(t * 30.0 + float(i))),
				FLAME_WIDTH,
				cos(a) * 5.0,
				dial_alpha
			)
		SignaturePaint.clock_dial(item, from, DIAL, HAND_FROM * (1.0 - ease(tick, 0.4)), dial_alpha)
	var laid := ease(phase(t, TICK, LAY), 0.6)
	var burnt := phase(t, TICK + LAY, BURN)
	var cord_alpha := alpha * (1.0 - phase(t, impact_at(), FADE * 0.5))
	var land := phase(t, impact_at(), FADE)
	for target in targets:
		SignaturePaint.fuse_cord(item, from, target, laid, burnt, cord_alpha, SWAY)
		SignaturePaint.powder_burst(item, target, land, BURST, alpha)
		SignaturePaint.sparks(item, target, land, alpha)


func _draw_ready(item: CanvasItem, t: float) -> void:
	var alpha := fade_alpha(t)
	var dash := phase(t, 0.0, DASH)
	for target in targets:
		var foot := target + Vector2(0.0, CardView.BOARD_ART_SIDE * 0.3)
		if dash > 0.0 and dash < 1.0:
			var head := foot + Vector2(-REACH * 0.5 + REACH * ease(dash, 0.5), 0.0)
			SignaturePaint.blaze_comet(item, head, Vector2.RIGHT, COMET, COMET_WIDTH, alpha)
		SignaturePaint.boon_ring(item, target, phase(t, impact_at(), FADE), alpha)


func _readying() -> bool:
	return style == CardEnums.EffectVisualStyle.DESCEND
