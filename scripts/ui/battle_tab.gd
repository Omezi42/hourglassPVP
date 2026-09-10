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

## ここで成立するのはランダムマッチだけ(ルームマッチは専用画面が持つ。
## GameDesign.md 11章)。対局種別は受け取った側が「ランダム」として扱う。
signal online_match_found(match_id: String, my_side: int, opponent_uid: String)
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
## 待機中の文言と、募集を知らせたことを示す丸い印との間隔。
const ANNOUNCE_BADGE_GAP := 8.0
## 印にカーソルを乗せたときだけ出す説明(GameDesign.md 11章)。
const ANNOUNCE_NOTE := "公式Discordサーバーへ「対戦相手をさがしている人がいる」と通知を送りました"

## アカウント帯を避ける上端と、下部タブに接する下端。他のタブと同じ値。
const TOP_BAND := 112.0
const BOTTOM := 560.0
const FRAME_X := 140.0
const FRAME_W := 1000.0
## 復帰の帯(GameDesign.md 9章)。**急ぐ用件なので最上段へ置く。**
const RESUME_RECT := Rect2(FRAME_X, TOP_BAND + 4.0, FRAME_W, 46.0)
const RESUME_GAP := 16.0

## 待機を中断するボタン(GameDesign.md 11章)。**「だれかと」の枠の見出しの行、
## その右端へ置く。**以前は画面の右上へ絶対座標で置いており、アカウント帯の
## 名札・砂金・メニューへ重なって文字が隠れていた。枠の名前を載せた真鍮のプレートと
## 同じように枠の上端へ跨がらせることで、左=何の枠か / 右=いま止められる操作、
## という1本の行として読める。
const CANCEL_SIZE := Vector2(152, 38)
## プレートと同じ跨がり方(`HomeFrame.HEADING_OVERLAP`)・同じ左右の余白
## (`HomeFrame.HEADING_LEFT`)にそろえる。**const から他クラスの const を参照しない**
## ため(Architecture.md 11章)、値は `_layout()` の中で実行時に読む。
const CANCEL_FONT_SIZE := 20
## 待機中の文言と、その右のボタンとのあいだに空ける幅。
const CANCEL_GAP := 16.0

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

var _queue: MatchmakingQueue
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
## 募集をDiscordへ知らせられたときに、待機中の文言の横へ出す丸い印
## (GameDesign.md 11章)。
var _announce_badge: StatusBadge
var _solo_tiles: Array[HomeTile] = []

@onready var status_label: Label = $Margin/VBox/StatusLabel
@onready var cancel_button: Button = $CancelButton


func _ready() -> void:
	_busy_dots_timer = Timer.new()
	_busy_dots_timer.wait_time = BUSY_DOTS_INTERVAL
	_busy_dots_timer.timeout.connect(_on_busy_dots_timeout)
	add_child(_busy_dots_timer)
	_take_over_status_label()
	_build()
	cancel_button.pressed.connect(_on_cancel_pressed)
	_take_over_cancel_button()
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
	_announce_badge = StatusBadge.new()
	status_label.add_child(_announce_badge)


## `.tscn` のキャンセルボタンは画面の右上へアンカーで貼り付けてあり、そのままでは
## `_layout()` が位置を決められない。**アンカーを左上へ戻して絶対座標の部品にする**
## (`.tscn` そのものは書き換えない。Architecture.md 4章)。
func _take_over_cancel_button() -> void:
	cancel_button.set_anchors_preset(Control.PRESET_TOP_LEFT)
	cancel_button.custom_minimum_size = CANCEL_SIZE
	cancel_button.size = CANCEL_SIZE
	cancel_button.add_theme_font_size_override("font_size", CANCEL_FONT_SIZE)


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
	move_child(cancel_button, get_child_count() - 1)
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


## 見出しの行(枠の上端に跨がる帯)へ、左から「枠の名前のプレート / 待機中の文言 /
## キャンセル」を並べる。**文言とキャンセルは必ず同じ行に置く**——何が起きているかと、
## それを止める手段が離れていると、止め方を探しに行くことになる。
func _layout_status_row(top: float) -> void:
	var plate_top: float = top - HomeFrame.HEADING_HEIGHT * HomeFrame.HEADING_OVERLAP
	var plate_center: float = plate_top + HomeFrame.HEADING_HEIGHT * 0.5
	cancel_button.position = Vector2(
		FRAME_X + FRAME_W - HomeFrame.HEADING_LEFT - CANCEL_SIZE.x,
		plate_center - CANCEL_SIZE.y * 0.5
	)
	cancel_button.size = CANCEL_SIZE
	var status_left: float = FRAME_X + 240.0
	var status_right: float = cancel_button.position.x - CANCEL_GAP
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


## cancellable: マッチングキュー参加中など、待機を中断できる操作の間だけtrueにする。
## 通信の完了を待つだけの短い処理では出さない。
func _set_busy(busy: bool, cancellable: bool = false) -> void:
	_busy = busy
	_random_tile.disabled = busy
	_room_tile.disabled = busy
	_cpu_tile.disabled = busy
	cancel_button.visible = busy and cancellable
	if busy:
		_busy_dot_count = 0
		_busy_dots_timer.start()
	else:
		_queue = null
		_stop_busy_dots()
		refresh()


## 対局から戻ってきたときに、マッチング成立時の状態(ボタンの無効化・成立の文言・
## キューのノード)を解く。**`_on_matched()` は待機を止めるだけで `_set_busy(false)` を
## 通らない**ため、これが無いとホームへ戻った後も「対戦相手が見つかりました!」のまま
## ボタンが押せない状態が残る。
func reset_after_match() -> void:
	_discard_session()
	_set_busy(false)


## キューのノードを片付ける。`_set_busy(false)` は参照を外すだけで
## ノードを残していたため、対戦のたびに子が積み上がっていた。
func _discard_session() -> void:
	if is_instance_valid(_queue):
		_queue.queue_free()
	_queue = null


## 待機中テキストの土台(base)を更新し、末尾のドットと合わせて表示し直す。
## 文言を差し替えたら印は消す。印は「いま出ている文言に添えるもの」であり、
## 別の知らせへ変わった後も残っていると、何に付いた印なのか読めなくなる。
func _set_status(text: String) -> void:
	_status_base_text = text
	if _announce_badge != null:
		_announce_badge.clear_note()
	_refresh_status_display()


func _refresh_status_display() -> void:
	var text := _status_base_text
	if _busy:
		text += ".".repeat(_busy_dot_count)
	status_label.text = text
	_place_announce_badge()


## 印は文言のすぐ右へ置く。**位置は巡回ドットを含まない幅から決める**
## (ドットに合わせて動かすと0.5秒ごとに印が跳ねる)。
func _place_announce_badge() -> void:
	if _announce_badge == null:
		return
	var font := status_label.get_theme_font("font")
	var font_size := status_label.get_theme_font_size("font_size")
	if font == null:
		return
	var text := _status_base_text + ".".repeat(BUSY_DOTS_MAX)
	var text_width := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x
	_announce_badge.position = Vector2(
		text_width + ANNOUNCE_BADGE_GAP, (status_label.size.y - StatusBadge.DIAMETER) * 0.5
	)


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


## デッキ選択画面での確定後にMainから呼ばれる。ランダムマッチのキューへ参加する。
func begin_random_match() -> void:
	if _busy:
		return
	_set_busy(true, true)
	_set_status("マッチング中")
	if not await _sign_in_or_fail():
		return
	_queue = MatchmakingQueue.new(NetSession.client, NetSession.auth)
	add_child(_queue)
	_queue.matched.connect(_on_matched)
	_queue.failed.connect(_fail)
	_queue.version_mismatch.connect(_on_version_mismatch)
	_queue.announce_result.connect(_on_announce_result)
	_queue.join()


## マッチングキューの待機を、対戦成立を待たずに取りやめる。
## **キャンセルは押した瞬間に効かせ、後片付け(通信)の完了は待たない。**
## 待っていると、応答が遅い・返らない場合に「押しても何も起きない」ように見えるため。
func _on_cancel_pressed() -> void:
	var queue := _queue
	_set_busy(false)
	status_label.text = "キャンセルしました"
	if queue != null:
		await queue.cancel()
		queue.queue_free()


## 募集をDiscordへ知らせられた(GameDesign.md 11章)。**文言としては出さない。**
## 待っている人にできることは無いため、丸い印だけを添え、知りたい人がカーソルを
## 乗せたときにその説明を出す。届かなかった場合は何も出さない。
func _on_announce_result(ok: bool) -> void:
	if ok and _announce_badge != null:
		_announce_badge.show_note(ANNOUNCE_NOTE)


## 待機者はいたが全員バージョンが違った(GameDesign.md 11章)。待機自体は続けるので、
## `_fail()` ではなく待機中の文言だけを差し替える(末尾に巡回ドットが付く)。
func _on_version_mismatch(newer_exists: bool) -> void:
	if newer_exists:
		_set_status("新しい版が公開されています。再読み込みしてください")
	else:
		_set_status("古い版の相手が待っています。マッチング中")


func _on_matched(match_id: String, opponent_uid: String) -> void:
	_busy = false
	cancel_button.visible = false
	_stop_busy_dots()
	var match_doc: Dictionary = await NetSession.client.get_document("matches/%s" % match_id)
	# 自分のuidがplayer_a/player_bのどちらとも一致しない場合、以前は黙って後手として
	# 扱っていた。双方が後手になると互いのデッキを待ち続けて対局が始まらないため、
	# ここで止めてやり直させる(マッチ成立の書き込みは原子的になったので通常は起きない)。
	var my_side: int
	if match_doc.get("player_a", "") == NetSession.auth.uid:
		my_side = MatchState.Side.A
	elif match_doc.get("player_b", "") == NetSession.auth.uid:
		my_side = MatchState.Side.B
	else:
		_fail("対戦相手との同期に失敗しました。もう一度お試しください")
		return
	status_label.text = "対戦相手が見つかりました!"
	online_match_found.emit(match_id, my_side, opponent_uid)
