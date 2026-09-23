class_name CardMatchBuild
extends RefCounted
## 対局画面の組み立てのうち、**作って並べるだけで状態を持たない部分**
## (情報帯・盤面の6枠・行動のボタン・盤面へ重ねるモーダル類)。
##
## `CardMatchOnline` / `CardMatchOutcome` と同じく `card_match_screen.gd` が
## 1000行の上限に達したための切り出しで、画面の private メンバを読み書きするのも
## 同じ流儀(Architecture.md 4.0節)。**こちらは対局中に呼ばれないため `_screen` 参照を
## 持たず static で置く**(組み立ては `_build()` から1度きり)。


## 情報帯。**両者を同じ幅にする**。右端に行動の列を通すため、どちらもその手前で止める
## (相手側だけ画面いっぱいに伸ばすと、対面させた2本の帯の右端が揃わない)。
static func make_bar(screen: CardMatchScreen, opponent: bool, top: float) -> PlayerInfoBar:
	var bar := PlayerInfoBar.new()
	bar.is_opponent = opponent
	bar.position = Vector2(CardMatchScreen.MARGIN, top)
	bar.size = Vector2(CardMatchScreen.BAR_WIDTH, PlayerInfoBar.BAR_HEIGHT)
	if opponent:
		bar.face_pressed.connect(screen.touch.on_face_pressed)
		bar.drop_handler = screen.touch.on_face_drop
		bar.mouse_entered.connect(screen._set_hover_target.bind(CardMatchSelection.FACE))
		bar.mouse_exited.connect(screen._set_hover_target.bind(CardMatchSelection.NO_HOVER))
	bar.graveyard_pressed.connect(screen._on_graveyard_pressed.bind(opponent))
	screen.add_child(bar)
	return bar


## 盤面の6枠。卓の幅に対して中央へ寄せる。
static func make_row(screen: CardMatchScreen, top: float, opponent: bool) -> Array[CardView]:
	var views: Array[CardView] = []
	var width := MatchState.BOARD_SIZE * CardView.BOARD_SIZE_PX.x
	width += (MatchState.BOARD_SIZE - 1) * CardMatchScreen.CARD_GAP
	var start := (
		CardMatchScreen.TABLE_RECT.position.x + (CardMatchScreen.TABLE_RECT.size.x - width) * 0.5
	)
	for i in MatchState.BOARD_SIZE:
		var view := CardView.new()
		view.mode = CardView.Mode.BOARD
		view.position = Vector2(
			start + i * (CardView.BOARD_SIZE_PX.x + CardMatchScreen.CARD_GAP), top
		)
		view.size = CardView.BOARD_SIZE_PX
		if opponent:
			# 相手の場だけをわずかに縮小して奥行きを出す(段階2)。中心を軸に縮めるため
			# position/sizeそのものは変えず、pivot_offsetとscaleだけを設定する。
			view.pivot_offset = CardView.BOARD_SIZE_PX * 0.5
			view.scale = Vector2.ONE * CardMatchScreen.FOE_ROW_SCALE
		view.pressed.connect(
			screen.touch.on_foe_slot_pressed if opponent else screen.touch.on_own_slot_pressed
		)
		view.hovered.connect(screen._on_view_hovered)
		view.mouse_exited.connect(screen._on_view_left)
		# 手札は自分の空き枠へ、場の駒は相手の駒へ落とす(GameDesign.md 9章)。
		if opponent:
			view.drop_handler = screen.touch.on_foe_slot_drop.bind(i)
		else:
			view.drop_handler = screen.touch.on_slot_drop.bind(i)
			view.drag_started.connect(screen.touch.on_own_slot_drag_started)
			view.drag_ended.connect(screen.touch.on_own_slot_drag_ended)
		screen.add_child(view)
		views.append(view)
	return views


## groupを省略すると従来どおり凹んだパネル(wide_text)。ターン終了のように
## 「対局中もっとも頻繁に押す主要な操作」は塗りつぶした真鍮(primary_action)を渡す。
static func add_button(
	screen: CardMatchScreen,
	label: String,
	button_size: Vector2,
	group: String = CodedButton.WIDE_GROUP
) -> Button:
	var button := CodedButton.make_in_group(label, button_size, group)
	screen.add_child(button)
	return button


## 行動の列(GameDesign.md 9章「対局画面の再構築」)の丸いボタン。
static func add_round_button(
	screen: CardMatchScreen, label: String, diameter: float, filled: bool
) -> RoundActionButton:
	var button := RoundActionButton.new(label, diameter, filled)
	screen.add_child(button)
	return button


## 行動の列の丸ボタン(GameDesign.md 9章)。縦の並びは `ActionColumnLayout` の3つの群。
## 反転権は `CardMatchFlipRight`、エモートは `CardMatchEmote`、時計は `make_clock_dial()` が置く。
static func action_column(screen: CardMatchScreen) -> void:
	screen._coin_button = _column_button(
		screen, "コイン", ActionColumnLayout.COIN_DIAMETER, ActionColumnLayout.COIN_Y
	)
	screen._coin_button.pressed.connect(screen._on_coin_pressed)
	screen._end_turn_button = _column_button(
		screen, "ターン終了", ActionColumnLayout.TURN_END_DIAMETER, ActionColumnLayout.TURN_END_Y, true
	)
	screen._end_turn_button.pressed.connect(screen._on_end_turn_pressed)
	screen._log_button = _column_button(
		screen, "ログ", ActionColumnLayout.SMALL_DIAMETER, ActionColumnLayout.LOG_Y
	)
	screen._log_button.pressed.connect(func() -> void: screen._log.set_open(true))
	screen._surrender_button = _column_button(
		screen, "投了", ActionColumnLayout.SMALL_DIAMETER, ActionColumnLayout.SURRENDER_Y
	)
	screen._surrender_button.pressed.connect(screen._on_surrender_pressed)
	# リプレイ・観戦の戻る導線。反転権と同じ位置(両者は同時に見えない)。
	screen._back_button = _column_button(
		screen, "戻る", ActionColumnLayout.FLIP_RIGHT_DIAMETER, ActionColumnLayout.FLIP_RIGHT_Y
	)
	screen._back_button.pressed.connect(func() -> void: screen.back_pressed.emit())


static func _column_button(
	screen: CardMatchScreen, label: String, diameter: float, center_y: float, filled := false
) -> RoundActionButton:
	var button := add_round_button(screen, label, diameter, filled)
	button.position = round_button_pos(diameter, center_y)
	return button


## 丸いボタンを行動の列の中心(`ACTION_COLUMN_X + ACTION_COLUMN_CENTER_OFFSET`)へ
## 揃えるための左端x座標。
static func round_button_x(diameter: float) -> float:
	return (
		CardMatchScreen.ACTION_COLUMN_X
		+ CardMatchScreen.ACTION_COLUMN_CENTER_OFFSET
		- diameter * 0.5
	)


## 丸いボタンの中心yから左端y座標を求める(`round_button_x()`と対になる)。
static func round_button_y(diameter: float, center_y: float) -> float:
	return center_y - diameter * 0.5


## `round_button_x()`/`round_button_y()`をまとめて呼ぶ(中心x・中心yの1点から置く)。
static func round_button_pos(diameter: float, center_y: float) -> Vector2:
	return Vector2(round_button_x(diameter), round_button_y(diameter, center_y))


## 行動の列の持ち時間の時計(GameDesign.md 9章)。丸ボタンと同じ列の中心へ置く。
static func make_clock_dial(screen: CardMatchScreen) -> TurnClockDial:
	var dial := TurnClockDial.new()
	dial.position = round_button_pos(TurnClockDial.DIAMETER, ActionColumnLayout.CLOCK_Y)
	screen.add_child(dial)
	return dial


## 盤面へ重ねるもの。**足す順がそのまま重なる順**になる(後の子ほど手前)。
## 光の筋は駒より手前・ログより背面、ログは結果パネルより手前(GameDesign.md 9章)。
## 終局後は結果パネルが盤面全体を塞ぐため、その上からログを開けないと読み返せない。
static func overlays(screen: CardMatchScreen) -> void:
	screen._flip_beam = CardFlipBeam.new()
	screen.add_child(screen._flip_beam)
	# 攻撃ドラッグの矢印も駒より手前(GameDesign.md 9章「対局画面の手触り」)。
	screen._drag_arrow = CardDragArrow.new()
	screen.add_child(screen._drag_arrow)
	screen._detail = CardMatchDetail.new(screen)
	# 直前の手の列は結果パネル・ログの暗幕より背面(開いている間に板へ触れられないように)。
	screen._history = CardMatchActionHistory.new(screen)
	screen.add_child(screen._history)
	# 通信待ちの文言と対象選択の案内は、駒より手前へ出すため独立したノードで描く。
	screen._status = CardMatchStatus.new()
	screen.add_child(screen._status)
	screen._feed = CardMatchTurnFeed.new()
	screen.add_child(screen._feed)
	screen._mulligan = CardMatchMulligan.new()
	screen._mulligan.confirmed.connect(screen._on_mulligan_confirmed)
	screen.add_child(screen._mulligan)
	# **誘導対局の帯はマリガンより後に足す**(GameDesign.md 18章)。マリガンの暗幕の下へ
	# 敷くと、いちばん案内が要る最初の画面ですなえるが読めなくなる。
	screen._tutorial = CardMatchTutorial.new()
	screen.add_child(screen._tutorial)
	screen._tutorial.cpu_resumed.connect(
		func() -> void:
			screen._cpu_timer.start(screen._tutorial.cpu_delay(CardMatchScreen.CPU_THINK_SECONDS))
	)
	screen._result = CardMatchResult.new()
	screen._result.home_pressed.connect(func() -> void: screen.back_pressed.emit())
	screen._result.rematch_pressed.connect(screen._on_rematch_pressed)
	screen._result.log_pressed.connect(func() -> void: screen._log.set_open(true))
	screen.add_child(screen._result)
	screen._log = CardMatchLog.new()
	screen._log.detail = screen._detail
	screen.add_child(screen._log)
	screen._pile = CardPileViewer.new()
	screen.add_child(screen._pile)
	screen._alert = CardMatchAlert.new()
	screen.add_child(screen._alert)
	screen._damage_assist = CardMatchDamageAssist.new(screen)
	screen.add_child(screen._damage_assist)
	screen._puzzle = CardMatchPuzzle.new(screen)
	screen._puzzle.finished.connect(
		func(_cleared: bool) -> void:
			screen._puzzle.close()
			screen.back_pressed.emit()
	)
	screen._solo = CardMatchSolo.new(screen)
	screen._solo.finished.connect(
		func(_cleared: bool) -> void:
			screen._solo.close()
			screen.back_pressed.emit()
	)


## 誘導対局を始める(GameDesign.md 18章)。台本(`TutorialScriptData`、Architecture.md
## 4.1.5節)の山札を切らずに使い、プレイヤーが先手、CPUの手も台本どおりに指す。
static func start_tutorial(screen: CardMatchScreen) -> void:
	var script: TutorialScriptData = load(TutorialScriptData.RESOURCE_PATH)
	screen.start_cpu_match(script.deck_a(), script.deck_b(), -1, true, script)
	# 相手(CPU)の開始HPだけ台本の値へ差し替える(GameDesign.md 18章「相手のHPは4から」)。
	screen.state.hp[MatchState.other_side(screen.my_side)] = script.foe_start_hp
	screen.refresh_bars()
	screen._tutorial.watch(screen, screen.state, screen.my_side)


## `start_cpu_match()` が誘導対局用に一度だけ立てたフラグを対局へ渡し、すぐ戻す
## (GameDesign.md 18章)。`card_match_screen.gd` が1000行の上限に達しているための切り出し。
static func apply_keep_deck_order(screen: CardMatchScreen, state: MatchState) -> void:
	state.keep_deck_order = screen._keep_deck_order
	screen._keep_deck_order = false
