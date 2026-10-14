extends SignatureMove
## リバーブの反転(GameDesign.md 9章):返った駒から音の波紋が広がり、少し遅れて対象の駒で
## 同じ波紋が響き返したところで対象が返る(こだま)。

const CALL := 0.36
## こだまが返り始めるまでの遅れと、響き返す長さ。
const DELAY := 0.2
const ECHO := 0.34
const REACH := 54.0
## こだまは元の波紋より少し弱い。
const ECHO_ALPHA := 0.75


func impact_at() -> float:
	return DELAY + ECHO


func duration() -> float:
	return maxf(CALL, impact_at()) + FADE


func draw(item: CanvasItem, t: float) -> void:
	if targets.is_empty():
		return
	var alpha := fade_alpha(t)
	var call := phase(t, 0.0, CALL)
	if call > 0.0:
		SignaturePaint.ripple(
			item, from, REACH * ease(call, 0.5), alpha * (1.0 - call), SignaturePaint.SPIN
		)
	var echo := phase(t, DELAY, ECHO)
	if echo > 0.0:
		var radius := REACH * ease(echo, 0.5)
		var strength := alpha * ECHO_ALPHA * (1.0 - 0.6 * echo)
		SignaturePaint.ripple(item, targets[0], radius, strength, SignaturePaint.SPIN)
