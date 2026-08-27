class_name CardMatchResult
extends Control
## 対局終了時に盤面へ重ねる結果パネル(GameDesign.md 9章)。
## 暗幕でクリックを受け止め、終局後に盤面が操作されるのを防ぐ。

signal home_pressed
signal log_pressed

const PANEL_SIZE := Vector2(520, 320)

var _title: Label
var _detail: Label


func _ready() -> void:
	visible = false
	mouse_filter = Control.MOUSE_FILTER_STOP
	set_anchors_preset(Control.PRESET_FULL_RECT)
	_build()


## 勝敗を表示する。my_side が負なら「先手/後手の勝利」と第三者視点で書く。
func show_for(state: MatchState, my_side: int, moves: int) -> void:
	var winner: int = state.winner
	_title.text = _title_text(winner, my_side)
	var own_hp: int = state.hp[my_side if my_side >= 0 else MatchState.Side.A]
	var foe_side: int = MatchState.other_side(my_side if my_side >= 0 else MatchState.Side.A)
	var lines: PackedStringArray = []
	lines.append("自分 %d / 相手 %d" % [own_hp, state.hp[foe_side]])
	lines.append("%d手で決着" % moves)
	if winner >= 0:
		lines.append("決め手: %s" % CardMatchLog.reason_text(state, winner))
	_detail.text = "\n".join(lines)
	visible = true


func _title_text(winner: int, my_side: int) -> String:
	if winner < 0:
		return "引き分け"
	if my_side < 0:
		return "%sの勝利!" % ("先手" if winner == MatchState.Side.A else "後手")
	return "勝利!" if winner == my_side else "敗北..."


func _build() -> void:
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.7)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(dim)

	var panel := PanelContainer.new()
	panel.custom_minimum_size = PANEL_SIZE
	panel.size = PANEL_SIZE
	panel.position = (Vector2(1280, 720) - PANEL_SIZE) * 0.5
	var style: StyleBox = load("res://resources/theme/content_panel.tres")
	if style != null:
		panel.add_theme_stylebox_override("panel", style)
	add_child(panel)

	var column := VBoxContainer.new()
	column.alignment = BoxContainer.ALIGNMENT_CENTER
	column.add_theme_constant_override("separation", 20)
	panel.add_child(column)

	_title = Label.new()
	_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_title.add_theme_font_size_override("font_size", 40)
	column.add_child(_title)

	_detail = Label.new()
	_detail.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	column.add_child(_detail)

	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 20)
	column.add_child(row)
	row.add_child(_make_button("ログ", log_pressed))
	row.add_child(_make_button("ホームへ", home_pressed))


func _make_button(label: String, target: Signal) -> Button:
	var button := Button.new()
	button.text = label
	button.custom_minimum_size = Vector2(180, 56)
	button.pressed.connect(func() -> void: target.emit())
	return button
