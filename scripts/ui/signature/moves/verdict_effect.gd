extends SignatureMove
## 時の裁き(GameDesign.md 9章):対象の真上に天秤が現れ、攻撃力の側(左)へ傾ききった
## ところで対象が砕ける。

const APPEAR := 0.24
const TIP := 0.4
const TILT := 0.42
const LIFT := 40.0
const DROP := 12.0


func impact_at() -> float:
	return APPEAR + TIP


func draw(item: CanvasItem, t: float) -> void:
	if targets.is_empty():
		return
	var intro := ease(phase(t, 0.0, APPEAR), 0.5)
	var tilt := TILT * back_out(phase(t, APPEAR, TIP))
	var base := targets[0] - Vector2(0.0, LIFT + DROP * (1.0 - intro))
	SignaturePaint.balance(item, base, tilt, intro * fade_alpha(t))
