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
		bar.face_pressed.connect(screen._on_face_pressed)
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
		view.pressed.connect(
			screen._on_foe_slot_pressed if opponent else screen._on_own_slot_pressed
		)
		view.hovered.connect(screen._on_view_hovered)
		view.mouse_exited.connect(screen._on_view_left)
		if not opponent:
			view.drop_handler = screen._on_slot_drop.bind(i)
		screen.add_child(view)
		views.append(view)
	return views


static func add_button(screen: CardMatchScreen, label: String, button_size: Vector2) -> Button:
	var button := CodedButton.make(label, button_size)
	screen.add_child(button)
	return button


## 盤面へ重ねるもの。**足す順がそのまま重なる順**になる(後の子ほど手前)。
## 光の筋は駒より手前・ログより背面、ログは結果パネルより手前(GameDesign.md 9章)。
## 終局後は結果パネルが盤面全体を塞ぐため、その上からログを開けないと読み返せない。
static func overlays(screen: CardMatchScreen) -> void:
	screen._flip_beam = CardFlipBeam.new()
	screen.add_child(screen._flip_beam)
	screen._detail = CardMatchDetail.new(screen)
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
	screen._result = CardMatchResult.new()
	screen._result.home_pressed.connect(func() -> void: screen.back_pressed.emit())
	screen._result.rematch_pressed.connect(screen._on_rematch_pressed)
	screen._result.log_pressed.connect(func() -> void: screen._log.set_open(true))
	screen.add_child(screen._result)
	screen._log = CardMatchLog.new()
	screen.add_child(screen._log)
	screen._pile = CardPileViewer.new()
	screen.add_child(screen._pile)
	screen._alert = CardMatchAlert.new()
	screen.add_child(screen._alert)
	screen._damage_assist = CardMatchDamageAssist.new(screen)
	screen.add_child(screen._damage_assist)
	screen._history = CardMatchActionHistory.new(screen)
	screen.add_child(screen._history)
	screen._puzzle = CardMatchPuzzle.new(screen)
	screen._puzzle.finished.connect(
		func(_cleared: bool) -> void:
			screen._puzzle.close()
			screen.back_pressed.emit()
	)
