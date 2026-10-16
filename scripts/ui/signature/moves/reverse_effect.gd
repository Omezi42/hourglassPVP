extends SignatureMove
## 時の逆流(GameDesign.md 9章):自分のHPの器の上に光の砂時計が現れて上下に半回転し、返りきった
## 瞬間に残りHPと失ったHPが入れ替わる。その後、上へ回った砂が下へ流れ落ちる(反転)。

const APPEAR := 0.18
const FLIP := 0.38
const POUR := 0.3
## 砂時計の置き場所(HPの器の中心から上へ)と、横・縦の半分の大きさ、くびれの幅。
const LIFT := 44.0
const HALF := Vector2(15.0, 21.0)
const NECK := 2.0
## 返す前に下の部屋を満たしている砂の割合。
const FILL := 0.75


func impact_at() -> float:
	return APPEAR + FLIP


func duration() -> float:
	return impact_at() + POUR + FADE


func draw(item: CanvasItem, t: float) -> void:
	if targets.is_empty():
		return
	var alpha := fade_alpha(t) * ease(phase(t, 0.0, APPEAR), 0.5)
	if alpha <= 0.0:
		return
	var center := targets[0] - Vector2(0.0, LIFT)
	var turn := back_out(phase(t, APPEAR, FLIP)) * PI
	var sand := Color(SignaturePaint.SAND, alpha)
	if t < impact_at():
		_polygon(item, center, turn, _lower(FILL), sand)
	else:
		var pour := phase(t, impact_at(), POUR)
		var flipped := PI
		_polygon(item, center, flipped, _upper_resting(FILL * (1.0 - pour)), sand)
		_polygon(item, center, 0.0, _lower(FILL * pour), sand)
		if pour < 1.0:
			item.draw_line(center, center + Vector2(0.0, HALF.y), sand, 1.4)
	var glass := PackedVector2Array(
		[
			Vector2(-HALF.x, -HALF.y),
			Vector2(HALF.x, -HALF.y),
			Vector2(NECK, 0.0),
			Vector2(HALF.x, HALF.y),
			Vector2(-HALF.x, HALF.y),
			Vector2(-NECK, 0.0),
			Vector2(-HALF.x, -HALF.y),
		]
	)
	var outline := PackedVector2Array()
	for p in glass:
		outline.append(center + p.rotated(turn))
	item.draw_polyline(outline, Color(UiPalette.OUTLINE_DARK, alpha * 0.7), 3.6, true)
	item.draw_polyline(outline, Color(SignaturePaint.SPIN, alpha), 1.8, true)
	for y: float in [-HALF.y, HALF.y]:
		var a := center + Vector2(-HALF.x - 3.0, y).rotated(turn)
		var b := center + Vector2(HALF.x + 3.0, y).rotated(turn)
		item.draw_line(a, b, Color(UiPalette.BRASS_HIGHLIGHT, alpha), 3.0)


## 下の部屋の底から `amount`(0→1)まで溜まった砂の形(砂時計の中心から見た座標)。
func _lower(amount: float) -> PackedVector2Array:
	var top := HALF.y * (1.0 - amount)
	return PackedVector2Array(
		[
			Vector2(-_width(top), top),
			Vector2(_width(top), top),
			Vector2(HALF.x, HALF.y),
			Vector2(-HALF.x, HALF.y),
		]
	)


## 返した後の上の部屋で、くびれの上に `amount` だけ残った砂の形。半回転させて描くため、
## ここではくびれから下へ向けた座標で持つ。
func _upper_resting(amount: float) -> PackedVector2Array:
	var reach := HALF.y * amount
	return PackedVector2Array(
		[
			Vector2(-NECK, 0.0),
			Vector2(NECK, 0.0),
			Vector2(_width(reach), reach),
			Vector2(-_width(reach), reach)
		]
	)


func _width(y: float) -> float:
	return lerpf(NECK, HALF.x, absf(y) / HALF.y)


func _polygon(
	item: CanvasItem, center: Vector2, turn: float, shape: PackedVector2Array, color: Color
) -> void:
	if absf(shape[0].y - shape[2].y) < 0.5:
		return
	var points := PackedVector2Array()
	for p in shape:
		points.append(center + p.rotated(turn))
	item.draw_colored_polygon(points, color)
