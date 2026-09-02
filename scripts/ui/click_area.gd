class_name ClickArea
extends Control

## クリック判定だけを持つ単純なコンポーネントとして直接使われる。
## ホバー・押下の共通アニメーションもここに集約する。

signal area_pressed

const HOVER_MODULATE := Color(1.08, 1.08, 1.08, 1.0)
const HOVER_LIFT := Vector2(0.0, -3.0)
const HOVER_TWEEN_DURATION := 0.1
const PRESS_SCALE := Vector2(0.96, 0.96)
const PRESS_TWEEN_DURATION := 0.1

var _press_tracker := PressTracker.new()
var _hovering := false
var _rest_position := Vector2.ZERO

## ホバー/押下でTweenするのはこのノード(見た目専用の子)。コンテナの直接の子である
## 自分自身(Control)のposition/scaleを外部から書き換えると、コンテナの再レイアウト時に
## 値が衝突して並びが崩れるため、見た目はVisualRootへ逃がす。存在しない場合は自分自身を使う。
var _visual_root: Control


func _ready() -> void:
	mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	_visual_root = get_node_or_null("VisualRoot")
	if _visual_root == null:
		_visual_root = self
	_rest_position = _visual_root.position
	resized.connect(_on_resized)
	mouse_entered.connect(_on_mouse_entered)
	mouse_exited.connect(_on_mouse_exited)


func _gui_input(event: InputEvent) -> void:
	match _press_tracker.feed(event, size):
		PressTracker.Result.PRESSED:
			animate_press(_visual_root, true)
		PressTracker.Result.CONFIRMED:
			animate_press(_visual_root, false)
			area_pressed.emit()
		PressTracker.Result.CANCELED:
			animate_press(_visual_root, false)


func _on_resized() -> void:
	_visual_root.pivot_offset = _visual_root.size / 2.0
	if not _hovering:
		_rest_position = _visual_root.position


func _on_mouse_entered() -> void:
	_hovering = true
	animate_hover(_visual_root, true, _rest_position)


func _on_mouse_exited() -> void:
	_hovering = false
	animate_hover(_visual_root, false, _rest_position)


static func is_primary_click(event: InputEvent) -> bool:
	if event is InputEventMouseButton:
		return event.pressed and event.button_index == MOUSE_BUTTON_LEFT
	if event is InputEventScreenTouch:
		return event.pressed
	return false


static func is_primary_release(event: InputEvent) -> bool:
	if event is InputEventMouseButton:
		return not event.pressed and event.button_index == MOUSE_BUTTON_LEFT
	if event is InputEventScreenTouch:
		return not event.pressed
	return false


## ホバーで軽く明るくしつつ、わずかに浮き上がらせる。選択ハイライト(StyleBox側)とは
## 独立したプロパティ(modulate/position)で表現するため、選択状態と共存できる。
static func animate_hover(control: Control, hovering: bool, rest_position: Vector2) -> void:
	var tween := control.create_tween()
	tween.set_parallel(true)
	var target_modulate := HOVER_MODULATE if hovering else Color(1.0, 1.0, 1.0, 1.0)
	var target_position := rest_position + HOVER_LIFT if hovering else rest_position
	tween.tween_property(control, "modulate", target_modulate, HOVER_TWEEN_DURATION)
	tween.tween_property(control, "position", target_position, HOVER_TWEEN_DURATION)


## 押し込みでわずかに縮小させる。呼び出し側は事前にpivot_offsetを中心へ設定しておくこと。
static func animate_press(control: Control, pressed: bool) -> void:
	var tween := control.create_tween()
	var target_scale := PRESS_SCALE if pressed else Vector2.ONE
	tween.tween_property(control, "scale", target_scale, PRESS_TWEEN_DURATION)
