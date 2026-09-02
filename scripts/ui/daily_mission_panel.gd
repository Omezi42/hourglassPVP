class_name DailyMissionPanel
extends Control
## デイリーミッションの確認と受取(GameDesign.md 23章)。
##
## 画面ではなくモーダルにしている。ホームのタブを1つ増やすほどの中身が無く、
## 3行を読んで押すだけの用件のため(`SettingsPanel` と同じ「暗幕+中央パネル」の作り)。

signal closed

const SCREEN_SIZE := Vector2(1280, 720)
const PANEL_SIZE := Vector2(600, 420)
const PANEL_STYLE := "res://resources/theme/content_panel.tres"
const CLAIM_SIZE := Vector2(120, 44)

var _rows: VBoxContainer
var _note: Label


func _ready() -> void:
	visible = false
	mouse_filter = Control.MOUSE_FILTER_STOP
	size = SCREEN_SIZE
	_build()


func open() -> void:
	_refresh()
	visible = true


func _build() -> void:
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.7)
	dim.size = SCREEN_SIZE
	dim.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(dim)

	var panel := PanelContainer.new()
	panel.size = PANEL_SIZE
	panel.position = (SCREEN_SIZE - PANEL_SIZE) * 0.5
	var style: StyleBox = load(PANEL_STYLE)
	if style != null:
		panel.add_theme_stylebox_override("panel", style)
	add_child(panel)

	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 12)
	panel.add_child(box)

	var title := Label.new()
	title.text = "デイリーミッション"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 28)
	box.add_child(title)

	_rows = VBoxContainer.new()
	_rows.add_theme_constant_override("separation", 10)
	box.add_child(_rows)

	_note = Label.new()
	_note.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_note.custom_minimum_size.x = PANEL_SIZE.x - 60.0
	_note.add_theme_font_size_override("font_size", 15)
	_note.add_theme_color_override("font_color", UiPalette.TEXT_MUTED)
	box.add_child(_note)

	var close := CodedButton.make("閉じる", Vector2(180, 48))
	close.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	close.pressed.connect(func() -> void: _on_close())
	box.add_child(close)


func _on_close() -> void:
	visible = false
	closed.emit()


func _refresh() -> void:
	for child in _rows.get_children():
		child.queue_free()
	var uid := _uid()
	for row in DailyMissionService.missions(uid):
		_rows.add_child(_make_row(uid, row))
	_note.text = "課題は毎日0時(日本時間)に入れ替わります。10手に満たない対局は数えません。"


func _make_row(uid: String, row: Dictionary) -> Control:
	var line := HBoxContainer.new()
	line.add_theme_constant_override("separation", 12)

	var column := VBoxContainer.new()
	column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	line.add_child(column)
	var text := Label.new()
	text.text = row["text"]
	text.add_theme_font_size_override("font_size", 19)
	column.add_child(text)
	var progress := Label.new()
	progress.text = "%d / %d   報酬 %d 砂金" % [row["progress"], row["goal"], row["reward"]]
	progress.add_theme_font_size_override("font_size", 15)
	progress.add_theme_color_override("font_color", UiPalette.TEXT_MUTED)
	column.add_child(progress)

	if bool(row["claimed"]):
		var done := Label.new()
		done.text = "受取済み"
		done.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		line.add_child(done)
		return line

	var button := CodedButton.make("受取", CLAIM_SIZE)
	button.disabled = not bool(row["done"])
	button.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	button.pressed.connect(func() -> void: _on_claim(uid, String(row["id"])))
	line.add_child(button)
	return line


## **通信できないときは受け取らせない**(GameDesign.md 21章のショップと同じ理由)。
## 残高はアカウントにあり、手元で増やしても次に通信した時点で消える。
func _on_claim(uid: String, id: String) -> void:
	if DailyMissionService.claim(uid, id):
		_refresh()
		return
	_note.text = "いま受け取れませんでした。接続を確かめてください"


func _uid() -> String:
	if NetSession.client == null or NetSession.client.auth == null:
		return ""
	return NetSession.client.auth.uid
