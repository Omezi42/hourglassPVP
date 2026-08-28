class_name CardMatchTutorial
extends Control
## 誘導対局の指示(GameDesign.md 18章)。実際の対局画面でそのまま手を指させ、
## 段階ごとに1つだけ操作を求める。
##
## **手は塞がない**(`mouse_filter` は IGNORE)。指示に従わない操作を禁止すると
## 「言われた通りにしか動かせない」体験になり、自分で考える余地が消える。
## ここは「次に何をすれば良いか分からない」状態を埋めるためだけに置く。

signal finished

const SCREEN_SIZE := Vector2(1280, 720)
## 置き場所は**手札の右隣の空き**とする。画面上端へ横長に敷くと相手のHP・マナ・山札を
## 覆ってしまい、攻撃や反転の判断に要る情報が誘導対局の間ずっと読めなくなる。
const BAND_RECT := Rect2(868, 520, 404, 96)
const CLOSE_SIZE := Vector2(88, 36)
const CLOSE_MARGIN := 10.0
const DONE_FLASH := 0.9

## 段階の定義。`event` は完了とみなすシグナルの種類。
const STEPS: Array[Dictionary] = [
	{
		"event": "play",
		"text": "手札のカードを空き枠へ出してみましょう(押すか、枠へドラッグします)",
		"done": "出したターンは攻撃も反転もできません",
	},
	{
		"event": "end_turn",
		"text": "右下の「ターン終了」を押しましょう",
		"done": "ターン終了で砂が1粒落ちます(体力-1 / 攻撃力+1)",
	},
	{
		"event": "attack",
		"text": "攻撃力が付いたら、自分の駒を選んで相手を攻撃しましょう",
		"done": "攻撃は相打ちです。自分も相手の攻撃力ぶん削れます",
	},
	{
		"event": "flip",
		"text": "自分の駒を選んで「反転」を押しましょう",
		"done": "体力と攻撃力が入れ替わります。攻撃力が体力を上回ったら返し時です",
	},
]

var _state: MatchState
var _my_side := MatchState.Side.A
var _index := 0
var _flash := 0.0
var _label: Label
var _panel: PanelContainer


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
	visible = true
	_refresh()


func close() -> void:
	visible = false
	finished.emit()


func _advance_if(event: String, side: int) -> void:
	if not visible or side != _my_side or _index >= STEPS.size():
		return
	if STEPS[_index]["event"] != event:
		return
	_label.text = STEPS[_index]["done"]
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
	_label.add_theme_font_size_override("font_size", 17)
	_label.add_theme_color_override("font_color", UiPalette.TEXT_OFFWHITE)
	_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_bottom", int(CLOSE_SIZE.y))
	_panel.add_child(margin)
	margin.add_child(_label)

	# 途中でやめられる(GameDesign.md 18章)。閉じた後は通常のCPU戦として続く。
	var close_button := CodedButton.make("閉じる", CLOSE_SIZE)
	close_button.position = (
		BAND_RECT.position + BAND_RECT.size - CLOSE_SIZE - Vector2(CLOSE_MARGIN, CLOSE_MARGIN)
	)
	close_button.pressed.connect(close)
	add_child(close_button)
