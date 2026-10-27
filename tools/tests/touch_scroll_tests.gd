extends RefCounted
## `TouchScroll`: ボタンの上からでも指で一覧を動かせ、動かした指を離しても押した扱いにならない。
## 入力は本物と同じ順(タッチから作られたマウス → タッチ)で画面へ流す。

const ROW_HEIGHT := 80.0
const ROWS := 20
const VIEW := Vector2(300, 400)

var _pressed := 0


func run(assert_true: Callable, root: Window) -> void:
	# ヘッドレスの窓は64px四方で、縮めて映した画面の外を押した入力は捨てられる。基準の大きさへ戻す。
	var window_size := root.size
	root.size = Vector2i(
		ProjectSettings.get_setting("display/window/size/viewport_width"),
		ProjectSettings.get_setting("display/window/size/viewport_height")
	)
	var scroll := ScrollContainer.new()
	scroll.size = VIEW
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	TouchScroll.enable(scroll)
	var rows := VBoxContainer.new()
	scroll.add_child(rows)
	root.add_child(scroll)
	for i in ROWS:
		var button := Button.new()
		button.custom_minimum_size = Vector2(VIEW.x, ROW_HEIGHT)
		button.pressed.connect(func() -> void: _pressed += 1)
		rows.add_child(button)
	await root.get_tree().process_frame
	await root.get_tree().process_frame

	var start := Vector2(150, 300)
	_touch(root, start, true)
	for step in 10:
		_drag(root, start + Vector2(0, -20 * (step + 1)), Vector2(0, -20))
	_touch(root, start + Vector2(0, -200), false)
	assert_true.call(
		scroll.scroll_vertical >= 190, "TouchScroll: dragging over a button scrolls the list"
	)
	assert_true.call(
		_pressed == 0, "TouchScroll: releasing after a scroll does not press the button"
	)

	_touch(root, start, true)
	_touch(root, start, false)
	assert_true.call(_pressed == 1, "TouchScroll: a plain tap still presses the button")

	scroll.queue_free()
	root.size = window_size


func _touch(root: Window, at: Vector2, pressed: bool) -> void:
	var mouse := InputEventMouseButton.new()
	mouse.device = InputEvent.DEVICE_ID_EMULATION
	mouse.button_index = MOUSE_BUTTON_LEFT
	mouse.pressed = pressed
	mouse.position = at
	mouse.global_position = at
	if pressed:
		mouse.button_mask = MOUSE_BUTTON_MASK_LEFT
	root.push_input(mouse)
	var touch := InputEventScreenTouch.new()
	touch.pressed = pressed
	touch.position = at
	root.push_input(touch)


func _drag(root: Window, at: Vector2, relative: Vector2) -> void:
	var motion := InputEventMouseMotion.new()
	motion.device = InputEvent.DEVICE_ID_EMULATION
	motion.button_mask = MOUSE_BUTTON_MASK_LEFT
	motion.position = at
	motion.global_position = at
	motion.relative = relative
	root.push_input(motion)
	var drag := InputEventScreenDrag.new()
	drag.position = at
	drag.relative = relative
	root.push_input(drag)
