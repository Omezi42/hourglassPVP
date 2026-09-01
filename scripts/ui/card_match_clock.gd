class_name CardMatchClock
extends RefCounted
## 対局の持ち時間まわり(GameDesign.md 5章・11章)を1箇所へ集める。
## `card_match_screen.gd` が1000行の上限に達したため切り出した(Architecture.md 11章)。
##
## **時計を持たない対局がある**(CPU戦・持ち時間を切ったルームマッチ)。その間 `clock` は
## null のままで、tick・送信への添付・相手の時間切れ監視のいずれもここで降りる。

## 相手の持ち時間が0になってから切断とみなすまでの猶予(GameDesign.md 5章・11章)。
const OPPONENT_TIMEOUT_GRACE := 20.0

var clock: MatchClock = null

var _screen: CardMatchScreen
var _opponent_wait := 0.0


func _init(screen: CardMatchScreen) -> void:
	_screen = screen


## 時計を作って最初の手番を始める。開始と復帰で同じ手順を踏むため1箇所へ寄せる。
func start() -> void:
	clock = MatchClock.new()
	clock.time_out.connect(_screen._on_local_timeout)
	start_turn()


func clear() -> void:
	clock = null
	_opponent_wait = 0.0


func active() -> bool:
	return clock != null


func remaining(side: int) -> float:
	return clock.get_remaining(side) if clock != null else -1.0


## 相手の手に添えられた残り時間で上書きする(GameDesign.md 11章)。
func overwrite_foe(seconds: float) -> void:
	if clock != null:
		clock.remaining[MatchState.other_side(_screen.my_side)] = seconds


func tick(delta: float) -> void:
	var state := _screen.state
	if clock == null or state == null or state.is_match_over():
		return
	clock.tick(delta)
	_watch_opponent_timeout(delta)
	refresh_bars()


## 手番の始まりに与える持ち時間。時間切れを重ねた側は半分ずつ短くなる
## (GameDesign.md 5章)。回数は `MatchState` が持つため、オンラインでも両者で一致する。
func start_turn() -> void:
	var state := _screen.state
	if clock == null or state == null or state.is_match_over():
		return
	clock.start_turn(state.current_turn, seconds_for(state.current_turn))


## その側の手番に与える持ち時間。時間切れを重ねているほど短い(GameDesign.md 5章)。
func seconds_for(side: int) -> float:
	var state := _screen.state
	if state == null:
		return MatchClock.DEFAULT_TURN_SECONDS
	return MatchClock.seconds_after_forfeits(int(state.turn_forfeits.get(side, 0)))


func refresh_bars() -> void:
	if clock == null:
		return
	var foe := MatchState.other_side(_screen.my_side)
	var own_bar := _screen.bar_for(_screen.my_side)
	var foe_bar := _screen.bar_for(foe)
	own_bar.clock_seconds = clock.get_remaining(_screen.my_side)
	foe_bar.clock_seconds = clock.get_remaining(foe)
	own_bar.clock_total = seconds_for(_screen.my_side)
	foe_bar.clock_total = seconds_for(foe)
	own_bar.queue_redraw()
	foe_bar.queue_redraw()


## 相手の持ち時間が0になっても申告が来ない場合、猶予を置いて待っている側の勝ちにする。
## **申告が届いている限り敗北にはしない**(GameDesign.md 11章)。ここに掛かるのは
## 「申告そのものが来ない=切断」の判定だけになる。
func _watch_opponent_timeout(delta: float) -> void:
	var foe := MatchState.other_side(_screen.my_side)
	if clock.get_remaining(foe) > 0.0:
		_opponent_wait = 0.0
		return
	_opponent_wait += delta
	if _opponent_wait >= OPPONENT_TIMEOUT_GRACE:
		_opponent_wait = 0.0
		_screen.state.surrender(foe, MatchState.EndReason.TIMEOUT)
