class_name CardMatchOnline
extends RefCounted
## オンライン対戦の2つの入口(開始・切断からの復帰)。
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
	opponent_uid: String = "",
	time_limit: bool = true,
	is_ranked: bool = false
) -> void:
	_screen._reset_for_new_match()
	_screen._cpu = null
	_screen._interactive = true
	_screen._match_kind = (
		CurrencyRules.MatchKind.RANKED
		if is_ranked
		else (CurrencyRules.MatchKind.ROOM if is_room else CurrencyRules.MatchKind.RANDOM)
	)
	_screen.my_side = p_my_side
	_screen._own_deck = deck_self
	_apply_player_names(client, opponent_uid)
	# 山札・種の交換を待つ間は `state` がまだ無く、盤面も行動ボタンも実体を
	# 持たない(`_reset_for_new_match()` で隠してある)。**「戻る」だけは
	# ここで出す**——通信が詰まって`wait_for_opponent_setup()`が長引いても、
	# 対局が始まる前ならいつでも中断してホームへ戻れる(GameDesign.md 11章)。
	_screen._back_button.visible = true
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
	_screen._online.is_own_turn = _is_own_turn
	_screen._online.start(p_match_id)
	# 切断しても同じ対局へ戻れるようにする(GameDesign.md 11章)。
	OnlineResume.remember(p_match_id, p_my_side, is_room, opponent_uid, time_limit, is_ranked)
	# マリガンは手と同じ `actions` として送り合う(GameDesign.md 2章)。両者の確定が
	# 揃うまで対局は始まらないため、持ち時間はここを抜けてから動かし始める。
	if _screen.state.mulligan_pending:
		var state: MatchState = _screen.state
		_screen._mulligan.show_hand(
			state.hand[_screen.my_side],
			state.first_side == _screen.my_side,
			state.coin_available.get(_screen.my_side, false)
		)
		await _screen.state.mulligan_finished
	# 持ち時間はオンライン対戦だけが使う(GameDesign.md 13章)。ルームマッチでは切れるため
	# (5章)、切ってあるときは時計そのものを作らない。**時計を持たない状態は既にCPU戦が
	# 通っている経路**で、送信の `clock` 付与・相手の時間切れ監視のいずれも null を見て降りる。
	if time_limit:
		_start_clock()
	_screen.set_process(true)


## 対戦相手のプロフィール(名前・アイコン・称号)を出す(GameDesign.md 14章)。
func _apply_player_names(client: FirestoreClient, opponent_uid: String) -> void:
	_screen._own_bar.display_name = AccountService.display_name()
	_screen._own_bar.icon_id = AccountService.icon_id()
	_screen._own_bar.title_id = AccountService.title_id()
	# 相手が分からなくても、自分のマットだけは先に敷く。
	_screen._set_playmats(AccountService.playmat_id(), PlaymatLibrary.DEFAULT_ID)
	if opponent_uid.is_empty():
		return
	var profile: Dictionary = await AccountService.fetch_profile(client, opponent_uid)
	var name: String = str(profile.get("display_name", ""))
	if not name.is_empty():
		_screen._foe_bar.display_name = name
	_screen._foe_bar.icon_id = str(profile.get("icon_id", UserProfileLibrary.DEFAULT_ICON_ID))
	_screen._foe_bar.title_id = str(profile.get("title_id", UserProfileLibrary.DEFAULT_TITLE_ID))
	# **相手のマットは相手の設定を使う**(GameDesign.md 9章)。名前・アイコン・称号と同じ経路。
	_screen._set_playmats(
		AccountService.playmat_id(), str(profile.get("playmat_id", PlaymatLibrary.DEFAULT_ID))
	)
	# 相手のスキンも同じ経路で受け取る(GameDesign.md 31章)。見た目の品は相手に見えて値打ちになる。
	CardSkins.set_opponent(
		profile.get("owned_skins", []),
		profile.get("disabled_skins", []),
		profile.get("enabled_skins", [])
	)
	_screen.refresh()


## 切断した対局へ戻る(GameDesign.md 11章)。局面は保存しておらず、
## `matches/{id}` に残る「デッキ・山札の種・指した手の並び」から作り直す
## (リプレイと同じ経路)。終わっている対局へは戻さない。
func resume(client: FirestoreClient, record: Dictionary) -> bool:
	var match_id: String = record.get("match_id", "")
	var p_my_side: int = int(record.get("side", MatchState.Side.A))
	_screen._reset_for_new_match()
	_screen._cpu = null
	_screen._interactive = true
	_screen._match_kind = OnlineResume.match_kind(record)
	_screen.my_side = p_my_side
	_screen._back_button.visible = true
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
	_screen._online.is_own_turn = _is_own_turn
	_screen._online.start(match_id, actions.size())
	# 持ち時間はこちら側では初期値から数え直すが、**相手はこちらの残り時間を
	# 自分の手元で減らし続けている**(GameDesign.md 11章)。したがって再読み込みで
	# 時計を戻す抜け道にはならず、時間切れの判定は相手側が持つ。
	# 持ち時間を切ったルームマッチ(5章)へは、時計を持たないまま戻る。
	# 古い記録は値を持たないため、これまでどおり持ち時間ありとして扱う。
	if bool(record.get("time_limit", true)):
		_start_clock()
	_screen.set_process(true)
	return true


## 持ち時間の時計を作って動かし始める。開始と復帰で同じ手順を踏むため1箇所へ寄せる。
func _start_clock() -> void:
	_screen.clocks.start()


## マリガン中は相手の確定を待つため、自分の手番として扱わない。
func _is_own_turn() -> bool:
	var state: MatchState = _screen.state
	return state != null and not state.mulligan_pending and state.current_turn == _screen.my_side
