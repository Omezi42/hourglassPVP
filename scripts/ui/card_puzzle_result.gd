class_name CardPuzzleResult
extends Control
## リーサルパズルの結果(GameDesign.md 24章)。
##
## **対局の結果パネル(`CardMatchResult`)を流用しない。**あちらは「勝利/敗北・最終HP・
## 総手数・決め手」を出す作りで、パズルに要るのは「解けたか」と「もう一度」だけになる。
## 文言も勝敗ではなく正解・失敗で書く。

signal retry_pressed
signal quit_pressed

const SCREEN_SIZE := Vector2(1280, 720)
const PANEL_SIZE := Vector2(480, 260)
const BUTTON_SIZE := Vector2(180, 48)

var _title: Label
var _detail: Label
var _remaining := 0


func _ready() -> void:
	visible = false
	mouse_filter = Control.MOUSE_FILTER_STOP
	# **`set_anchors_preset()` は使わない**(Architecture.md 11章)。生成直後はサイズ0で、
	# 暗幕が盤面を覆わずクリックも止められない状態になる。
	size = SCREEN_SIZE
	_build()


## cleared が false なら失敗。reward は初回クリアで得た砂金の行(無ければ空)。
func show_for(cleared: bool, stage: PuzzleStageData, reward: String = "") -> void:
	_title.text = "正解!" if cleared else "とどかなかった"
	var lines: PackedStringArray = []
	lines.append(stage.title)
	lines.append(stage.hint)
	if cleared and not reward.is_empty():
		lines.append(reward)
	elif not cleared:
		lines.append("相手のHPが %d 残っている" % maxi(_remaining, 0))
	_detail.text = "\n".join(lines)
	visible = true


func set_remaining(value: int) -> void:
	_remaining = value


func _build() -> void:
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.7)
	dim.size = SCREEN_SIZE
	dim.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(dim)

	var panel := PanelContainer.new()
	panel.size = PANEL_SIZE
	panel.position = (SCREEN_SIZE - PANEL_SIZE) * 0.5
	panel.add_theme_stylebox_override("panel", load("res://resources/theme/content_panel.tres"))
	add_child(panel)

	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 14)
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	panel.add_child(box)

	_title = Label.new()
	_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_title.add_theme_font_size_override("font_size", 34)
	box.add_child(_title)

	_detail = Label.new()
	_detail.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_detail.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_detail.custom_minimum_size.x = PANEL_SIZE.x - 60.0
	_detail.add_theme_font_size_override("font_size", 17)
	box.add_child(_detail)

	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 16)
	box.add_child(row)
	row.add_child(_button("もう一度", retry_pressed))
	row.add_child(_button("一覧へ", quit_pressed))


func _button(label: String, target: Signal) -> Button:
	var button := CodedButton.make(label, BUTTON_SIZE)
	button.pressed.connect(func() -> void: target.emit())
	return button
