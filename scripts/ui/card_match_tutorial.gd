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
const NEXT_SIZE := Vector2(88, 36)
const BUTTON_MARGIN := 10.0

## 段階の定義。`event` は完了とみなすシグナルの種類。
const STEPS: Array[Dictionary] = [
	{
		"event": "mulligan",
		"text": "こんにちは、ぼくすなえる! まずは初手だよ。いらないカードは押すと引き直せるんだ",
		"done": "そのまま始めてもぜんぜんいいんだよ。ここからが対局だよ!",
	},
	{
		"event": "play",
		"text": "手札の砂時計を、空いている台座へ出してみてね",
		"done": "出したばかりの子はまだ動けないんだ。攻撃も反転も次のターンからだよ",
	},
	{
		"event": "end_turn",
		"text": "つぎは画面右の「ターン終了」を押してみてね",
		"done": "砂が1粒落ちたよ! 体力が1減って、攻撃力が1増えるんだ",
	},
	{
		"event": "attack",
		"text": "攻撃力がついたら、その子で相手を殴ってみてね",
		"done": "攻撃はおたがいさま。ぼくたちも相手の攻撃力ぶん削れちゃうんだ",
	},
	{
		"event": "flip",
		"text": "さいごは反転だよ。自分の子を選んで「反転」を押してみてね",
		"done": "体力と攻撃力が入れ替わったよ。攻撃力が体力を追い越したら返し時なんだ",
	},
]
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


func _ready() -> void:
	visible = false
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	size = SCREEN_SIZE
	_build()


## 対局が始まったところから見張り始める。
func watch(state: MatchState, my_side: int) -> void:
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
	if _portrait != null:
		_portrait.cheer()
	if event == "mulligan":
		_place_band(false)
	_refresh()


func _on_next_pressed() -> void:
	if _outro:
		close()
		return
	if not _showing_done:
		return
	_showing_done = false
	_index += 1
	if _index >= STEPS.size():
		_outro = true
	_refresh()


func _refresh() -> void:
	if _outro:
		_label.text = OUTRO_TEXT
		_next_button.text = "とじる"
		_next_button.visible = true
		return
	_next_button.text = "つぎへ"
	_next_button.visible = _showing_done
	_label.text = STEPS[_index]["done" if _showing_done else "text"]


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
	margin.add_theme_constant_override("margin_right", int(NEXT_SIZE.x + BUTTON_MARGIN))
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

	# すなえるは帯の左端へ小さく置くだけにする(GameDesign.md 18章)。
	# 盤面を新たに隠さないよう、帯の中に収める。
	_portrait = SunaeruPortrait.new()
	_portrait.size = PORTRAIT_SIZE
	_band.add_child(_portrait)
