class_name CardMatchOnline
extends RefCounted
## オンライン対戦の3つの入口(開始・切断からの復帰・観戦)。
## `CardMatchOutcome` 等と同じく `_screen` 参照を持つ切り出しで、
## `card_match_screen.gd` が1000行の上限に達したため分けている。
## 画面の private メンバを読むのは、既存の切り出しクラスと同じ流儀(Architecture.md 4.0節)。

var _screen: CardMatchScreen


func _init(screen: CardMatchScreen) -> void:
	_screen = screen


## オンライン対戦を開始する。配置フェーズは無く、デッキと山札の種を交換したら
## そのまま対局へ入る(GameDesign.md 2章・11章)。
func start(
	deck_self: Array,
	client: FirestoreClient,
	p_match_id: String,
	p_my_side: int,
	is_room: bool = false,
	opponent_uid: String = ""
) -> void:
	_screen._reset_for_new_match()
	_screen._cpu = null
	_screen._interactive = true
	_screen._match_kind = (
		CurrencyRules.MatchKind.ROOM if is_room else CurrencyRules.MatchKind.RANDOM
	)
	_screen.my_side = p_my_side
	_screen._own_deck = deck_self
	_apply_player_names(client, opponent_uid)
	_screen._status.set_waiting("対戦相手を待っています")
	var rng := RandomNumberGenerator.new()
	rng.randomize()
	var seed_value := rng.randi_range(1, 1 << 30)
	_screen._client = client
	_screen._match_id = p_match_id
	_screen._setup = OnlineSetup.new(client, p_match_id, p_my_side)
	_screen.add_child(_screen._setup)
	await _screen._setup.push_setup(CardLibrary.ids_from_deck(deck_self), seed_value)
	var result: Dictionary = await _screen._setup.wait_for_opponent_setup(seed_value)
	var opponent_ids: Array = result["deck"]
	if opponent_ids.is_empty():
		_screen._status.set_waiting(_screen._setup.abort_message())
		return
	_screen._status.set_waiting("")
	var opponent_deck := CardLibrary.deck_from_ids(opponent_ids)
	_screen._begin_state(
		deck_self if p_my_side == MatchState.Side.A else opponent_deck,
		opponent_deck if p_my_side == MatchState.Side.A else deck_self,
		int(result["seed"]),
		true
	)
	_screen._online = OnlineMatch.new(client)
	_screen.add_child(_screen._online)
	_screen._online.action_received.connect(_screen._on_action_received)
	_screen._online.start(p_match_id)
	# 切断しても同じ対局へ戻れるようにする(GameDesign.md 11章)。
	OnlineResume.remember(p_match_id, p_my_side, is_room, opponent_uid)
	# マリガンは手と同じ `actions` として送り合う(GameDesign.md 2章)。両者の確定が
	# 揃うまで対局は始まらないため、持ち時間はここを抜けてから動かし始める。
	if _screen.state.mulligan_pending:
		_screen._mulligan.show_hand(_screen.state.hand[_screen.my_side])
		await _screen.state.mulligan_finished
	# 持ち時間はオンライン対戦だけが使う(GameDesign.md 13章)。
	_screen._clock = MatchClock.new()
	_screen._clock.time_out.connect(_screen._on_local_timeout)
	_screen._clock.start_turn(_screen.state.current_turn)
	_screen.set_process(true)


## 対戦相手の表示名を出す(GameDesign.md 14章)。取得できなければ既定の「相手」のまま。
func _apply_player_names(client: FirestoreClient, opponent_uid: String) -> void:
	_screen._own_bar.display_name = AccountService.display_name()
	if opponent_uid.is_empty():
		return
	var name: String = await AccountService.fetch_display_name(client, opponent_uid)
	if not name.is_empty():
		_screen._foe_bar.display_name = name
	_screen.refresh()


## 切断した対局へ戻る(GameDesign.md 11章)。局面は保存しておらず、
## `matches/{id}` に残る「デッキ・山札の種・指した手の並び」から作り直す
## (リプレイ・観戦と同じ経路)。終わっている対局へは戻さない。
func resume(client: FirestoreClient, record: Dictionary) -> bool:
	var match_id: String = record.get("match_id", "")
	var p_my_side: int = int(record.get("side", MatchState.Side.A))
	_screen._reset_for_new_match()
	_screen._cpu = null
	_screen._interactive = true
	_screen._match_kind = (
		CurrencyRules.MatchKind.ROOM
		if bool(record.get("is_room", false))
		else CurrencyRules.MatchKind.RANDOM
	)
	_screen.my_side = p_my_side
	_apply_player_names(client, record.get("opponent_uid", ""))
	var doc: Dictionary = await client.get_document("matches/%s" % match_id)
	var deck_a := CardLibrary.deck_from_ids(doc.get("deck_a", []))
	var deck_b := CardLibrary.deck_from_ids(doc.get("deck_b", []))
	if deck_a.size() != MatchState.DECK_SIZE or deck_b.size() != MatchState.DECK_SIZE:
		OnlineResume.clear()
		_screen._status.set_waiting("前回の対局は見つかりませんでした")
		return false
	_screen._own_deck = deck_a if p_my_side == MatchState.Side.A else deck_b
	var actions: Array = doc.get("actions", [])
	_screen._begin_state(
		deck_a, deck_b, int(doc.get("seed", 0)), MatchAction.contains_mulligan(actions)
	)
	for action in actions:
		MatchAction.apply(_screen.state, action)
	if _screen.state.is_match_over() or doc.has("finished_at"):
		OnlineResume.clear()
		_screen._status.set_waiting("前回の対局は既に終わっています")
		return false
	_screen.refresh()
	_screen._client = client
	_screen._match_id = match_id
	_screen._online = OnlineMatch.new(client)
	_screen.add_child(_screen._online)
	_screen._online.action_received.connect(_screen._on_action_received)
	_screen._online.start(match_id, actions.size())
	# 持ち時間はこちら側では初期値から数え直すが、**相手はこちらの残り時間を
	# 自分の手元で減らし続けている**(GameDesign.md 11章)。したがって再読み込みで
	# 時計を戻す抜け道にはならず、時間切れの判定は相手側が持つ。
	_screen._clock = MatchClock.new()
	_screen._clock.time_out.connect(_screen._on_local_timeout)
	_screen._clock.start_turn(_screen.state.current_turn)
	_screen.set_process(true)
	return true


## 観戦モードとして開始する(GameDesign.md 12章)。進行中の対局を第三者が見る。
## 手を送らず、受け取って反映するだけ。観戦者のuidは対局者のどちらとも違うため、
## OnlineMatch のポーリングは両者の手をそのまま配ってくる。
func spectate(client: FirestoreClient, p_match_id: String) -> bool:
	_screen._reset_for_new_match()
	_screen._cpu = null
	_screen._interactive = false
	_screen.my_side = MatchState.Side.A
	var record: Dictionary = await client.get_document("matches/%s" % p_match_id)
	var deck_a := CardLibrary.deck_from_ids(record.get("deck_a", []))
	var deck_b := CardLibrary.deck_from_ids(record.get("deck_b", []))
	if deck_a.size() != MatchState.DECK_SIZE or deck_b.size() != MatchState.DECK_SIZE:
		_screen._status.set_waiting("この対局はまだ始まっていません")
		return false
	var actions: Array = record.get("actions", [])
	_screen._begin_state(
		deck_a, deck_b, int(record.get("seed", 0)), MatchAction.contains_mulligan(actions)
	)
	# 既に進んでいる手をまとめて追いつかせてから、以降をポーリングで受け取る。
	for action in actions:
		MatchAction.apply(_screen.state, action)
	_screen.refresh()
	_screen._online = OnlineMatch.new(client)
	_screen.add_child(_screen._online)
	_screen._online.action_received.connect(_screen._on_action_received)
	_screen._online.start(p_match_id, actions.size())
	return true
