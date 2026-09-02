class_name CardMatchOutcome
extends RefCounted
## 終局後の後始末(リプレイの保存・砂金の付与・戦績の記録)。
## `CardMatchReplay` 等と同じく `_screen` 参照を持つ切り出しで、
## `card_match_screen.gd` が1000行の上限に達したため分けている。
## 画面の private メンバを読むのは、既存の切り出しクラスと同じ流儀(Architecture.md 4.0節)。

## 最後の手が送り終わるのを待つ上限。届かないまま待ち続けないための保険。
const SEND_WAIT_FRAMES := 600

var _screen: CardMatchScreen


func _init(screen: CardMatchScreen) -> void:
	_screen = screen


## 結果パネルへ出す1行(砂金)を返し、リプレイと戦績を残す。
func finish(kind: int, deck: Array) -> String:
	var state: MatchState = _screen.state
	if state.winner < 0:
		return ""
	var won: bool = state.winner == _screen.my_side
	var uid := _uid()
	MatchStats.record(uid, kind, won, state.turn_count, deck)
	save_replay()
	_submit_record(kind)
	return _grant(kind, won, state.turn_count, uid)


## 分析用の記録(GameDesign.md 22章)。**オンライン対戦だけ**が対象で、CPU戦・観戦・
## リプレイ再生では呼ばれない。**完了を待たない**(結果パネルの表示を通信で止めないため。
## 砂金の付与が既に通っている扱いと同じ)。失敗しても画面には何も出さない。
func _submit_record(kind: int) -> void:
	if kind != CurrencyRules.MatchKind.RANDOM and kind != CurrencyRules.MatchKind.ROOM:
		return
	if _screen._client == null or _screen._match_id.is_empty():
		return
	# 最後の手が届いてから読む。自分の投了・時間切れは終局と同時に送られるため、
	# 待たずに読むと棋譜の末尾が欠ける。届かないまま止まらないよう上限を置く。
	var waited := 0
	while _screen._online != null and _screen._online.is_busy() and waited < SEND_WAIT_FRAMES:
		waited += 1
		await _screen.get_tree().process_frame
	await MatchRecordService.submit(_screen._client, _screen._match_id, kind, _screen.state)


## 砂金の付与(GameDesign.md 15章)。**判定はキャッシュから即座に行い、実際の加算
## (通信)は待たない。**オフラインでも遊べるCPU戦で結果表示が止まらないようにするため。
func _grant(kind: int, won: bool, moves: int, uid: String) -> String:
	var result := CurrencyRules.evaluate(kind, won, moves, AccountService.cpu_reward_count_today())
	var amount: int = int(result.get("amount", 0))
	if amount > 0 and NetSession.client != null and not uid.is_empty():
		AccountService.grant(NetSession.client, uid, amount, kind == CurrencyRules.MatchKind.CPU)
	return CurrencyRules.format_reward(result)


## リプレイとして残す(GameDesign.md 12章)。CPU戦はローカルへ1回だけ書き、
## オンライン対戦は matches/{id} へ finished_at/winner を書く(観戦者は書かない)。
func save_replay() -> void:
	var state: MatchState = _screen.state
	var winner := "a" if state.winner == MatchState.Side.A else "b"
	if not _screen._cpu_record.is_empty():
		_screen._cpu_record["winner"] = winner
		LocalReplayService.mark_finished(_screen._cpu_record, _uid())
		return
	if _screen._client == null or _screen._match_id.is_empty():
		return
	var uid: String = _screen._client.auth.uid if _screen._client.auth != null else ""
	ReplayService.mark_finished(_screen._client, _screen._match_id, winner, uid)


func _uid() -> String:
	if NetSession.client == null or NetSession.client.auth == null:
		return ""
	return NetSession.client.auth.uid
