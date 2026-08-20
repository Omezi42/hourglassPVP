class_name DeckSlot
extends Control

signal slot_pressed
signal card_dropped(hourglass_id: String)

var hourglass_id: String = ""

var _press_tracker := PressTracker.new()
var _hovering := false
var _rest_position := Vector2.ZERO

## ホバー/押下のTween先。コンテナの直接の子である自分自身のposition/scaleを
## 外部から動かすと再レイアウト時に崩れるため、見た目専用のVisualRootへ逃がす。
@onready var visual_root: Control = $VisualRoot
@onready var icon: TextureRect = $VisualRoot/Icon
@onready var empty_label: Label = $VisualRoot/EmptyLabel


func _ready() -> void:
	_rest_position = visual_root.position
	resized.connect(_on_resized)
	mouse_entered.connect(_on_mouse_entered)
	mouse_exited.connect(_on_mouse_exited)


func _gui_input(event: InputEvent) -> void:
	if hourglass_id == "":
		return
	match _press_tracker.feed(event, size):
		PressTracker.Result.PRESSED:
			ClickArea.animate_press(visual_root, true)
		PressTracker.Result.CONFIRMED:
			ClickArea.animate_press(visual_root, false)
			slot_pressed.emit()
		PressTracker.Result.CANCELED:
			ClickArea.animate_press(visual_root, false)


func _get_drag_data(_at_position: Vector2) -> Variant:
	if hourglass_id == "":
		return null
	# ドラッグが始まったら、押しっぱなしのまま宙に浮く見た目にならないよう押下状態を解除する
	if _press_tracker.cancel():
		ClickArea.animate_press(visual_root, false)
	var dragged_id := hourglass_id
	var preview: TextureRect = TextureRect.new()
	preview.texture = icon.texture
	preview.custom_minimum_size = Vector2(64, 64)
	preview.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	set_drag_preview(preview)
	clear()
	return {"hourglass_id": dragged_id}


func _can_drop_data(_at_position: Vector2, data: Variant) -> bool:
	return typeof(data) == TYPE_DICTIONARY and data.has("hourglass_id")


func _drop_data(_at_position: Vector2, data: Variant) -> void:
	card_dropped.emit(str(data["hourglass_id"]))


func show_hourglass(data: HourglassData) -> void:
	hourglass_id = data.id
	icon.texture = data.icon_upright
	icon.visible = true
	empty_label.visible = false
	mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND


func clear() -> void:
	hourglass_id = ""
	icon.texture = null
	icon.visible = false
	empty_label.visible = true
	mouse_default_cursor_shape = Control.CURSOR_ARROW
	_hovering = false
	visual_root.modulate = Color(1.0, 1.0, 1.0, 1.0)
	visual_root.scale = Vector2.ONE


func _on_resized() -> void:
	visual_root.pivot_offset = visual_root.size / 2.0
	if not _hovering:
		_rest_position = visual_root.position


func _on_mouse_entered() -> void:
	if hourglass_id == "":
		return
	_hovering = true
	ClickArea.animate_hover(visual_root, true, _rest_position)


func _on_mouse_exited() -> void:
	_hovering = false
	ClickArea.animate_hover(visual_root, false, _rest_position)
