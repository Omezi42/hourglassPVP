class_name ButtonFold
extends RefCounted
## ボタンの出し消し(GameDesign.md 9章「対局画面の手触り」)。出すときは即時、消すときは短く薄れてから隠す。
## 薄れている間は押せない。落ちている途中で再び出すときは tween を止めて元へ戻す。

const DURATION := CardView.UNSELECT_DURATION

var _button: Control
var _tween: Tween
var _folding := false
var _filter := Control.MOUSE_FILTER_STOP


func _init(button: Control) -> void:
	_button = button
	_filter = button.mouse_filter


func set_shown(shown: bool) -> void:
	if shown:
		_restore()
		_button.visible = true
		return
	if not _button.visible or _folding:
		return
	_folding = true
	_button.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_tween = _button.create_tween().set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	_tween.tween_property(_button, "modulate:a", 0.0, DURATION)
	_tween.tween_callback(_finish)


func _finish() -> void:
	_restore()
	_button.visible = false


func _restore() -> void:
	if _tween != null and _tween.is_valid():
		_tween.kill()
	_folding = false
	_button.modulate.a = 1.0
	_button.mouse_filter = _filter
