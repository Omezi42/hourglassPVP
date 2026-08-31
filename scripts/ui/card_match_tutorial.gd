class_name CardMatchTutorial
extends Control
## 誘導対局の指示(GameDesign.md 18章)。実際の対局画面でそのまま手を指させ、
## 段階ごとに1つだけ操作を求める。
##
## **話すのはマスコットのすなえる**(GameDesign.md 18章)。指示だけが帯に出ていると
## 話者がおらず、画面が一方的に命令しているように読めるため。指示の文は短く保つこと。
## このゲームは覚えることが多く、長い語りはルールの読解を妨げる。
##
## **手は塞がない**(`mouse_filter` は IGNORE)。指示に従わない操作を禁止すると
## 「言われた通りにしか動かせない」体験になり、自分で考える余地が消える。
## ここは「次に何をすれば良いか分からない」状態を埋めるためだけに置く。
##
## **段階を終えたときの説明は時間で消さない。**「つぎへ」を押すまで残す。読む速さは人により、
## 1秒足らずでは読み切れない(GameDesign.md 18章)。同じ理由で**途中で閉じる導線も置かない**。
## 一度閉じると、以降の段階の案内が二度と読めなくなるため。

signal finished

const SCREEN_SIZE := Vector2(1280, 720)
## 置き場所は**卓の上端へ横長に渡した帯**とする。相手のHP・マナ・山札を覆う位置
## (画面の最上段)は避ける。攻撃や反転の判断に要る情報が誘導対局の間ずっと読めなくなるため。
## 手札の右隣へ置いていた時期もあるが、手札を盤面の真下で中央へ揃えた際に重なった。
## すなえるの立ち絵を左端へ足したぶん、帯を左へ広げてある(文の幅は変えていない)。
const BAND_RECT := Rect2(206, 74, 824, 64)
## **マリガンの間だけ帯を下げる**。マリガン画面は見出し・手札・確定ボタンで y=66〜432 を
## 使うため、通常の位置(y=74)へ出すと見出しへ重なる。確定ボタンの下が唯一の空きになる。
const MULLIGAN_BAND_TOP := 470.0
const PORTRAIT_SIZE := Vector2(54, 64)
## 進み具合の点。**終わりが見えないと、いつまで案内が続くのか分からない**
## (GameDesign.md 18章)。「つぎへ」の左へ小さく並べる。
const DOTS_WIDTH := 56.0
const DOT_RADIUS := 4.0
const DOT_STEP := 11.0
## いま触るものを囲む枠(GameDesign.md 18章)。手は塞がず、視線だけを誘導する。
const FOCUS_COLOR := Color(0.55, 0.9, 1.0)
const FOCUS_PERIOD := 1.2
const FOCUS_GROW := 5.0
const FOCUS_WIDTH := 2.5
const FOCUS_RINGS := [0, 1]
const NEXT_SIZE := Vector2(88, 36)
const BUTTON_MARGIN := 10.0

## 段階の定義。`event` は完了とみなすシグナルの種類。
const STEPS: Array[Dictionary] = [
	{
		"event": "mulligan",
		"focus": "",
		"text": "こんにちは、ぼくすなえる! まずは初手だよ。いらないカードは押すと引き直せるんだ",
		"done": "そのまま始めてもぜんぜんいいんだよ。ここからが対局だよ!",
	},
	{
		"event": "play",
		"focus": "hand",
		"text": "手札の砂時計を、空いている台座へ出してみてね",
		"done": "出したばかりの子はまだ動けないんだ。攻撃も反転も次のターンからだよ",
	},
	{
		"event": "end_turn",
		"focus": "end_turn",
		"text": "つぎは画面右の「ターン終了」を押してみてね",
		"done": "ターンを終えるたびに、砂が1粒ずつ落ちていくんだ",
	},
	{
		"event": "attack",
		"focus": "attack",
		"text": "攻撃力がついたら、その子で相手を殴ってみてね",
		"done": "攻撃はおたがいさま。殴った側も相手の攻撃力ぶん削れちゃうんだ",
	},
	{
		"event": "flip",
		"focus": "flip",
		"text": "さいごは反転だよ。自分の子を選んで「反転」を押してみてね",
		"done": "攻撃力が体力を追い越したら返し時だよ。長生きするほど強くなるんだ",
	},
]
## 出せる札が1枚も無いときに代わりに出す案内(GameDesign.md 18章)。1ターン目はマナが
## 1しか無いため、手札によっては「出してみてね」と言われても1枚も出せない。
const STUCK_TEXT := "いまはマナが足りないみたい。「ターン終了」を押すと、つぎのターンはマナが1つ増えるよ"

## 締めのひと言(GameDesign.md 18章)。何の区切りも無く案内が消えると、
## 続きを投げ出されたように読める。**これ以上は喋らせない**。
const OUTRO_TEXT := "あとは自由に遊んでみてね。相手のHPを0にしたら勝ちだよ。駒を押せば効果も読めるよ!"

var _state: MatchState
var _my_side := MatchState.Side.A
var _index := 0
var _showing_done := false
var _outro := false
var _label: Label
var _band: Control
var _next_button: Button
var _portrait: SunaeruPortrait
var _screen: CardMatchScreen
var _dots: Control
var _elapsed := 0.0
## 段階を終えたときの一言へ差し込む、いま自分の盤面で起きた実際の数値
## (GameDesign.md 18章)。一般論より目の前の駒と結びついた説明のほうが速く入る。
var _fact := ""
## 攻撃の最中かどうか。`attack_performed` はダメージの解決より前に出るため、
## 実際に削れた量は後から届く `unit_damaged` / `hp_changed` で数える。
var _counting_attack := false
var _dealt := 0
var _taken := 0
var _face_damage := 0
var _foe_hp := 0
## 求めた操作が今できない(出せる札が1枚も無い)状態か。
var _stuck := false


func _ready() -> void:
	visible = false
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	size = SCREEN_SIZE
	_build()


## 対局が始まったところから見張り始める。
func watch(screen: CardMatchScreen, state: MatchState, my_side: int) -> void:
	_screen = screen
	_state = state
	_my_side = my_side
	_index = 0
	_showing_done = false
	_outro = false
	state.unit_played.connect(func(side: int, _slot: int) -> void: _advance_if("play", side))
	state.attack_performed.connect(
		func(side: int, _slot: int, _target: int) -> void: _advance_if("attack", side)
	)
	state.unit_flipped.connect(func(side: int, _slot: int) -> void: _advance_if("flip", side))
	# ターンを終えたことは「相手の手番が始まった」ことで分かる。
	state.turn_started.connect(
		func(side: int) -> void: _advance_if("end_turn", MatchState.other_side(side))
	)
	state.mulligan_finished.connect(func() -> void: _advance_if("mulligan", _my_side))
	state.unit_damaged.connect(_on_unit_damaged)
	state.hp_changed.connect(_on_hp_changed)
	# マリガンの間は暗幕より手前へ、確定ボタンの下へ下げて出す(GameDesign.md 18章)。
	_place_band(state.mulligan_pending)
	visible = true
	_refresh()


func close() -> void:
	visible = false
	finished.emit()


## 帯の位置をマリガン中かどうかで切り替える。
func _place_band(during_mulligan: bool) -> void:
	_band.position = Vector2(
		BAND_RECT.position.x, MULLIGAN_BAND_TOP if during_mulligan else BAND_RECT.position.y
	)


func _advance_if(event: String, side: int) -> void:
	if not visible or side != _my_side or _index >= STEPS.size():
		return
	if _showing_done or STEPS[_index]["event"] != event:
		return
	_showing_done = true
	_fact = _fact_for(event)
	if event == "attack":
		# ダメージはこの後に届く。数え終えたところで文を組み直す。
		_begin_attack_count()
	if _portrait != null:
		_portrait.cheer()
	if event == "mulligan":
		_place_band(false)
	_refresh()


## 段階を終えた瞬間の盤面から、一言へ差し込む事実を1つ取り出す。
## 取り出せない場合は空文字を返し、従来どおりの一般的な説明だけを出す。
func _fact_for(event: String) -> String:
	match event:
		"play":
			var played := _newest_unit()
			return "" if played == null else "「%s」を出したよ。" % played.data.display_name
		"end_turn":
			var ticked := _newest_unit()
			if ticked == null:
				return ""
			return (
				"%sの体力が%d→%d、攻撃力が%d→%dになったよ。"
				% [
					ticked.data.display_name,
					ticked.health + 1,
					ticked.health,
					ticked.attack - 1,
					ticked.attack,
				]
			)
		"flip":
			var flipped := _newest_unit()
			if flipped == null:
				return ""
			return (
				"体力%d・攻撃力%dが入れ替わって、体力%d・攻撃力%dになったよ。"
				% [flipped.attack, flipped.health, flipped.health, flipped.attack]
			)
	return ""


## 自分の場に残っている駒を1体返す。誘導対局は段階1で1体出すところから始まるため、
## 枠の順に最初に見つかったものでよい。
func _newest_unit() -> CardInstance:
	for slot in MatchState.BOARD_SIZE:
		var unit: CardInstance = _state.board[_my_side][slot]
		if unit != null:
			return unit
	return null


func _begin_attack_count() -> void:
	_counting_attack = true
	_dealt = 0
	_taken = 0
	_face_damage = 0
	_foe_hp = int(_state.hp[MatchState.other_side(_my_side)])


func _on_unit_damaged(side: int, _slot: int, amount: int) -> void:
	if not _counting_attack:
		return
	if side == _my_side:
		_taken += amount
	else:
		_dealt += amount
	_update_attack_fact()


func _on_hp_changed(side: int, new_hp: int) -> void:
	if not _counting_attack or side == _my_side:
		return
	_face_damage += maxi(_foe_hp - new_hp, 0)
	_foe_hp = new_hp
	_update_attack_fact()


## 相打ちの結果を書き直す。**攻撃はおたがいさま**であることを、自分が受けた量を
## 数字で見せて伝える(GameDesign.md 18章)。
func _update_attack_fact() -> void:
	if _face_damage > 0 and _dealt == 0:
		_fact = "相手のHPへ%dダメージ! " % _face_damage
	elif _dealt > 0 or _taken > 0:
		_fact = "相手に%dダメージ、こっちも%d削れたよ。" % [_dealt, _taken]
	_refresh()


func _on_next_pressed() -> void:
	if _outro:
		close()
		return
	if not _showing_done:
		return
	_showing_done = false
	_counting_attack = false
	_fact = ""
	_index += 1
	if _index >= STEPS.size():
		_outro = true
	_refresh()


func _refresh() -> void:
	if _outro:
		_label.text = OUTRO_TEXT
		_next_button.text = "とじる"
		_next_button.visible = true
		_dots.queue_redraw()
		return
	_next_button.text = "つぎへ"
	_next_button.visible = _showing_done
	var line := str(STEPS[_index]["done" if _showing_done else "text"])
	if _stuck and not _showing_done:
		line = STUCK_TEXT
	_label.text = (_fact + line) if _showing_done and not _fact.is_empty() else line
	_dots.queue_redraw()


func _build() -> void:
	_band = Control.new()
	_band.size = BAND_RECT.size
	_band.position = BAND_RECT.position
	_band.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_band)

	var panel := PanelContainer.new()
	panel.custom_minimum_size = BAND_RECT.size
	panel.size = BAND_RECT.size
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var style: StyleBox = load("res://resources/theme/content_panel.tres")
	if style != null:
		panel.add_theme_stylebox_override("panel", style)
	_band.add_child(panel)

	_label = Label.new()
	_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_label.add_theme_font_size_override("font_size", 16)
	_label.add_theme_color_override("font_color", UiPalette.TEXT_OFFWHITE)
	_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var margin := MarginContainer.new()
	# 文が「つぎへ」の下へ潜らないよう、ボタンぶんの余白を右へ空ける。
	# **「つぎへ」が出ていない間も同じだけ空ける**。出入りのたびに文が折り返し直すため。
	# 「つぎへ」と進み具合の点のぶんを右へ空ける。
	margin.add_theme_constant_override(
		"margin_right", int(NEXT_SIZE.x + BUTTON_MARGIN + DOTS_WIDTH)
	)
	# 左はすなえるの立ち絵ぶん。文と絵を重ねない。
	margin.add_theme_constant_override("margin_left", int(PORTRAIT_SIZE.x))
	panel.add_child(margin)
	margin.add_child(_label)

	# **「閉じる」は置かない**(GameDesign.md 18章)。一度閉じると以降の案内が
	# 読めなくなるため。帯は最後の「とじる」まで残る。
	_next_button = CodedButton.make("つぎへ", NEXT_SIZE)
	_next_button.visible = false
	_next_button.position = Vector2(
		BAND_RECT.size.x - NEXT_SIZE.x - BUTTON_MARGIN, (BAND_RECT.size.y - NEXT_SIZE.y) * 0.5
	)
	_next_button.pressed.connect(_on_next_pressed)
	_band.add_child(_next_button)

	# 進み具合の点は「つぎへ」の左へ置く。段の数だけ並べ、済んだものを塗る。
	_dots = Control.new()
	_dots.position = Vector2(BAND_RECT.size.x - NEXT_SIZE.x - BUTTON_MARGIN - DOTS_WIDTH, 0.0)
	_dots.size = Vector2(DOTS_WIDTH, BAND_RECT.size.y)
	_dots.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_dots.draw.connect(_draw_dots)
	_band.add_child(_dots)

	# すなえるは帯の左端へ小さく置くだけにする(GameDesign.md 18章)。
	# 盤面を新たに隠さないよう、帯の中に収める。
	_portrait = SunaeruPortrait.new()
	_portrait.size = PORTRAIT_SIZE
	_band.add_child(_portrait)


func _process(delta: float) -> void:
	if not visible:
		return
	_elapsed += delta
	var stuck := _is_stuck()
	if stuck != _stuck:
		_stuck = stuck
		_refresh()
	queue_redraw()


## 「出す」を求めているのに1枚も出せない状態か。マナは手番の始めに増えるため、
## 毎フレーム見て切り替わったときだけ文を組み直す。
func _is_stuck() -> bool:
	if _screen == null or _state == null or _showing_done or _outro:
		return false
	if _index >= STEPS.size() or str(STEPS[_index].get("focus", "")) != "hand":
		return false
	if _state.current_turn != _my_side or _state.is_match_over():
		return false
	return _screen.playable_hand_rects().is_empty()


## 何段階のうちどこにいるかを点で示す(GameDesign.md 18章)。
func _draw_dots() -> void:
	var width: float = DOT_STEP * (STEPS.size() - 1)
	var left: float = (DOTS_WIDTH - width) * 0.5
	var y: float = _dots.size.y * 0.5
	for i in STEPS.size():
		var at := Vector2(left + DOT_STEP * i, y)
		var done: bool = _outro or i < _index or (i == _index and _showing_done)
		if done:
			_dots.draw_circle(at, DOT_RADIUS, UiPalette.GLOW_AMBER)
		else:
			_dots.draw_circle(at, DOT_RADIUS, Color(UiPalette.GLOW_AMBER, 0.22))
			_dots.draw_arc(at, DOT_RADIUS, 0.0, TAU, 16, Color(UiPalette.GLOW_AMBER, 0.7), 1.2)


## いま触るものを囲む(GameDesign.md 18章)。**手は塞がず、視線だけを誘導する**ため、
## `mouse_filter` は IGNORE のまま枠だけを描く。
func _draw() -> void:
	var rects := _focus_rects()
	if rects.is_empty():
		return
	var pulse: float = 0.5 + 0.5 * sin(_elapsed * TAU / FOCUS_PERIOD)
	for rect: Rect2 in rects:
		for ring in FOCUS_RINGS:
			var spread: float = 2.0 + FOCUS_GROW * (float(ring) + pulse)
			var alpha: float = 0.8 / (float(ring) + 1.0)
			draw_rect(rect.grow(spread), Color(FOCUS_COLOR, alpha), false, FOCUS_WIDTH)


## 光らせる場所。**説明を読んでいる間(「つぎへ」が出ている間)は光らせない**。
## 次に何をするかはまだ示していないため。
func _focus_rects() -> Array[Rect2]:
	var found: Array[Rect2] = []
	if _screen == null or _state == null or _showing_done or _outro:
		return found
	if _index >= STEPS.size() or _state.current_turn != _my_side or _state.is_match_over():
		return found
	match str(STEPS[_index].get("focus", "")):
		"hand":
			# 出せる札が無いときは、代わりにターン終了を示す(GameDesign.md 18章)。
			if _stuck:
				return [_screen.end_turn_button_rect()] as Array[Rect2]
			# **いま出せる手札だけを囲む。**空き枠まで一緒に光らせると盤面の大半が
			# 枠だらけになり、どれを押せばよいのか却って分からない(実際に描いて確認した)。
			# 押した後に空き枠が光るのは通常の操作のとおり(GameDesign.md 9章)。
			found.append_array(_screen.playable_hand_rects())
		"end_turn":
			found.append(_screen.end_turn_button_rect())
		"attack":
			for slot in MatchState.BOARD_SIZE:
				var unit: CardInstance = _state.board[_my_side][slot]
				if unit != null and unit.can_attack():
					found.append(_slot_rect(slot))
		"flip":
			for slot in MatchState.BOARD_SIZE:
				if _state.can_flip(_my_side, slot):
					found.append(_slot_rect(slot))
	return found


func _slot_rect(slot: int) -> Rect2:
	var view := _screen.view_at(_my_side, slot)
	return Rect2(view.position, view.size)
