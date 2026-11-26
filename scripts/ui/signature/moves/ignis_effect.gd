extends SignatureMove
## イグニスの恵与(GameDesign.md 9章):HPを失うたび、駒の頭上で火の鳥が炎の翼を大きく広げて一度羽ばたき、
## 羽根から駆ける火の筋が駒へ降りて、金色の輪が広がる(総量+1)。

const SPREAD := 0.24
const FLAP := 0.2
const RING := 0.3
## 鳥の位置(駒の中心から上へ)、翼の羽根の数・長さ・幅・開く角度、羽ばたく深さ、胴の大きさ。
const LIFT := 58.0
const FEATHERS := 4
const WING := 40.0
const FEATHER_WIDTH := 10.0
const FAN := 0.9
const BEAT := 0.5
const BODY := 7.0
## 駒へ降りる火の筋の数・長さ・太さ。
const DIVES := 2
const COMET := 26.0
const COMET_WIDTH := 7.0


func impact_at() -> float:
	return SPREAD + FLAP


func duration() -> float:
	return impact_at() + RING


func top_extent() -> float:
	return (LIFT + WING) * zoom


func draw(item: CanvasItem, t: float) -> void:
	if targets.is_empty():
		return
	var ci := item.get_canvas_item()
	var alpha := fade_alpha(t)
	var bird := from - Vector2(0.0, LIFT * zoom)
	var spread := ease(phase(t, 0.0, SPREAD), 0.4)
	var flap := sin(phase(t, SPREAD, FLAP) * PI) * BEAT
	var bird_alpha := alpha * minf(spread * 3.0, 1.0)
	for side: float in [-1.0, 1.0]:
		for i in range(FEATHERS):
			# 水平(外)から斜め上へ扇に開く。羽ばたきで下へ振れる
			var a := (FAN * float(i) / float(FEATHERS - 1) - flap) * spread
			var dir := Vector2(side * cos(a), -sin(a))
			var length := WING * zoom * (1.0 - 0.15 * float(i)) * (0.4 + 0.6 * spread)
			SignaturePaint.blaze_comet(
				item, bird + dir * length, dir, length, FEATHER_WIDTH * zoom, bird_alpha
			)
	ShapePaint.circle(ci, bird, (BODY + 2.0) * zoom, Color(UiPalette.FLAME_RED, bird_alpha))
	ShapePaint.circle(ci, bird, BODY * zoom, Color(UiPalette.FLAME, bird_alpha))
	ShapePaint.circle(
		ci,
		bird + Vector2(2.0, -BODY * 1.3) * zoom,
		BODY * 0.6 * zoom,
		Color(SignaturePaint.SPARK_HOT, bird_alpha)
	)
	var dive := phase(t, SPREAD, FLAP)
	if dive > 0.0 and dive < 1.0:
		for i in range(DIVES):
			var start := bird + Vector2((float(i) - 0.5) * 24.0, 0.0) * zoom
			SignaturePaint.blaze_comet(
				item,
				start.lerp(targets[0], ease(dive, 1.6)),
				targets[0] - start,
				COMET * zoom,
				COMET_WIDTH * zoom,
				alpha
			)
	SignaturePaint.boon_ring(item, targets[0], phase(t, impact_at(), RING), alpha)
