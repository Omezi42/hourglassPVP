class_name WelcomeDaysPanel
extends Control
## はじめの7日の受取(GameDesign.md 23章)。ホームへ重ねる「暗幕+中央パネル」のモーダル
## (`DailyMissionPanel` と同じ作り)。`HomeScreen.offer_welcome_days()` が開く。

signal closed
## 受け取った瞬間、押したボタンの位置と獲得額を運ぶ(ヘッダーの砂金へ飛ばす演出は `HomeScreen` が持つ)。
signal reward_claimed(from_rect: Rect2, amount: int)

const SCREEN_SIZE := Vector2(1280, 720)
const PANEL_SIZE := Vector2(560, 330)
const PANEL_STYLE := "res://resources/theme/content_panel.tres"
const CLAIM_SIZE := Vector2(240, 56)
const FAILED_TEXT := "通信に失敗しました。次にホームを開いたときに受け取れます"

var _pips: WelcomeDayPips
var _reward_label: Label
var _note: Label
var _claim_button: Button
var _busy := false


func _ready() -> void:
	visible = false
	mouse_filter = Control.MOUSE_FILTER_STOP
	size = SCREEN_SIZE
	_build()


func open() -> void:
	var day := WelcomeDays.claimed_days() + 1
	_pips.claimed = day - 1
	_pips.queue_redraw()
	_reward_label.text = "%d日目 ・ %s" % [day, WelcomeDays.reward_text(day)]
	_note.text = "来た日の数で進みます。続けて来なくても大丈夫です"
	_claim_button.text = "受け取る"
	_claim_button.disabled = false
	_busy = false
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
	box.add_theme_constant_override("separation", 14)
	panel.add_child(box)

	var title := Label.new()
	title.text = "はじめの7日"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 28)
	box.add_child(title)

	_pips = WelcomeDayPips.new()
	_pips.custom_minimum_size = Vector2(PANEL_SIZE.x - 60.0, WelcomeDayPips.HEIGHT)
	_pips.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	box.add_child(_pips)

	_reward_label = Label.new()
	_reward_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_reward_label.add_theme_font_size_override("font_size", 22)
	_reward_label.add_theme_color_override("font_color", UiPalette.BRASS_HIGHLIGHT)
	box.add_child(_reward_label)

	_note = Label.new()
	_note.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_note.custom_minimum_size.x = PANEL_SIZE.x - 60.0
	_note.add_theme_font_size_override("font_size", 15)
	_note.add_theme_color_override("font_color", UiPalette.TEXT_MUTED)
	box.add_child(_note)

	_claim_button = CodedButton.make_in_group("受け取る", CLAIM_SIZE, CodedButton.PRIMARY_ACTION_GROUP)
	_claim_button.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_claim_button.pressed.connect(_on_claim_pressed)
	box.add_child(_claim_button)


## 受け取れなかったとき(通信の失敗)は、文言を出してボタンを「閉じる」に替える。
func _on_claim_pressed() -> void:
	if _busy:
		return
	if _claim_button.text != "受け取る":
		_close()
		return
	_busy = true
	_claim_button.disabled = true
	var uid := NetSession.auth.uid if NetSession.auth != null else ""
	var day: int = await WelcomeDays.claim(NetSession.client, uid)
	_busy = false
	_claim_button.disabled = false
	if day <= 0:
		_note.text = FAILED_TEXT
		_claim_button.text = "閉じる"
		return
	_pips.claimed = day
	_pips.queue_redraw()
	reward_claimed.emit(_claim_button.get_global_rect(), WelcomeDays.gold_for(day))
	_close()


func _close() -> void:
	visible = false
	closed.emit()
