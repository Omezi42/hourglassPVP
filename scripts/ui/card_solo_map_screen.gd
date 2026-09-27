class_name CardSoloMapScreen
extends Control
## ソロモードのステージ一覧(GameDesign.md 27章)。左に蛇行する1本道(`SoloTrail`)、右に選んだ
## ステージの中身と「挑戦」(`SoloStageDetail`)を置く。開いたときは次に挑むステージを選んでおく。

signal back_pressed
signal stage_selected(stage: SoloStageData)

const HEADER_SCENE := "res://scenes/screen_header.tscn"
const MAP_RECT := Rect2(24, ScreenHeader.CONTENT_TOP, 820, ScreenHeader.CONTENT_HEIGHT)
const DETAIL_RECT := Rect2(868, ScreenHeader.CONTENT_TOP, 388, ScreenHeader.CONTENT_HEIGHT)

var _scroll: ScrollContainer
var _trail: SoloTrail
var _detail: SoloStageDetail
var _empty: EmptyState
var _stages: Array[SoloStageData] = []
var _cleared: Array[bool] = []
var _unlocked: Array[bool] = []


func _ready() -> void:
	_build()


func open() -> void:
	_refresh()


func _build() -> void:
	var backdrop := ScreenBackdrop.new()
	backdrop.room = ScreenBackdrop.Room.HALL
	add_child(backdrop)
	var header: ScreenHeader = load(HEADER_SCENE).instantiate()
	add_child(header)
	header.set_title("ソロモード")
	header.back_pressed.connect(func() -> void: back_pressed.emit())

	_scroll = ScrollContainer.new()
	_scroll.position = MAP_RECT.position
	_scroll.size = MAP_RECT.size
	_scroll.custom_minimum_size = MAP_RECT.size
	TouchScroll.enable(_scroll)
	_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	add_child(_scroll)

	var centering := CenterContainer.new()
	centering.custom_minimum_size = MAP_RECT.size
	_scroll.add_child(centering)
	_trail = SoloTrail.new()
	_trail.stage_chosen.connect(_select)
	centering.add_child(_trail)

	_detail = SoloStageDetail.new()
	_detail.position = DETAIL_RECT.position
	_detail.size = DETAIL_RECT.size
	_detail.custom_minimum_size = DETAIL_RECT.size
	_detail.challenge_pressed.connect(
		func(stage: SoloStageData) -> void: stage_selected.emit(stage)
	)
	add_child(_detail)

	_empty = EmptyState.new()
	_empty.position = MAP_RECT.position
	_empty.size = Vector2(DETAIL_RECT.end.x - MAP_RECT.position.x, MAP_RECT.size.y)
	add_child(_empty)


func _refresh() -> void:
	_stages = SoloLibrary.all_stages()
	var has_stages := not _stages.is_empty()
	_scroll.visible = has_stages
	_detail.visible = has_stages
	_empty.visible = not has_stages
	if not has_stages:
		_empty.show_message("まだステージがありません", "近日公開")
		return
	var uid := _uid()
	_cleared.clear()
	_unlocked.clear()
	for stage in _stages:
		_cleared.append(SoloProgress.is_cleared(uid, stage.id))
		_unlocked.append(SoloLibrary.is_unlocked(stage, uid))
	_trail.show_stages(_stages, _cleared, _unlocked, MAP_RECT.size.x)
	var next := _next_stage_index()
	_select(next)
	_scroll_to.call_deferred(next)


func _select(index: int) -> void:
	_trail.select(index)
	_detail.show_stage(_stages[index], _cleared[index], _unlocked[index])


## 解放済みで未クリアの先頭。すべてクリア済みなら最後のステージ。
func _next_stage_index() -> int:
	for i in _stages.size():
		if _unlocked[i] and not _cleared[i]:
			return i
	return _stages.size() - 1


func _scroll_to(index: int) -> void:
	var center_y := _trail.node_center(index).y
	_scroll.scroll_vertical = int(maxf(center_y - MAP_RECT.size.y * 0.5, 0.0))


func _uid() -> String:
	if NetSession.client == null or NetSession.client.auth == null:
		return ""
	return NetSession.client.auth.uid
