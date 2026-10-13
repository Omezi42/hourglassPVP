class_name SignaturePaint
extends RefCounted
## カードの演出(GameDesign.md 9章)で使う絵の部品。鐘・天秤・歯車の輪・砂の帯・昇る砂粒を
## コードで描く。進行(いつ何をどれだけ描くか)は `moves/` の各カードが持ち、
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
static func ripple(item: CanvasItem, center: Vector2, radius: float, alpha: float) -> void:
	const RINGS := 3
	const GAP := 16.0
	if alpha <= 0.0:
		return
	for i in range(RINGS):
		var r := radius - GAP * float(i)
		if r <= 0.0:
			continue
		var a := alpha * (1.0 - float(i) / float(RINGS))
		item.draw_arc(center, r, 0.0, TAU, 72, Color(1.0, 0.88, 0.58, a * 0.7), 2.4 - 0.6 * i, true)


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
