extends RefCounted

## フェーズ26: オンライン対戦の作り込みで入れた変更のうち、実通信なしで検証できる部分。
## run_tests.gdが1000行の上限(gdlintのmax-file-lines)に達しているため別ファイルにしている。
## 判定はハーネス側の_assert_trueをCallableで受け取って共有する。
##
## 実通信を伴う経路(マッチ成立・手の送受信)は2クライアントを同時に動かさないと再現できない
## ため、ここではロジックとして切り出せる部分だけを押さえている。


func run(assert_true: Callable) -> void:
	_test_time_up_forfeits_the_turn_until_the_limit(assert_true)
	_test_time_up_ends_the_match_at_the_limit(assert_true)
	_test_turn_seconds_halve_after_each_forfeit(assert_true)
	_test_timeout_action_ends_match(assert_true)
	_test_apply_ignores_transport_keys(assert_true)
	_test_transient_status_classification(assert_true)
	_test_actions_survive_the_firestore_codec(assert_true)
	_test_clock_can_be_overwritten_by_the_opponent_value(assert_true)
	_test_timeout_reports_the_side_that_actually_ran_out(assert_true)
	_test_online_setup_abort_messages(assert_true)


## 持ち時間切れは、敗北ではなく**手番の強制終了**として送受信される(GameDesign.md 5章)。
## 連続の上限に達したときだけ敗北になり、1手でも指せば数え直すこと。
func _test_time_up_forfeits_the_turn_until_the_limit(assert_true: Callable) -> void:
	var state := _make_state()
	var first := state.current_turn
	var forfeits: Array = []
	state.turn_forfeited.connect(func(side: int, n: int) -> void: forfeits.append([side, n]))

	assert_true.call(
		MatchAction.apply(state, {"type": "time_up", "side": first}), "time_up applies"
	)
	assert_true.call(not state.is_match_over(), "one time-up should not end the match")
	assert_true.call(
		state.current_turn == MatchState.other_side(first), "time_up should pass the turn over"
	)
	assert_true.call(forfeits == [[first, 1]], "the forfeit should be reported with its count")

	# 相手が普通にターンを終え、こちらが2回目の時間切れ。
	MatchAction.apply(state, {"type": "end_turn", "side": MatchState.other_side(first)})
	MatchAction.apply(state, {"type": "time_up", "side": first})
	assert_true.call(
		int(state.turn_forfeits[first]) == 2, "consecutive time-ups should keep counting up"
	)
	assert_true.call(not state.is_match_over(), "the second time-up should still not end it")

	# 1手でも指せば数え直す。ここでは自分でターンを終える。
	MatchAction.apply(state, {"type": "end_turn", "side": MatchState.other_side(first)})
	MatchAction.apply(state, {"type": "end_turn", "side": first})
	assert_true.call(
		int(state.turn_forfeits[first]) == 0, "ending your own turn should reset the count"
	)


## 連続して上限に達したら敗北になること(GameDesign.md 5章)。
func _test_time_up_ends_the_match_at_the_limit(assert_true: Callable) -> void:
	var state := _make_state()
	var first := state.current_turn
	var foe := MatchState.other_side(first)
	for i in MatchState.TURN_FORFEIT_LIMIT:
		if state.is_match_over():
			break
		MatchAction.apply(state, {"type": "time_up", "side": first})
		if not state.is_match_over():
			MatchAction.apply(state, {"type": "end_turn", "side": foe})
	assert_true.call(
		state.is_match_over(),
		"forfeiting the turn %d times in a row should end the match" % MatchState.TURN_FORFEIT_LIMIT
	)
	assert_true.call(state.winner == foe, "the side that kept running out of time should lose")
	assert_true.call(
		state.end_reason == MatchState.EndReason.TIMEOUT, "the end reason should be TIMEOUT"
	)
	assert_true.call(
		(
			state.hp[MatchState.Side.A] == MatchState.INITIAL_HP
			and state.hp[MatchState.Side.B] == MatchState.INITIAL_HP
		),
		"running out of time should never deal damage"
	)


## 時間切れを重ねた側の次の手番は半分ずつ短くなる(GameDesign.md 5章)。
func _test_turn_seconds_halve_after_each_forfeit(assert_true: Callable) -> void:
	assert_true.call(
		is_equal_approx(MatchClock.seconds_after_forfeits(0), 60.0), "the first turn gets 60s"
	)
	assert_true.call(
		is_equal_approx(MatchClock.seconds_after_forfeits(1), 30.0), "one forfeit halves it"
	)
	assert_true.call(
		is_equal_approx(MatchClock.seconds_after_forfeits(2), 15.0), "two forfeits halve it again"
	)
	assert_true.call(
		MatchClock.seconds_after_forfeits(9) >= MatchClock.MIN_TURN_SECONDS,
		"the shortened turn should never fall below the floor"
	)


## 切断とみなした時間切れ(`timeout`)だけは、従来どおりその場で敗北になること。
## 申告そのものが届かない相手を終わらせるための保険(GameDesign.md 11章)。
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
## **上書きは手番を始めた後に行う**。持ち時間は1手番ぶんで、手番の開始が60秒へ
## 戻すため、順序を逆にすると届いた値がその場で消える。
func _test_clock_can_be_overwritten_by_the_opponent_value(assert_true: Callable) -> void:
	var clock := MatchClock.new(60.0)
	clock.start_turn(MatchState.Side.B)
	clock.remaining[MatchState.Side.B] = 1.0
	assert_true.call(
		is_equal_approx(clock.get_remaining(MatchState.Side.B), 1.0),
		"the opponent clock should take the value that came with their action"
	)
	assert_true.call(
		is_equal_approx(clock.get_remaining(MatchState.Side.A), 60.0),
		"overwriting one side should not touch the other"
	)

	var timed_out_box: Array = [null]
	clock.time_out.connect(func(side: int) -> void: timed_out_box[0] = side)
	clock.tick(1.5)
	assert_true.call(
		timed_out_box[0] == MatchState.Side.B,
		"the overwritten clock should still run out and report the timeout"
	)
	assert_true.call(not clock.running, "the clock should stop once it has reported the timeout")


## **時間切れの通知は「手番側の時計が尽きた」という意味であり、自分の時間切れとは
## 限らない。**相手の手番でも発火するため、受け口は引数の側を見て自分のときだけ
## 申告する(見ないと、相手が切れた瞬間に自分が負けを送る)。
func _test_timeout_reports_the_side_that_actually_ran_out(assert_true: Callable) -> void:
	var clock := MatchClock.new(60.0)
	var timed_out_box: Array = [null]
	clock.time_out.connect(func(side: int) -> void: timed_out_box[0] = side)

	clock.start_turn(MatchState.Side.A)
	clock.tick(10.0)
	clock.start_turn(MatchState.Side.B)
	clock.tick(60.0)
	assert_true.call(
		timed_out_box[0] == MatchState.Side.B,
		"the timeout should name the side whose turn it was, not the local player"
	)
	assert_true.call(
		is_equal_approx(clock.get_remaining(MatchState.Side.A), 50.0),
		"the waiting side should keep the time it had left"
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
