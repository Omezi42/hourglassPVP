class_name CardMatchPuzzle
extends RefCounted
## リーサルパズルの進行(GameDesign.md 24章)。
##
## **専用の対局画面を作らない。**盤面・手札・演出・ログはすべて `CardMatchScreen` の
## ものをそのまま使い、ここは「固定の局面を作る」「解けたかどうかを見る」だけを持つ。
## 誘導対局(`CardMatchTutorial`)と同じで、対局のルールが2箇所に分かれないようにするため。
##
## `card_match_screen.gd` が1000行の上限に近いため、`CardMatchOnline` 等と同じく
## `_screen` 参照を持つ切り出しにしている(Architecture.md 4.0節)。

signal finished(cleared: bool)

var _screen: CardMatchScreen
var _stage: PuzzleStageData = null
var _panel: CardPuzzleResult
var _settled := false


func _init(screen: CardMatchScreen) -> void:
	_screen = screen
	_panel = CardPuzzleResult.new()
	_panel.retry_pressed.connect(func() -> void: start(_stage))
	_panel.quit_pressed.connect(func() -> void: finished.emit(_settled and _cleared()))
	screen.add_child(_panel)


## いま解いている最中か。終局の受け口が結果パネルを出し分けるのに使う。
func active() -> bool:
	return _stage != null


func stage() -> PuzzleStageData:
	return _stage


## 1問を始める。局面は `MatchState` を普通に作ってから、盤面・手札・マナを差し替える
## (ルール画面の教材の盤面と同じ作り方。Architecture.md 4.2節)。
func start(target: PuzzleStageData) -> void:
	if target == null:
		return
	# **局面を作ってから問題を覚える。**`_begin_state()` は画面の後始末を通り、
	# そこで `close()` が呼ばれる。先に覚えると、その場で消される。
	_begin_state()
	_stage = target
	_settled = false
	_panel.visible = false
	_apply(target)
	_screen.refresh()


## 相手のいない対局を1つ作る。中身は普通の `MatchState` で、局面だけを後から差し替える。
## 画面の private を読むのは、既存の切り出しクラスと同じ流儀(Architecture.md 4.0節)。
func _begin_state() -> void:
	_screen._reset_for_new_match()
	_screen._cpu = null
	_screen._interactive = true
	_screen._match_kind = CurrencyRules.MatchKind.NONE
	_screen.my_side = MatchState.Side.A
	_screen.bar_for(MatchState.Side.A).display_name = AccountService.display_name()
	_screen.bar_for(MatchState.Side.A).icon_id = AccountService.icon_id()
	_screen.bar_for(MatchState.Side.A).title_id = AccountService.title_id()
	_screen.foe_bar.display_name = "パズル"
	_screen.foe_bar.icon_id = UserProfileLibrary.CPU_ICON_ID
	_screen.foe_bar.title_id = UserProfileLibrary.CPU_TITLE_ID
	_screen._begin_state(CardPresetDecks.basic(), CardPresetDecks.basic(), 1, false)


## 1手ごとの判定。**マナも行動権も残っている間は何も言わない**——手が尽きたかどうかを
## こちらで決めると、プレイヤーが気づいていない手順まで「詰み」と断じることになる。
## 失敗は「ターン終了を押した」ときだけとする(GameDesign.md 24章)。
func after_action(action: Dictionary) -> void:
	if _stage == null or _settled:
		return
	if _cleared():
		return
	if String(action.get("type", "")) == "end_turn":
		_settle(false)


## 相手のHPが0になった。`MatchState.match_ended` から呼ばれる。
func on_match_ended() -> void:
	if _stage == null or _settled:
		return
	_settle(_cleared())


func close() -> void:
	_stage = null
	_settled = false
	_panel.visible = false


func _cleared() -> bool:
	var state: MatchState = _screen.state
	if state == null:
		return false
	return int(state.hp[MatchState.other_side(_screen.my_side)]) <= 0


func _settle(cleared: bool) -> void:
	_settled = true
	var reward := ""
	if cleared:
		reward = _grant()
	var state: MatchState = _screen.state
	if state != null:
		_panel.set_remaining(int(state.hp[MatchState.other_side(_screen.my_side)]))
	_panel.show_for(cleared, _stage, reward)


## 初回クリアだけ砂金を出す(GameDesign.md 24章)。**通信は待たない**——
## 結果の表示を通信で止めない扱いは、対局の砂金(`CardMatchOutcome`)と同じ。
func _grant() -> String:
	var uid := ""
	if NetSession.client != null and NetSession.client.auth != null:
		uid = NetSession.client.auth.uid
	if not PuzzleProgress.mark_cleared(uid, _stage.id):
		return "この問題は解決済み"
	if NetSession.client == null or uid.is_empty():
		# 通信できないときは手元へ控え、次に加算が通ったときにまとめて足す
		# (対局の砂金と同じ扱い。Architecture.md 10.2節)。
		AccountStore.add_pending_currency(PuzzleProgress.CLEAR_REWARD)
		return "+%d 砂金(次に接続できたときに反映)" % PuzzleProgress.CLEAR_REWARD
	AccountService.grant(NetSession.client, uid, PuzzleProgress.CLEAR_REWARD, false)
	return "+%d 砂金" % PuzzleProgress.CLEAR_REWARD


## 問題の局面を盤面へ写す。**駒は出したターン扱いを解いて置く**
## (そのままだと反転も攻撃もできず、どの問題も解けない)。
func _apply(target: PuzzleStageData) -> void:
	var state: MatchState = _screen.state
	var mine: int = _screen.my_side
	var foe: int = MatchState.other_side(mine)
	state.hp[mine] = target.own_hp
	state.hp[foe] = target.foe_hp
	state.max_mana[mine] = target.mana
	state.mana[mine] = target.mana
	state.coin_available[mine] = false
	state.hand[mine] = _hand(target.hand_ids)
	state.hand[foe] = []
	_place(state, mine, target.own_units)
	_place(state, foe, target.foe_units)
	state.hp_changed.emit(mine, state.hp[mine])
	state.hp_changed.emit(foe, state.hp[foe])
	state.mana_changed.emit(mine, state.mana[mine], state.max_mana[mine])
	state.hand_changed.emit(mine)
	state.board_changed.emit(mine)
	state.board_changed.emit(foe)


func _hand(ids: Array[String]) -> Array:
	var cards: Array = []
	for id in ids:
		var card := CardLibrary.find_by_id(id)
		if card != null:
			cards.append(card)
	return cards


func _place(state: MatchState, side: int, rows: Array[String]) -> void:
	var slots: Array = []
	slots.resize(MatchState.BOARD_SIZE)
	for i in rows.size():
		if i >= MatchState.BOARD_SIZE:
			break
		var parsed := PuzzleStageData.parse_unit(rows[i])
		if parsed.is_empty():
			continue
		var unit := CardInstance.new(parsed["card"])
		unit.health = int(parsed["health"])
		unit.attack = int(parsed["attack"])
		unit.summoned_this_turn = false
		slots[i] = unit
	state.board[side] = slots
