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
	var rect := Rect2(Vector2.ZERO, size)
	_fill(rect, UiPalette.BAR_FILL_TOP, UiPalette.BAR_FILL_BOTTOM)
	if targetable:
		draw_rect(rect, UiPalette.WARNING_RED, false, 3.0)
	var label := display_name
	if label.is_empty():
		label = "相手" if is_opponent else "あなた"
	_text(Vector2(18, 36), label, 20)
	_draw_hp()
	_draw_mana()
	_pile(Vector2(620, 8), "山札", _deck)
	_pile(_graveyard_rect().position, "墓地", _graveyard)
	if is_opponent:
		_pile(Vector2(804, 8), "手札", _hand)
	if _has_coin:
		_draw_coin()
	if clock_seconds >= 0.0:
		_draw_clock()


## 残り時間は「相手の手札」の右、情報帯の末尾に置く。
func _draw_clock() -> void:
	var minutes := int(clock_seconds) / 60
	var seconds := int(clock_seconds) % 60
	var low := clock_seconds <= 30.0
	_text(
		Vector2(900, 36),
		"%d:%02d" % [minutes, seconds],
		20,
		UiPalette.WARNING_RED if low else UiPalette.TEXT_OFFWHITE
	)


func _graveyard_rect() -> Rect2:
	return Rect2(Vector2(712, 8), PILE_SIZE)


func _draw_hp() -> void:
	var rect := Rect2(Vector2(96, 16), HP_BAR_SIZE)
	_fill(rect, Color(0.16, 0.12, 0.1, 1.0), Color(0.1, 0.08, 0.07, 1.0))
	var ratio := clampf(float(_hp) / float(MatchState.INITIAL_HP), 0.0, 1.0)
	var color := UiPalette.GLOW_AMBER if ratio > DANGER_RATIO else UiPalette.WARNING_RED
	draw_rect(Rect2(rect.position, Vector2(rect.size.x * ratio, rect.size.y)), color)
	draw_rect(rect, UiPalette.BRASS_MID, false, 1.0)
	_text(Vector2(rect.position.x + 96, rect.position.y + 19), "%d / 30" % _hp, 17)


func _draw_mana() -> void:
	_text(Vector2(356, 36), "マナ %d/%d" % [_mana, _max_mana], 18)
	for i in _max_mana:
		var center := Vector2(452 + i * PIP_STEP, 28)
		draw_circle(center, PIP_RADIUS, MANA_BLUE if i < _mana else MANA_EMPTY)
		draw_arc(center, PIP_RADIUS, 0.0, TAU, 16, Color(0.75, 0.85, 1.0, 0.6), 1.5)


## コインを持っている間だけ、マナの並びの右隣に金色の粒を出す。
func _draw_coin() -> void:
	var center := Vector2(452 + _max_mana * PIP_STEP + 6, 28)
	draw_circle(center, PIP_RADIUS + 1.0, UiPalette.GLOW_AMBER)
	draw_arc(center, PIP_RADIUS + 1.0, 0.0, TAU, 16, UiPalette.BRASS_HIGHLIGHT, 1.5)


func _pile(pos: Vector2, label: String, count: int) -> void:
	var rect := Rect2(pos, PILE_SIZE)
	_fill(rect, Color(0.2, 0.16, 0.12, 1.0), Color(0.11, 0.09, 0.07, 1.0))
	draw_rect(rect, UiPalette.BRASS_MID, false, 1.0)
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
