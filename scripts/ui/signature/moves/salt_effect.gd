extends SignatureMove
## ソルトの落砂(GameDesign.md 9章):駒の上に小さな塩の小瓶が現れて2度振られ、白い結晶が弧を
## 描いて対象へ降り、届いたところで金色の輪が広がる(恵与)。

const APPEAR := 0.12
const SHAKE := 0.28
const FLIGHT := 0.28
const RING := 0.32
## 小瓶の置き場所(駒の中心から)と胴・蓋の大きさ、対象の側へ傾ける量と振りの幅。
const LIFT := 66.0
const BODY := Vector2(9.0, 13.0)
const CAP := Vector2(9.5, 4.0)
const TILT := 0.9
const SHAKES := 2
const SHAKE_SWING := 0.35
## 結晶の数と大きさ、飛ぶ弧の高さ、粒ごとに出発を遅らせる幅。
const CRYSTALS := 9
const CRYSTAL := 2.6
const ARC := 34.0
const STAGGER := 0.4
const GLASS := Color(0.92, 0.95, 0.98, 1.0)
const METAL := Color(0.72, 0.74, 0.8, 1.0)


func impact_at() -> float:
	return APPEAR + SHAKE + FLIGHT


func duration() -> float:
	return impact_at() + RING


func draw(item: CanvasItem, t: float) -> void:
	if targets.is_empty():
		return
	var alpha := fade_alpha(t)
	var appear := ease(phase(t, 0.0, APPEAR), 0.5)
	var lean := signf(targets[0].x - from.x) if absf(targets[0].x - from.x) > 1.0 else 1.0
	var shake := phase(t, APPEAR, SHAKE)
	var angle := lean * TILT * ease(minf(shake * 3.0, 1.0), 0.5)
	angle += lean * SHAKE_SWING * sin(shake * TAU * float(SHAKES)) * (1.0 - shake * 0.5)
	var center := from - Vector2(0.0, LIFT)
	var mouth := _shaker(item, center, angle, alpha * appear)
	var flight := phase(t, APPEAR + SHAKE * 0.4, FLIGHT + SHAKE * 0.6)
	if flight > 0.0 and t < impact_at():
		for i in range(CRYSTALS):
			var delay := SignaturePaint.jitter(i, 51) * STAGGER
			var q := clampf((flight - delay) / (1.0 - STAGGER), 0.0, 1.0)
			if q <= 0.0 or q >= 1.0:
				continue
			var s := ease(q, 1.3)
			var spread := (SignaturePaint.jitter(i, 52) - 0.5) * 14.0 * s
			var at := mouth.lerp(targets[0], s) - Vector2(-spread, ARC * sin(s * PI))
			_crystal(item, at, t * 9.0 + float(i), alpha)
	SignaturePaint.boon_ring(item, targets[0], phase(t, impact_at(), RING), alpha)


## 塩の小瓶。胴の中心 `center` から `angle` だけ傾ける。蓋の口の位置を返す。
func _shaker(item: CanvasItem, center: Vector2, angle: float, alpha: float) -> Vector2:
	var up := Vector2.UP.rotated(angle)
	var mouth := center + up * (BODY.y + CAP.y * 2.0)
	if alpha <= 0.0:
		return mouth
	var ci := item.get_canvas_item()
	var body := _box(center, BODY, angle)
	ShapePaint.colored_polygon(ci, body, Color(GLASS, alpha * 0.9))
	var closed := body.duplicate()
	closed.append(body[0])
	ShapePaint.polyline(ci, closed, Color(UiPalette.OUTLINE_DARK, alpha * 0.7), 1.2, true)
	var fill := _box(center + up * -BODY.y * 0.35, Vector2(BODY.x - 2.0, BODY.y * 0.6), angle)
	ShapePaint.colored_polygon(ci, fill, Color(1, 1, 1, alpha))
	var cap := _box(center + up * (BODY.y + CAP.y), CAP, angle)
	ShapePaint.colored_polygon(ci, cap, Color(METAL, alpha))
	var cap_closed := cap.duplicate()
	cap_closed.append(cap[0])
	ShapePaint.polyline(ci, cap_closed, Color(UiPalette.OUTLINE_DARK, alpha * 0.7), 1.0, true)
	return mouth


## 中心と半分の大きさで決まる箱を `angle` だけ傾けた四隅。
func _box(center: Vector2, half: Vector2, angle: float) -> PackedVector2Array:
	var out := PackedVector2Array()
	for corner: Vector2 in [Vector2(-1, -1), Vector2(1, -1), Vector2(1, 1), Vector2(-1, 1)]:
		out.append(center + (corner * half).rotated(angle))
	return out


## 回りながら落ちる小さな菱形の結晶。
func _crystal(item: CanvasItem, at: Vector2, turn: float, alpha: float) -> void:
	var shape := PackedVector2Array()
	for k in range(4):
		shape.append(at + Vector2.UP.rotated(turn + PI * 0.5 * float(k)) * CRYSTAL)
	ShapePaint.colored_polygon(item.get_canvas_item(), shape, Color(1, 1, 1, alpha))
