class_name PlayerInfoBarFx
extends Control
## 情報帯(`PlayerInfoBar`)の上で絶えず動く光だけを持つ層(GameDesign.md 9章「対局画面の手触り」)。
## HPの砂粒のきらめき・手番の光の輪・攻撃の的の赤い縁・支払うピップの脈打ち。
## 帯本体は影・板・真鍮の輪を重ねた重い絵のため、値が変わったときだけ描き直す。
## この層も光の形は `PaintedShape` に1度だけ描き、毎フレームは不透明度と拡大だけを動かす
## (Architecture.md 10.10.3節)。
##
## 値は帯が自分の `_draw()` のたびに `sync()` で渡す。座標はすべて帯のローカル。

const RING_GAP := 2.5
const RING_WIDTH := 2.5
const RING_SEGMENTS := 32
const RING_PULSE_SPEED := 3.0
const PIP_GLOW_WIDTH := 2.0
const PIP_GLOW_SEGMENTS := 16
const PIP_GLOW_COLOR := Color(1.0, 0.92, 0.6)
const GLINT_COLOR := Color(1.0, 0.96, 0.82)
const GLINT_PHASE_STEP := 1.7
const RIM_GAP := 2.5
const RIM_WIDTH := 2.5
const RIM_CORNER_SEGMENTS := 6
const RIM_PULSE_SPEED := 4.0
## バッジの真鍮の外輪(半径 + 3.5)まで覆う。
const RIM_BADGE_COVER := 3.5

var _bar: PlayerInfoBar
var _time := 0.0
var _hp_rect := Rect2()
var _glints: Array[PaintedShape] = []
var _ring: PaintedShape
var _rim: PaintedShape
var _pip_glows: Array[PaintedShape] = []


func _init(bar: PlayerInfoBar) -> void:
	_bar = bar


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	for i in PlayerInfoBar.SAND_GLINT_FRACTIONS.size():
		_glints.append(_add_shape(_paint_glint))
	_ring = _add_shape(_paint_ring)
	_rim = _add_shape(_paint_rim)


## 画面に出ている間だけ時間を進める(隠れた画面の帯は止める)。
func _process(delta: float) -> void:
	if not is_visible_in_tree():
		return
	_time += delta
	for i in _glints.size():
		var pulse := _pulse(PlayerInfoBar.SAND_GLINT_SPEED, float(i) * GLINT_PHASE_STEP)
		_glints[i].modulate.a = 0.15 + pulse * 0.45
	_ring.modulate.a = 0.55 + 0.35 * _pulse(RING_PULSE_SPEED)
	_rim.modulate.a = 0.6 + 0.4 * _pulse(RIM_PULSE_SPEED)
	var pip_pulse := _pulse(PlayerInfoBar.PIP_GLOW_SPEED)
	var pip_scale := 1.0 + PlayerInfoBar.PIP_GLOW_EXTRA * pip_pulse / PlayerInfoBar.PIP_RADIUS
	for glow in _pip_glows:
		glow.scale = Vector2(pip_scale, pip_scale)
		glow.modulate.a = 0.5 + 0.4 * pip_pulse


func sync(
	active: bool, targetable: bool, hp_rect: Rect2, hp_ratio: float, glow_centers: Array[Vector2]
) -> void:
	if hp_rect != _hp_rect:
		_hp_rect = hp_rect
		_rim.repaint()
	_ring.visible = active
	_ring.position = _bar.portrait_center()
	_rim.visible = targetable
	_place_glints(hp_ratio)
	while _pip_glows.size() < glow_centers.size():
		_pip_glows.append(_add_shape(_paint_pip_glow))
	for i in _pip_glows.size():
		_pip_glows[i].visible = i < glow_centers.size()
		if i < glow_centers.size():
			_pip_glows[i].position = glow_centers[i]


func _add_shape(painter: Callable) -> PaintedShape:
	var shape := PaintedShape.new(painter)
	add_child(shape)
	return shape


func _pulse(speed: float, phase: float = 0.0) -> float:
	return (sin(_time * speed + phase) + 1.0) * 0.5


## HPの砂に光が当たっている粒。**残っている砂の範囲だけ**出す(割合を超えた位置は隠れている)。
func _place_glints(hp_ratio: float) -> void:
	var inner := _hp_rect.grow(-PlayerInfoBar.HP_RIM_WIDTH)
	var fill_rect := Rect2(inner.position, Vector2(inner.size.x * hp_ratio, inner.size.y))
	for i in _glints.size():
		var frac: float = PlayerInfoBar.SAND_GLINT_FRACTIONS[i]
		_glints[i].visible = hp_ratio > 0.0 and frac <= hp_ratio
		var phase := float(i) * GLINT_PHASE_STEP
		_glints[i].position = Vector2(
			fill_rect.position.x + fill_rect.size.x * frac,
			fill_rect.position.y + fill_rect.size.y * (0.35 + 0.3 * sin(phase))
		)


func _paint_glint(shape: PaintedShape) -> void:
	var radius := PlayerInfoBar.SAND_GLINT_RADIUS
	UiPaint.fill_gradient_polygon(
		shape.get_canvas_item(),
		UiPaint.circle_points(Vector2.ZERO, radius, 8),
		Rect2(-Vector2(radius, radius), Vector2(radius, radius) * 2.0),
		[[0.0, GLINT_COLOR], [1.0, Color(GLINT_COLOR, 0.0)]]
	)


func _paint_ring(shape: PaintedShape) -> void:
	UiPaint.draw_ring(
		shape.get_canvas_item(),
		Vector2.ZERO,
		PlayerInfoBar.PORTRAIT_RADIUS + RING_GAP,
		Color(UiPalette.GLOW_AMBER, 1.0),
		RING_WIDTH,
		RING_SEGMENTS
	)


func _paint_pip_glow(shape: PaintedShape) -> void:
	UiPaint.draw_ring(
		shape.get_canvas_item(),
		Vector2.ZERO,
		PlayerInfoBar.PIP_RADIUS,
		PIP_GLOW_COLOR,
		PIP_GLOW_WIDTH,
		PIP_GLOW_SEGMENTS
	)


## 攻撃の的になっている間の赤い縁。右端の体力のバッジは帯本体(この層の背面)にあるため、
## バッジに掛かる区間は描かずに、縁がバッジの下へ潜って見えるようにする。
func _paint_rim(shape: PaintedShape) -> void:
	if _hp_rect.size == Vector2.ZERO:
		return
	var color := Color(UiPalette.WARNING_RED, 1.0)
	var ring := UiPaint.rounded_rect_points_uniform(
		_hp_rect.grow(RIM_GAP), PlayerInfoBar.HP_BAR_RADIUS + RIM_GAP, RIM_CORNER_SEGMENTS
	)
	var badge_center := Vector2(_hp_rect.end.x, _hp_rect.get_center().y)
	var hidden_radius := PlayerInfoBar.HP_BADGE_RADIUS + RIM_BADGE_COVER
	var start := -1
	for i in ring.size():
		if ring[i].distance_to(badge_center) < hidden_radius:
			start = i
			break
	if start < 0:
		ring.append(ring[0])
		ShapePaint.polyline(shape.get_canvas_item(), ring, color, RIM_WIDTH, true)
		return
	var run := PackedVector2Array()
	for k in ring.size() + 1:
		var p := ring[(start + k) % ring.size()]
		if p.distance_to(badge_center) < hidden_radius:
			if run.size() >= 2:
				ShapePaint.polyline(shape.get_canvas_item(), run, color, RIM_WIDTH, true)
			run = PackedVector2Array()
		else:
			run.append(p)
	if run.size() >= 2:
		ShapePaint.polyline(shape.get_canvas_item(), run, color, RIM_WIDTH, true)
