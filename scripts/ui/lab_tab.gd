class_name LabTab
extends Control
## ホーム画面5つ目のタブ「つくる」(GameDesign.md 9章・29章)。
## `RecordTab` / `RulesTab` と同じく `.tscn` を持たず、`HomeScreen` がコードで生成する。
##
## 掲示板〈ラボ〉への入口だけをここへ置く。タイルの副題に、開いている回のお題を出す。

signal lab_requested

const TOP_BAND := 112.0
const FRAME_X := 140.0
const FRAME_W := 1000.0
const TILE_PAD := 20.0

const FRAME := Rect2(FRAME_X, TOP_BAND + 26.0, FRAME_W, 240.0)
const TILE_SIZE := Vector2(620, 150)
const TILE_TOP := 60.0
const TILE_FONT_SIZE := 30
const IDLE_SUBTITLE := "お題に沿ったカード案を出す・選ぶ"

var _tile: HomeTile


func _ready() -> void:
	add_child(HomeFrame.make(FRAME, "つくる"))
	_tile = HomeTile.make("掲示板〈ラボ〉", IDLE_SUBTITLE, "eye", TILE_SIZE, TILE_FONT_SIZE, true)
	_tile.position = FRAME.position + Vector2(TILE_PAD, TILE_TOP)
	_tile.pressed.connect(func() -> void: lab_requested.emit())
	add_child(_tile)
	visibility_changed.connect(_refresh_subtitle)


func _refresh_subtitle() -> void:
	if not is_visible_in_tree() or NetSession.client == null:
		return
	var rounds: Array = await LabProposalService.fetch_rounds(NetSession.client)
	var current := LabRules.current_round(rounds, Time.get_unix_time_from_system())
	if current.is_empty():
		_tile.set_subtitle(IDLE_SUBTITLE)
		return
	_tile.set_subtitle("募集中のお題:%s" % str(current.get("title", "")))
