class_name TouchScroll
extends RefCounted
## `ScrollContainer` を、中身のどこをつかんでも指で動かせるようにする(GameDesign.md 9章「タッチでの操作」)。
##
## 素の `ScrollContainer` へ届くのは、ボタンやカードが受け取らなかった入力(すき間を押したとき)だけ。
## そこで中身の `Control` 全部の `gui_input` へ後付けで見張りを掛ける。シグナルは各 `Control` 自身の処理より
## 先に呼ばれるため、スクロールした指を離したときの「押した」をここで握りつぶせる。
## 1つのScrollContainerにつき1個作り、ScrollContainerのメタに持たせて寿命を合わせる。

## 指がこれだけ動くまではタップのぶれとして扱い、スクロールを始めない(Godotのドラッグ開始と同じ値)。
const DEADZONE := 10.0
## 離した後に惰性で流れる時間。距離は離す直前の速さ × この時間の半分になる。
const FLING_SECONDS := 0.5
## 離す直前にこれより長く止まっていたら惰性を付けない。
const FLING_STALE_MSEC := 100
const META_KEY := &"touch_scroll"

## いま指が一覧の上に置かれているか。ドラッグで運べる札が「縦の動きはスクロールに譲る」判断に使う。
static var _touching := false

var _scroll: ScrollContainer
var _tracking := false
var _accum := Vector2.ZERO
## 遊びを超えた時点で決めた向き(RIGHT / DOWN)。ZEROはまだ遊びの内。
var _axis := Vector2.ZERO
var _scrolled := false
var _carry := Vector2.ZERO
var _velocity := Vector2.ZERO
var _last_drag_msec := 0
var _fling: Tween


## 生成した(または `.tscn` から取り出した)ScrollContainerへ1回だけ呼ぶ。
static func enable(scroll: ScrollContainer) -> void:
	var touch := TouchScroll.new()
	touch._scroll = scroll
	scroll.set_meta(META_KEY, touch)
	scroll.tree_entered.connect(touch._watch_tree)
	scroll.tree_exiting.connect(touch._unwatch_tree)
	if scroll.is_inside_tree():
		touch._watch_tree()
		touch._wire_subtree(scroll)


static func is_touching() -> bool:
	return _touching


func _watch_tree() -> void:
	var tree := _scroll.get_tree()
	if not tree.node_added.is_connected(_on_node_added):
		tree.node_added.connect(_on_node_added)


func _unwatch_tree() -> void:
	var tree := _scroll.get_tree()
	if tree.node_added.is_connected(_on_node_added):
		tree.node_added.disconnect(_on_node_added)


func _wire_subtree(node: Node) -> void:
	_on_node_added(node)
	for child in node.get_children():
		_wire_subtree(child)


func _on_node_added(node: Node) -> void:
	if not node is Control or not _owns(node):
		return
	var watcher := _on_gui_input.bind(node)
	if not (node as Control).gui_input.is_connected(watcher):
		(node as Control).gui_input.connect(watcher)


func _owns(node: Node) -> bool:
	return node == _scroll or _scroll.is_ancestor_of(node)


func _on_gui_input(event: InputEvent, control: Control) -> void:
	if not _owns(control):
		return
	if event is InputEventScreenTouch and event.index == 0:
		if event.pressed:
			_begin()
		else:
			_end(control)
	elif event is InputEventScreenDrag and event.index == 0:
		if _tracking:
			_drag(event)
		control.accept_event()
	elif event is InputEventMouse and event.device == InputEvent.DEVICE_ID_EMULATION:
		# タッチから作られたマウス。スクロールした指の「離した」は押した扱いにしない。
		# すき間を押したときはScrollContainer自身の指スクロールとも二重に動くため止める。
		var release: bool = event is InputEventMouseButton and not event.pressed
		if control == _scroll or (_scrolled and release):
			control.accept_event()


func _begin() -> void:
	if _fling != null:
		_fling.kill()
	_touching = true
	_tracking = true
	_accum = Vector2.ZERO
	_axis = Vector2.ZERO
	_scrolled = false
	_carry = Vector2.ZERO
	_velocity = Vector2.ZERO


func _drag(event: InputEventScreenDrag) -> void:
	_velocity = event.velocity
	_last_drag_msec = Time.get_ticks_msec()
	if _axis != Vector2.ZERO:
		if _scrolled:
			_move(event.relative)
		return
	_accum += event.relative
	if _accum.length() < DEADZONE:
		return
	_axis = Vector2.RIGHT if absf(_accum.x) > absf(_accum.y) else Vector2.DOWN
	if not _can_scroll(_axis):
		return
	_scrolled = true
	# ボタンの押し込みを解く(BaseButton と ClickArea がこの通知で取り消す)。
	_scroll.propagate_notification(Control.NOTIFICATION_SCROLL_BEGIN)
	_move(_accum)


func _end(control: Control) -> void:
	_touching = false
	_tracking = false
	if not _scrolled:
		return
	control.accept_event()
	_scroll.propagate_notification(Control.NOTIFICATION_SCROLL_END)
	if Time.get_ticks_msec() - _last_drag_msec > FLING_STALE_MSEC:
		return
	var from := _offset()
	var to := from - _velocity * _axis * FLING_SECONDS * 0.5
	_fling = _scroll.create_tween()
	_fling.tween_method(_set_offset, from, to, FLING_SECONDS).set_trans(Tween.TRANS_QUAD).set_ease(
		Tween.EASE_OUT
	)


func _can_scroll(axis: Vector2) -> bool:
	var mode := _scroll.horizontal_scroll_mode if axis.x != 0.0 else _scroll.vertical_scroll_mode
	return mode != ScrollContainer.SCROLL_MODE_DISABLED


## 指の動きは小数で来るため、端数を持ち越して整数のスクロール位置へ足す(切り捨てると遅く感じる)。
func _move(delta: Vector2) -> void:
	_carry += delta * _axis
	var whole := Vector2i(_carry)
	_carry -= Vector2(whole)
	_scroll.scroll_horizontal -= whole.x
	_scroll.scroll_vertical -= whole.y


func _offset() -> Vector2:
	return Vector2(_scroll.scroll_horizontal, _scroll.scroll_vertical)


func _set_offset(value: Vector2) -> void:
	_scroll.scroll_horizontal = roundi(value.x)
	_scroll.scroll_vertical = roundi(value.y)
