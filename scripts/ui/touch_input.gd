class_name TouchInput
extends RefCounted
## いまタッチで操作しているか(GameDesign.md 9章「タッチでの操作」/ Architecture.md 4.7節)。
## 直前の入力が画面のタッチか、タッチから作られたマウスなら true。向きとは独立に持つ。

static var active := false


static func note(event: InputEvent) -> void:
	if event is InputEventScreenTouch or event is InputEventScreenDrag:
		active = true
	elif event is InputEventMouseButton or event is InputEventMouseMotion:
		active = event.device == InputEvent.DEVICE_ID_EMULATION
