extends SignatureMove
## 逆さ砂(GameDesign.md 9章):砂粒の筋が台座から駒の脇を逆さに昇り、頭上で弧を描いて回り込んだ
## ところで対象が返る。続く総量+1では、頭上から砂粒が1つ降りて金色の輪が広がる。
## 反転(SPIN)と恵与(DESCEND)の2つの効果で呼ばれ、`style` で描き分ける。

const CLIMB := 0.5
const DROP := 0.24
const RING := 0.32
## 筋の道:台座の右の縁から昇り、頭上で左へ回り込む。
const SIDE := 46.0
const OVER := 62.0
const GRAINS := 14
const STREAK := 0.35
const STEPS := 24
const DROP_FROM := 70.0


func impact_at() -> float:
	if style == CardEnums.EffectVisualStyle.SPIN:
		return CLIMB
	return DROP


func duration() -> float:
	if style == CardEnums.EffectVisualStyle.SPIN:
		return impact_at() + FADE
	return impact_at() + RING


func draw(item: CanvasItem, t: float) -> void:
	if targets.is_empty():
		return
	var alpha := fade_alpha(t)
	if style != CardEnums.EffectVisualStyle.SPIN:
		var fall := ease(phase(t, 0.0, DROP), 2.0)
		if fall < 1.0:
			var at := targets[0] - Vector2(0.0, DROP_FROM * (1.0 - fall))
			ShapePaint.circle(item.get_canvas_item(), at, 3.4, Color(SignaturePaint.SAND, alpha))
		SignaturePaint.boon_ring(item, targets[0], phase(t, impact_at(), RING), alpha)
		return
	var head := ease(phase(t, 0.0, CLIMB), 0.8)
	var points := PackedVector2Array()
	var count := maxi(int(STEPS * head), 1)
	for i in range(count + 1):
		points.append(_path(head * float(i) / float(count)))
	ShapePaint.polyline(
		item.get_canvas_item(), points, Color(SignaturePaint.SPIN, alpha * 0.5), 3.0, true
	)
	for i in range(GRAINS):
		var s := head - STREAK * float(i) / float(GRAINS)
		if s <= 0.0:
			continue
		var color := Color(SignaturePaint.SAND, alpha * (1.0 - float(i) / float(GRAINS)))
		ShapePaint.circle(item.get_canvas_item(), _path(s), 2.4, color)


## 筋の道の上で `s`(0→1)進んだ位置。右の縁から真上へ昇り、頭上の半円で左へ回る。
func _path(s: float) -> Vector2:
	var center := targets[0]
	var floor_y := center.y + CardView.BOARD_ART_SIDE * 0.5
	const SPLIT := 0.55
	if s < SPLIT:
		var q := s / SPLIT
		return Vector2(center.x + SIDE, lerpf(floor_y, center.y - OVER * 0.4, q))
	var a := (s - SPLIT) / (1.0 - SPLIT) * PI
	var hub := Vector2(center.x, center.y - OVER * 0.4)
	return hub + Vector2(cos(a) * SIDE, -sin(a) * OVER * 0.6)
