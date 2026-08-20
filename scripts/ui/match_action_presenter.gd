class_name MatchActionPresenter
extends RefCounted
## 反転/移動/交代が適用された直後の演出(GameDesign.md 9章)。MatchTurnResolverが
## 「ターン終了時に自動で起きたこと」を見せるのに対し、こちらは「プレイヤーが指した手そのもの」を
## 見せる。自分の手・オンライン相手の手・CPUの手の3経路すべてがここを通るため、待っている側でも
## 相手が何をしたのかを追える。MatchTurnResolver/MatchEventCaptionと同様、MatchScreenの責務を
## 分離するために切り出している。

## 交代は控え(盤面外のHourglassSlotStrip)から場の左マスへ入るため実距離が離れすぎる。
## 方向だけを保ったままこの距離までに丸め、滑り込みが視界の外から飛んでくるのを避ける。
const SWAP_IN_MAX_DISTANCE := 220.0
## 移動で入れ替わる2駒は同じ直線上をすれ違うため、そのままだと中央で完全に重なって
## どちらも見えなくなる。互いに逆向きの弧を描かせて上下によける。入ってくる駒を大きく上へ、
## 出ていく駒はわずかに下へ膨らませる(下は盤面の縁が近く、深くすると駒がはみ出すため)。
const MOVE_ARC_IN := 46.0
const MOVE_ARC_OUT := -20.0

## 演出中はtrueになり、MatchScreen側(_can_act()/_process())が盤面操作・持ち時間の消費を止める
## (MatchTurnResolver.resolvingと同じ扱い)。
var presenting := false

var _screen: MatchScreen


func _init(screen: MatchScreen) -> void:
	_screen = screen


func reset() -> void:
	presenting = false


## ターン終了時の解決(MatchTurnResolver)が、その行動を設定したマスへズームし終えた時点で
## 呼ぶ(フェーズ17 V-2)。ズーム・スポットライト・間の確保は呼び出し側が済ませているため、
## ここでは「その手そのものの見た目」(実況テキスト・滑り込み・光の筋と持ち上げ)だけを出す。
## リプレイの巻き戻し・観戦の追いつきで手を一気に再現している最中は演出せず即座に戻る。
func play_step(action: Dictionary) -> void:
	if not _should_present():
		return
	presenting = true
	_slide(action)
	_caption(action)
	await _flip(action)
	presenting = false


func _should_present() -> bool:
	# 観戦で複数手がまとめて届いた場合など、演出中にさらに手が来ることがある。重ねて再生すると
	# どれがどの手の演出か分からなくなるため、その場合は演出せず盤面の反映だけに留める。
	if presenting:
		return false
	if _screen.state == null:
		return false
	return not _screen.is_catching_up()


## 対局ログと同一の文言(MatchBattleLog.format_action())を、行動の結果が現れたマスの近くへ
## フロート表示する。
func _caption(action: Dictionary) -> void:
	var text: String = _screen._battle_log.format_action(_screen.state, action)
	if text.is_empty():
		return
	var side: GameState.PlayerSide = action["side"]
	_screen._event_caption.show_action_text(text, side, _caption_position(action))


func _caption_position(action: Dictionary) -> int:
	match action.get("type", ""):
		"move":
			return action["to"]
		"swap_in":
			return GameState.BoardPosition.LEFT
		_:
			return action["position"]


## 移動は入れ替わった2駒を互いの元の位置から、交代は控えのスロットから場の左マスへ
## 滑り込ませる。反転は既存の回転演出(HourglassSlot._animate_flip())があるため何もしない。
func _slide(action: Dictionary) -> void:
	var self_side := _screen.perspective_side()
	var side: GameState.PlayerSide = action["side"]
	match action.get("type", ""):
		"move":
			var from_position: int = action["from"]
			var to_position: int = action["to"]
			var from_rect := _screen.game_board.get_board_slot_rect(self_side, side, from_position)
			var to_rect := _screen.game_board.get_board_slot_rect(self_side, side, to_position)
			if from_rect.size == Vector2.ZERO or to_rect.size == Vector2.ZERO:
				return
			var delta := to_rect.get_center() - from_rect.get_center()
			_screen.game_board.play_slide_in(self_side, side, to_position, -delta, MOVE_ARC_IN)
			_screen.game_board.play_slide_in(self_side, side, from_position, delta, MOVE_ARC_OUT)
		"swap_in":
			var left := GameState.BoardPosition.LEFT
			var bench_rect := _bench_rect(side, action.get("bench_index", 0))
			var left_rect := _screen.game_board.get_board_slot_rect(self_side, side, left)
			if bench_rect.size == Vector2.ZERO or left_rect.size == Vector2.ZERO:
				return
			var offset := bench_rect.get_center() - left_rect.get_center()
			if offset.length() > SWAP_IN_MAX_DISTANCE:
				offset = offset.normalized() * SWAP_IN_MAX_DISTANCE
			_screen.game_board.play_slide_in(self_side, side, left, offset)


## 反転(GameDesign.md 9章、T-1)。移動/交代のような位置の入れ替えが無いため、代わりに
## 「行動した側の陣地から対象の駒へ光の筋を伸ばし、届いた瞬間に持ち上げて着地させる」ことで
## 誰が手を出したのかを示す(FlipReachOverlay/HourglassSlot.play_flip_lift())。アイコン
## 自体の回転は既存の_animate_flip()(_present_action()のrefresh_view()経由でこの演出より
## 前に開始済み)にそのまま任せ、ここでは光の筋と持ち上げだけを追加する。
func _flip(action: Dictionary) -> void:
	if action.get("type", "") != "flip":
		return
	var self_side := _screen.perspective_side()
	var actor: GameState.PlayerSide = action["actor"]
	var side: GameState.PlayerSide = action["side"]
	var position: int = action["position"]
	if not _screen.game_board.play_flip_reach(self_side, actor, side, position):
		return
	await _screen.get_tree().create_timer(FlipReachOverlay.REACH_DURATION).timeout
	_screen.game_board.play_flip_lift(self_side, side, position)


func _bench_rect(side: GameState.PlayerSide, bench_index: int) -> Rect2:
	var strip: HourglassSlotStrip = _screen.opponent_slot_strip
	if side == _screen.perspective_side():
		strip = _screen.own_slot_strip
	return strip.get_bench_slot_rect(bench_index)
