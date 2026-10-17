extends SignatureMove
## 砂の補給(GameDesign.md 9章):自分の情報帯の上に小さな砂袋が現れて口が開き、砂が2度に分けて
## 手札の側へこぼれ落ちる(2枚引く。静止の型)。

const APPEAR := 0.18
const POUR := 0.26
const POURS := 2
## 袋の置き場所(情報帯の中心から上へ)・大きさと、こぼれた砂が落ちる距離。
const LIFT := 46.0
const SACK := Vector2(17.0, 15.0)
const NECK := Vector2(7.0, 6.0)
const FALL := 70.0
const GRAINS := 9
const TIE := Color(0.55, 0.30, 0.20, 1.0)


func impact_at() -> float:
	return APPEAR + POUR * POURS


func draw(item: CanvasItem, t: float) -> void:
	var ci := item.get_canvas_item()
	var alpha := fade_alpha(t)
	var appear := ease(phase(t, 0.0, APPEAR), 0.5)
	var sack := from - Vector2(0.0, LIFT)
	# 注ぐ間は口を手札の側へ傾ける。
	var tilt := 0.5 * sin(phase(t, APPEAR, POUR * POURS) * PI)
	var mouth := sack + Vector2(0.0, -SACK.y - NECK.y).rotated(PI * _toward_hand() * tilt)
	UiPaint.fill_ellipse(
		ci, sack, SACK * appear + Vector2.ONE, Color(UiPalette.OUTLINE_DARK, alpha), 20
	)
	UiPaint.fill_ellipse(ci, sack, SACK * appear, Color(SignaturePaint.SAND_DARK, alpha), 20)
	if appear >= 1.0:
		item.draw_line(sack, mouth, Color(SignaturePaint.SAND_DARK, alpha), NECK.x * 1.6)
		ShapePaint.circle(
			item.get_canvas_item(), sack.lerp(mouth, 0.55), NECK.y * 0.5, Color(TIE, alpha)
		)
	for pour in range(POURS):
		var q := phase(t, APPEAR + POUR * pour, POUR + FADE)
		if q <= 0.0 or q >= 1.0:
			continue
		for i in range(GRAINS):
			var s := q - float(i) / float(GRAINS) * 0.45
			if s <= 0.0 or s >= 1.0:
				continue
			var drift := (SignaturePaint.jitter(i + pour * GRAINS, 17) - 0.5) * 12.0
			var at := mouth + Vector2(drift, _toward_hand() * FALL * s * s)
			ShapePaint.circle(
				item.get_canvas_item(), at, 2.0, Color(SignaturePaint.SAND, alpha * (1.0 - s))
			)


## 手札のある向き(1=下、-1=上)。情報帯が卓の下半分なら自分の側。
func _toward_hand() -> float:
	return 1.0 if from.y > CardMatchLayout.current().table_rect.get_center().y else -1.0
