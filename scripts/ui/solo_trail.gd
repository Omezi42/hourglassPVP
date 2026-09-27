class_name SoloTrail
extends Control
## ソロモードのステージを、蛇行する1本道の上の駒として描く(GameDesign.md 27章)。
##
## 1段に `COLUMNS` 個ずつ並べ、段の端で折り返して下の段へ続ける。ステージを足すと段が増え、
## 画面側のスクロールで下へ伸びる。押した駒を選ぶだけで、挑戦は隣の詳細パネルが受け持つ。

signal stage_chosen(index: int)

const COLUMNS := 5
const COLUMN_GAP := 150.0
const ROW_GAP := 200.0
const TOP_MARGIN := 96.0
const BOTTOM_MARGIN := 84.0
const TURN_SEGMENTS := 24

const NODE_RADIUS := 32.0
## 並びの最後(最終ステージ)だけ一回り大きく置き、道の行き先として見せる。
const FINAL_RADIUS := 40.0
const RIM_WIDTH := 4.0
const HIT_SLOP := 8.0
const SELECT_RING_GAP := 8.0
const SELECT_RING_WIDTH := 3.0
const SHADOW_OFFSET := Vector2(0, 6)
const SHADOW_COLOR := Color(0, 0, 0, 0.45)
const HOVER_LIFT := 0.12

const ROAD_WIDTH := 22.0
const ROAD_EDGE := Color(0.05, 0.04, 0.03, 0.75)
const ROAD_BED_WIDTH := 14.0
const ROAD_BED := Color(0.27, 0.21, 0.15, 1.0)
const ROAD_SAND_WIDTH := 8.0
const ROAD_SAND := Color(0.93, 0.72, 0.36, 1.0)
const ROAD_SHINE_WIDTH := 2.0
const ROAD_SHINE := Color(1, 0.93, 0.75, 0.55)
const ROAD_SHINE_OFFSET := Vector2(0, -2)

const PULSE_SPEED := 2.4
const HALO_RADIUS := 1.9
const HALO_STEPS := 6
const HALO_ALPHA := 0.16

const NUMBER_FONT_SIZE := 26
const FINAL_NUMBER_FONT_SIZE := 32
const NAME_FONT_SIZE := 15
const NAME_GAP := 26.0
const BADGE_RADIUS := 12.0
const BADGE_OFFSET := Vector2(0.72, 0.72)

const REWARD_ART_SIZE := Vector2(30, 40)
const REWARD_OFFSET := Vector2(0.9, -1.35)
const REWARD_POOL := Vector2(14, 4)
const REWARD_POOL_ALPHA := 0.45

const FACE_CLEARED := [[0.0, UiPalette.BRASS_HIGHLIGHT], [1.0, UiPalette.BRASS_MID]]
const FACE_OPEN := [[0.0, UiPalette.NAVY_PANEL_TOP], [1.0, UiPalette.FELT_NAVY_TOP]]
const FACE_LOCKED := [[0.0, UiPalette.PANEL_SLATE_TOP], [1.0, UiPalette.PANEL_PRESSED_BOTTOM]]
const NUMBER_ON_BRASS := Color(0.2, 0.13, 0.07, 1.0)
const NUMBER_LOCKED := Color(0.5, 0.48, 0.46, 1.0)

var _stages: Array[SoloStageData] = []
var _cleared: Array[bool] = []
var _unlocked: Array[bool] = []
var _selected := -1
var _hover := -1
var _time := 0.0
var _font: Font


func _ready() -> void:
	_font = get_theme_default_font()
	mouse_filter = Control.MOUSE_FILTER_STOP


func show_stages(
	stages: Array[SoloStageData], cleared: Array[bool], unlocked: Array[bool], width: float
) -> void:
	_stages = stages
	_cleared = cleared
	_unlocked = unlocked
	var rows: int = ceili(float(stages.size()) / COLUMNS)
	custom_minimum_size = Vector2(width, TOP_MARGIN + ROW_GAP * maxi(rows - 1, 0) + BOTTOM_MARGIN)
	set_process(_current_index() >= 0)
	queue_redraw()


func select(index: int) -> void:
	_selected = index
	queue_redraw()


## いま挑むべき駒(解放済みで未クリアの先頭)。すべてクリア済みなら -1。
func _current_index() -> int:
	for i in _stages.size():
		if _unlocked[i] and not _cleared[i]:
			return i
	return -1


func node_center(index: int) -> Vector2:
	var row: int = index / COLUMNS
	var column: int = index % COLUMNS
	if row % 2 == 1:
		column = COLUMNS - 1 - column
	var left := (custom_minimum_size.x - COLUMN_GAP * (COLUMNS - 1)) * 0.5
	return Vector2(left + COLUMN_GAP * column, TOP_MARGIN + ROW_GAP * row)


func _radius(index: int) -> float:
	return FINAL_RADIUS if index == _stages.size() - 1 else NODE_RADIUS


func _process(delta: float) -> void:
	_time += delta
	queue_redraw()


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion:
		var hit := _hit(event.position)
		if hit != _hover:
			_hover = hit
			if hit >= 0:
				SoundBank.play(SoundBank.Sfx.HOVER)
			mouse_default_cursor_shape = CURSOR_POINTING_HAND if hit >= 0 else CURSOR_ARROW
			queue_redraw()
	elif event is InputEventMouseButton and event.pressed:
		if event.button_index != MOUSE_BUTTON_LEFT:
			return
		var hit := _hit(event.position)
		if hit >= 0 and hit != _selected:
			SoundBank.play(SoundBank.Sfx.BUTTON)
			stage_chosen.emit(hit)
		accept_event()


func _notification(what: int) -> void:
	if what == NOTIFICATION_MOUSE_EXIT and _hover >= 0:
		_hover = -1
		queue_redraw()


func _hit(point: Vector2) -> int:
	for i in _stages.size():
		if point.distance_to(node_center(i)) <= _radius(i) + HIT_SLOP:
			return i
	return -1


func _draw() -> void:
	for i in range(_stages.size() - 1):
		_draw_road(_segment_points(i), _cleared[i])
	for i in _stages.size():
		_draw_node(i)


## 駒 i から i+1 までの道。同じ段なら直線、段をまたぐなら外側へ張り出す半円。
func _segment_points(index: int) -> PackedVector2Array:
	var from := node_center(index)
	var to := node_center(index + 1)
	if is_equal_approx(from.y, to.y):
		return PackedVector2Array([from, to])
	var center := (from + to) * 0.5
	var radius := ROW_GAP * 0.5
	var outward := 1.0 if (index / COLUMNS) % 2 == 0 else -1.0
	var points := PackedVector2Array()
	for step in TURN_SEGMENTS + 1:
		var angle := -PI * 0.5 + PI * float(step) / TURN_SEGMENTS
		points.append(center + Vector2(cos(angle) * outward, sin(angle)) * radius)
	return points


func _draw_road(points: PackedVector2Array, walked: bool) -> void:
	draw_polyline(points, ROAD_EDGE, ROAD_WIDTH, true)
	draw_polyline(points, ROAD_BED, ROAD_BED_WIDTH, true)
	if not walked:
		return
	draw_polyline(points, ROAD_SAND, ROAD_SAND_WIDTH, true)
	var shine := PackedVector2Array()
	for point in points:
		shine.append(point + ROAD_SHINE_OFFSET)
	draw_polyline(shine, ROAD_SHINE, ROAD_SHINE_WIDTH, true)


func _draw_node(index: int) -> void:
	var ci := get_canvas_item()
	var center := node_center(index)
	var radius := _radius(index)
	var cleared := _cleared[index]
	var unlocked := _unlocked[index]
	var is_current := index == _current_index()

	if is_current:
		var pulse := 0.5 + 0.5 * sin(_time * PULSE_SPEED)
		for step in HALO_STEPS:
			var t := float(step + 1) / HALO_STEPS
			var halo := radius * lerpf(1.0, HALO_RADIUS, t) * lerpf(0.92, 1.0, pulse)
			var alpha := HALO_ALPHA * (1.0 - t) * lerpf(0.6, 1.0, pulse)
			UiPaint.fill_circle(ci, center, halo, Color(UiPalette.GLOW_AMBER, alpha), 40)

	UiPaint.fill_ellipse(
		ci, center + SHADOW_OFFSET, Vector2(radius, radius * 0.9), SHADOW_COLOR, 32
	)
	var rim := UiPalette.BRASS_HIGHLIGHT if unlocked else UiPalette.BRASS_DARK
	UiPaint.fill_circle(ci, center, radius, UiPalette.OUTLINE_DARK, 40)
	UiPaint.fill_circle(ci, center, radius - 1.5, rim, 40)
	var face_stops: Array = FACE_CLEARED if cleared else (FACE_OPEN if unlocked else FACE_LOCKED)
	if index == _hover and unlocked:
		face_stops = _lifted(face_stops)
	var face_radius := radius - RIM_WIDTH
	UiPaint.fill_gradient_polygon(
		ci,
		UiPaint.circle_points(center, face_radius, 40),
		Rect2(center - Vector2.ONE * face_radius, Vector2.ONE * face_radius * 2.0),
		face_stops
	)
	UiPaint.draw_ring(ci, center, face_radius, Color(0, 0, 0, 0.35), 1.5, 40)

	if index == _selected:
		UiPaint.draw_ring(
			ci, center, radius + SELECT_RING_GAP, UiPalette.GLOW_AMBER, SELECT_RING_WIDTH, 48
		)

	var number_color := UiPalette.TEXT_OFFWHITE
	if cleared:
		number_color = NUMBER_ON_BRASS
	elif not unlocked:
		number_color = NUMBER_LOCKED
	var font_size := FINAL_NUMBER_FONT_SIZE if index == _stages.size() - 1 else NUMBER_FONT_SIZE
	_draw_centered(str(_stages[index].order), center, font_size, number_color)

	var badge := center + Vector2(radius * BADGE_OFFSET.x, radius * BADGE_OFFSET.y)
	if cleared:
		UiPaint.fill_circle(ci, badge, BADGE_RADIUS, UiPalette.OUTLINE_DARK, 24)
		UiPaint.draw_emblem(ci, UiPaint.Emblem.CHECK, badge, BADGE_RADIUS * 0.8)
	elif not unlocked:
		UiPaint.draw_lock(self, badge, BADGE_RADIUS)

	if not cleared:
		_draw_reward_art(index, center, radius)

	var name_color := UiPalette.TEXT_OFFWHITE if unlocked else UiPalette.TEXT_MUTED
	_draw_centered(
		_stages[index].display_name,
		center + Vector2(0, radius + NAME_GAP),
		NAME_FONT_SIZE,
		name_color
	)


## 初回クリアでカードかアイコンが手に入る駒には、その絵を肩へ小さく立てる。
func _draw_reward_art(index: int, center: Vector2, radius: float) -> void:
	var stage := _stages[index]
	var texture: Texture2D = null
	if not stage.reward_card_set_id.is_empty():
		var ids := CardSetLibrary.card_ids(stage.reward_card_set_id)
		var card: CardData = null if ids.is_empty() else CardLibrary.find_by_id(ids[0])
		if card != null:
			texture = HourglassArt.texture(card.art_key(), HourglassArt.State.UPRIGHT)
	elif not stage.reward_icon_id.is_empty():
		texture = UserProfileLibrary.get_icon_texture(stage.reward_icon_id)
	if texture == null:
		return
	var foot := center + Vector2(radius * REWARD_OFFSET.x, radius * REWARD_OFFSET.y)
	UiPaint.fill_ellipse(
		get_canvas_item(), foot, REWARD_POOL, Color(UiPalette.GLOW_AMBER, REWARD_POOL_ALPHA), 20
	)
	var tex_size := texture.get_size()
	var fit: float = minf(REWARD_ART_SIZE.x / tex_size.x, REWARD_ART_SIZE.y / tex_size.y)
	var draw_size := tex_size * fit
	draw_texture_rect(
		texture, Rect2(Vector2(foot.x - draw_size.x * 0.5, foot.y - draw_size.y), draw_size), false
	)


func _lifted(stops: Array) -> Array:
	var lifted := []
	for stop in stops:
		lifted.append([stop[0], (stop[1] as Color).lightened(HOVER_LIFT)])
	return lifted


func _draw_centered(text: String, center: Vector2, font_size: int, color: Color) -> void:
	if _font == null:
		return
	var width := _font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x
	var ascent := _font.get_ascent(font_size)
	var descent := _font.get_descent(font_size)
	var baseline := center.y + (ascent - descent) * 0.5
	draw_string(
		_font,
		Vector2(center.x - width * 0.5, baseline),
		text,
		HORIZONTAL_ALIGNMENT_LEFT,
		-1,
		font_size,
		color
	)
