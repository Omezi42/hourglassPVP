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
const NAME_PLATE_RECT := Rect2(8, 8, 146, 40)
const HP_BAR_X := 162.0
const MANA_TEXT_X := 418.0
const PIP_START_X := 516.0
const DECK_PILE_X := 730.0
const GRAVE_PILE_X := 812.0
const HAND_PILE_X := 894.0
const CLOCK_X := 990.0
const CLOCK_SIZE := Vector2(80, 40)
const CLOCK_RADIUS := 6.0
const BAR_CORNER := 10.0
const HP_BAR_RADIUS := 6.0
const PILE_RADIUS := 6.0
## 被弾の演出(GameDesign.md 9章)。バーは補間して減らし、光らせ、増減を数字で浮かせる。
const HP_SLIDE_DURATION := 0.35
const FLASH_DURATION := 0.4
const FLOAT_DURATION := 0.9
const FLOAT_RISE := 16.0
## 山札の脈打ち(GameDesign.md 9章)。ドローと疲労の発生源を山札そのもので示す。
const DECK_PULSE_DURATION := 0.45

## 相手側かどうか。相手側だけ手札の枚数を出す。
var is_opponent := false
## 表示名(未設定なら「あなた」「相手」)。
var display_name := ""
## アイコンID(GameDesign.md 14章)。
var icon_id := UserProfileLibrary.DEFAULT_ICON_ID
## 称号ID(GameDesign.md 14章)。
var title_id := UserProfileLibrary.DEFAULT_TITLE_ID
## 攻撃の対象として選べる状態か。光らせて示す。
var targetable := false
## 残り持ち時間(秒)。負の値なら表示しない(CPU戦は持ち時間を使わない)。
var clock_seconds := -1.0
## その手番に与えられた持ち時間。**時間切れを重ねた側は短くなる**(GameDesign.md 5章)ため、
## 危険域を固定の秒数で決めると、半減した手番が最初から赤いままになる。割合で判定する。
var clock_total := MatchClock.DEFAULT_TURN_SECONDS
## いまこの側の手番か。手番の側だけ明るくして、どちらが指す番かを示す
## (GameDesign.md 9章)。
var active := false

var _hp := MatchState.INITIAL_HP
var _mana := 0
var _max_mana := 0
var _deck := 0
var _graveyard := 0
var _hand := 0
var _has_coin := false
var _font: Font
var _tracker := PressTracker.new()
## 被弾の演出。HPは瞬時に減らさず、この値から実際の値へ補間する。
var _shown_hp := float(MatchState.INITIAL_HP)
var _flash := 0.0
## 浮かせている増減の量と残り時間。
var _float_amount := 0
var _float_left := 0.0
var _hp_tween: Tween
## 一度でも状態を受け取ったか。初回の差し替えを被弾として見せないために持つ。
var _initialized := false
## 山札の脈打ちの強さと色。疲労だけ赤にして、ドローと区別する。
var _deck_pulse := 0.0
var _deck_pulse_color := UiPalette.GLOW_AMBER
var _deck_tween: Tween


func _ready() -> void:
	_font = get_theme_default_font()
	if _font == null:
		_font = ThemeDB.fallback_font
	custom_minimum_size = Vector2(0, BAR_HEIGHT)
	mouse_filter = Control.MOUSE_FILTER_STOP


## 対局の状態から自分の側の値をまとめて取り込む。
func show_state(state: MatchState, side: int) -> void:
	var previous := _hp
	_hp = state.hp[side]
	# **最初の1回は演出しない。**教材の盤面(ルール画面・画面の見かた)は初期値30から
	# 教材用のHPへ差し替えるため、そのままだと開いた瞬間に「-6」が浮いてしまう。
	if not _initialized:
		_initialized = true
		_shown_hp = float(_hp)
	elif previous != _hp:
		_animate_hp(previous)
	_mana = state.mana[side]
	_max_mana = state.max_mana[side]
	_deck = state.deck[side].size()
	_graveyard = state.graveyard[side].size()
	_hand = state.hand[side].size()
	_has_coin = state.coin_available.get(side, false)
	queue_redraw()


## エモートの吹き出しを名札付近へ出す(GameDesign.md 9章)。
func show_emote(text: String) -> void:
	for child in get_children():
		if child is EmoteBubble:
			child.queue_free()
	var bubble := EmoteBubble.new()
	bubble.text = text
	bubble.is_opponent = is_opponent
	# 相手側(画面上部)なら下へ、自分側(画面下部)なら上へ出す
	bubble.position = Vector2(10.0, 48.0 if is_opponent else -36.0)
	add_child(bubble)


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
	var edge := Color(UiPalette.BRASS_MID, 0.95)
	var width := 2.0
	if targetable:
		edge = UiPalette.WARNING_RED
		width = 3.0
	elif active:
		# 手番の側だけ縁を明るくする。どちらが指す番かを常に読めるようにするため
		# (GameDesign.md 9章)。
		edge = UiPalette.GLOW_AMBER
		width = 3.0
	draw_polyline(outline, edge, width, true)
	_draw_name_plate()
	_draw_hp()
	_draw_mana()
	_pile(deck_pile_rect().position, "山札", _deck)
	_pile(_graveyard_rect().position, "墓地", _graveyard)
	if is_opponent:
		_pile(Vector2(HAND_PILE_X, 8), "手札", _hand)
	if _has_coin:
		_draw_coin()
	if clock_seconds >= 0.0:
		_draw_clock()


## 名前・アイコン・称号は真鍮の名札に載せる(GameDesign.md 9章・14章)。
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

	# アイコン描画(左端・円形枠)
	var icon_rect := Rect2(14, 14, 28, 28)
	var icon_center := icon_rect.position + icon_rect.size * 0.5
	var icon_tex := UserProfileLibrary.get_icon_texture(icon_id)
	if icon_tex != null:
		draw_texture_rect(icon_tex, icon_rect, false)
	draw_arc(icon_center, 14.5, 0.0, TAU, 20, UiPalette.BRASS_LIGHT, 1.5)

	# 称号と表示名の描画
	var title_text := UserProfileLibrary.get_title_display(title_id)
	var text_x := 48.0
	if not title_text.is_empty():
		_text(
			Vector2(text_x, NAME_PLATE_RECT.position.y + 16),
			title_text,
			11,
			UiPalette.BRASS_HIGHLIGHT
		)
		_text(Vector2(text_x, NAME_PLATE_RECT.position.y + 32), label, 15, UiPalette.TEXT_OFFWHITE)
	else:
		_text(Vector2(text_x, NAME_PLATE_RECT.position.y + 26), label, 17, UiPalette.TEXT_OFFWHITE)


## 残り時間は「相手の手札」の右、情報帯の末尾に置く。
## 真鍮枠のプレート内に秒数と砂時計アイコンを描画する。
func _draw_clock() -> void:
	var ci := get_canvas_item()
	var rect := Rect2(Vector2(CLOCK_X - 10, 8), CLOCK_SIZE)
	var is_critical := clock_seconds <= 15.0 and active
	var is_low := clock_seconds <= maxf(clock_total, 1.0) * 0.5

	# プレート背景
	var points := UiPaint.rounded_rect_points_uniform(rect, CLOCK_RADIUS, 5)
	UiPaint.fill_gradient_polygon(
		ci, points, rect, [[0.0, Color(0.18, 0.14, 0.12, 1.0)], [1.0, Color(0.08, 0.06, 0.06, 1.0)]]
	)

	# 枠線 (残り15秒以下かつ手番中なら脈動パルス)
	var outline := points.duplicate()
	outline.append(points[0])
	if is_critical:
		var pulse := (sin(Time.get_ticks_msec() * 0.008) + 1.0) * 0.5
		var pulse_color := UiPalette.WARNING_RED.lerp(UiPalette.GLOW_AMBER, pulse * 0.4)
		draw_polyline(outline, pulse_color, 2.5, true)
		draw_rect(rect.grow(1.5), Color(pulse_color, 0.15 * pulse))
	elif is_low:
		draw_polyline(outline, Color(UiPalette.WARNING_RED, 0.8), 1.5, true)
	else:
		draw_polyline(outline, UiPalette.BRASS_MID, 1.5, true)

	var minutes := int(clock_seconds) / 60
	var seconds := int(clock_seconds) % 60
	var text_color := UiPalette.TEXT_OFFWHITE
	if is_critical:
		var pulse := (sin(Time.get_ticks_msec() * 0.008) + 1.0) * 0.5
		text_color = Color(1.0, 0.35 + 0.35 * pulse, 0.35 + 0.35 * pulse, 1.0)
	elif is_low:
		text_color = UiPalette.WARNING_RED

	# ミニ砂時計アイコン (枠内左側)
	var icon_x := rect.position.x + 10.0
	var icon_y := rect.position.y + 14.0
	var icon_color := UiPalette.WARNING_RED if is_critical or is_low else UiPalette.BRASS_LIGHT
	draw_line(Vector2(icon_x, icon_y), Vector2(icon_x + 10, icon_y), icon_color, 1.5)
	draw_line(Vector2(icon_x, icon_y + 14), Vector2(icon_x + 10, icon_y + 14), icon_color, 1.5)
	draw_line(Vector2(icon_x, icon_y), Vector2(icon_x + 10, icon_y + 14), icon_color, 1.2)
	draw_line(Vector2(icon_x + 10, icon_y), Vector2(icon_x, icon_y + 14), icon_color, 1.2)

	_text(
		Vector2(rect.position.x + 26, rect.position.y + 26),
		"%d:%02d" % [minutes, seconds],
		16,
		text_color
	)


## 山札の山。ドロー・疲労の演出の出どころとして画面側からも引く。
func deck_pile_rect() -> Rect2:
	return Rect2(Vector2(DECK_PILE_X, 8), PILE_SIZE)


## 相手側だけに出る手札の山。ドローの行き先として使う。
func hand_pile_rect() -> Rect2:
	return Rect2(Vector2(HAND_PILE_X, 8), PILE_SIZE)


## 山札を脈打たせる。`danger` は疲労(GameDesign.md 9章)。
func play_deck_pulse(danger: bool) -> void:
	_deck_pulse_color = UiPalette.WARNING_RED if danger else UiPalette.GLOW_AMBER
	if _deck_tween != null and _deck_tween.is_valid():
		_deck_tween.kill()
	_deck_tween = create_tween()
	_deck_tween.tween_method(_set_deck_pulse, 1.0, 0.0, DECK_PULSE_DURATION)


func _set_deck_pulse(value: float) -> void:
	_deck_pulse = value
	queue_redraw()


func _graveyard_rect() -> Rect2:
	return Rect2(Vector2(GRAVE_PILE_X, 8), PILE_SIZE)


## HPバーは彫り込まれた溝に見せる(角丸 + 内側の落ち込み影)。残量の色は
## 十分なうちは琥珀、危険域まで減ったら赤(GameDesign.md 9章)。
## HPバーの矩形。攻撃の演出が本体を狙うときの的であり、被弾の演出の出どころでもある。
func hp_bar_rect() -> Rect2:
	return Rect2(Vector2(HP_BAR_X, 16), HP_BAR_SIZE)


func _draw_hp() -> void:
	var ci := get_canvas_item()
	var rect := hp_bar_rect()
	var track := UiPaint.rounded_rect_points_uniform(rect, HP_BAR_RADIUS, 5)
	UiPaint.fill_gradient_polygon(
		ci, track, rect, [[0.0, Color(0.06, 0.05, 0.05, 1.0)], [1.0, Color(0.14, 0.11, 0.1, 1.0)]]
	)
	var ratio := clampf(_shown_hp / float(MatchState.INITIAL_HP), 0.0, 1.0)
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
	if _flash > 0.0:
		var glow := UiPaint.rounded_rect_points_uniform(rect, HP_BAR_RADIUS, 5)
		UiPaint.fill_gradient_polygon(
			ci,
			glow,
			rect,
			[[0.0, Color(1, 1, 1, 0.5 * _flash)], [1.0, Color(1, 0.9, 0.7, 0.2 * _flash)]]
		)
	_text(Vector2(rect.position.x + 96, rect.position.y + 19), "%d / 30" % _hp, 17)
	if _float_left > 0.0:
		_draw_float(rect)


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
	var pulsing: bool = _deck_pulse > 0.0 and is_equal_approx(pos.x, DECK_PILE_X)
	if pulsing:
		draw_polyline(outline, Color(_deck_pulse_color, _deck_pulse), 3.0, true)
		draw_rect(rect.grow(2.0), Color(_deck_pulse_color, 0.18 * _deck_pulse))
	else:
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


## HPが動いた。**瞬時に差し替えず補間し、バーを光らせ、増減を数字で浮かせる**
## (GameDesign.md 9章)。数字が入れ替わるだけでは、何点入ったのかが分からない。
func _animate_hp(previous: int) -> void:
	_float_amount = _hp - previous
	_float_left = FLOAT_DURATION
	_flash = 1.0
	if _hp_tween != null and _hp_tween.is_valid():
		_hp_tween.kill()
	_hp_tween = create_tween()
	_hp_tween.tween_method(_set_shown_hp, _shown_hp, float(_hp), HP_SLIDE_DURATION)
	_hp_tween.parallel().tween_method(_set_flash, 1.0, 0.0, FLASH_DURATION)
	_hp_tween.parallel().tween_method(_set_float_left, FLOAT_DURATION, 0.0, FLOAT_DURATION)


func _set_shown_hp(value: float) -> void:
	_shown_hp = value
	queue_redraw()


func _set_flash(value: float) -> void:
	_flash = value
	queue_redraw()


func _set_float_left(value: float) -> void:
	_float_left = value
	queue_redraw()


## 増減のフローティング数字。減ったら赤、回復したら琥珀。
func _draw_float(rect: Rect2) -> void:
	var ratio := _float_left / FLOAT_DURATION
	var rise := (1.0 - ratio) * FLOAT_RISE
	var color := UiPalette.GLOW_AMBER if _float_amount > 0 else CardView.HEALTH_RED
	var text := "+%d" % _float_amount if _float_amount > 0 else str(_float_amount)
	draw_string(
		_font,
		Vector2(rect.end.x + 8.0, rect.position.y + 18.0 - rise),
		text,
		HORIZONTAL_ALIGNMENT_LEFT,
		-1,
		22,
		Color(color, minf(ratio * 2.0, 1.0))
	)
