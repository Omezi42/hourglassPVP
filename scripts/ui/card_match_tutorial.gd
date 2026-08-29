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

signal finished

const SCREEN_SIZE := Vector2(1280, 720)
## 置き場所は**卓の上端へ横長に渡した帯**とする。相手のHP・マナ・山札を覆う位置
## (画面の最上段)は避ける。攻撃や反転の判断に要る情報が誘導対局の間ずっと読めなくなるため。
## 手札の右隣へ置いていた時期もあるが、手札を盤面の真下で中央へ揃えた際に重なった。
## すなえるの立ち絵を左端へ足したぶん、帯を左へ広げてある(文の幅は変えていない)。
const BAND_RECT := Rect2(206, 74, 824, 64)
const PORTRAIT_SIZE := Vector2(54, 64)
const CLOSE_SIZE := Vector2(88, 36)
const CLOSE_MARGIN := 10.0
const DONE_FLASH := 0.9

## 段階の定義。`event` は完了とみなすシグナルの種類。
const STEPS: Array[Dictionary] = [
	{
		"event": "play",
		"text": "こんにちは、ぼくすなえる! まずは手札の砂時計を空き枠へ出してみてね",
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

var _state: MatchState
var _my_side := MatchState.Side.A
var _index := 0
var _flash := 0.0
var _label: Label
var _panel: PanelContainer
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
	_flash = 0.0
	state.unit_played.connect(func(side: int, _slot: int) -> void: _advance_if("play", side))
	state.attack_performed.connect(
		func(side: int, _slot: int, _target: int) -> void: _advance_if("attack", side)
	)
	state.unit_flipped.connect(func(side: int, _slot: int) -> void: _advance_if("flip", side))
	# ターンを終えたことは「相手の手番が始まった」ことで分かる。
	state.turn_started.connect(
		func(side: int) -> void: _advance_if("end_turn", MatchState.other_side(side))
	)
	# マリガンの暗幕の下では読めないため、対局が始まってから出す。
	visible = not state.mulligan_pending
	if not visible:
		state.turn_started.connect(_show_after_mulligan)
	_refresh()


func _show_after_mulligan(_side: int) -> void:
	if _state != null and _state.turn_started.is_connected(_show_after_mulligan):
		_state.turn_started.disconnect(_show_after_mulligan)
	if _index < STEPS.size():
		visible = true


func close() -> void:
	if _state != null and _state.turn_started.is_connected(_show_after_mulligan):
		_state.turn_started.disconnect(_show_after_mulligan)
	visible = false
	finished.emit()


func _advance_if(event: String, side: int) -> void:
	if not visible or side != _my_side or _index >= STEPS.size():
		return
	if STEPS[_index]["event"] != event:
		return
	_label.text = STEPS[_index]["done"]
	if _portrait != null:
		_portrait.cheer()
	_flash = DONE_FLASH
	_index += 1
	set_process(true)


func _process(delta: float) -> void:
	if _flash <= 0.0:
		return
	_flash -= delta
	if _flash > 0.0:
		return
	set_process(false)
	if _index >= STEPS.size():
		close()
		return
	_refresh()


func _refresh() -> void:
	if _index < STEPS.size():
		_label.text = STEPS[_index]["text"]


func _build() -> void:
	_panel = PanelContainer.new()
	_panel.custom_minimum_size = BAND_RECT.size
	_panel.size = BAND_RECT.size
	_panel.position = BAND_RECT.position
	_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var style: StyleBox = load("res://resources/theme/content_panel.tres")
	if style != null:
		_panel.add_theme_stylebox_override("panel", style)
	add_child(_panel)

	_label = Label.new()
	_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_label.add_theme_font_size_override("font_size", 16)
	_label.add_theme_color_override("font_color", UiPalette.TEXT_OFFWHITE)
	_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var margin := MarginContainer.new()
	# 文が「閉じる」の下へ潜らないよう、ボタンぶんの余白を右へ空ける。
	margin.add_theme_constant_override("margin_right", int(CLOSE_SIZE.x + CLOSE_MARGIN))
	# 左はすなえるの立ち絵ぶん。文と絵を重ねない。
	margin.add_theme_constant_override("margin_left", int(PORTRAIT_SIZE.x))
	_panel.add_child(margin)
	margin.add_child(_label)

	# 途中でやめられる(GameDesign.md 18章)。閉じた後は通常のCPU戦として続く。
	var close_button := CodedButton.make("閉じる", CLOSE_SIZE)
	close_button.position = Vector2(
		BAND_RECT.position.x + BAND_RECT.size.x - CLOSE_SIZE.x - CLOSE_MARGIN,
		BAND_RECT.position.y + (BAND_RECT.size.y - CLOSE_SIZE.y) * 0.5
	)
	close_button.pressed.connect(close)
	add_child(close_button)

	# すなえるは帯の左端へ小さく置くだけにする(GameDesign.md 18章)。
	# 盤面を新たに隠さないよう、帯の中に収める。
	_portrait = SunaeruPortrait.new()
	_portrait.size = PORTRAIT_SIZE
	_portrait.position = BAND_RECT.position
	add_child(_portrait)
