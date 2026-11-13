class_name PuzzleEntryCard
extends PanelContainer
## パズル選択の札1枚(GameDesign.md 24章)。札の全面が当たりで、反応は札1枚にまとめる。
## 乗ると「挑戦」ボタンの縁が照って2px浮き、面が明るむ。押すと札ごと縮む。
## 中身(`bind_button` のボタンを除く)は当たりを塞がない(`MOUSE_FILTER_IGNORE`)ようにする側が決める。

signal tapped

## 押した位置からこれだけ動いたら一覧のスクロールと見なし、タップにしない。
const TAP_SLOP := 10.0
const CARD_HOVER_TINT := ClickArea.HOVER_MODULATE
const CARD_PRESS_SCALE := ClickArea.PRESS_SCALE.x
## 解いた印の中心 = 札の右上から、右へ内側の余白・上へこの距離。
const MARK_RIGHT_INSET := 24.0
const MARK_TOP_INSET := 12.0

var cleared := false
var mark_radius := 0.0
var hover_amount := 0.0:
	set(value):
		hover_amount = value
		self_modulate = Color.WHITE.lerp(CARD_HOVER_TINT, value)
		_set_button_hover(value)
var press_amount := 0.0:
	set(value):
		press_amount = value
		scale = Vector2.ONE * lerpf(1.0, CARD_PRESS_SCALE, value)

var _button: Button
var _hover_tween: Tween
var _press_tween: Tween
var _pressed := false
var _press_origin := Vector2.ZERO


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_PASS
	mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	resized.connect(func() -> void: pivot_offset = size / 2.0)
	mouse_entered.connect(_animate_hover.bind(1.0))
	mouse_exited.connect(_on_mouse_exited)
	visibility_changed.connect(_on_visibility_changed)


## 「挑戦」ボタン。当たりは札に一本化し、ボタンは反応の出る場所として残す。
func bind_button(button: Button) -> void:
	_button = button
	button.mouse_filter = Control.MOUSE_FILTER_IGNORE
	button.focus_mode = Control.FOCUS_NONE


func _gui_input(event: InputEvent) -> void:
	if ClickArea.is_primary_click(event):
		_pressed = true
		_press_origin = _event_position(event)
		_animate_press(1.0)
	elif _pressed and (event is InputEventMouseMotion or event is InputEventScreenDrag):
		if _event_position(event).distance_to(_press_origin) >= TAP_SLOP:
			_cancel_press()
	elif _pressed and ClickArea.is_primary_release(event):
		_pressed = false
		_animate_press(0.0)
		if Rect2(Vector2.ZERO, size).has_point(_event_position(event)):
			tapped.emit()


## 押したまま指で一覧をスクロールし始めた(`TouchScroll`)。
func _notification(what: int) -> void:
	if what == NOTIFICATION_SCROLL_BEGIN:
		_cancel_press()


func _draw() -> void:
	if cleared:
		var at := Vector2(size.x - MARK_RIGHT_INSET - mark_radius, MARK_TOP_INSET + mark_radius)
		RankMedal.draw_filled_star(self, at, mark_radius)


func _cancel_press() -> void:
	if _pressed:
		_pressed = false
		_animate_press(0.0)


func _on_mouse_exited() -> void:
	# 子の上へ移っただけでは戻さない。
	if not Rect2(Vector2.ZERO, size).has_point(get_local_mouse_position()):
		_animate_hover(0.0)


## 隠れた間に外れの通知が届かないことがある(モーダルを閉じたとき)。量を戻しておく。
func _on_visibility_changed() -> void:
	if not is_visible_in_tree():
		_pressed = false
		hover_amount = 0.0
		press_amount = 0.0


func _animate_hover(target: float) -> void:
	_hover_tween = _retween(_hover_tween, "hover_amount", target, UiPalette.DUR_HOVER)


func _animate_press(target: float) -> void:
	_press_tween = _retween(_press_tween, "press_amount", target, UiPalette.DUR_PRESS)


func _retween(running: Tween, property: String, target: float, seconds: float) -> Tween:
	if running != null and running.is_valid():
		running.kill()
	var tween := create_tween().set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
	tween.tween_property(self, property, target, seconds)
	return tween


func _set_button_hover(value: float) -> void:
	if _button == null:
		return
	var style := _button.get_theme_stylebox("normal") as CodedButtonStyle
	if style == null:
		return
	style.hover_amount = value
	_button.queue_redraw()


static func _event_position(event: InputEvent) -> Vector2:
	if event is InputEventMouse or event is InputEventScreenTouch or event is InputEventScreenDrag:
		return event.position
	return Vector2.ZERO
