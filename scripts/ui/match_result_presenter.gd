class_name MatchResultPresenter
extends RefCounted
## 対局終了時の結果パネル演出(GameDesign.md 9章、O-7)。パネルの登場アニメーション・
## タイトル→詳細→ボタンの段階表示・勝利時の光の粒演出をここへ切り出している
## (MatchBattleLog/MatchTurnResolverと同様、MatchScreenの責務を分離するため)。

## 結果パネルの暗幕の目標透明度。敗北時は少し暗めにして雰囲気を分ける。
const DIM_ALPHA_VICTORY := 0.6
const DIM_ALPHA_DEFEAT := 0.75
## 勝利演出(パーティクル)のパラメータ
const BURST_LIFETIME := 0.9
const BURST_AMOUNT := 36
## 決着演出(フェーズ18 W-2)。決着を生んだイベントの直後、盤面中央へ大きく重ねる表示。
const FINISH_TEXT := "決着"
const FINISH_FONT_SIZE := 64
const FINISH_POP_DURATION := 0.28
const FINISH_HOLD := 0.9
## 「決着」表示を出してから結果パネルへ移るまでの待ち時間(表示のフェードアウトは
## 結果パネルの登場と重なってよいため、HOLDまでで切り上げる)。
const FINISH_LEAD := FINISH_POP_DURATION + FINISH_HOLD

var _screen: MatchScreen


func _init(screen: MatchScreen) -> void:
	_screen = screen


## winner/self_side/move_countから表示文言を組み立て、演出付きで結果パネルを表示する。
## 視点の書き分け(勝敗表記 vs 先手/後手表記)は呼び出し側(MatchScreen)が既に持つ判断を
## そのまま踏襲し、ここでは完成済みのtitle/detailテキストを受け取るだけにする。
func show_result(title: String, detail: String) -> void:
	var overlay: Control = _screen.result_overlay
	var panel: PanelContainer = _screen.result_panel
	var title_label: Label = _screen.result_title
	var detail_label: Label = _screen.result_detail
	var home_button: Button = _screen.result_home_button

	title_label.text = title
	detail_label.text = detail

	var is_defeat := title == "敗北..."

	overlay.visible = true
	panel.pivot_offset = panel.size / 2
	panel.scale = Vector2(0.85, 0.85)
	overlay.modulate.a = 0.0
	detail_label.modulate.a = 0.0
	home_button.modulate.a = 0.0
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
	tween.chain().tween_property(home_button, "modulate:a", 1.0, 0.25)

	if not is_defeat:
		_spawn_victory_burst(panel)


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


## 決着を生んだイベントの直後に呼ばれ、盤面中央へ「決着」を大きく重ねて短い間を置く
## (GameDesign.md 3章、フェーズ18 W-2)。原因の駒に当たっているスポットライトはここでは
## 解除せず、照らしたまま結果パネルの表示へ移る。
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
	label.position = _screen.game_board.get_global_rect().get_center() - min_size * 0.5
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
## ダメージを伴わないためblowを参照しない。loser_labelは敗者の呼び方(視点が固定される
## 対局は「自分」「相手」、ローカル対戦は「先手」「後手」)で、呼び出し側が視点に合わせて決める。
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
