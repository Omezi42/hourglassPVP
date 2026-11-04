extends SignatureMove
## 砂礫の雨(GameDesign.md 9章):対象の真上に小石がばらばらと降り、着いたところで火花が散る(打撃)。
## 1回ぶんの着弾ごとに出る(3回なら3つの駒へ順に降る)。

const FALL := 0.34
## 小石の数・落ち始める高さ・横のばらつき・落ちる時間のずれ・大きさ。
const STONES := 6
const DROP := 130.0
const SPREAD := 22.0
const STAGGER := 0.12
const STONE := 3.2
const STONE_COLOR := Color(0.58, 0.5, 0.4, 1.0)


func impact_at() -> float:
	return FALL


func draw(item: CanvasItem, t: float) -> void:
	if targets.is_empty():
		return
	var ci := item.get_canvas_item()
	var alpha := fade_alpha(t)
	var target: Vector2 = targets[0]
	if t >= impact_at():
		SignaturePaint.sparks(item, target, phase(t, impact_at(), FADE), alpha)
		return
	for i in range(STONES):
		var delay := STAGGER * SignaturePaint.jitter(i, 181)
		var fall := ease(phase(t, delay, FALL - delay), 2.0)
		var x := (SignaturePaint.jitter(i, 182) - 0.5) * 2.0 * SPREAD
		var at := target + Vector2(x * (1.0 - fall * 0.6), -DROP * (1.0 - fall))
		item.draw_line(
			at - Vector2(0.0, STONE * 3.0), at, Color(STONE_COLOR, alpha * 0.35), 1.4, true
		)
		ShapePaint.circle(ci, at, STONE, Color(STONE_COLOR, alpha))
