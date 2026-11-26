extends SignatureMove
## ディガーの設置(GameDesign.md 9章):駒の足元の脇につるはしが現れて2度打ち下ろされ、そのたびに土くれが跳ねる。
## 2度目で素焼きの壺が掘り出されて光り、山なりに自分の情報帯(手札の側)へ飛んで、届いたところで光の輪が広がる(静止)。

const SWING := 0.17
const SWINGS := 2
const UNEARTH := 0.1
const FLY := 0.3
## 打つ所(駒の中心から)、柄の握り(打つ所から)と長さ、振りかぶった角度、壺の大きさ・飛ぶ弧の高さ、土くれの数と跳ね。
const DIG := Vector2(18.0, 52.0)
const GRIP := Vector2(-34.0, -4.0)
const HANDLE := 40.0
const RAISED := -2.3
const JAR := Vector2(9.0, 10.0)
const ARC := 70.0
const CLODS := 6
const KICK := 26.0


func impact_at() -> float:
	return SWING * float(SWINGS) + UNEARTH + FLY


func draw(item: CanvasItem, t: float) -> void:
	if targets.is_empty():
		return
	var alpha := fade_alpha(t)
	var dig := from + DIG * zoom
	var grip := dig + GRIP * zoom
	var swinging := t < SWING * float(SWINGS)
	if swinging or t < SWING * float(SWINGS) + UNEARTH:
		var k := fmod(t, SWING) / SWING if swinging else 1.0
		var strike_angle := (dig - grip).angle()
		var angle := lerpf(RAISED, strike_angle, ease(k, 2.4))
		_pick(item, grip, angle, alpha)
	for n in range(SWINGS):
		var kick := phase(t, SWING * float(n + 1) - 0.02, 0.22)
		_clods(item, dig, kick, alpha, n)
	var out := phase(t, SWING * float(SWINGS), UNEARTH)
	var fly := phase(t, SWING * float(SWINGS) + UNEARTH, FLY)
	var target := targets[0]
	if out > 0.0 and t < impact_at():
		var at := dig.lerp(target, ease(fly, 0.8)) - Vector2(0.0, ARC * sin(fly * PI) + 10.0 * out)
		_jar(item, at, zoom * (1.0 - 0.3 * fly), alpha * out)
		ForesightPaint.next_star(
			item, at + Vector2(-6.0, -6.0) * zoom, 0.5 * zoom, alpha * out, t * 4.0
		)
	if t >= impact_at():
		var lit := phase(t, impact_at(), FADE)
		SignaturePaint.pulse_ring(item, target, lit, alpha)


func _pick(item: CanvasItem, grip: Vector2, angle: float, alpha: float) -> void:
	var dir := Vector2.from_angle(angle)
	var head := grip + dir * HANDLE * zoom
	item.draw_line(grip, head, Color(UiPalette.BRASS_INK, alpha), 5.0, true)
	item.draw_line(grip, head, Color(UiPalette.BIRCH, alpha), 3.2, true)
	var across := dir.orthogonal()
	var blade := PackedVector2Array()
	for i in range(9):
		var s := (float(i) / 8.0 - 0.5) * 2.0
		blade.append(head + across * s * 14.0 * zoom - dir * s * s * 5.0 * zoom)
	ShapePaint.polyline(item.get_canvas_item(), blade, Color(UiPalette.INK_950, alpha), 6.0, true)
	ShapePaint.polyline(item.get_canvas_item(), blade, Color(UiPalette.STEEL, alpha), 3.6, true)


func _clods(item: CanvasItem, at: Vector2, kick: float, alpha: float, salt: int) -> void:
	if kick <= 0.0 or kick >= 1.0:
		return
	var ci := item.get_canvas_item()
	for i in range(CLODS):
		var spread := (SignaturePaint.jitter(i, 51 + salt) - 0.5) * 2.0
		var up := KICK * (0.6 + 0.4 * SignaturePaint.jitter(i, 52 + salt)) * zoom
		var p := at + Vector2(spread * KICK * kick * zoom, -up * sin(kick * PI))
		ShapePaint.circle(ci, p, 2.6 * zoom, Color(UiPalette.EARTH, alpha * (1.0 - kick)))


func _jar(item: CanvasItem, at: Vector2, scale: float, alpha: float) -> void:
	if alpha <= 0.0:
		return
	var ci := item.get_canvas_item()
	var body := PackedVector2Array()
	for i in range(16):
		var a := TAU * float(i) / 16.0
		body.append(at + Vector2(cos(a) * JAR.x, sin(a) * JAR.y) * scale)
	var neck := at - Vector2(0.0, JAR.y) * scale
	item.draw_line(
		neck, neck - Vector2(0.0, 6.0) * scale, Color(UiPalette.INK_950, alpha), 8.0 * scale, true
	)
	item.draw_line(
		neck, neck - Vector2(0.0, 6.0) * scale, Color(UiPalette.CLAY, alpha), 5.5 * scale, true
	)
	ShapePaint.convex_polygon(
		ci, ForesightPaint.grown(body, at, 1.6), Color(UiPalette.INK_950, alpha)
	)
	ShapePaint.convex_polygon(ci, body, Color(UiPalette.CLAY, alpha))
	ShapePaint.circle(
		ci, at + Vector2(-3.0, -3.0) * scale, 2.4 * scale, Color(UiPalette.GOLD_HI, alpha * 0.7)
	)
