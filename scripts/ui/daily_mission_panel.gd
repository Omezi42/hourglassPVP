class_name DailyMissionPanel
extends Control
## デイリーミッションの確認と受取(GameDesign.md 23章)。
##
## 画面ではなくモーダルにしている。ホームのタブを1つ増やすほどの中身が無く、
## 3行を読んで押すだけの用件のため(`SettingsPanel` と同じ「暗幕+中央パネル」の作り)。

signal closed
## 受け取った瞬間、押したボタンの位置と獲得額を運ぶ(GameDesign.md 9章)。
## ヘッダーの `CurrencyChip` へ向けて飛ばす演出は `HomeScreen` 側が持つ
## (このパネルは自分の外にあるチップの位置を知らないため)。
signal reward_claimed(from_rect: Rect2, amount: int)

const SCREEN_SIZE := Vector2(1280, 720)
const PANEL_SIZE := Vector2(600, 420)
const PANEL_STYLE := "res://resources/theme/content_panel.tres"
const CLAIM_SIZE := Vector2(120, 44)
const CLOSE_SIZE := Vector2(180, 48)
const NOTE_INSET := 60.0
## 縦(GameDesign.md 9章「縦画面」)。`PortraitModal` の論理幅で組み、中身ごと拡大する。
const PORTRAIT_PANEL_SIZE := Vector2(PortraitModal.WIDTH, 470)
const PORTRAIT_CLAIM_SIZE := Vector2(120, 52)
const PORTRAIT_CLOSE_SIZE := Vector2(180, 56)
const SMALL_FONT := 15
## 縦(パネルごと1.4倍)で本文の目安(24px)にする進み具合・注記の大きさ。
const PORTRAIT_SMALL_FONT := 17

var _rows: VBoxContainer
var _note: Label
var _dim: ColorRect
var _panel: PanelContainer
var _close: Button


func _ready() -> void:
	visible = false
	mouse_filter = Control.MOUSE_FILTER_STOP
	size = SCREEN_SIZE
	_build()
	PortraitModal.watch(self, _layout)


func open() -> void:
	_layout()
	_refresh()
	visible = true


func _layout() -> void:
	var portrait := ScreenOrientation.is_portrait()
	var panel_size := PORTRAIT_PANEL_SIZE if portrait else PANEL_SIZE
	size = PortraitModal.screen_size()
	_dim.size = size
	# 中身の最小幅を先に変える(パネルは中身より狭くならないため)。
	_note.custom_minimum_size.x = panel_size.x - NOTE_INSET
	_note.add_theme_font_size_override("font_size", _small_font())
	_close.custom_minimum_size = PORTRAIT_CLOSE_SIZE if portrait else CLOSE_SIZE
	_panel.size = panel_size
	_panel.position = (size - panel_size) * 0.5
	PortraitModal.fit(_panel)


func _build() -> void:
	_dim = ColorRect.new()
	_dim.color = Color(0, 0, 0, 0.7)
	_dim.size = SCREEN_SIZE
	_dim.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(_dim)

	_panel = PanelContainer.new()
	_panel.size = PANEL_SIZE
	_panel.position = (SCREEN_SIZE - PANEL_SIZE) * 0.5
	var style: StyleBox = load(PANEL_STYLE)
	if style != null:
		_panel.add_theme_stylebox_override("panel", style)
	add_child(_panel)

	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 12)
	_panel.add_child(box)

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
	_note.custom_minimum_size.x = PANEL_SIZE.x - NOTE_INSET
	_note.add_theme_font_size_override("font_size", SMALL_FONT)
	_note.add_theme_color_override("font_color", UiPalette.TEXT_MUTED)
	box.add_child(_note)

	_close = CodedButton.make("閉じる", CLOSE_SIZE)
	_close.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_close.pressed.connect(func() -> void: _on_close())
	box.add_child(_close)


func _small_font() -> int:
	return PORTRAIT_SMALL_FONT if ScreenOrientation.is_portrait() else SMALL_FONT


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
	progress.add_theme_font_size_override("font_size", _small_font())
	progress.add_theme_color_override("font_color", UiPalette.TEXT_MUTED)
	column.add_child(progress)

	if bool(row["claimed"]):
		var done := Label.new()
		done.text = "受取済み"
		done.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		line.add_child(done)
		return line

	var button := CodedButton.make(
		"受取", PORTRAIT_CLAIM_SIZE if ScreenOrientation.is_portrait() else CLAIM_SIZE
	)
	button.disabled = not bool(row["done"])
	button.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	button.pressed.connect(
		func() -> void: _on_claim(uid, String(row["id"]), button, int(row["reward"]))
	)
	line.add_child(button)
	return line


## **通信できないときは受け取らせない**(GameDesign.md 21章のショップと同じ理由)。
## 残高はアカウントにあり、手元で増やしても次に通信した時点で消える。
func _on_claim(uid: String, id: String, button: Control, amount: int) -> void:
	if DailyMissionService.claim(uid, id):
		reward_claimed.emit(button.get_global_rect(), amount)
		_refresh()
		return
	_note.text = "いま受け取れませんでした。接続を確かめてください"


func _uid() -> String:
	if NetSession.client == null or NetSession.client.auth == null:
		return ""
	return NetSession.client.auth.uid
