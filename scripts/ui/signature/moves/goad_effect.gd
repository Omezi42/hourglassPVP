extends SignatureMove
## 揺さぶりの一手(GameDesign.md 9章):対象の左右で揺れの弧が交互に3回はね、だんだん大きくなって
## 最後の揺れで対象が返る(反転)。

const SHAKES := 3
const BEAT := 0.17
## 弧の置き場所(対象の中心から左右へ)と、最初と最後の大きさ。
const SIDE := 50.0
const SMALL := 12.0
const LARGE := 26.0
const ARCS := 2
const ARC_GAP := 7.0


func impact_at() -> float:
	return BEAT * SHAKES


func draw(item: CanvasItem, t: float) -> void:
	if targets.is_empty():
		return
	var alpha := fade_alpha(t)
	for i in range(SHAKES):
		var beat := phase(t, BEAT * i, BEAT * 1.6)
		if beat <= 0.0 or beat >= 1.0:
			continue
		var side := 1.0 if i % 2 == 0 else -1.0
		var size := lerpf(SMALL, LARGE, float(i) / float(SHAKES - 1))
		var center := targets[0] + Vector2(side * SIDE, 0.0)
		var spread := ease(beat, 0.4)
		for k in range(ARCS):
			var radius := size * spread + ARC_GAP * k
			var facing := 0.0 if side > 0.0 else PI
			var color := Color(SignaturePaint.SPIN, alpha * (1.0 - beat))
			ShapePaint.arc(
				item.get_canvas_item(),
				center,
				radius,
				facing - 0.7,
				facing + 0.7,
				12,
				color,
				2.4,
				true
			)
