extends RefCounted
## v5.0のオンライン対戦を、差し替え用クライアント(FakeFirestoreClient)の上で
## 実通信なしに検証する。
##
## **確かめたいのは1点だけ:2人のクライアントが同じ盤面を保ち続けること。**
## v5.0は山札の並びを「種」から再現する方式のため、初期状態が一致していることと、
## 送られた手が相手側でも同じ結果になることが崩れると、対局が静かに食い違う。
##
## ポーリングのタイマーを待つと実時間が伸びるため、_poll_loop() は止めたうえで
## _fetch()/_deliver_one() を直接呼ぶ(既存の online_match_flow_tests.gd と同じ流儀)。

const MATCH_ID := "m_v5"
const MATCH_PATH := "matches/m_v5"
const SEED := 987654
const FakeClient = preload("res://tools/tests/fake_firestore_client.gd")

var _assert: Callable
var _inbox_b: Array = []


func run(assert_true: Callable) -> void:
	_assert = assert_true
	var tree := Engine.get_main_loop() as SceneTree
	var auth := FirebaseAuth.new(null)
	auth.uid = "uid-a"
	var client = FakeClient.new(auth)
	tree.root.add_child(client)
	client.store[MATCH_PATH] = {"fields": {"actions": []}, "update_time": "0"}

	var decks := _decks()
	var state_a := MatchState.new()
	var state_b := MatchState.new()
	tree.root.add_child(state_a)
	tree.root.add_child(state_b)
	state_a.start_match(decks[0], decks[1], MatchState.Side.A, SEED)
	state_b.start_match(decks[0], decks[1], MatchState.Side.A, SEED)
	_assert_same("開始直後", state_a, state_b)

	# 側Aが送信する側、側Bが受信する側。Bのポーリングは自分のuidを持たないため
	# Aの手をすべて受け取る。
	var sender := OnlineMatch.new(client)
	tree.root.add_child(sender)
	sender.start(MATCH_ID)
	sender.stop()
	var receiver := OnlineMatch.new(client)
	tree.root.add_child(receiver)
	receiver.action_received.connect(func(action: Dictionary) -> void: _inbox_b.append(action))
	receiver.start(MATCH_ID)
	receiver.stop()
	receiver._my_uid = "uid-b"

	await _play_a_turn(tree, sender, receiver, state_a, state_b)

	sender.stop()
	receiver.stop()
	sender.queue_free()
	receiver.queue_free()
	client.queue_free()
	state_a.queue_free()
	state_b.queue_free()


func _decks() -> Array:
	var cards := CardLibrary.all_cards()
	var deck_a: Array = []
	var deck_b: Array = []
	for i in MatchState.DECK_SIZE:
		deck_a.append(cards[i % cards.size()])
		deck_b.append(cards[(i + 4) % cards.size()])
	return [deck_a, deck_b]


## 側Aが1手番ぶん指し、側Bが受け取って同じ盤面になることを確かめる。
## 手には持ち時間(clock)を添える。MatchAction が知らないキーを無視することの確認も兼ねる。
func _play_a_turn(
	tree: SceneTree,
	sender: OnlineMatch,
	receiver: OnlineMatch,
	state_a: MatchState,
	state_b: MatchState
) -> void:
	var cpu := CardCpuStrategy.new()
	for step in 12:
		if state_a.is_match_over():
			break
		var action := cpu.choose_action(state_a, MatchState.Side.A)
		action["clock"] = 180.0 - step
		MatchAction.apply(state_a, action)
		sender.send(action)
		while sender.is_busy():
			await tree.process_frame
		if action["type"] == "end_turn":
			break
	await receiver._fetch()
	# _deliver_one() は待ち行列から1件だけ配る。受け取り側の待ち行列が空になるまで回す。
	while not receiver._inbox.is_empty():
		receiver._deliver_one()
		await tree.process_frame
	for action in _inbox_b:
		MatchAction.apply(state_b, action)
	_assert.call(not _inbox_b.is_empty(), "the receiver should have been handed the sent actions")
	_assert_same("1手番の送受信のあと", state_a, state_b)


func _assert_same(label: String, a: MatchState, b: MatchState) -> void:
	_assert.call(
		(
			a.hp[MatchState.Side.A] == b.hp[MatchState.Side.A]
			and a.hp[MatchState.Side.B] == b.hp[MatchState.Side.B]
		),
		"%s: 両者のHPが一致すること" % label
	)
	_assert.call(a.current_turn == b.current_turn, "%s: 手番が一致すること" % label)
	for side in [MatchState.Side.A, MatchState.Side.B]:
		_assert.call(
			CardLibrary.ids_from_deck(a.hand[side]) == CardLibrary.ids_from_deck(b.hand[side]),
			"%s: 手札の中身と並びが一致すること(側%d)" % [label, side]
		)
		_assert.call(
			CardLibrary.ids_from_deck(a.deck[side]) == CardLibrary.ids_from_deck(b.deck[side]),
			"%s: 山札の並びが一致すること(側%d)" % [label, side]
		)
		for slot in MatchState.BOARD_SIZE:
			var left: CardInstance = a.board[side][slot]
			var right: CardInstance = b.board[side][slot]
			var same := (
				(left == null and right == null)
				or (
					left != null
					and right != null
					and left.data == right.data
					and left.health == right.health
					and left.attack == right.attack
				)
			)
			_assert.call(same, "%s: 盤面が一致すること(側%d 枠%d)" % [label, side, slot])
