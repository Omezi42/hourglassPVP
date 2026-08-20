class_name MatchResultPresenter
extends RefCounted
## 対局終了時の結果パネル(GameDesign.md 3章・9章、O-7)。勝敗テキストの組み立て・パネルの
## 登場アニメーション・タイトル→詳細→ボタンの段階表示・勝利時の光の粒演出に加えて、
## 決着そのものの演出(フェーズ18 W-2)と「決め手」の1行(W-3)をここが担う。
## MatchBattleLog/MatchTurnResolverと同様、MatchScreenの責務を分離するため切り出している。

## 結果パネルの暗幕の目標透明度。敗北時は少し暗めにして雰囲気を分ける。
const DIM_ALPHA_VICTORY := 0.6
const DIM_ALPHA_DEFEAT := 0.75
## 勝利演出(パーティクル)のパラメータ
const BURST_LIFETIME := 0.9
const BURST_AMOUNT := 36
## 決着演出(フェーズ18 W-2)。決着を生んだイベントの直後、画面中央へ大きく重ねる表示。
const FINISH_TEXT := "決着"
const FINISH_FONT_SIZE := 64
const FINISH_POP_DURATION := 0.28
## 「決着」を出す高さ(画面高さに対する比率)。決め手の駒を隠さないよう、盤面の駒より下へ置く。
const FINISH_Y_RATIO := 0.74
const FINISH_HOLD := 0.9
## 「決着」表示を出してから結果パネルへ移るまでの待ち時間(表示のフェードアウトは
## 結果パネルの登場と重なってよいため、HOLDまでで切り上げる)。
const FINISH_LEAD := FINISH_POP_DURATION + FINISH_HOLD

var _screen: MatchScreen
## 決着を生んだ一撃(HPを0にしたダメージ)。{"side","amount","source"}で、sourceは
## 落ちきった駒({"side","position"})または効果ダメージ等で特定できない場合のnull。
var _finishing_blow: Dictionary = {}
## 解決演出の再生中に決着した場合、再生し終えるまで結果パネルの表示を待つための勝者。
var _pending_winner: Variant = null


func _init(screen: MatchScreen) -> void:
	_screen = screen


func reset() -> void:
	_finishing_blow = {}
	_pending_winner = null


## HPが変化するたびにMatchScreenから呼ばれ、決着を生んだ一撃を覚えておく(W-3)。
## HPを0にしたダメージだけを記録し、それ以外は無視する。
func note_hp_change(
	side: GameState.PlayerSide, previous_hp: int, new_hp: int, source: Variant
) -> void:
	if new_hp > 0 or new_hp >= previous_hp:
		return
	_finishing_blow = {"side": side, "amount": previous_hp - new_hp, "source": source}


## 解決演出の途中で決着した場合、結果パネルの表示を演出の完了まで保留する(W-2)。
## 「勝敗が決まった時点で即座に終了する」は盤面を操作できなくなることを指し、決着に至った
## 出来事の演出まで省略することは意味しない(GameDesign.md 3章)。
func hold_result(winner: GameState.PlayerSide) -> void:
	_pending_winner = winner


## 保留していた結果パネルがあれば表示する。解決演出の完了後と、演出を再生しなかった経路の
## 両方から呼ばれる。
func flush_pending() -> void:
	if _pending_winner == null:
		return
	var winner: GameState.PlayerSide = _pending_winner
	_pending_winner = null
	show_for(winner)


## 勝敗テキストを組み立てて結果パネルを表示する。自視点が固定される対局(オンライン/CPU戦)
## だけ勝敗で書き、同一端末で交互に操作するローカル対戦と観戦は「自分」が定まらないため
## 先手/後手で書く。決め手の1行も同じ視点に合わせる。
func show_for(winner: GameState.PlayerSide) -> void:
	var state: GameState = _screen.state
	# ログの決着行は、決着した手番の進行・ダメージを記録し終えた後(=結果を出す直前)に積む。
	# match_ended発火の時点で積むと、演出で後から積まれる行の下に埋もれてしまう(W-4)。
	_screen._battle_log.record_match_end(state, winner)
	var title: String
	var detail: String
	if _screen.is_self_view_fixed():
		var self_side: GameState.PlayerSide = _screen.self_side()
		title = "勝利!" if winner == self_side else "敗北..."
		detail = (
			"自分 %d  /  相手 %d\n%d手で決着"
			% [state.hp[self_side], state.hp[state.other_side(self_side)], _screen.move_count()]
		)
	else:
		title = "先手の勝利!" if winner == GameState.PlayerSide.A else "後手の勝利!"
		detail = (
			"先手 %d  /  後手 %d\n%d手で決着"
			% [
				state.hp[GameState.PlayerSide.A],
				state.hp[GameState.PlayerSide.B],
				_screen.move_count(),
			]
		)
	var blow := format_finishing_blow(state, _finishing_blow, _loser_label(state, winner))
	if not blow.is_empty():
		detail += "\n" + blow
	show_result(title, detail)


## 敗者の呼び方。視点が固定される対局は「自分」「相手」、ローカル対戦・観戦は「先手」「後手」。
func _loser_label(state: GameState, winner: GameState.PlayerSide) -> String:
	var loser: GameState.PlayerSide = state.other_side(winner)
	if _screen.is_self_view_fixed():
		return "自分" if loser == _screen.self_side() else "相手"
	return "先手" if loser == GameState.PlayerSide.A else "後手"


## 完成済みのtitle/detailテキストを受け取り、演出付きで結果パネルを表示する。
func show_result(title: String, detail: String) -> void:
	var overlay: Control = _screen.result_overlay
	var panel: PanelContainer = _screen.result_panel
	var title_label: Label = _screen.result_title
	var detail_label: Label = _screen.result_detail
	var button_row: Control = _screen.result_button_row

	title_label.text = title
	detail_label.text = detail

	var is_defeat := title == "敗北..."

	overlay.visible = true
	panel.pivot_offset = panel.size / 2
	panel.scale = Vector2(0.85, 0.85)
	overlay.modulate.a = 0.0
	detail_label.modulate.a = 0.0
	button_row.modulate.a = 0.0
	var dim: ColorRect = overlay.get_node("Dim")
	var dim_target_alpha := DIM_ALPHA_DEFEAT if is_defeat else DIM_ALPHA_VICTORY
	dim.color.a = 0.0

	var tween := _screen.create_tween()
	tween.set_parallel(true)
	tween.tween_property(overlay, "modulate:a", 1.0, 0.3)
	tween.tween_property(dim, "color:a", dim_target_alpha, 0.3)
	tween.tween_property(panel, "scale", Vector2.ONE, 0.35).set_trans(Tween.TRANS_BACK).set_ease(
		Tween.EASE_OUT
	)
	# タイトル→詳細→ボタンの順に少し間を置いて表示する
	tween.chain().tween_property(detail_label, "modulate:a", 1.0, 0.25)
	tween.chain().tween_property(button_row, "modulate:a", 1.0, 0.25)

	if not is_defeat:
		_spawn_victory_burst(panel)


## 決着を生んだイベントの直後に呼ばれ、画面中央へ「決着」を大きく重ねて短い間を置く
## (GameDesign.md 3章、フェーズ18 W-2)。原因の駒に当たっているスポットライトとカメラの
## ズームはここでは戻さず、その駒を見せたまま結果パネルの表示へ移る。
func play_finishing_blow() -> void:
	var label := Label.new()
	label.text = FINISH_TEXT
	label.add_theme_font_size_override("font_size", FINISH_FONT_SIZE)
	label.add_theme_color_override("font_color", UiPalette.GLOW_AMBER)
	label.add_theme_color_override("font_outline_color", UiPalette.OUTLINE_DARK)
	label.add_theme_constant_override("outline_size", 8)
	_screen.add_child(label)

	var min_size: Vector2 = label.get_minimum_size()
	label.pivot_offset = min_size * 0.5
	label.position = (
		Vector2(_screen.size.x * 0.5, _screen.size.y * FINISH_Y_RATIO) - min_size * 0.5
	)
	label.scale = Vector2(1.35, 1.35)
	label.modulate.a = 0.0

	var tween := _screen.create_tween()
	tween.set_parallel(true)
	tween.tween_property(label, "modulate:a", 1.0, 0.15)
	(
		tween
		. tween_property(label, "scale", Vector2.ONE, FINISH_POP_DURATION)
		. set_trans(Tween.TRANS_BACK)
		. set_ease(Tween.EASE_OUT)
	)
	tween.chain().tween_interval(FINISH_HOLD)
	tween.chain().tween_property(label, "modulate:a", 0.0, 0.25)
	tween.chain().tween_callback(label.queue_free)

	await _screen.get_tree().create_timer(FINISH_LEAD).timeout


## 結果パネルの「決め手」1行を組み立てる(GameDesign.md 3章、フェーズ18 W-3)。blowは決着を
## 生んだダメージ({"amount": int, "source": {"side","position"} or null})で、sourceは
## 落ちきった駒(MatchScreenが_pop_fall_source()で追跡しているもの)。持ち時間切れ・投了は
## ダメージを伴わないためblowを参照しない。
func format_finishing_blow(state: GameState, blow: Dictionary, loser_label: String) -> String:
	match state.end_reason:
		GameState.EndReason.TIMEOUT:
			return "決め手: %sの持ち時間切れ" % loser_label
		GameState.EndReason.SURRENDER:
			return "決め手: %sの投了" % loser_label
	if blow.is_empty():
		return ""
	var amount: int = blow.get("amount", 0)
	var source: Variant = blow.get("source")
	if source == null:
		return "決め手: 効果によるダメージ %d" % amount
	var instance: HourglassInstance = state.board[source["side"]][source["position"]]
	return "決め手: 「%s」の落下ダメージ %d" % [instance.data.display_name, amount]


## 勝利時に結果パネルの中央から琥珀色の光の粒を弾けさせる。新規画像は使わず、
## CPUParticles2Dのみで表現する(BoardTable等の「コード描画で質感を出す」方針を踏襲)。
func _spawn_victory_burst(panel: PanelContainer) -> void:
	var particles := CPUParticles2D.new()
	particles.position = panel.size / 2
	particles.one_shot = true
	particles.explosiveness = 1.0
	particles.amount = BURST_AMOUNT
	particles.lifetime = BURST_LIFETIME
	particles.direction = Vector2.UP
	particles.spread = 180.0
	particles.gravity = Vector2(0, 160)
	particles.initial_velocity_min = 120.0
	particles.initial_velocity_max = 260.0
	particles.scale_amount_min = 2.0
	particles.scale_amount_max = 4.0
	particles.color = Color(0.95, 0.78, 0.35, 1.0)
	panel.add_child(particles)
	panel.move_child(particles, 0)
	particles.emitting = true
	_screen.get_tree().create_timer(particles.lifetime + 0.3).timeout.connect(particles.queue_free)
