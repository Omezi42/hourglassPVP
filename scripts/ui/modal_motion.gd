class_name ModalMotion
extends RefCounted
## モーダルの出入り(GameDesign.md 9章「動きの尺」の出る・消える 0.24秒)。
## 暗幕とパネルをまとめた `root` を透かして出し入れし、パネルは `SCALE_FROM` 倍からの拡縮を添える。
## 縦のパネルは `PortraitModal.SCALE` 倍で持つため、倍率は基準の倍率へ掛けて毎フレーム書く
## (`scale` へ直接 tween すると、基準の倍率を失う)。開いている途中から中のボタンは押せ、
## 閉じ始めた瞬間に下の画面を押せるようにする。

const SCALE_FROM := 0.96
const META_TWEEN := "modal_motion_tween"
const META_BASE := "modal_motion_base"
const META_CLOSING := "modal_motion_closing"


## `root` を出す。`panel` が null なら透かすだけ(押したボタンから膨らむ絞り込みなど)。
static func show(root: Control, panel: Control) -> void:
	var base := _begin(root, panel)
	root.visible = true
	root.set_meta(META_CLOSING, false)
	root.mouse_behavior_recursive = Control.MOUSE_BEHAVIOR_INHERITED
	if not root.is_inside_tree():
		_rest(root, panel, base)
		return
	_apply(0.0, root, panel, base, true)
	_play(root, panel, base, true, Tween.EASE_OUT, Callable())


## `root` を畳んで見えなくする。見えていないとき、畳んでいる最中は何もしない。
static func hide(root: Control, panel: Control, on_done: Callable = Callable()) -> void:
	if not root.visible or (root.has_meta(META_CLOSING) and root.get_meta(META_CLOSING)):
		return
	var base := _begin(root, panel)
	if not root.is_inside_tree():
		root.visible = false
		_rest(root, panel, base)
		if on_done.is_valid():
			on_done.call()
		return
	root.set_meta(META_CLOSING, true)
	root.mouse_behavior_recursive = Control.MOUSE_BEHAVIOR_DISABLED
	_play(root, panel, base, false, Tween.EASE_IN, on_done)


static func _begin(root: Control, panel: Control) -> Vector2:
	var base := Vector2.ONE if panel == null else panel.scale
	if root.has_meta(META_TWEEN):
		var running: Tween = root.get_meta(META_TWEEN)
		if running != null and running.is_valid():
			running.kill()
			base = root.get_meta(META_BASE)
	root.set_meta(META_BASE, base)
	if panel != null:
		panel.pivot_offset = panel.size * 0.5
	return base


static func _play(
	root: Control,
	panel: Control,
	base: Vector2,
	showing: bool,
	ease_type: Tween.EaseType,
	on_done: Callable
) -> void:
	var tween := root.create_tween().set_trans(Tween.TRANS_CUBIC).set_ease(ease_type)
	root.set_meta(META_TWEEN, tween)
	tween.tween_method(_apply.bind(root, panel, base, showing), 0.0, 1.0, UiPalette.DUR_SHOW)
	tween.tween_callback(_finish.bind(root, panel, base, showing, on_done))


## `progress` は0→1。出るときは透明→不透明と `SCALE_FROM`→1、消えるときはその逆。
static func _apply(
	progress: float, root: Control, panel: Control, base: Vector2, showing: bool
) -> void:
	var amount := progress if showing else 1.0 - progress
	root.modulate.a = amount
	if panel != null:
		panel.scale = base * lerpf(SCALE_FROM, 1.0, amount)


static func _finish(
	root: Control, panel: Control, base: Vector2, showing: bool, on_done: Callable
) -> void:
	if not showing:
		root.visible = false
		root.set_meta(META_CLOSING, false)
		root.mouse_behavior_recursive = Control.MOUSE_BEHAVIOR_INHERITED
	_rest(root, panel, base)
	if on_done.is_valid():
		on_done.call()


## 動きの外の姿(不透明・基準の倍率)へ戻す。
static func _rest(root: Control, panel: Control, base: Vector2) -> void:
	root.modulate.a = 1.0
	if panel != null:
		panel.scale = base
