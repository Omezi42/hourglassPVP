class_name MatchBoardCamera
extends RefCounted
## ターン終了時の解決演出で、盤面だけをズーム/パンさせる(GameDesign.md 9章)。
## 対象はMatchScreenのBoardArea(clip_contents付きのControl)配下に置いたBoardCameraのみで、
## 上下のTopBar/BottomBar(HPと砂時計スロット)はBoardAreaの外にあるため影響を受けない。
## GameBoard側の座標系・レイアウトには一切触れず、scaleとpositionだけをTweenする。

const ZOOM_SCALE := 1.5
const FOCUS_DURATION := 0.34
const RESET_DURATION := 0.3

var _screen: MatchScreen
var _tween: Tween


func _init(screen: MatchScreen) -> void:
	_screen = screen


## 注目させたい駒の矩形(画面座標。移動は関与する2マス)を受け取り、その中心が
## BoardAreaの中心へ来るように寄せる。pivot_offsetは使わず「position + 局所座標 * scale」の
## 一次変換をそのままTweenするため、途中フレームでも見た目が破綻しない。
func focus(global_rects: Array[Rect2]) -> void:
	var camera := _screen.board_camera
	if camera == null or global_rects.is_empty():
		return
	var bounds: Rect2 = global_rects[0]
	for i in range(1, global_rects.size()):
		bounds = bounds.merge(global_rects[i])
	var local_center: Vector2 = camera.get_global_transform().affine_inverse() * bounds.get_center()
	var target_scale := Vector2(ZOOM_SCALE, ZOOM_SCALE)
	var target_position: Vector2 = _area_center() - local_center * ZOOM_SCALE
	_start(target_scale, target_position, FOCUS_DURATION)


## 引きの画(等倍・中央)へ戻す。
func reset(instant: bool = false) -> void:
	var camera := _screen.board_camera
	if camera == null:
		return
	var rest_position: Vector2 = _area_center() - camera.size * 0.5
	if instant:
		_kill()
		camera.scale = Vector2.ONE
		camera.position = rest_position
		return
	_start(Vector2.ONE, rest_position, RESET_DURATION)


func _area_center() -> Vector2:
	var area := _screen.board_area
	return Vector2.ZERO if area == null else area.size * 0.5


func _start(target_scale: Vector2, target_position: Vector2, duration: float) -> void:
	var camera := _screen.board_camera
	_kill()
	_tween = camera.create_tween()
	_tween.set_trans(Tween.TRANS_CUBIC)
	_tween.set_ease(Tween.EASE_OUT)
	_tween.tween_property(camera, "scale", target_scale, duration)
	_tween.parallel().tween_property(camera, "position", target_position, duration)


func _kill() -> void:
	if _tween != null and _tween.is_valid():
		_tween.kill()
