class_name BattleTab
extends Control
## ホーム画面の「たたかう」タブ(GameDesign.md 9章)。
##
## **対局の入口をすべてここへ集める。**以前はランダムマッチがこのタブ、CPU戦とパズルが
## ソロタブ、誘導対局がルールタブにあり、「いまから1局遊びたい」の行き先が決まらなかった。
## 上枠「だれかと」・下枠「ひとりで」の2つに分け、オンラインを上に置く。
##
## **クラス名は `BattleTab` のまま変えない。**`scenes/battle_tab.tscn` を
## `scenes/home_screen.tscn` が instance しており、名前を変えると参照の書き換えという
## 実害のある作業を招く(`DeckTab` / `RulesTab` を変えないのと同じ理由。Architecture.md 4章)。
## 画面に出る名前が「たたかう」であることと、意味の上でも食い違わない。
##
## **ランダムマッチのキュー参加・待機・成立は持たない**(Architecture.md 6.6節)。
## デッキ選択画面を終えた後は専用の `CardRandomMatchScreen` へ入るため、このタブが
## 持つのは入口のタイルが `random_match_deck_requested` を発行するところまで。

signal resume_requested(record: Dictionary)
signal random_match_deck_requested
## ルームマッチの専用画面を開く。デッキ選択もその画面の中で行うため、
## 他の導線と違ってここでデッキ選択画面を挟まない(GameDesign.md 9章)。
signal room_match_requested
signal cpu_match_requested
signal puzzle_requested
signal solo_requested

## 通信待ち中の「...」演出。3個目まで打ってから空に戻る(対局画面の待機表現と統一)。
const BUSY_DOTS_MAX := 3
const BUSY_DOTS_INTERVAL := 0.5

## アカウント帯を避ける上端と、下部タブに接する下端。他のタブと同じ値。
const TOP_BAND := 112.0
const BOTTOM := 560.0
const FRAME_X := 140.0
const FRAME_W := 1000.0
## 復帰の帯(GameDesign.md 9章)。**急ぐ用件なので最上段へ置く。**
const RESUME_RECT := Rect2(FRAME_X, TOP_BAND + 4.0, FRAME_W, 46.0)
const RESUME_GAP := 16.0

const ONLINE_FRAME_H := 164.0
const SOLO_FRAME_H := 186.0
const FRAME_GAP := 18.0
const TILE_TOP := 46.0
const TILE_PAD := 20.0
const MAIN_TILE_SIZE := Vector2(600, 100)
const SIDE_TILE_SIZE := Vector2(340, 100)
const SOLO_TILE_SIZE := Vector2(306, 114)
const SOLO_TILE_GAP := 320.0
const MAIN_FONT_SIZE := 30
const SIDE_FONT_SIZE := 24
const SOLO_FONT_SIZE := 22

var _busy := false
var _busy_dots_timer: Timer
var _busy_dot_count := 0
var _status_base_text := ""
## 切断した対局へ戻る導線(GameDesign.md 11章)。戻れる対局があるときだけ出す。
var _resume_band: ResumeBand
var _online_frame: HomeFrame
var _solo_frame: HomeFrame
var _random_tile: HomeTile
var _room_tile: HomeTile
var _cpu_tile: HomeTile
var _solo_tiles: Array[HomeTile] = []

@onready var status_label: Label = $Margin/VBox/StatusLabel


func _ready() -> void:
	_busy_dots_timer = Timer.new()
	_busy_dots_timer.wait_time = BUSY_DOTS_INTERVAL
	_busy_dots_timer.timeout.connect(_on_busy_dots_timeout)
	add_child(_busy_dots_timer)
	_take_over_status_label()
	_build()
	refresh()


## `.tscn` の縦並び(`Margin/VBox`)は、枠を絶対座標へ置く新しい構成では使えない。
## **待機中の文言だけを引き取り、残りは捨てる。**`.tscn` そのものは書き換えない
## (`scenes/home_screen.tscn` が instance しているため。Architecture.md 4章)。
func _take_over_status_label() -> void:
	var margin: Node = $Margin
	status_label.get_parent().remove_child(status_label)
	add_child(status_label)
	margin.queue_free()
	status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT


func _build() -> void:
	_resume_band = ResumeBand.make(RESUME_RECT)
	_resume_band.pressed.connect(_on_resume_pressed)
	add_child(_resume_band)

	_online_frame = HomeFrame.make(Rect2(Vector2.ZERO, Vector2(FRAME_W, ONLINE_FRAME_H)), "だれかと")
	add_child(_online_frame)
	_random_tile = HomeTile.make(
		"ランダムマッチ", "いますぐ相手を探す", "burst", MAIN_TILE_SIZE, MAIN_FONT_SIZE, true
	)
	_random_tile.pressed.connect(func() -> void: random_match_deck_requested.emit())
	add_child(_random_tile)
	_room_tile = HomeTile.make("ルームマッチ", "合言葉で友達と", "shield", SIDE_TILE_SIZE, SIDE_FONT_SIZE)
	_room_tile.pressed.connect(func() -> void: room_match_requested.emit())
	add_child(_room_tile)

	_solo_frame = HomeFrame.make(Rect2(Vector2.ZERO, Vector2(FRAME_W, SOLO_FRAME_H)), "ひとりで")
	add_child(_solo_frame)
	# **副題で「自由な対局」と「決まった課題」を対比させる**(GameDesign.md 9章)。
	# ソロモードはCPU対戦型・パズル型を含む上位集合であり、並べただけでは関係が読めない。
	# **固定の数を書かない**——ステージを足したときに嘘になる。
	_cpu_tile = HomeTile.make("CPU戦", "好きなデッキで1局", "hour", SOLO_TILE_SIZE, SOLO_FONT_SIZE)
	_cpu_tile.pressed.connect(func() -> void: cpu_match_requested.emit())
	add_child(_cpu_tile)
	var solo_tile := HomeTile.make("ソロモード", "決まった条件の関門に挑む", "crown", SOLO_TILE_SIZE, SOLO_FONT_SIZE)
	solo_tile.pressed.connect(func() -> void: solo_requested.emit())
	add_child(solo_tile)
	var puzzle_tile := HomeTile.make("リーサルパズル", "1手番で仕留める", "sword", SOLO_TILE_SIZE, SOLO_FONT_SIZE)
	puzzle_tile.pressed.connect(func() -> void: puzzle_requested.emit())
	add_child(puzzle_tile)
	_solo_tiles = [_cpu_tile, solo_tile, puzzle_tile]
	# 見出しの行は枠の上端に跨がるため、枠より後の子にしないとパネルへ隠れる
	# (**後から `add_child()` した子ほど手前に描かれる**。Architecture.md 11章)。
	move_child(status_label, get_child_count() - 1)
	_layout()


## 復帰の帯の有無で全体の位置が変わる。**どちらの場合も、与えられた領域
## (上端112px〜下部タブ)の中央へ置く。**上端へ寄せると下半分がまるごと空き、
## 帯の有無で上下の余白が食い違う。
func _layout() -> void:
	var stack: float = ONLINE_FRAME_H + FRAME_GAP + SOLO_FRAME_H
	var band_on: bool = _resume_band != null and _resume_band.visible
	if band_on:
		stack += RESUME_RECT.size.y + RESUME_GAP
	var origin: float = TOP_BAND + (BOTTOM - TOP_BAND - stack) * 0.5
	var top := origin
	if band_on:
		_resume_band.position = Vector2(FRAME_X, origin)
		top = origin + RESUME_RECT.size.y + RESUME_GAP
	_online_frame.position = Vector2(FRAME_X, top)
	_random_tile.position = _online_frame.position + Vector2(TILE_PAD, TILE_TOP)
	_room_tile.position = (
		_online_frame.position + Vector2(TILE_PAD + MAIN_TILE_SIZE.x + TILE_PAD, TILE_TOP)
	)
	var solo_top: float = top + ONLINE_FRAME_H + FRAME_GAP
	_solo_frame.position = Vector2(FRAME_X, solo_top)
	for i in _solo_tiles.size():
		_solo_tiles[i].position = (
			_solo_frame.position + Vector2(TILE_PAD + float(i) * SOLO_TILE_GAP, TILE_TOP + 2.0)
		)
	_layout_status_row(top)


## 見出しの行(枠の上端に跨がる帯)へ、待機中の文言を置く。**マッチングの待機はもう
## ここに乗らない**(専用画面へ移した)ため、以前あったキャンセルボタンは無い。
func _layout_status_row(top: float) -> void:
	var plate_top: float = top - HomeFrame.HEADING_HEIGHT * HomeFrame.HEADING_OVERLAP
	var plate_center: float = plate_top + HomeFrame.HEADING_HEIGHT * 0.5
	var status_left: float = FRAME_X + 240.0
	var status_right: float = FRAME_X + FRAME_W - HomeFrame.HEADING_LEFT
	status_label.position = Vector2(status_left, plate_center - 15.0)
	status_label.size = Vector2(maxf(status_right - status_left, 120.0), 30.0)


func refresh() -> void:
	if _busy:
		return
	_refresh_resume()
	# 未保存でもプリセットの「基本」が返るため、常に対戦できる(GameDesign.md 18章)。
	var ready_to_battle: bool = CardDeckSave.selected_deck().size() == MatchState.DECK_SIZE
	_random_tile.disabled = not ready_to_battle
	_room_tile.disabled = not ready_to_battle
	_cpu_tile.disabled = not ready_to_battle
	_set_status("" if ready_to_battle else "デッキを%d枚にしてください" % MatchState.DECK_SIZE)


## 覚えている対局があるときだけ出す。終わっているかどうかは押した時点で確かめる
## (毎回ホームで通信すると、オフラインでも遊べるという前提を崩すため)。
func _refresh_resume() -> void:
	if _resume_band == null:
		return
	_resume_band.visible = not OnlineResume.pending().is_empty()
	_layout()


func _on_resume_pressed() -> void:
	var record := OnlineResume.pending()
	if record.is_empty():
		_refresh_resume()
		return
	_set_busy(true)
	_set_status("前回の対局を確認しています")
	if not await _sign_in_or_fail():
		return
	_busy = false
	_stop_busy_dots()
	resume_requested.emit(record)


func _set_busy(busy: bool) -> void:
	_busy = busy
	_random_tile.disabled = busy
	_room_tile.disabled = busy
	_cpu_tile.disabled = busy
	if busy:
		_busy_dot_count = 0
		_busy_dots_timer.start()
	else:
		_stop_busy_dots()
		refresh()


## 対局から戻ってきたときに、待機状態(ボタンの無効化)を解く。
func reset_after_match() -> void:
	_set_busy(false)


## 待機中テキストの土台(base)を更新し、末尾のドットと合わせて表示し直す。
func _set_status(text: String) -> void:
	_status_base_text = text
	_refresh_status_display()


func _refresh_status_display() -> void:
	var text := _status_base_text
	if _busy:
		text += ".".repeat(_busy_dot_count)
	status_label.text = text


func _on_busy_dots_timeout() -> void:
	_busy_dot_count = (_busy_dot_count % BUSY_DOTS_MAX) + 1
	_refresh_status_display()


func _stop_busy_dots() -> void:
	_busy_dots_timer.stop()
	_busy_dot_count = 0


func _sign_in_or_fail() -> bool:
	var ok: bool = await NetSession.sign_in()
	if not ok:
		_fail("通信に失敗しました。もう一度お試しください")
	return ok


## 失敗の理由を表示して待機状態を解く。_set_busy(false)は最後にrefresh()を呼んで
## 定型文でstatus_labelを上書きするため、文言はその後に入れないと表示されない。
func _fail(message: String) -> void:
	_set_busy(false)
	status_label.text = message
