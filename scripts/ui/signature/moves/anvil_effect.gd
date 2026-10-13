extends SignatureMove
## アンヴィルの被弾(GameDesign.md 9章):駒の上に金床が現れ、槌が打ち下ろされて火花が散る
## (打たれて鍛え直され、砂が1粒上へ戻る)。

const APPEAR := 0.16
const SWING := 0.2
const SPARK := 0.4
## 金床の置き場所(駒の中心から)と、現れるときに落ちてくる量。
const LIFT := 72.0
const DROP := 10.0
## 槌の握りの位置(金床の上面の中心から)と、振りかぶった角度(打つ向きからの開き)。
## 打つ瞬間は柄が水平で、頭の打面が真下の上面へ当たる。
const GRIP := Vector2(34.0, -9.0)
const STRIKE_X := 4.0
const WINDUP := 1.5
## 金床の形(上面の中心が原点)。左に角(つの)、下に脚。
const ANVIL := [
	Vector2(-26.0, 0.0),
	Vector2(18.0, 0.0),
	Vector2(18.0, 7.0),
	Vector2(10.0, 9.0),
	Vector2(8.0, 17.0),
	Vector2(15.0, 22.0),
	Vector2(16.0, 25.0),
	Vector2(-16.0, 25.0),
	Vector2(-15.0, 22.0),
	Vector2(-8.0, 17.0),
	Vector2(-10.0, 9.0),
	Vector2(-16.0, 6.0),
]
const IRON_TOP := Color(0.56, 0.56, 0.62, 1.0)
const IRON_BOTTOM := Color(0.18, 0.18, 0.22, 1.0)
const HOT := Color(1.0, 0.55, 0.15, 1.0)


func impact_at() -> float:
	return APPEAR + SWING


func duration() -> float:
	return impact_at() + SPARK


func draw(item: CanvasItem, t: float) -> void:
	if targets.is_empty():
		return
	var intro := ease(phase(t, 0.0, APPEAR), 0.5)
	var alpha := intro * fade_alpha(t)
	var top := targets[0] - Vector2(0.0, LIFT + DROP * (1.0 - intro))
	var heat := 1.0 - phase(t, impact_at(), SPARK)
	_anvil(item, top, heat if t >= impact_at() else 0.0, alpha)
	var grip := top + GRIP
	var face := top + Vector2(STRIKE_X, 0.0)
	var strike := (face - Vector2(0.0, SignaturePaint.HAMMER_HEAD.x * 0.5) - grip).angle()
	var swing := ease(phase(t, APPEAR, SWING), 2.6)
	var recoil := 0.18 * sin(phase(t, impact_at(), SPARK * 0.5) * PI)
	SignaturePaint.hammer(item, grip, strike + WINDUP * (1.0 - swing) + recoil, alpha)
	SignaturePaint.sparks(item, face, phase(t, impact_at(), SPARK), alpha)


func _anvil(item: CanvasItem, top: Vector2, heat: float, alpha: float) -> void:
	if alpha <= 0.0:
		return
	var shape := PackedVector2Array()
	for p: Vector2 in ANVIL:
		shape.append(top + p)
	var rect := Rect2(top - Vector2(26.0, 0.0), Vector2(44.0, 25.0))
	UiPaint.fill_gradient_polygon(
		item.get_canvas_item(),
		shape,
		rect,
		[[0.0, Color(IRON_TOP, alpha)], [1.0, Color(IRON_BOTTOM, alpha)]]
	)
	var closed := shape.duplicate()
	closed.append(shape[0])
	item.draw_polyline(closed, Color(UiPalette.OUTLINE_DARK, alpha * 0.85), 1.4, true)
	# 打たれた上面だけが赤く焼け、火花が冷めるのに合わせて鉄の色へ戻る。
	var glow := Color(IRON_TOP.lightened(0.3).lerp(HOT, heat), alpha)
	item.draw_line(top + Vector2(-26.0, 0.5), top + Vector2(18.0, 0.5), glow, 2.4)
