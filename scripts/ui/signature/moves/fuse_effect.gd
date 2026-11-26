extends SignatureMove
## フューズの余砂(GameDesign.md 9章):砕けた台座から麻の導火線が対象の駒へ波打って伸び、火の点が縄を這って届くと、
## 黒色火薬がぎざぎざの閃光で爆ぜて煤の輪が広がり、火花が散る(打撃。盤面を揺らす)。

const SPARK_UP := 0.08
const LAY := 0.16
const BURN := 0.3
## 導火線の波の振れ幅、爆ぜの大きさ、砕けた所で灯る火の点の大きさ。
const SWAY := 7.0
const BURST := 34.0
const IGNITE := 1.4


func impact_at() -> float:
	return SPARK_UP + LAY + BURN


func draw(item: CanvasItem, t: float) -> void:
	if targets.is_empty():
		return
	var alpha := fade_alpha(t)
	var lit := phase(t, 0.0, SPARK_UP)
	if lit > 0.0 and t < SPARK_UP + LAY:
		SignaturePaint.fuse_spark(item, from, IGNITE * zoom * lit, alpha, t * 9.0)
	var laid := ease(phase(t, SPARK_UP, LAY), 0.6)
	var burnt := phase(t, SPARK_UP + LAY, BURN)
	var cord_alpha := alpha * (1.0 - phase(t, impact_at(), FADE * 0.5))
	var land := phase(t, impact_at(), FADE)
	for target in targets:
		SignaturePaint.fuse_cord(item, from, target, laid, burnt, cord_alpha, SWAY)
		SignaturePaint.powder_burst(item, target, land, BURST, alpha)
		SignaturePaint.sparks(item, target, land, alpha)
