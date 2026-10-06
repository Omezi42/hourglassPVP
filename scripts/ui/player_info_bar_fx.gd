class_name PlayerInfoBarFx
extends Control
## 情報帯(`PlayerInfoBar`)の上で絶えず動く光だけを描く層(GameDesign.md 9章「対局画面の手触り」)。
## HPの砂粒のきらめき・手番の光の輪・攻撃の的の赤い縁・支払うピップの脈打ち。
## 帯本体は影・板・真鍮の輪を重ねた重い絵のため、値が変わったときだけ描き直し、
## 毎フレーム描き直すのはこの層だけにする(Architecture.md 10.10.3節)。
##
## 値は帯が自分の `_draw()` のたびに `sync()` で渡す。座標はすべて帯のローカル。

var _bar: PlayerInfoBar
var _time := 0.0
var _active := false
var _targetable := false
var _hp_rect := Rect2()
var _hp_ratio := 0.0
var _glow_centers: Array[Vector2] = []


func _init(bar: PlayerInfoBar) -> void:
	_bar = bar


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE


## 画面に出ている間だけ時間を進めて描き直す(隠れた画面の帯は止める)。
func _process(delta: float) -> void:
	if not is_visible_in_tree():
		return
	_time += delta
	queue_redraw()


func sync(
	active: bool, targetable: bool, hp_rect: Rect2, hp_ratio: float, glow_centers: Array[Vector2]
) -> void:
	_active = active
	_targetable = targetable
	_hp_rect = hp_rect
	_hp_ratio = hp_ratio
	_glow_centers = glow_centers
	queue_redraw()


func _draw() -> void:
	var ci := get_canvas_item()
	if _hp_ratio > 0.0:
		_draw_sand_glints(ci)
	if _active:
		var pulse := (sin(_time * 3.0) + 1.0) * 0.5
		UiPaint.draw_ring(
			ci,
			PlayerInfoBar.PORTRAIT_CENTER,
			PlayerInfoBar.PORTRAIT_RADIUS + 2.5,
			Color(UiPalette.GLOW_AMBER, 0.55 + 0.35 * pulse),
			2.5,
			32
		)
	if _targetable:
		_draw_target_rim()
	for center in _glow_centers:
		var pulse := (sin(_time * PlayerInfoBar.PIP_GLOW_SPEED) + 1.0) * 0.5
		var radius := PlayerInfoBar.PIP_RADIUS + PlayerInfoBar.PIP_GLOW_EXTRA * pulse
		UiPaint.draw_ring(ci, center, radius, Color(1.0, 0.92, 0.6, 0.5 + 0.4 * pulse), 2.0, 16)


## HPの砂に光が当たっている粒をいくつか置き、ゆっくり明滅させる。**残っている砂の
## 範囲だけ**描く(割合を超えた位置は隠れているので描かない)。
func _draw_sand_glints(ci: RID) -> void:
	var inner := _hp_rect.grow(-PlayerInfoBar.HP_RIM_WIDTH)
	var fill_rect := Rect2(inner.position, Vector2(inner.size.x * _hp_ratio, inner.size.y))
	var radius := PlayerInfoBar.SAND_GLINT_RADIUS
	for i in PlayerInfoBar.SAND_GLINT_FRACTIONS.size():
		var frac: float = PlayerInfoBar.SAND_GLINT_FRACTIONS[i]
		if frac > _hp_ratio:
			continue
		var phase := float(i) * 1.7
		var pulse := (sin(_time * PlayerInfoBar.SAND_GLINT_SPEED + phase) + 1.0) * 0.5
		var alpha := 0.15 + pulse * 0.45
		var center := Vector2(
			fill_rect.position.x + fill_rect.size.x * frac,
			fill_rect.position.y + fill_rect.size.y * (0.35 + 0.3 * sin(phase))
		)
		UiPaint.fill_gradient_polygon(
			ci,
			UiPaint.circle_points(center, radius, 8),
			Rect2(center - Vector2(radius, radius), Vector2(radius, radius) * 2.0),
			[[0.0, Color(1.0, 0.96, 0.82, alpha)], [1.0, Color(1.0, 0.96, 0.82, 0.0)]]
		)


## 攻撃の的になっている間の赤い縁。右端の体力のバッジは帯本体(この層の背面)にあるため、
## バッジに掛かる区間は描かずに、縁がバッジの下へ潜って見えるようにする。
func _draw_target_rim() -> void:
	var pulse := (sin(_time * 4.0) + 1.0) * 0.5
	var color := Color(UiPalette.WARNING_RED, 0.6 + 0.4 * pulse)
	var ring := UiPaint.rounded_rect_points_uniform(
		_hp_rect.grow(2.5), PlayerInfoBar.HP_BAR_RADIUS + 2.5, 6
	)
	var badge_center := Vector2(_hp_rect.end.x, _hp_rect.get_center().y)
	# バッジの真鍮の外輪(半径 + 3.5)まで覆う。
	var hidden_radius := PlayerInfoBar.HP_BADGE_RADIUS + 3.5
	var start := -1
	for i in ring.size():
		if ring[i].distance_to(badge_center) < hidden_radius:
			start = i
			break
	if start < 0:
		ring.append(ring[0])
		draw_polyline(ring, color, 2.5, true)
		return
	var run := PackedVector2Array()
	for k in ring.size() + 1:
		var p := ring[(start + k) % ring.size()]
		if p.distance_to(badge_center) < hidden_radius:
			if run.size() >= 2:
				draw_polyline(run, color, 2.5, true)
			run = PackedVector2Array()
		else:
			run.append(p)
	if run.size() >= 2:
		draw_polyline(run, color, 2.5, true)
