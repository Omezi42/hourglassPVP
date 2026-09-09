class_name SoloTab
extends Control
## ホーム画面の「ソロ」タブ(GameDesign.md 9章・27章)。
##
## CPU戦・リーサルパズルの入口は、以前バトルタブにあったものをここへ移した
## (**中身は変更しない**。押した先の画面・遷移はそのまま)。「ソロモード」は
## ステージのツリー(27章)を開くボタン。
## `RulesTab` と同じく `.tscn` を持たず、`HomeScreen` がコードで生成する。

signal cpu_match_requested
signal puzzle_requested
signal solo_requested

## アカウント帯を避ける上端と、下部タブに接する下端。`RulesTab`と同じ値。
const TOP_BAND := 112.0
const BOTTOM := 560.0
const TILE_SIZE := Vector2(460, 108)
const TILE_FONT_SIZE := 26
const TILE_GAP := 24.0
## 基準解像度1280x720(GameDesign.md 9章)の横幅を基準に中央へ置く。
const SCREEN_WIDTH := 1280.0

var _cpu_tile: HomeTile


func _ready() -> void:
	var total_height: float = TILE_SIZE.y * 3 + TILE_GAP * 2
	var start_y: float = TOP_BAND + (BOTTOM - TOP_BAND - total_height) * 0.5
	var left: float = (SCREEN_WIDTH - TILE_SIZE.x) * 0.5

	_cpu_tile = HomeTile.make("CPU戦", "思考レベルを選んでCPUと対局します", "hour", TILE_SIZE, TILE_FONT_SIZE)
	_cpu_tile.position = Vector2(left, start_y)
	_cpu_tile.pressed.connect(func() -> void: cpu_match_requested.emit())
	add_child(_cpu_tile)

	var puzzle_tile := HomeTile.make(
		"リーサルパズル", "固定の盤面から1手で仕留める手順を探します", "sword", TILE_SIZE, TILE_FONT_SIZE
	)
	puzzle_tile.position = Vector2(left, start_y + TILE_SIZE.y + TILE_GAP)
	puzzle_tile.pressed.connect(func() -> void: puzzle_requested.emit())
	add_child(puzzle_tile)

	var solo_tile := HomeTile.make("ソロモード", "ツリー状のステージに挑みます", "crown", TILE_SIZE, TILE_FONT_SIZE)
	solo_tile.position = Vector2(left, start_y + (TILE_SIZE.y + TILE_GAP) * 2)
	solo_tile.pressed.connect(func() -> void: solo_requested.emit())
	add_child(solo_tile)

	refresh()


## デッキタブと同じく、開くたびに読み直す(GameDesign.md 9章)。CPU戦は対局前の
## デッキ選択画面が`CardDeckSave.selected_deck()`を使うため、それが30枚に
## 満たない間は押しても対局へ入れない旨を先に示す(以前のバトルタブと同じ判定)。
func refresh() -> void:
	if _cpu_tile == null:
		return
	# 未保存でもプリセットの「基本」が返るため、通常はここで無効になることはない
	# (GameDesign.md 18章)。壊れたデッキが選ばれている場合の保険として残す。
	var ready_to_battle: bool = CardDeckSave.selected_deck().size() == MatchState.DECK_SIZE
	_cpu_tile.disabled = not ready_to_battle
	_cpu_tile.set_subtitle(
		"デッキを%d枚にしてください" % MatchState.DECK_SIZE if not ready_to_battle else "思考レベルを選んでCPUと対局します"
	)
