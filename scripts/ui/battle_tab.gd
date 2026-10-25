class_name BattleTab
extends Control
## ホームの左「ソロモード」と中央「バトル」の列(GameDesign.md 9章)。右の列は `DeckTab`。
##
## **対局の入口はホームに並べず、押してから選ばせる。**「バトル」を押すと対局の種類を選ぶ
## モーダル(ランクマッチ / ルームマッチ / CPU戦)、「ソロモード」を押すと遠征 / リーサルパズルの
## モーダルを出す(`HomeModePicker`)。モーダルはヘッダーより手前に出すため、
## `HomeScreen` が `mount_pickers()` で自分の子として預かる。
##
## **クラス名は `BattleTab` のまま変えない。**`scenes/battle_tab.tscn` を
## `scenes/home_screen.tscn` が instance しており、名前を変えると参照の書き換えという
## 実害のある作業を招く(`DeckTab` も同じ)。
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
## ランク画面(ランキング)。対局の種類を選ぶモーダルの「ランキングを見る」から開く(28章)。
signal rank_requested

## 通信待ち中の「...」演出。3個目まで打ってから空に戻る(対局画面の待機表現と統一)。
const BUSY_DOTS_MAX := 3
const BUSY_DOTS_INTERVAL := 0.5
## 待っている人の数を読み直す間隔(ホームが見えている間だけ)。
const WAITING_POLL_SECONDS := 15.0
const STATUS_FONT := 22
const PORTRAIT_STATUS_FONT := 24

const BATTLE_TITLE := "バトル"
const RESUME_TITLE := "対局へ戻る"
const RANKED_TITLE := "ランクマッチ"
const EXPEDITION_TITLE := "遠征"
const PUZZLE_TITLE := "リーサルパズル"
const PUZZLE_SUBTITLE := "1手番で仕留める"
const DAILY_OPEN := "今日の1問 まだ解いていません"
const DAILY_DONE := "今日の1問 クリア済み"
const EXPEDITION_NEW := "作戦を選んで出発"
const EXPEDITION_CONTINUE := "続きから進める"
const MAIN_FONT_SIZE := 40
const PICKER_FONT_SIZE := 30
## 縦画面では「バトル」も横長の札になり、見出しは札(`HomeTile`)が描く。
const PORTRAIT_MAIN_FONT := 44
const PORTRAIT_MARK_SCALE := 1.5
const DISABLED_ALPHA := 0.55
const RANKING_BUTTON_SIZE := Vector2(340, 56)

var _busy := false
var _busy_dots_timer: Timer
var _busy_dot_count := 0
var _status_base_text := ""
var _waiting_timer: Timer
## 切断した対局へ戻れるか(GameDesign.md 11章)。立っている間は「バトル」を押すと選択を挟まず復帰する。
var _resume_pending := false
var _battle_tile: HomeTile
var _battle_info: RankedEntryInfo
var _solo_tile: HomeTile
var _solo_info: SoloEntryInfo
var _battle_picker: HomeModePicker
var _ranked_tile: HomeTile
var _ranked_info: RankedEntryInfo
var _room_tile: HomeTile
var _cpu_tile: HomeTile
var _solo_picker: HomeModePicker
var _expedition_tile: HomeTile
var _puzzle_tile: HomeTile
## 次にやってほしい入口に掛ける印(GameDesign.md 18章)。ホームの札と、開いたモーダルの札に1つずつ。
var _next_mark := NextStepMark.new()
var _picker_mark := NextStepMark.new()
var _portrait := false

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
## **待機中の文言だけを引き取り、残りは捨てる。**`.tscn` そのものは書き換えない。
func _take_over_status_label() -> void:
	var margin: Node = $Margin
	status_label.get_parent().remove_child(status_label)
	add_child(status_label)
	margin.queue_free()
	status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER


func _build() -> void:
	_battle_tile = HomeTile.make("", "", "", Vector2.ZERO, MAIN_FONT_SIZE, true)
	# 段位の徽章が札を占めるため、紋章の透かしは敷かない。
	_battle_tile.emblem = null
	_battle_tile.pressed.connect(_on_battle_pressed)
	add_child(_battle_tile)
	_battle_info = RankedEntryInfo.new()
	_battle_tile.add_child(_battle_info)

	_solo_tile = HomeTile.make("", "", "", Vector2.ZERO, MAIN_FONT_SIZE)
	_solo_tile.emblem = null
	_solo_tile.pressed.connect(_open_picker.bind(false))
	add_child(_solo_tile)
	_solo_info = SoloEntryInfo.new()
	_solo_tile.add_child(_solo_info)
	_build_battle_picker()
	_build_solo_picker()
	for info: Control in [_battle_info, _solo_info, _ranked_info]:
		# 札の大きさはモーダル側・向きの切り替えで変わる。中身は札いっぱいに追わせる。
		info.anchor_right = 1.0
		info.anchor_bottom = 1.0
	move_child(status_label, get_child_count() - 1)
	_layout()


## 「バトル」を押したあとに選ぶ3つ(9章)。ランクマッチは段位を、残りは副題を持つ。
func _build_battle_picker() -> void:
	_battle_picker = HomeModePicker.make("対局の種類を選ぶ")
	_battle_picker.closed.connect(_on_picker_closed)
	_ranked_tile = HomeTile.make("", "", "", Vector2.ZERO, PICKER_FONT_SIZE, true)
	_ranked_tile.emblem = null
	_ranked_tile.pressed.connect(func() -> void: ranked_match_deck_requested.emit())
	_ranked_info = RankedEntryInfo.new()
	_ranked_info.head_text = RANKED_TITLE
	_ranked_info.head_on_top = true
	_ranked_info.show_well = false
	_ranked_tile.add_child(_ranked_info)
	_battle_picker.add_tile(_ranked_tile)
	# **固定の数を書かない**——ステージを足したときに嘘になる(GameDesign.md 9章)。
	_room_tile = HomeTile.make("ルームマッチ", "合言葉で友達と", "shield", Vector2.ZERO, PICKER_FONT_SIZE)
	_room_tile.pressed.connect(func() -> void: room_match_requested.emit())
	_battle_picker.add_tile(_room_tile)
	_cpu_tile = HomeTile.make("CPU戦", "好きなデッキで1局", "hour", Vector2.ZERO, PICKER_FONT_SIZE)
	_cpu_tile.pressed.connect(func() -> void: cpu_match_requested.emit())
	_battle_picker.add_tile(_cpu_tile)
	var ranking := CodedButton.make("ランキングを見る", RANKING_BUTTON_SIZE)
	ranking.pressed.connect(func() -> void: rank_requested.emit())
	_battle_picker.set_extra_button(ranking)


func _build_solo_picker() -> void:
	_solo_picker = HomeModePicker.make("ソロモード")
	_solo_picker.closed.connect(_on_picker_closed)
	_expedition_tile = HomeTile.make(
		EXPEDITION_TITLE, EXPEDITION_NEW, "", Vector2.ZERO, PICKER_FONT_SIZE, true
	)
	_expedition_tile.emblem = null
	_expedition_tile.pressed.connect(func() -> void: solo_requested.emit())
	_solo_picker.add_tile(_expedition_tile)
	_puzzle_tile = HomeTile.make(
		PUZZLE_TITLE, PUZZLE_SUBTITLE, "sword", Vector2.ZERO, PICKER_FONT_SIZE
	)
	_puzzle_tile.pressed.connect(func() -> void: puzzle_requested.emit())
	_solo_picker.add_tile(_puzzle_tile)


## モーダルはヘッダーより手前に出す必要があるため、ホーム画面の子として預ける。
func mount_pickers(host: Control) -> void:
	for picker in [_battle_picker, _solo_picker]:
		if picker.get_parent() != null:
			picker.get_parent().remove_child(picker)
		host.add_child(picker)


## 縦横が変わったときに `HomeScreen` から呼ばれる(Architecture.md 4.7節)。
func apply_orientation(portrait: bool) -> void:
	_portrait = portrait
	if _battle_tile != null:
		_layout()


func _layout() -> void:
	_next_mark.tag_scale = PORTRAIT_MARK_SCALE if _portrait else 1.0
	_picker_mark.tag_scale = _next_mark.tag_scale
	var battle_rect := HomeLayout.portrait_battle_rect() if _portrait else HomeLayout.column_rect(1)
	var solo_rect := HomeLayout.portrait_solo_rect() if _portrait else HomeLayout.column_rect(0)
	var status_rect := HomeLayout.portrait_status_rect() if _portrait else HomeLayout.status_rect()
	_place(_battle_tile, battle_rect)
	_place(_solo_tile, solo_rect)
	# 縦では「バトル」も横長になり、徽章を右・文字を左に置く組み方へ戻す。見出しは札が描く。
	_battle_info.tall = not _portrait
	_ranked_info.tall = not _portrait
	_refresh_battle_title()
	status_label.add_theme_font_size_override(
		"font_size", PORTRAIT_STATUS_FONT if _portrait else STATUS_FONT
	)
	status_label.position = status_rect.position
	status_label.size = status_rect.size
	_battle_picker.apply_orientation(_portrait)
	_solo_picker.apply_orientation(_portrait)


func _place(tile: HomeTile, rect: Rect2) -> void:
	tile.custom_minimum_size = rect.size
	tile.position = rect.position
	tile.size = rect.size


## 縦長の札は中身(`RankedEntryInfo`)が見出しを彫り、横長の札は `HomeTile` が見出しを描く。
func _refresh_battle_title() -> void:
	var head := RESUME_TITLE if _resume_pending else BATTLE_TITLE
	_battle_info.head_text = head
	_battle_tile.title = head if _portrait else ""
	_battle_tile.title_size = PORTRAIT_MAIN_FONT if _portrait else MAIN_FONT_SIZE
	_battle_tile.queue_redraw()
	_battle_info.queue_redraw()
	_ranked_tile.title = RANKED_TITLE if _portrait else ""
	_ranked_tile.queue_redraw()


## 待っている人の数を読む。ホームが見えていないとき・通信できないときは行を隠す。
func _refresh_waiting() -> void:
	if not is_visible_in_tree():
		return
	if NetSession.client == null or not await NetSession.sign_in():
		_battle_info.set_waiting(-1)
		return
	var count: int = await RankedMatchmakingQueue.count_waiting(NetSession.client, _uid())
	_battle_info.set_waiting(count)


func _uid() -> String:
	if NetSession.client != null and NetSession.client.auth != null:
		return NetSession.client.auth.uid
	return ""


func refresh() -> void:
	if _busy:
		return
	var uid := _uid()
	_solo_info.refresh(uid)
	_refresh_solo_picker(uid)
	_refresh_resume()
	_battle_info.refresh()
	_ranked_info.refresh()
	_refresh_waiting()
	# 未保存でもプリセットの「基本」が返るため、常に対戦できる(GameDesign.md 18章)。
	var ready_to_battle: bool = CardDeckSave.selected_deck().size() == MatchState.DECK_SIZE
	_set_battle_disabled(not ready_to_battle)
	_set_status("" if ready_to_battle else "デッキを%d枚にしてください" % MatchState.DECK_SIZE)
	_refresh_next_marks(ready_to_battle and not _resume_pending)


## 今日の1問があるあいだは、リーサルパズルの副題をその状態にする(GameDesign.md 24章)。
func _refresh_solo_picker(uid: String) -> void:
	_expedition_tile.set_subtitle(
		EXPEDITION_NEW if SoloProgress.load_run(uid) == null else EXPEDITION_CONTINUE
	)
	var daily := DailyPuzzle.today()
	if daily == null:
		_puzzle_tile.set_subtitle(PUZZLE_SUBTITLE)
		_puzzle_tile.subtitle_accent = false
		return
	var cleared := PuzzleProgress.is_cleared(uid, daily.id)
	_puzzle_tile.set_subtitle(DAILY_DONE if cleared else DAILY_OPEN)
	_puzzle_tile.subtitle_accent = not cleared


## 1局も終えていなければCPU戦、遠征を始めていなければ遠征、今日の1問を解いていなければ
## リーサルパズル(GameDesign.md 18章)。ホームではその入口を含む札に、モーダルではその入口の札に掛ける。
func _refresh_next_marks(enabled: bool) -> void:
	var target := _next_step_tile() if enabled else null
	var home_tile: HomeTile = null
	if target == _cpu_tile:
		home_tile = _battle_tile
	elif target != null:
		home_tile = _solo_tile
	_next_mark.attach_to(home_tile)
	_picker_mark.attach_to(target)


func _next_step_tile() -> HomeTile:
	var uid := _uid()
	if int(MatchStats.totals(uid).get("games", 0)) == 0:
		return _cpu_tile
	if not SoloProgress.has_started(uid):
		return _expedition_tile
	var daily := DailyPuzzle.today()
	if daily != null and not PuzzleProgress.is_cleared(uid, daily.id):
		return _puzzle_tile
	return null


## デッキが要る入口(バトルと、モーダルのランクマッチ / ルームマッチ / CPU戦)を押せなくする。
func _set_battle_disabled(disabled: bool) -> void:
	for tile in [_battle_tile, _ranked_tile, _room_tile, _cpu_tile]:
		tile.disabled = disabled
	_battle_info.modulate.a = DISABLED_ALPHA if disabled else 1.0
	_ranked_info.modulate.a = _battle_info.modulate.a


## 覚えている対局があるときだけ出す。終わっているかどうかは押した時点で確かめる
## (毎回ホームで通信すると、オフラインでも遊べるという前提を崩すため)。
func _refresh_resume() -> void:
	_resume_pending = not OnlineResume.pending().is_empty()
	_refresh_battle_title()
	_battle_info.set_resume(_resume_pending)


func _on_battle_pressed() -> void:
	if _resume_pending:
		_on_resume_pressed()
	else:
		_open_picker(true)


func _open_picker(battle: bool) -> void:
	var picker := _battle_picker if battle else _solo_picker
	picker.open()


## 選んだ先へ移るときも、とじるで戻るときも、ホームの札の状態を読み直す。
func _on_picker_closed() -> void:
	refresh()


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
