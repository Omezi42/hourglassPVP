class_name LongPress
extends RefCounted
## タッチの長押し(GameDesign.md 9章「タッチでの操作」)。押したまま指を動かさずに
## `CardMatchPointer.LONG_PRESS_SECONDS` 経ったら `fired` を出す。対局画面以外の画面が使う。

signal fired

var _timer: Timer
var _at := Vector2.ZERO
var _fired := false


func _init(owner: Node) -> void:
	_timer = Timer.new()
	_timer.one_shot = true
	_timer.wait_time = CardMatchPointer.LONG_PRESS_SECONDS
	_timer.timeout.connect(_on_timeout)
	owner.add_child(_timer)


## 押した。`at` はグローバル座標。
func begin(at: Vector2) -> void:
	_at = at
	_fired = false
	_timer.start()


## 指が動いた。遊びを超えたら長押しにしない(スクロール・ドラッグとして扱う)。
func move(at: Vector2) -> void:
	if not _fired and at.distance_to(_at) > PressTracker.SLOP_MARGIN:
		_timer.stop()


## 離した。長押しが成立していたら true(押した扱いにしない)。
func end() -> bool:
	_timer.stop()
	var was_fired := _fired
	_fired = false
	return was_fired


func is_fired() -> bool:
	return _fired


func _on_timeout() -> void:
	_fired = true
	fired.emit()
