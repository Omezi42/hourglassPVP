class_name LabTab
extends Control
## ホーム画面5つ目のタブ「つくる」(GameDesign.md 9章・29章)。
## `RecordTab` / `RulesTab` と同じく `.tscn` を持たず、`HomeScreen` がコードで生成する。
##
## 掲示板〈ラボ〉——新規カード案の投稿と投票——への入口だけをここへ置く。

signal lab_requested

const TOP_BAND := 112.0
const FRAME_X := 140.0
const FRAME_W := 1000.0
const TILE_PAD := 20.0

const FRAME := Rect2(FRAME_X, TOP_BAND + 26.0, FRAME_W, 240.0)
const TILE_SIZE := Vector2(620, 150)
const TILE_TOP := 60.0
const TILE_FONT_SIZE := 30

var _tile: HomeTile


func _ready() -> void:
	add_child(HomeFrame.make(FRAME, "つくる"))
	_tile = HomeTile.make("掲示板〈ラボ〉", "こんなカードが欲しい、を投稿する", "eye", TILE_SIZE, TILE_FONT_SIZE, true)
	_tile.position = FRAME.position + Vector2(TILE_PAD, TILE_TOP)
	_tile.pressed.connect(func() -> void: lab_requested.emit())
	add_child(_tile)
