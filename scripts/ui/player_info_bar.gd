class_name PlayerInfoBar
extends Control
## 片方のプレイヤーの情報帯(GameDesign.md 9章「対局画面」)。
## HP・マナ・山札の残り・墓地の枚数を並べ、相手側は手札の枚数も出す(中身は伏せる)。

signal face_pressed
signal graveyard_pressed

const BAR_HEIGHT := 56.0
const MANA_BLUE := Color(0.35, 0.6, 0.95, 1.0)
const MANA_EMPTY := Color(0.2, 0.22, 0.28, 1.0)
const HP_BAR_SIZE := Vector2(240, 24)
const PILE_SIZE := Vector2(74, 40)
const DANGER_RATIO := 0.4
## マナのピップの間隔と半径。上限10まで並べても情報帯の幅に収まる。
const PIP_STEP := 20.0
const PIP_RADIUS := 7.0
## 帯の中の横位置。マナのピップは上限10まで並ぶため、山札の山と重ならない位置から始める。
const NAME_PLATE_RECT := Rect2(10, 10, 140, 36)
const HP_BAR_X := 162.0
const MANA_TEXT_X := 418.0
const PIP_START_X := 516.0
const DECK_PILE_X := 730.0
const GRAVE_PILE_X := 812.0
const HAND_PILE_X := 894.0
const CLOCK_X := 990.0
const BAR_CORNER := 10.0
const HP_BAR_RADIUS := 6.0
const PILE_RADIUS := 6.0

## 相手側かどうか。相手側だけ手札の枚数を出す。
var is_opponent := false
## 表示名(未設定なら「あなた」「相手」)。
var display_name := ""
## 攻撃の対象として選べる状態か。光らせて示す。
var targetable := false
## 残り持ち時間(秒)。負の値なら表示しない(CPU戦は持ち時間を使わない)。
var clock_seconds := -1.0

var _hp := MatchState.INITIAL_HP
var _mana := 0
var _max_mana := 0
var _deck := 0
var _graveyard := 0
var _hand := 0
var _has_coin := false
var _font: Font
var _tracker := PressTracker.new()


func _ready() -> void:
	_font = get_theme_default_font()
	if _font == null:
		_font = ThemeDB.fallback_font
	custom_minimum_size = Vector2(0, BAR_HEIGHT)
	mouse_filter = Control.MOUSE_FILTER_STOP


## 対局の状態から自分の側の値をまとめて取り込む。
func show_state(state: MatchState, side: int) -> void:
	_hp = state.hp[side]
	_mana = state.mana[side]
	_max_mana = state.max_mana[side]
	_deck = state.deck[side].size()
	_graveyard = state.graveyard[side].size()
	_hand = state.hand[side].size()
	_has_coin = state.coin_available.get(side, false)
	queue_redraw()


func _gui_input(event: InputEvent) -> void:
	if _tracker.feed(event, size) != PressTracker.Result.CONFIRMED:
		return
	var position: Vector2 = (event as InputEventMouseButton).position
	if _graveyard_rect().has_point(position):
		graveyard_pressed.emit()
	elif targetable:
		face_pressed.emit()


func _draw() -> void:
	var ci := get_canvas_item()
	var rect := Rect2(Vector2.ZERO, size)
	var points := UiPaint.rounded_rect_points_uniform(rect, BAR_CORNER, 6)
	UiPaint.fill_gradient_polygon(
		ci, points, rect, [[0.0, UiPalette.BAR_FILL_TOP], [1.0, UiPalette.BAR_FILL_BOTTOM]]
	)
	var outline := points.duplicate()
	outline.append(points[0])
	var edge := UiPalette.WARNING_RED if targetable else Color(UiPalette.BRASS_MID, 0.95)
	draw_polyline(outline, edge, 3.0 if targetable else 2.0, true)
	_draw_name_plate()
	_draw_hp()
	_draw_mana()
	_pile(Vector2(DECK_PILE_X, 8), "山札", _deck)
	_pile(_graveyard_rect().position, "墓地", _graveyard)
	if is_opponent:
		_pile(Vector2(HAND_PILE_X, 8), "手札", _hand)
	if _has_coin:
		_draw_coin()
	if clock_seconds >= 0.0:
		_draw_clock()


## 名前は真鍮の名札に載せる。どちらのHPかは配置と名前で示すため、色は使わない
## (GameDesign.md 9章)。
func _draw_name_plate() -> void:
	var ci := get_canvas_item()
	var label := display_name
	if label.is_empty():
		label = "相手" if is_opponent else "あなた"
	var points := UiPaint.rounded_rect_points_uniform(NAME_PLATE_RECT, 6.0, 5)
	UiPaint.fill_gradient_polygon(
		ci,
		points,
		NAME_PLATE_RECT,
		[[0.0, UiPalette.NAMEPLATE_PANEL_TOP], [1.0, UiPalette.NAMEPLATE_PANEL_BOTTOM]]
	)
	var outline := points.duplicate()
	outline.append(points[0])
	draw_polyline(outline, UiPalette.BRASS_LIGHT, 1.5, true)
	_text(NAME_PLATE_RECT.position + Vector2(12, 25), label, 18)


## 残り時間は「相手の手札」の右、情報帯の末尾に置く。
func _draw_clock() -> void:
	var minutes := int(clock_seconds) / 60
	var seconds := int(clock_seconds) % 60
	var low := clock_seconds <= 30.0
	_text(
		Vector2(CLOCK_X, 36),
		"%d:%02d" % [minutes, seconds],
		20,
		UiPalette.WARNING_RED if low else UiPalette.TEXT_OFFWHITE
	)


func _graveyard_rect() -> Rect2:
	return Rect2(Vector2(GRAVE_PILE_X, 8), PILE_SIZE)


## HPバーは彫り込まれた溝に見せる(角丸 + 内側の落ち込み影)。残量の色は
## 十分なうちは琥珀、危険域まで減ったら赤(GameDesign.md 9章)。
func _draw_hp() -> void:
	var ci := get_canvas_item()
	var rect := Rect2(Vector2(HP_BAR_X, 16), HP_BAR_SIZE)
	var track := UiPaint.rounded_rect_points_uniform(rect, HP_BAR_RADIUS, 5)
	UiPaint.fill_gradient_polygon(
		ci, track, rect, [[0.0, Color(0.06, 0.05, 0.05, 1.0)], [1.0, Color(0.14, 0.11, 0.1, 1.0)]]
	)
	var ratio := clampf(float(_hp) / float(MatchState.INITIAL_HP), 0.0, 1.0)
	if ratio > 0.0:
		var fill_rect := Rect2(rect.position, Vector2(rect.size.x * ratio, rect.size.y))
		var color := UiPalette.GLOW_AMBER if ratio > DANGER_RATIO else UiPalette.WARNING_RED
		var fill := UiPaint.rounded_rect_points_uniform(
			fill_rect, minf(HP_BAR_RADIUS, fill_rect.size.x * 0.5), 5
		)
		UiPaint.fill_gradient_polygon(
			ci, fill, fill_rect, [[0.0, color.lightened(0.28)], [1.0, color.darkened(0.22)]]
		)
	UiPaint.draw_inner_shadow(ci, rect, HP_BAR_RADIUS, 5, 3, Color(0, 0, 0, 1), 0.5)
	var outline := track.duplicate()
	outline.append(track[0])
	draw_polyline(outline, UiPalette.BRASS_MID, 1.5, true)
	_text(Vector2(rect.position.x + 96, rect.position.y + 19), "%d / 30" % _hp, 17)


func _draw_mana() -> void:
	_text(Vector2(MANA_TEXT_X, 36), "マナ %d/%d" % [_mana, _max_mana], 18)
	for i in _max_mana:
		var center := Vector2(PIP_START_X + i * PIP_STEP, 28)
		draw_circle(center, PIP_RADIUS, MANA_BLUE if i < _mana else MANA_EMPTY)
		draw_arc(center, PIP_RADIUS, 0.0, TAU, 16, Color(0.75, 0.85, 1.0, 0.6), 1.5)


## コインを持っている間だけ、マナの並びの右隣に金色の粒を出す。
func _draw_coin() -> void:
	var center := Vector2(PIP_START_X + _max_mana * PIP_STEP + 6, 28)
	draw_circle(center, PIP_RADIUS + 1.0, UiPalette.GLOW_AMBER)
	draw_arc(center, PIP_RADIUS + 1.0, 0.0, TAU, 16, UiPalette.BRASS_HIGHLIGHT, 1.5)


## 山札・墓地・手札の枚数。小さな山を模した角丸のプレートに枚数を載せる。
func _pile(pos: Vector2, label: String, count: int) -> void:
	var ci := get_canvas_item()
	var rect := Rect2(pos, PILE_SIZE)
	var points := UiPaint.rounded_rect_points_uniform(rect, PILE_RADIUS, 5)
	UiPaint.fill_gradient_polygon(
		ci, points, rect, [[0.0, Color(0.24, 0.18, 0.13, 1.0)], [1.0, Color(0.1, 0.08, 0.06, 1.0)]]
	)
	var outline := points.duplicate()
	outline.append(points[0])
	draw_polyline(outline, UiPalette.BRASS_MID, 1.5, true)
	_text(Vector2(pos.x + 8, pos.y + 26), label, 15)
	_text(Vector2(pos.x + 46, pos.y + 27), str(count), 19, UiPalette.GLOW_AMBER)


func _fill(rect: Rect2, top: Color, bottom: Color) -> void:
	var points := PackedVector2Array(
		[
			rect.position,
			Vector2(rect.end.x, rect.position.y),
			rect.end,
			Vector2(rect.position.x, rect.end.y)
		]
	)
	draw_polygon(points, PackedColorArray([top, top, bottom, bottom]))


func _text(
	pos: Vector2, value: String, font_size: int, color: Color = UiPalette.TEXT_OFFWHITE
) -> void:
	draw_string(_font, pos, value, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, color)
