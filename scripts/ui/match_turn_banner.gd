class_name MatchTurnBanner
extends RefCounted
## 「今が誰の手番か」の表示をまとめて受け持つ。上部バーの手番テキスト・相手待ちの巡回ドット・
## 手番が自分に回ってきた瞬間の一瞬のバナー(P-5)の3つは同じ判定(自視点が固定される対局か
## どうか)から決まるため、1箇所にまとめている。
## 自視点が固定される対局(オンライン/CPU戦)は「あなたの番です/相手の手を待っています」、
## 「自分」が定まらないローカル対戦・観戦・リプレイ再生は先手/後手で表す
## (MatchResultPresenterの視点判定と同じ書き分け)。バナーは前者でのみ出す。

const BANNER_TEXT := "あなたの番です"
const WAIT_TEXT := "相手の手を待っています"
const OVER_TEXT := "対局終了"
const WAIT_DOTS_MAX := 3
const HOLD_DURATION := 0.9
const FADE_IN_DURATION := 0.2
const FADE_OUT_DURATION := 0.4
const FONT_SIZE := 30
const TOP_OFFSET := 90.0

var _screen: MatchScreen
## null=未確定(直前の状態が分からないため初回は発火しない)。
var _last_is_my_turn: Variant = null
var _wait_dots_active := false
var _wait_dot_count := 0
## 巡回ドットの更新は同じ表示を描き直すだけなので、MatchScreenへ問い合わせずに済むよう
## 直近の引数を控えておく。
var _last_args := {}


func _init(screen: MatchScreen) -> void:
	_screen = screen


func setup() -> void:
	_screen.wait_dots_timer.timeout.connect(_on_wait_dots_timeout)


func reset() -> void:
	_last_is_my_turn = null
	_last_args = {}
	_wait_dots_active = false
	_screen.wait_dots_timer.stop()


func refresh_label(self_locked_view: bool, is_my_turn: bool, match_over: bool) -> void:
	_last_args = {"locked": self_locked_view, "mine": is_my_turn, "over": match_over}
	# 終局後は手番が存在しない。「相手の手を待っています」が残ると、結果パネルの外側で
	# 対局が続いているように見えてしまう。
	if match_over:
		_set_wait_dots_active(false)
		_screen.turn_label.text = OVER_TEXT
		return
	var waiting := self_locked_view and not is_my_turn
	_set_wait_dots_active(waiting)
	_notify_turn(self_locked_view, is_my_turn)

	if not self_locked_view:
		var first := _screen.state.current_turn == GameState.PlayerSide.A
		_screen.turn_label.text = "先手のターン" if first else "後手のターン"
		return
	if not waiting:
		_screen.turn_label.text = BANNER_TEXT
		return
	_screen.turn_label.text = WAIT_TEXT + ".".repeat(_wait_dot_count)


## self_locked_viewでない対局(ローカル対戦・観戦・リプレイ)ではバナーを出さない。
func _notify_turn(self_locked_view: bool, is_my_turn: bool) -> void:
	if not self_locked_view:
		_last_is_my_turn = null
		return
	if _last_is_my_turn == false and is_my_turn:
		_flash()
	_last_is_my_turn = is_my_turn


func _set_wait_dots_active(active: bool) -> void:
	if active == _wait_dots_active:
		return
	_wait_dots_active = active
	_wait_dot_count = 0
	if active:
		_screen.wait_dots_timer.start()
	else:
		_screen.wait_dots_timer.stop()


func _on_wait_dots_timeout() -> void:
	_wait_dot_count = (_wait_dot_count % WAIT_DOTS_MAX) + 1
	if _last_args.is_empty():
		return
	refresh_label(_last_args["locked"], _last_args["mine"], _last_args["over"])


func _flash() -> void:
	var label := Label.new()
	label.text = BANNER_TEXT
	label.add_theme_font_size_override("font_size", FONT_SIZE)
	label.add_theme_color_override("font_color", Color(1.0, 0.86, 0.5, 1))
	label.add_theme_color_override("font_outline_color", Color(0.1, 0.07, 0.03, 0.95))
	label.add_theme_constant_override("outline_size", 6)
	_screen.add_child(label)

	var min_size: Vector2 = label.get_minimum_size()
	label.pivot_offset = min_size * 0.5
	label.position = Vector2((_screen.size.x - min_size.x) * 0.5, TOP_OFFSET)
	label.modulate.a = 0.0
	label.scale = Vector2(0.85, 0.85)

	var tween := _screen.create_tween()
	tween.set_parallel(true)
	tween.tween_property(label, "modulate:a", 1.0, FADE_IN_DURATION)
	tween.tween_property(label, "scale", Vector2.ONE, FADE_IN_DURATION)
	tween.chain().tween_interval(HOLD_DURATION)
	tween.chain().tween_property(label, "modulate:a", 0.0, FADE_OUT_DURATION)
	tween.chain().tween_callback(label.queue_free)
