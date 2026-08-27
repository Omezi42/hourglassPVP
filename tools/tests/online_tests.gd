extends RefCounted

## フェーズ26: オンライン対戦の作り込みで入れた変更のうち、実通信なしで検証できる部分。
## run_tests.gdが1000行の上限(gdlintのmax-file-lines)に達しているため別ファイルにしている。
## 判定はハーネス側の_assert_trueをCallableで受け取って共有する。
##
## 実通信を伴う経路(マッチ成立・手の送受信)は2クライアントを同時に動かさないと再現できない
## ため、ここではロジックとして切り出せる部分だけを押さえている。


func run(assert_true: Callable) -> void:
	_test_timeout_action_ends_match(assert_true)
	_test_apply_ignores_transport_keys(assert_true)
	_test_transient_status_classification(assert_true)
	_test_actions_survive_the_firestore_codec(assert_true)
	_test_clock_can_be_overwritten_by_the_opponent_value(assert_true)
	_test_online_setup_abort_messages(assert_true)


## 持ち時間切れは投了と同じactionsの1件として送受信される(GameDesign.md 11章)。
## 申告した側の相手の勝ちで、盤面・HPを変えずに即座に終局すること。
func _test_timeout_action_ends_match(assert_true: Callable) -> void:
	var state := _make_state()
	var winner_box: Array = [null]
	state.match_ended.connect(func(w: int) -> void: winner_box[0] = w)

	MatchAction.apply(state, {"type": "timeout", "side": MatchState.Side.B})

	assert_true.call(state.is_match_over(), "timeout action should end the match")
	assert_true.call(
		winner_box[0] == MatchState.Side.A,
		"the side that still had time (A) should be declared the winner"
	)
	assert_true.call(
		state.end_reason == MatchState.EndReason.TIMEOUT,
		"the end reason should be recorded as TIMEOUT, not SURRENDER"
	)
	assert_true.call(
		(
			state.hp[MatchState.Side.A] == MatchState.INITIAL_HP
			and state.hp[MatchState.Side.B] == MatchState.INITIAL_HP
		),
		"timeout should end the match without dealing any damage"
	)


## 送信時に付く通信用のキー(by/clock)は、盤面の解決に一切影響しないこと。
## これらは棋譜には無くてもよいキーのため、リプレイ再生との互換性の担保でもある。
func _test_apply_ignores_transport_keys(assert_true: Callable) -> void:
	var state := _make_state()
	var before: int = state.hand[MatchState.Side.A].size()
	var action := {
		"type": "end_turn",
		"side": MatchState.Side.A,
		"by": "some-firebase-uid",
		"clock": 123.5,
	}
	MatchAction.apply(state, action)

	assert_true.call(
		state.current_turn == MatchState.Side.B,
		"an action carrying transport keys should still be applied"
	)
	assert_true.call(
		not state.is_match_over(), "an action carrying transport keys should not end the match"
	)
	assert_true.call(before > 0, "the opening hand should have been dealt")


## リトライしてよい失敗(応答なし・429・5xx)と、呼び出し側の判断が要る失敗の切り分け。
func _test_transient_status_classification(assert_true: Callable) -> void:
	for code in [0, -1, 429, 500, 503]:
		assert_true.call(HttpJson.is_transient(code), "%d should be retried" % code)
	for code in [200, 400, 401, 403, 404, 409]:
		assert_true.call(not HttpJson.is_transient(code), "%d should not be retried" % code)


## actionsはFirestoreのvalue表現へ変換して書き込むため、往復しても順序・型・値が
## 変わらないことを確認する(clockのfloat・byのstringが壊れると同期がずれる)。
func _test_actions_survive_the_firestore_codec(assert_true: Callable) -> void:
	var actions := [
		{"type": "flip", "actor": 0, "side": 1, "position": 2, "by": "uid-a", "clock": 176.25},
		{"type": "pass", "side": 1, "by": "uid-b", "clock": 90.0},
		{"type": "timeout", "side": 0, "by": "uid-a"},
	]
	var encoded := FirestoreCodec.encode_fields({"actions": actions})
	var decoded: Dictionary = FirestoreCodec.decode_fields(encoded)
	var round_tripped: Array = decoded["actions"]

	assert_true.call(round_tripped.size() == actions.size(), "the action count should survive")
	for i in range(actions.size()):
		var original: Dictionary = actions[i]
		var result: Dictionary = round_tripped[i]
		assert_true.call(
			result["type"] == original["type"], "action %d should keep its type and order" % i
		)
		assert_true.call(
			int(result["side"]) == int(original["side"]), "action %d should keep its side" % i
		)
		assert_true.call(result.get("by", "") == original.get("by", ""), "action %d keeps by" % i)
		if original.has("clock"):
			assert_true.call(
				is_equal_approx(float(result["clock"]), float(original["clock"])),
				"action %d should keep its clock value" % i
			)


## 相手の残り時間は、届いた手に添えられた値で上書きする(GameDesign.md 11章)。
## 上書き後もその側の時計が正しく減り、時間切れを発火することを確認する。
func _test_clock_can_be_overwritten_by_the_opponent_value(assert_true: Callable) -> void:
	var clock := MatchClock.new(180.0)
	clock.remaining[MatchState.Side.B] = 1.0
	assert_true.call(
		is_equal_approx(clock.get_remaining(MatchState.Side.B), 1.0),
		"the opponent clock should take the value that came with their action"
	)
	assert_true.call(
		is_equal_approx(clock.get_remaining(MatchState.Side.A), 180.0),
		"overwriting one side should not touch the other"
	)

	var timed_out_box: Array = [null]
	clock.time_out.connect(func(side: int) -> void: timed_out_box[0] = side)
	clock.start_turn(MatchState.Side.B)
	clock.tick(1.5)
	assert_true.call(
		timed_out_box[0] == MatchState.Side.B,
		"the overwritten clock should still run out and report the timeout"
	)


func _test_online_setup_abort_messages(assert_true: Callable) -> void:
	var setup := OnlineSetup.new(null, "m_test", MatchState.Side.A)
	assert_true.call(setup.abort_message() == "", "no abort reason should produce no message")
	setup.abort_reason = "abandoned"
	assert_true.call(
		setup.abort_message().contains("取りやめ"),
		"an abandoned match should tell the waiting player that the opponent left"
	)
	setup.abort_reason = "timeout"
	assert_true.call(setup.abort_message() != "", "a timed out wait should explain itself")
	setup.free()


func _make_state() -> MatchState:
	var deck: Array = []
	for _i in range(MatchState.DECK_SIZE):
		deck.append(CardLibrary.find_by_id("sand"))
	var state := MatchState.new()
	state.start_match(deck, deck.duplicate(), MatchState.Side.A, 1234)
	return state
