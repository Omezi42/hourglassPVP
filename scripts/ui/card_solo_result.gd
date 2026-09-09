class_name CardSoloResult
extends Control
## ソロモードのステージ結果(GameDesign.md 27章)。
##
## `CardPuzzleResult`と同じ理由で、対局の結果パネル(`CardMatchResult`)を流用しない。
## 出すのは「クリアできたか」と、初回クリアで得た報酬(砂金・カード)だけでよい。

signal retry_pressed
signal quit_pressed

const SCREEN_SIZE := Vector2(1280, 720)
const PANEL_SIZE := Vector2(480, 260)
const BUTTON_SIZE := Vector2(180, 48)

var _title: Label
var _detail: Label
var _panel: PanelContainer


func _ready() -> void:
	visible = false
	mouse_filter = Control.MOUSE_FILTER_STOP
	# **`set_anchors_preset()` は使わない**(Architecture.md 11章)。生成直後はサイズ0で、
	# 暗幕が盤面を覆わずクリックも止められない状態になる。
	size = SCREEN_SIZE
	_build()


## cleared が false なら失敗。reward は初回クリアで得た砂金・カードの行(無ければ空)。
func show_for(cleared: bool, stage: SoloStageData, reward: String = "") -> void:
	_title.text = "クリア!" if cleared else "届かなかった"
	var lines: PackedStringArray = []
	lines.append(stage.display_name)
	lines.append(stage.description)
	if cleared and not reward.is_empty():
		lines.append(reward)
	_detail.text = "\n".join(lines)
	visible = true


func _build() -> void:
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.7)
	dim.size = SCREEN_SIZE
	dim.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(dim)

	_panel = PanelContainer.new()
	_panel.size = PANEL_SIZE
	_panel.position = (SCREEN_SIZE - PANEL_SIZE) * 0.5
	_panel.add_theme_stylebox_override("panel", load("res://resources/theme/content_panel.tres"))
	add_child(_panel)

	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 14)
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	_panel.add_child(box)

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
