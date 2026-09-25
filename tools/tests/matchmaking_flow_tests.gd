extends RefCounted
## 複数のプレイヤーが実際に `join()` のポーリングを回し、互いを見つけて同じ対局へ入ることを、
## 差し替え用クライアント1つを共有して確かめる(Architecture.md 6.1節・10.16節)。
## `_try_claim_or_check()` を1回ずつ呼ぶ単体の検証では、ポーリングの順序・心拍・掃除との
## 絡みで待ち続ける不具合を拾えないため、ループそのものを動かす。
## Firestoreの応答の形まで含めた確認は `matchmaking_live_test.gd`(本物へ当てる)が持つ。

const FakeClient = preload("res://tools/tests/fake_firestore_client.gd")
const QUEUE := RankedMatchmakingQueue.RANKED_COLLECTION
const FAST_POLL_SECONDS := 0.05
const MATCH_TIMEOUT_SECONDS := 3.0
## 成立しないことを確かめるときに待つ時間。ポーリングが何周も回る長さにする。
const NO_MATCH_WAIT_SECONDS := 0.5

var _assert: Callable
var _tree: SceneTree
var _client


## 募集の知らせ(Discord)はテストから送らない。
class SilentQueue:
	extends RankedMatchmakingQueue

	func _announce_if_due() -> void:
		pass


class Player:
	var queue: MatchmakingQueue
	var match_id := ""
	var opponent_uid := ""


func run(assert_true: Callable) -> void:
	_assert = assert_true
	_tree = Engine.get_main_loop() as SceneTree
	await _test_late_joiner_matches_the_waiting_player()
	await _test_simultaneous_join_makes_one_match()
	await _test_third_player_waits_for_the_next_one()
	await _test_heartbeat_after_sweep_keeps_player_visible()
	await _test_cpu_player_is_matched_after_returning()
	await _test_cancelled_player_is_not_matched()


func _test_late_joiner_matches_the_waiting_player() -> void:
	_reset()
	var a := _player("uid-a")
	a.queue.join()
	await _wait(NO_MATCH_WAIT_SECONDS)
	var b := _player("uid-b")
	b.queue.join()
	await _wait_matched([a, b])
	_assert_pair(a, b, "後から入った相手")
	_cleanup([a, b])


func _test_simultaneous_join_makes_one_match() -> void:
	_reset()
	var a := _player("uid-a")
	var b := _player("uid-b")
	a.queue.join()
	b.queue.join()
	await _wait_matched([a, b])
	_assert_pair(a, b, "同時に入った2人")
	_assert.call(_match_docs().size() == 1, "同時に入っても対局は1つだけ作られること")
	_cleanup([a, b])


func _test_third_player_waits_for_the_next_one() -> void:
	_reset()
	var players: Array = [_player("uid-a"), _player("uid-b"), _player("uid-c")]
	for p: Player in players:
		p.queue.join()
	await _wait_until(
		func() -> bool:
			return players.filter(func(p: Player) -> bool: return p.match_id != "").size() >= 2
	)
	await _wait(NO_MATCH_WAIT_SECONDS)
	var matched: Array = players.filter(func(p: Player) -> bool: return p.match_id != "")
	var left: Array = players.filter(func(p: Player) -> bool: return p.match_id == "")
	_assert.call(matched.size() == 2 and left.size() == 1, "3人のうち2人だけが組になること")
	if matched.size() != 2 or left.size() != 1:
		_cleanup(players)
		return
	_assert_pair(matched[0], matched[1], "3人のうちの2人")
	var d := _player("uid-d")
	d.queue.join()
	await _wait_matched([left[0], d])
	_assert_pair(left[0], d, "余った1人と次に来た人")
	players.append(d)
	_cleanup(players)


## 裏のタブで心拍が止まって掃除された直後に、心拍やCPU戦からの復帰の書き込みが走っても、
## `match_id` の無い文書を作らないこと。作ると誰の検索にも掛からず、自分も「在る」と見て
## 書き直さない。**2人ともそうなると互いに見えないまま待ち続ける。**
func _test_heartbeat_after_sweep_keeps_player_visible() -> void:
	_reset()
	var players: Array = [_player("uid-a"), _player("uid-b")]
	for p: Player in players:
		# CPU戦中は掴み合わないため、2人とも待機したまま掃除される状況を作れる
		p.queue.join()
		await p.queue.set_cpu_playing(true)
	await _wait(NO_MATCH_WAIT_SECONDS)
	for p: Player in players:
		_client.store.erase(_path(p.queue.auth.uid))
		await p.queue._touch_waiting_doc({"joined_at": Time.get_unix_time_from_system()})
		await p.queue.set_cpu_playing(false)
	await _wait_matched(players)
	_assert_pair(players[0], players[1], "掃除された後に心拍が走った2人")
	_cleanup(players)


func _test_cpu_player_is_matched_after_returning() -> void:
	_reset()
	var a := _player("uid-a")
	a.queue.join()
	await _wait(NO_MATCH_WAIT_SECONDS)
	await a.queue.set_cpu_playing(true)
	var b := _player("uid-b")
	b.queue.join()
	await _wait(NO_MATCH_WAIT_SECONDS)
	_assert.call(a.match_id == "" and b.match_id == "", "CPU戦中の待機者は掴まないこと")
	await a.queue.set_cpu_playing(false)
	await _wait_matched([a, b])
	_assert_pair(a, b, "CPU戦から戻った待機者")
	_cleanup([a, b])


func _test_cancelled_player_is_not_matched() -> void:
	_reset()
	var a := _player("uid-a")
	a.queue.join()
	await _wait(NO_MATCH_WAIT_SECONDS)
	await a.queue.cancel()
	var b := _player("uid-b")
	b.queue.join()
	await _wait(NO_MATCH_WAIT_SECONDS)
	_assert.call(a.match_id == "" and b.match_id == "", "キャンセルした人とは組まないこと")
	var c := _player("uid-c")
	c.queue.join()
	await _wait_matched([b, c])
	_assert_pair(b, c, "キャンセルの後に来た2人")
	_cleanup([a, b, c])


func _assert_pair(a: Player, b: Player, label: String) -> void:
	_assert.call(a.match_id != "" and b.match_id != "", "%sと成立すること" % label)
	_assert.call(a.match_id == b.match_id, "%sと同じ対局へ入ること" % label)
	_assert.call(
		a.opponent_uid == b.queue.auth.uid and b.opponent_uid == a.queue.auth.uid,
		"%sと互いを相手として受け取ること" % label
	)
	var doc: Dictionary = _client.store.get("matches/%s" % a.match_id, {}).get("fields", {})
	var sides := [doc.get("player_a", ""), doc.get("player_b", "")]
	_assert.call(
		sides.has(a.queue.auth.uid) and sides.has(b.queue.auth.uid),
		"%sとの対局で先手・後手が1人ずつ決まること" % label
	)
	_assert.call(
		(
			not _client.store.has(_path(a.queue.auth.uid))
			and not _client.store.has(_path(b.queue.auth.uid))
		),
		"%sと成立したら待合室から消えること" % label
	)


func _reset() -> void:
	if _client != null:
		_client.queue_free()
	var auth := FirebaseAuth.new(null)
	_client = FakeClient.new(auth)
	_tree.root.add_child(_client)


func _player(uid: String) -> Player:
	var p := Player.new()
	var auth := FirebaseAuth.new(null)
	auth.uid = uid
	p.queue = SilentQueue.new(_client, auth)
	p.queue.poll_interval = FAST_POLL_SECONDS
	_tree.root.add_child(p.queue)
	p.queue.matched.connect(
		func(id: String, opponent: String) -> void:
			p.match_id = id
			p.opponent_uid = opponent
	)
	return p


## 待機ループが回っている最中に解放すると落ちるため、キャンセルしてループが抜けてから解放する。
func _cleanup(players: Array) -> void:
	for p: Player in players:
		if p.match_id == "":
			await p.queue.cancel()
	await _wait(FAST_POLL_SECONDS * 4.0)
	for p: Player in players:
		p.queue.queue_free()


func _match_docs() -> Array:
	return _client.store.keys().filter(
		func(path: String) -> bool: return path.begins_with("matches/")
	)


func _path(uid: String) -> String:
	return "%s/%s" % [QUEUE, uid]


func _wait_matched(players: Array) -> void:
	await _wait_until(
		func() -> bool: return players.all(func(p: Player) -> bool: return p.match_id != "")
	)


func _wait_until(condition: Callable) -> void:
	var deadline := Time.get_ticks_msec() + int(MATCH_TIMEOUT_SECONDS * 1000.0)
	while Time.get_ticks_msec() < deadline and not condition.call():
		await _tree.process_frame


func _wait(seconds: float) -> void:
	await _tree.create_timer(seconds).timeout
