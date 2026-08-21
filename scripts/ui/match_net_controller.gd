class_name MatchNetController
extends RefCounted
## オンライン対戦の「通信そのもの」に関わる表示と判定をMatchScreenから切り出したもの。
## 受け持つのは (1)通信状態の表示 (2)持ち時間の同期 (3)時間切れの申告と、相手が切断して
## 申告が来ない場合の猶予つき判定 の3つ(GameDesign.md 11章)。
## いずれもオンライン対戦でしか働かず、ローカル対戦・CPU戦・観戦・リプレイでは何もしない。

const SENDING_TEXT := "送信中"
const OFFLINE_TEXT := "相手と接続できません(再試行中)"
const WAITING_TIMEOUT_TEXT := "相手の応答を待っています"
## 相手の持ち時間が0になってから、時間切れの申告を待つ猶予。相手が切断していると
## 申告は来ないため、この猶予を過ぎたら待っている側の勝ちとして終局させる。
const OPPONENT_TIMEOUT_GRACE := 12.0
const FONT_SIZE := 18
const TOP_OFFSET := 100.0

var _screen: MatchScreen
var _label: Label = null
var _online := true
## 相手の時間切れを待っている残り秒数。負なら待っていない。
var _grace_left := -1.0
var _last_text := ""


func _init(screen: MatchScreen) -> void:
	_screen = screen


func setup() -> void:
	_label = Label.new()
	_label.add_theme_font_size_override("font_size", FONT_SIZE)
	_label.add_theme_color_override("font_color", Color(1.0, 0.78, 0.52, 1))
	_label.add_theme_color_override("font_outline_color", Color(0.1, 0.07, 0.03, 0.95))
	_label.add_theme_constant_override("outline_size", 5)
	_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_label.visible = false
	_screen.add_child(_label)


func reset() -> void:
	_online = true
	_grace_left = -1.0
	_set_text("")


## 対局開始時に、その対局のOnlineMatchを結び付ける。
func attach(online_match: OnlineMatch) -> void:
	reset()
	if online_match == null:
		return
	_online = online_match.connected
	if not online_match.connection_changed.is_connected(_on_connection_changed):
		online_match.connection_changed.connect(_on_connection_changed)


## 送信する手に自分の残り時間を添える(GameDesign.md 11章)。相手の手が届くまでの遅延ぶん
## 相手の時計を余分に減らしてしまい、実際より早く時間切れと判定するのを防ぐ。
func stamp(action: Dictionary) -> Dictionary:
	if not _screen._is_online or _screen._clock == null:
		return action
	var stamped := action.duplicate(true)
	stamped["clock"] = _screen._clock.get_remaining(_screen._my_side)
	stamped["clock_side"] = int(_screen._my_side)
	return stamped


## 受け取った手に添えられた残り時間で、こちらが持っている送り主側の時計を上書きする。
func apply_incoming(action: Dictionary) -> void:
	_grace_left = -1.0
	if not _screen._is_online or _screen._clock == null:
		return
	if not action.has("clock") or not action.has("clock_side"):
		return
	var side: int = int(action["clock_side"])
	_screen._clock.remaining[side] = maxf(float(action["clock"]), 0.0)


## 持ち時間が0になったときの処理をオンライン対戦の流儀で引き受ける。
## 引き受けた場合はtrueを返し、MatchScreen側の既定処理(その場で終局)を行わせない。
func handle_timeout(side: GameState.PlayerSide) -> bool:
	if not _screen._is_online or _screen._online_match == null:
		return false
	if side == _screen._my_side:
		_report_timeout(side)
		return true
	# 相手の時間切れ。申告が来るのを猶予つきで待つ
	_grace_left = OPPONENT_TIMEOUT_GRACE
	refresh()
	return true


func process(delta: float) -> void:
	refresh()
	if _grace_left < 0.0:
		return
	if _screen.state == null or _screen.state.is_match_over():
		_grace_left = -1.0
		return
	_grace_left -= delta
	if _grace_left > 0.0:
		return
	_grace_left = -1.0
	# 猶予を過ぎても申告が来なかった。相手は切断しているとみなし、こちらで終局させる
	# (相手にも1手として書き残すため、復帰した場合も同じ結果になる)。
	_report_timeout(_screen.state.other_side(_screen._my_side))


func refresh() -> void:
	if not _screen._is_online:
		_set_text("")
		return
	if _grace_left >= 0.0:
		_set_text(WAITING_TIMEOUT_TEXT)
		return
	if not _online:
		_set_text(OFFLINE_TEXT)
		return
	var busy: bool = _screen._online_match != null and _screen._online_match.is_busy()
	_set_text(SENDING_TEXT if busy else "")


func _report_timeout(side: GameState.PlayerSide) -> void:
	var action := {"type": "timeout", "side": int(side)}
	_screen._online_match.send(action)
	_screen._battle_log.record_action(_screen.state, action)
	OnlineMatch.apply(action, _screen.state)
	refresh()


func _on_connection_changed(online: bool) -> void:
	_online = online
	refresh()


func _set_text(text: String) -> void:
	if _label == null or text == _last_text:
		return
	_last_text = text
	_label.text = text
	_label.visible = text != ""
	if text == "":
		return
	var min_size: Vector2 = _label.get_minimum_size()
	_label.position = Vector2((_screen.size.x - min_size.x) * 0.5, TOP_OFFSET)
