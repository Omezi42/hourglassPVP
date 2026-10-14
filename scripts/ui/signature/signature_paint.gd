class_name SignaturePaint
extends RefCounted
## カードの演出(GameDesign.md 9章)で使う絵の部品。鐘・天秤・歯車の輪・砂の帯・昇る砂粒・
## 雪の結晶・水滴・ばね・槌・火花・時計の文字盤・恵与の輪をコードで描く。
## 進行(いつ何をどれだけ描くか)は `moves/` の各カードが持ち、
## ここは「この形をこの状態で描く」だけを受け持つ。

const SAND := Color(0.93, 0.78, 0.42, 1.0)
const SAND_DARK := Color(0.62, 0.45, 0.22, 1.0)
const BELL_WIDTH := 34.0
const BELL_HEIGHT := 36.0
const SCALE_BEAM := 76.0
const SCALE_POST := 54.0
const SCALE_CHAIN := 26.0
const SCALE_PAN := Vector2(17.0, 5.0)
const GEAR_TEETH := 18
const GEAR_TOOTH := 7.0
## 恵与の型(`EmblemStrikeFx` の DESCEND)と同じ金色。恵与の演出が届いた印に使う。
const BOON := Color(1.0, 0.92, 0.62, 1.0)
## 反転の型(`EmblemStrikeFx` の SPIN)と同じ淡い水色。反転させる演出が届く印に使う。
const SPIN := Color(0.78, 0.92, 1.0, 1.0)
const ICE := Color(0.80, 0.93, 1.0, 1.0)
const WATER := Color(0.60, 0.87, 1.0, 1.0)
const SPARK_HOT := Color(1.0, 0.97, 0.80, 1.0)
const SPARK_COOL := Color(1.0, 0.62, 0.20, 1.0)
const DIAL_FACE := Color(0.96, 0.92, 0.82, 1.0)
const HAMMER_HANDLE := 30.0
const HAMMER_HEAD := Vector2(18.0, 10.0)


## 吊られた鐘。`swing` は支点まわりの傾き(ラジアン)。支点は `pivot`。
static func bell(item: CanvasItem, pivot: Vector2, swing: float, alpha: float) -> void:
	if alpha <= 0.0:
		return
	var ci := item.get_canvas_item()
	var w := BELL_WIDTH * 0.5
	var h := BELL_HEIGHT
	var outline := PackedVector2Array(
		[
			Vector2(-w * 0.22, 0.0),
			Vector2(w * 0.22, 0.0),
			Vector2(w * 0.5, h * 0.18),
			Vector2(w * 0.62, h * 0.55),
			Vector2(w * 0.86, h * 0.86),
			Vector2(w, h),
			Vector2(-w, h),
			Vector2(-w * 0.86, h * 0.86),
			Vector2(-w * 0.62, h * 0.55),
			Vector2(-w * 0.5, h * 0.18),
		]
	)
	var shape := _rotated(outline, pivot + Vector2(0.0, 6.0), swing)
	var rect := Rect2(pivot - Vector2(w, 0.0), Vector2(w * 2.0, h + 6.0))
	(
		UiPaint
		. fill_gradient_polygon(
			ci,
			shape,
			rect,
			[
				[0.0, Color(UiPalette.BRASS_HIGHLIGHT, alpha)],
				[0.6, Color(UiPalette.BRASS_LIGHT, alpha)],
				[1.0, Color(UiPalette.BRASS_DARK, alpha)],
			]
		)
	)
	var closed := shape.duplicate()
	closed.append(shape[0])
	item.draw_polyline(closed, Color(UiPalette.OUTLINE_DARK, alpha * 0.8), 1.2, true)
	# 鐘は支点から逆に振れる舌を持つ。遅れて振れる分だけ鐘の内側で揺れて見える。
	var clapper := pivot + Vector2(0.0, 6.0) + Vector2(0.0, h * 0.92).rotated(swing * 0.4)
	UiPaint.fill_circle(ci, clapper, 3.4, Color(UiPalette.BRASS_DARK, alpha), 12)
	item.draw_line(pivot, pivot + Vector2(0.0, 6.0), Color(UiPalette.BRASS_DARK, alpha), 2.0)
	UiPaint.fill_circle(ci, pivot, 3.0, Color(UiPalette.BRASS_HIGHLIGHT, alpha), 10)


## 鐘の音の波紋。間を空けた3重の輪が、外側ほど濃く広がる。
static func ripple(
	item: CanvasItem,
	center: Vector2,
	radius: float,
	alpha: float,
	color := Color(1.0, 0.88, 0.58, 1.0)
) -> void:
	const RINGS := 3
	const GAP := 16.0
	if alpha <= 0.0:
		return
	for i in range(RINGS):
		var r := radius - GAP * float(i)
		if r <= 0.0:
			continue
		var a := alpha * (1.0 - float(i) / float(RINGS))
		item.draw_arc(center, r, 0.0, TAU, 72, Color(color, a * 0.7), 2.4 - 0.6 * i, true)


## 天秤。`tilt` が正なら左の皿(攻撃力の側)が下がる。
static func balance(item: CanvasItem, base: Vector2, tilt: float, alpha: float) -> void:
	if alpha <= 0.0:
		return
	var ci := item.get_canvas_item()
	var brass := Color(UiPalette.BRASS_HIGHLIGHT, alpha)
	var dark := Color(UiPalette.OUTLINE_DARK, alpha * 0.8)
	var top := base - Vector2(0.0, SCALE_POST)
	item.draw_line(base, top, dark, 4.0)
	item.draw_line(base, top, brass, 2.4)
	UiPaint.fill_ellipse(ci, base, Vector2(14.0, 4.0), brass, 20)
	var arm := Vector2(SCALE_BEAM * 0.5, 0.0).rotated(-tilt)
	item.draw_line(top - arm, top + arm, dark, 4.4)
	item.draw_line(top - arm, top + arm, brass, 2.8)
	UiPaint.fill_circle(ci, top, 4.0, brass, 12)
	for end in [top - arm, top + arm]:
		var pan: Vector2 = end + Vector2(0.0, SCALE_CHAIN)
		item.draw_line(end, pan + Vector2(-SCALE_PAN.x, 0.0), Color(brass, alpha * 0.7), 1.0)
		item.draw_line(end, pan + Vector2(SCALE_PAN.x, 0.0), Color(brass, alpha * 0.7), 1.0)
		UiPaint.fill_ellipse(ci, pan + Vector2(0.0, 2.0), SCALE_PAN, brass, 20)
		UiPaint.draw_ellipse_ring(ci, pan + Vector2(0.0, 2.0), SCALE_PAN, dark, 1.0, 20)


## 台座を囲む歯車の輪。卓の奥行きに合わせた楕円の上へ歯を並べる。
## `turn` は回った量(ラジアン)、`grow` は輪の広がり(0→1)。
static func gear_ring(
	item: CanvasItem, center: Vector2, radius: Vector2, turn: float, alpha: float
) -> void:
	if alpha <= 0.0:
		return
	var ci := item.get_canvas_item()
	var brass := Color(UiPalette.BRASS_HIGHLIGHT, alpha)
	UiPaint.draw_ellipse_ring(ci, center, radius, Color(UiPalette.OUTLINE_DARK, alpha), 4.0, 56)
	UiPaint.draw_ellipse_ring(ci, center, radius, brass, 2.4, 56)
	var squash := radius.y / radius.x
	for i in range(GEAR_TEETH):
		var angle := turn + TAU * float(i) / float(GEAR_TEETH)
		var dir := Vector2(cos(angle), sin(angle))
		var inner := center + Vector2(dir.x * radius.x, dir.y * radius.y)
		var outer := inner + Vector2(dir.x, dir.y * squash) * GEAR_TOOTH
		# 奥(上半分)の歯は暗く、手前は明るく描いて輪が寝ていることを見せる。
		var shade := 0.55 + 0.45 * clampf(dir.y * 0.5 + 0.5, 0.0, 1.0)
		item.draw_line(
			inner, outer, Color(brass.r * shade, brass.g * shade, brass.b * shade, alpha), 3.6
		)


## 横殴りの砂の帯。`front` は帯の先頭のx、`rect` は帯が吹き抜ける範囲。
static func sand_band(item: CanvasItem, rect: Rect2, front: float, alpha: float) -> void:
	if alpha <= 0.0:
		return
	const GRAINS := 90
	const STREAK := 22.0
	const TAIL := 260.0
	for i in range(GRAINS):
		var lane := _hash(i, 1)
		var lag := _hash(i, 2) * TAIL
		var x := front - lag
		if x < rect.position.x or x > rect.end.x:
			continue
		var wave := sin((x + _hash(i, 3) * 200.0) * 0.03) * 8.0
		var y := rect.position.y + lane * rect.size.y + wave
		var fade := alpha * (1.0 - lag / TAIL)
		var color := SAND.lerp(SAND_DARK, _hash(i, 4))
		var length := STREAK * (0.5 + _hash(i, 5))
		item.draw_line(Vector2(x - length, y), Vector2(x, y), Color(color, fade * 0.8), 1.6)
	var ci := item.get_canvas_item()
	var mist := Rect2(front - TAIL, rect.position.y, TAIL, rect.size.y).intersection(rect)
	if mist.size.x > 0.0:
		UiPaint.fill_gradient_polygon(
			ci,
			PackedVector2Array(
				[
					mist.position,
					Vector2(mist.end.x, mist.position.y),
					mist.end,
					Vector2(mist.position.x, mist.end.y)
				]
			),
			mist,
			[[0.0, Color(SAND, 0.0)], [0.5, Color(SAND, alpha * 0.18)], [1.0, Color(SAND, 0.0)]]
		)


## 駒から上へ昇る砂粒。`progress` は0→1の進み。
static func rising_grains(item: CanvasItem, center: Vector2, progress: float, alpha: float) -> void:
	if alpha <= 0.0:
		return
	const COUNT := 10
	const SPAN := 70.0
	for i in range(COUNT):
		var start := _hash(i, 7) * 0.5
		var local := clampf((progress - start) / (1.0 - start), 0.0, 1.0)
		if local <= 0.0 or local >= 1.0:
			continue
		var x := center.x + (_hash(i, 8) - 0.5) * 50.0
		var y := center.y + 40.0 - local * SPAN
		item.draw_circle(Vector2(x, y), 1.8, Color(SAND, alpha * (1.0 - local)))


## 恵与が届いた印の金色の輪。`progress` は0→1で広がりながら薄れる。
static func boon_ring(item: CanvasItem, center: Vector2, progress: float, alpha: float) -> void:
	const REACH := 38.0
	if alpha <= 0.0 or progress <= 0.0 or progress >= 1.0:
		return
	var radius := REACH * ease(progress, 0.4)
	item.draw_arc(
		center, radius, 0.0, TAU, 40, Color(BOON, alpha * 0.75 * (1.0 - progress)), 2.4, true
	)


## 雪の結晶。6本の腕にそれぞれ2対の小枝を付ける。`turn` は回った量(ラジアン)。
static func snowflake(
	item: CanvasItem, center: Vector2, radius: float, turn: float, alpha: float
) -> void:
	const TWIGS := [0.42, 0.7]
	const TWIG_ANGLE := 0.8
	if alpha <= 0.0 or radius <= 0.5:
		return
	var color := Color(ICE, alpha)
	for i in range(6):
		var dir := Vector2.UP.rotated(turn + TAU * float(i) / 6.0)
		item.draw_line(center, center + dir * radius, color, 1.6, true)
		for k: float in TWIGS:
			var root := center + dir * radius * k
			var twig := radius * (1.0 - k) * 0.6
			item.draw_line(root, root + dir.rotated(TWIG_ANGLE) * twig, color, 1.2, true)
			item.draw_line(root, root + dir.rotated(-TWIG_ANGLE) * twig, color, 1.2, true)
	UiPaint.fill_circle(item.get_canvas_item(), center, radius * 0.16, Color(1, 1, 1, alpha), 12)


## しずく形の水滴。`heading` は進む向きで、尾はその反対へ伸びる。
static func water_drop(
	item: CanvasItem, at: Vector2, radius: float, heading: Vector2, alpha: float
) -> void:
	const TAIL := 2.2
	if alpha <= 0.0 or radius <= 0.3:
		return
	var ci := item.get_canvas_item()
	var back := -heading.normalized() if heading.length() > 0.001 else Vector2.UP
	var side := Vector2(-back.y, back.x)
	var shape := PackedVector2Array()
	shape.append(at + back * radius * TAIL)
	for i in range(13):
		var a := PI * float(i) / 12.0
		shape.append(at + side * cos(a) * radius - back * sin(a) * radius)
	var rect := Rect2(at - Vector2.ONE * radius * TAIL, Vector2.ONE * radius * TAIL * 2.0)
	UiPaint.fill_gradient_polygon(
		ci, shape, rect, [[0.0, Color(1, 1, 1, alpha)], [1.0, Color(WATER, alpha)]]
	)
	UiPaint.fill_circle(
		ci, at - back * radius * 0.3 + side * radius * 0.35, radius * 0.28, Color(1, 1, 1, alpha), 8
	)


## 伸び縮みするばね。`a` から `b` へ `turns` 巻き。奥の線を先に暗く細く、手前を後から
## 明るく太く描いて巻きの重なりを見せる。
static func coil(
	item: CanvasItem, a: Vector2, b: Vector2, turns: int, radius: float, alpha: float
) -> void:
	const STEPS_PER_TURN := 14
	const LEAN := 0.35
	var axis := b - a
	if alpha <= 0.0 or axis.length() < 0.5:
		return
	var dir := axis.normalized()
	var normal := Vector2(-dir.y, dir.x)
	var steps := turns * STEPS_PER_TURN
	var points: Array[Vector2] = []
	for i in range(steps + 1):
		var s := float(i) / float(steps)
		var angle := TAU * float(turns) * s
		points.append(
			a + axis * s + dir * cos(angle) * radius * LEAN + normal * sin(angle) * radius
		)
	for front: bool in [false, true]:
		var color := UiPalette.BRASS_HIGHLIGHT if front else UiPalette.BRASS_DARK
		for i in range(steps):
			var angle := TAU * float(turns) * (float(i) + 0.5) / float(steps)
			if (cos(angle) > 0.0) != front:
				continue
			item.draw_line(
				points[i], points[i + 1], Color(color, alpha), 2.6 if front else 1.6, true
			)


## 槌。`pivot` は柄の握り、`angle` は柄の向き(ラジアン)。頭は柄の先で柄と直交する。
static func hammer(item: CanvasItem, pivot: Vector2, angle: float, alpha: float) -> void:
	if alpha <= 0.0:
		return
	var dir := Vector2.from_angle(angle)
	var across := dir.orthogonal()
	var head := pivot + dir * HAMMER_HANDLE
	item.draw_line(pivot, head, Color(UiPalette.OUTLINE_DARK, alpha * 0.8), 4.6)
	item.draw_line(pivot, head, Color(UiPalette.WOOD_TOP.lightened(0.3), alpha), 3.0)
	var half_long := across * HAMMER_HEAD.x * 0.5
	var half_short := dir * HAMMER_HEAD.y * 0.5
	var shape := PackedVector2Array(
		[
			head - half_long - half_short,
			head + half_long - half_short,
			head + half_long + half_short,
			head - half_long + half_short,
		]
	)
	var rect := Rect2(head - Vector2.ONE * HAMMER_HEAD.x, Vector2.ONE * HAMMER_HEAD.x * 2.0)
	UiPaint.fill_gradient_polygon(
		item.get_canvas_item(),
		shape,
		rect,
		[[0.0, Color(0.72, 0.72, 0.78, alpha)], [1.0, Color(0.28, 0.28, 0.33, alpha)]]
	)
	var closed := shape.duplicate()
	closed.append(shape[0])
	item.draw_polyline(closed, Color(UiPalette.OUTLINE_DARK, alpha * 0.8), 1.2, true)


## 打った点から上へ散る火花。`progress` は0→1で、重さで弧を描いて落ちながら冷める。
static func sparks(item: CanvasItem, origin: Vector2, progress: float, alpha: float) -> void:
	const COUNT := 14
	const REACH := 48.0
	const GRAVITY := 44.0
	const TAIL := 0.14
	if alpha <= 0.0 or progress <= 0.0 or progress >= 1.0:
		return
	for i in range(COUNT):
		var angle := -PI * (0.08 + 0.84 * _hash(i, 11))
		var velocity := Vector2.from_angle(angle) * REACH * (0.55 + 0.45 * _hash(i, 12))
		var head := _ballistic(origin, velocity, GRAVITY, progress)
		var tail := _ballistic(origin, velocity, GRAVITY, maxf(progress - TAIL, 0.0))
		var color := SPARK_HOT.lerp(SPARK_COOL, progress)
		item.draw_line(tail, head, Color(color, alpha * (1.0 - progress)), 1.8, true)


## 時計の文字盤。`hand` は長針の角度(0で12時、正で時計回り)。短針は長針の12分の1だけ進む。
static func clock_dial(
	item: CanvasItem, center: Vector2, radius: float, hand: float, alpha: float
) -> void:
	const HOUR_START := TAU * 10.0 / 12.0
	if alpha <= 0.0 or radius <= 1.0:
		return
	var ci := item.get_canvas_item()
	UiPaint.fill_circle(ci, center, radius + 1.6, Color(UiPalette.OUTLINE_DARK, alpha * 0.8), 40)
	UiPaint.fill_circle(ci, center, radius, Color(UiPalette.BRASS_HIGHLIGHT, alpha), 40)
	UiPaint.fill_circle(ci, center, radius * 0.84, Color(DIAL_FACE, alpha * 0.94), 40)
	for i in range(12):
		var dir := Vector2.UP.rotated(TAU * float(i) / 12.0)
		var major := i % 3 == 0
		var inner := radius * (0.62 if major else 0.7)
		item.draw_line(
			center + dir * inner,
			center + dir * radius * 0.8,
			Color(UiPalette.BRASS_DARK, alpha),
			1.8 if major else 1.0,
			true
		)
	_dial_hand(item, center, HOUR_START + hand / 12.0, radius * 0.45, 2.8, alpha)
	_dial_hand(item, center, hand, radius * 0.72, 1.8, alpha)
	UiPaint.fill_circle(ci, center, radius * 0.1, Color(UiPalette.BRASS_DARK, alpha), 10)


## 八分音符。`at` は玉の中心、`size` は玉の横の半径。
static func note(item: CanvasItem, at: Vector2, size: float, color: Color, alpha: float) -> void:
	if alpha <= 0.0 or size <= 0.5:
		return
	var ci := item.get_canvas_item()
	var head := Vector2(size, size * 0.72)
	UiPaint.fill_ellipse(ci, at, head + Vector2.ONE, Color(UiPalette.OUTLINE_DARK, alpha * 0.7), 16)
	UiPaint.fill_ellipse(ci, at, head, Color(color, alpha), 16)
	var foot := at + Vector2(head.x * 0.85, 0.0)
	var top := foot - Vector2(0.0, size * 3.2)
	item.draw_line(foot, top, Color(color, alpha), maxf(size * 0.28, 1.2), true)
	var flag := PackedVector2Array(
		[top, top + Vector2(size * 1.1, size * 0.9), top + Vector2(size * 0.9, size * 2.0)]
	)
	item.draw_polyline(flag, Color(color, alpha), maxf(size * 0.28, 1.2), true)


static func _dial_hand(
	item: CanvasItem, center: Vector2, angle: float, length: float, width: float, alpha: float
) -> void:
	var tip := center + Vector2.UP.rotated(angle) * length
	item.draw_line(center, tip, Color(UiPalette.OUTLINE_DARK, alpha), width, true)


static func _ballistic(origin: Vector2, velocity: Vector2, gravity: float, t: float) -> Vector2:
	return origin + velocity * t + Vector2(0.0, gravity * t * t)


static func _rotated(
	points: PackedVector2Array, pivot: Vector2, angle: float
) -> PackedVector2Array:
	var out := PackedVector2Array()
	for p in points:
		out.append(pivot + p.rotated(angle))
	return out


## 粒ごとに決まった揺らぎ。毎フレーム同じ値を返すため、乱数の種を持ち歩かずに済む。
static func _hash(i: int, salt: int) -> float:
	var v := sin(float(i) * 12.9898 + float(salt) * 78.233) * 43758.5453
	return v - floorf(v)
