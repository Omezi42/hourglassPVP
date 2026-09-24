class_name BattleTab
extends Control
## ホーム画面の「たたかう」タブ(GameDesign.md 9章)。
##
## **対局の入口をすべてここへ集める。**左に真鍮の札「対戦する」(= ランクマッチ)を1枚、
## 右に凹んだパネルの列(CPU戦 / ソロモード / リーサルパズル / ルームマッチ)を置く。
## 1局も終えていない人には「対戦する」とCPU戦だけを出す。
##
## **クラス名は `BattleTab` のまま変えない。**`scenes/battle_tab.tscn` を
## `scenes/home_screen.tscn` が instance しており、名前を変えると参照の書き換えという
## 実害のある作業を招く(`DeckTab` / `RulesTab` を変えないのと同じ理由。Architecture.md 4章)。
##
## **マッチングの待機・成立は持たない**(Architecture.md 6.6節)。
## デッキ選択画面を終えた後は `CardRankedMatchScreen` へ入る。

signal resume_requested(record: Dictionary)
## ランクマッチ(GameDesign.md 28章)。デッキ選択画面を終えたら専用画面へ入る。
signal ranked_match_deck_requested
## ルームマッチの専用画面を開く。デッキ選択もその画面の中で行うため、
## 他の導線と違ってここでデッキ選択画面を挟まない(GameDesign.md 9章)。
signal room_match_requested
signal cpu_match_requested
signal puzzle_requested
signal solo_requested

## 通信待ち中の「...」演出。3個目まで打ってから空に戻る(対局画面の待機表現と統一)。
const BUSY_DOTS_MAX := 3
const BUSY_DOTS_INTERVAL := 0.5
## 待っている人の数を読み直す間隔(タブが見えている間だけ)。
const WAITING_POLL_SECONDS := 15.0

## アカウント帯を避ける上端と、下部タブに接する下端。他のタブと同じ値。
const TOP_BAND := 112.0
const BOTTOM := 560.0
const BOTTOM_MARGIN := 16.0
const FRAME_X := 140.0
const FRAME_W := 1000.0
## 待機中・失敗の文言を置く行。
const STATUS_TOP := TOP_BAND + 4.0
const STATUS_ROW := 32.0
## 復帰の帯(GameDesign.md 9章)。**急ぐ用件なので最上段へ置く。**
const RESUME_HEIGHT := 46.0
const RESUME_GAP := 16.0

const MAIN_WIDTH := 600.0
const COLUMN_GAP := 24.0
const SIDE_WIDTH := FRAME_W - MAIN_WIDTH - COLUMN_GAP
const SIDE_GAP := 20.0
const SIDE_MAX_HEIGHT := 86.0
const MAIN_FONT_SIZE := 40
const SIDE_FONT_SIZE := 22

var _busy := false
var _busy_dots_timer: Timer
var _busy_dot_count := 0
var _status_base_text := ""
var _waiting_timer: Timer
## 切断した対局へ戻る導線(GameDesign.md 11章)。戻れる対局があるときだけ出す。
var _resume_band: ResumeBand
var _ranked_tile: HomeTile
var _ranked_info: RankedEntryInfo
var _cpu_tile: HomeTile
var _room_tile: HomeTile
## CPU戦の下に並ぶ入口。1局終えるまで出さない(GameDesign.md 9章)。
var _later_tiles: Array[HomeTile] = []

@onready var status_label: Label = $Margin/VBox/StatusLabel


func _ready() -> void:
	_busy_dots_timer = Timer.new()
	_busy_dots_timer.wait_time = BUSY_DOTS_INTERVAL
	_busy_dots_timer.timeout.connect(_on_busy_dots_timeout)
	add_child(_busy_dots_timer)
	_waiting_timer = Timer.new()
	_waiting_timer.wait_time = WAITING_POLL_SECONDS
	_waiting_timer.timeout.connect(_refresh_waiting)
	add_child(_waiting_timer)
	_waiting_timer.start()
	_take_over_status_label()
	_build()
	refresh()


## `.tscn` の縦並び(`Margin/VBox`)は、札を絶対座標へ置く構成では使えない。
## **待機中の文言だけを引き取り、残りは捨てる。**`.tscn` そのものは書き換えない
## (`scenes/home_screen.tscn` が instance しているため。Architecture.md 4章)。
func _take_over_status_label() -> void:
	var margin: Node = $Margin
	status_label.get_parent().remove_child(status_label)
	add_child(status_label)
	margin.queue_free()
	status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT


func _build() -> void:
	_resume_band = ResumeBand.make(Rect2(FRAME_X, 0.0, FRAME_W, RESUME_HEIGHT))
	_resume_band.pressed.connect(_on_resume_pressed)
	add_child(_resume_band)

	_ranked_tile = HomeTile.make(
		"対戦する", "人と戦って段位を上げる", "burst", Vector2(MAIN_WIDTH, 0.0), MAIN_FONT_SIZE, true
	)
	_ranked_tile.pressed.connect(func() -> void: ranked_match_deck_requested.emit())
	add_child(_ranked_tile)
	_ranked_info = RankedEntryInfo.new()
	_ranked_tile.add_child(_ranked_info)

	# **副題で「自由な対局」と「決まった課題」を対比させる**(GameDesign.md 9章)。
	# **固定の数を書かない**——ステージを足したときに嘘になる。
	_cpu_tile = _make_side_tile("CPU戦", "好きなデッキで1局", "hour")
	_cpu_tile.pressed.connect(func() -> void: cpu_match_requested.emit())
	var solo_tile := _make_side_tile("ソロモード", "決まった条件の関門に挑む", "crown")
	solo_tile.pressed.connect(func() -> void: solo_requested.emit())
	var puzzle_tile := _make_side_tile("リーサルパズル", "1手番で仕留める", "sword")
	puzzle_tile.pressed.connect(func() -> void: puzzle_requested.emit())
	_room_tile = _make_side_tile("ルームマッチ", "合言葉で友達と", "shield")
	_room_tile.pressed.connect(func() -> void: room_match_requested.emit())
	_later_tiles = [solo_tile, puzzle_tile, _room_tile]
	move_child(status_label, get_child_count() - 1)
	_layout()


func _make_side_tile(title: String, subtitle: String, emblem: String) -> HomeTile:
	var tile := HomeTile.make(title, subtitle, emblem, Vector2(SIDE_WIDTH, 0.0), SIDE_FONT_SIZE)
	add_child(tile)
	return tile


## 復帰の帯があるときは、そのぶん札と列を縮める。
func _layout() -> void:
	var top := STATUS_TOP
	status_label.position = Vector2(FRAME_X, top)
	status_label.size = Vector2(FRAME_W, STATUS_ROW)
	top += STATUS_ROW
	if _resume_band.visible:
		_resume_band.position = Vector2(FRAME_X, top)
		top += RESUME_HEIGHT + RESUME_GAP
	var height: float = BOTTOM - BOTTOM_MARGIN - top
	_ranked_tile.position = Vector2(FRAME_X, top)
	_ranked_tile.size = Vector2(MAIN_WIDTH, height)
	_ranked_info.size = _ranked_tile.size
	var side_height: float = minf(SIDE_MAX_HEIGHT, (height - SIDE_GAP * 3.0) / 4.0)
	var side_x: float = FRAME_X + MAIN_WIDTH + COLUMN_GAP
	var side_tiles: Array[HomeTile] = [_cpu_tile]
	side_tiles.append_array(_later_tiles)
	for i in side_tiles.size():
		side_tiles[i].position = Vector2(side_x, top + float(i) * (side_height + SIDE_GAP))
		side_tiles[i].size = Vector2(SIDE_WIDTH, side_height)


## 1局でも終えていれば(誘導対局は戦績に数えない)すべての入口を出す(GameDesign.md 9章)。
func _all_entries_open() -> bool:
	return int(MatchStats.totals(_uid()).get("games", 0)) > 0


## 待っている人の数を読む。タブが見えていないとき・通信できないときは行を隠す。
func _refresh_waiting() -> void:
	if not is_visible_in_tree():
		return
	if NetSession.client == null or not await NetSession.sign_in():
		_ranked_info.set_waiting(-1)
		return
	var count: int = await RankedMatchmakingQueue.count_waiting(NetSession.client, _uid())
	_ranked_info.set_waiting(count)


func _uid() -> String:
	if NetSession.client != null and NetSession.client.auth != null:
		return NetSession.client.auth.uid
	return ""


func refresh() -> void:
	if _busy:
		return
	var all_open := _all_entries_open()
	for tile in _later_tiles:
		tile.visible = all_open
	_refresh_resume()
	_ranked_info.refresh()
	_refresh_waiting()
	# 未保存でもプリセットの「基本」が返るため、常に対戦できる(GameDesign.md 18章)。
	var ready_to_battle: bool = CardDeckSave.selected_deck().size() == MatchState.DECK_SIZE
	_set_battle_disabled(not ready_to_battle)
	_set_status("" if ready_to_battle else "デッキを%d枚にしてください" % MatchState.DECK_SIZE)


## デッキが要る入口(対戦する / CPU戦 / ルームマッチ)を押せなくする。
func _set_battle_disabled(disabled: bool) -> void:
	for tile in [_ranked_tile, _cpu_tile, _room_tile]:
		tile.disabled = disabled


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
	_set_battle_disabled(busy)
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
