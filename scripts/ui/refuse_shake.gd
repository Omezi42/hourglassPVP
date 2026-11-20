class_name RefuseShake
extends RefCounted
## 「だめ」の首振り(GameDesign.md 9章「操作への反応」)。出せない札・狙えない駒・入らない札が同じ振れで返事する。
## 位置の並びと1振りの尺はここだけが持つ。

const SWINGS: Array[float] = [7.0, -6.0, 4.0, -2.0, 0.0]
const STEP := 0.045
const REST_META := &"refuse_rest"
const TWEEN_META := &"refuse_tween"


## `rest` を中心に、`node.position` を左右へ振って戻す。
static func play(node: Node, rest: Vector2) -> Tween:
	var tween := node.create_tween().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	for swing in SWINGS:
		tween.tween_property(node, "position", rest + Vector2(swing, 0.0), STEP)
	return tween


## 置かれた位置のまま首を振る。振っている途中で呼ばれても、元の位置を見失わない。
static func play_in_place(node: Control) -> void:
	var previous: Variant = node.get_meta(TWEEN_META, null)
	if previous is Tween and (previous as Tween).is_valid():
		(previous as Tween).kill()
	var rest: Vector2 = node.get_meta(REST_META, node.position)
	node.set_meta(REST_META, rest)
	node.position = rest
	var tween := play(node, rest)
	tween.tween_callback(node.remove_meta.bind(REST_META))
	node.set_meta(TWEEN_META, tween)
