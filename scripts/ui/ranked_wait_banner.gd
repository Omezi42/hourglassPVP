class_name RankedWaitBanner
extends Control
## ランクマッチを待機したまま他の画面にいる間、下端中央へ出す帯(GameDesign.md 11章)。
## どの画面で出すかは `Main` が決め、ここは中身と短い知らせだけを持つ。

signal open_pressed
signal cancel_pressed

const BANNER_SIZE := Vector2(620, 64)
const PORTRAIT_BANNER_SIZE := Vector2(680, 88)
const BOTTOM_MARGIN := 16.0
const PADDING := 10.0
const BUTTON_GAP := 8.0
const OPEN_BUTTON_WIDTH := 150.0
const CANCEL_BUTTON_WIDTH := 100.0
const PORTRAIT_OPEN_BUTTON_WIDTH := 190.0
const PORTRAIT_CANCEL_BUTTON_WIDTH := 120.0
const FONT_SIZE := 20
const PORTRAIT_FONT_SIZE := 26
const WAITING_TEXT := "ランクマッチ待機中  %d:%02d"
const FOUND_TEXT := "相手が見つかりました"
const FLASH_SECONDS := 2.0
const ENDED_SECONDS := 3.0
const SECONDS_PER_MINUTE := 60
const MSEC_PER_SECOND := 1000

var _started_msec := 0
## 知らせを出している間は経過時間で上書きしない。
var _note_until_msec := 0
## 知らせを消したあと帯ごと隠す(待機が終わった)。
var _hide_after_note := false
var _label: Label
var _open_button: Button
var _cancel_button: Button
var _row: HBoxContainer
var _portrait := false


func _ready() -> void:
	anchor_left = 0.5
	anchor_right = 0.5
	anchor_top = 1.0
	anchor_bottom = 1.0
	mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(BarPanel.new())
	_row = HBoxContainer.new()
	_row.add_theme_constant_override("separation", int(BUTTON_GAP))
	add_child(_row)
	_label = Label.new()
	_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_label.add_theme_color_override("font_color", UiPalette.TEXT_OFFWHITE)
	_row.add_child(_label)
	_open_button = CodedButton.make("待機画面へ", Vector2.ZERO)
	_open_button.pressed.connect(func() -> void: open_pressed.emit())
	_row.add_child(_open_button)
	_cancel_button = CodedButton.make("やめる", Vector2.ZERO)
	_cancel_button.pressed.connect(func() -> void: cancel_pressed.emit())
	_row.add_child(_cancel_button)
	apply_orientation(_portrait)
	visible = false
	set_process(false)


func apply_orientation(portrait: bool) -> void:
	_portrait = portrait
	if _row == null:
		return
	var banner_size := PORTRAIT_BANNER_SIZE if portrait else BANNER_SIZE
	offset_left = -banner_size.x * 0.5
	offset_right = banner_size.x * 0.5
	offset_bottom = -BOTTOM_MARGIN
	offset_top = offset_bottom - banner_size.y
	var panel: Control = get_child(0)
	panel.size = banner_size
	_row.position = Vector2(PADDING * 2.0, PADDING)
	_row.size = banner_size - Vector2(PADDING * 3.0, PADDING * 2.0)
	var font_size := PORTRAIT_FONT_SIZE if portrait else FONT_SIZE
	_label.add_theme_font_size_override("font_size", font_size)
	var button_height := banner_size.y - PADDING * 2.0
	_open_button.custom_minimum_size = Vector2(
		PORTRAIT_OPEN_BUTTON_WIDTH if portrait else OPEN_BUTTON_WIDTH, button_height
	)
	_cancel_button.custom_minimum_size = Vector2(
		PORTRAIT_CANCEL_BUTTON_WIDTH if portrait else CANCEL_BUTTON_WIDTH, button_height
	)
	for button in [_open_button, _cancel_button]:
		(button as Button).add_theme_font_size_override("font_size", font_size)


## 待機を始めた時刻(`Time.get_ticks_msec()`)から経過時間を数える。
func begin(started_msec: int) -> void:
	_started_msec = started_msec
	_note_until_msec = 0
	_hide_after_note = false
	_set_buttons_visible(true)
	_refresh_elapsed()


## 帯を出す・隠す。知らせを出している間は隠さない(失敗の文言を読ませるため)。
func set_shown(shown: bool) -> void:
	if not shown and _hide_after_note and _note_active():
		return
	visible = shown
	set_process(shown)


func flash(text: String) -> void:
	_show_note(text, FLASH_SECONDS)


func show_found() -> void:
	_set_buttons_visible(false)
	_show_note(FOUND_TEXT, FLASH_SECONDS)


## 待機が終わった。いま出ていれば文言を少し見せてから消える。
func show_ended(text: String) -> void:
	if not visible or text.is_empty():
		set_shown(false)
		return
	_set_buttons_visible(false)
	_hide_after_note = true
	_show_note(text, ENDED_SECONDS)


func _show_note(text: String, seconds: float) -> void:
	_label.text = text
	_note_until_msec = Time.get_ticks_msec() + int(seconds * MSEC_PER_SECOND)


func _note_active() -> bool:
	return Time.get_ticks_msec() < _note_until_msec


func _set_buttons_visible(shown: bool) -> void:
	_open_button.visible = shown
	_cancel_button.visible = shown


func _process(_delta: float) -> void:
	if _note_active():
		return
	if _hide_after_note:
		_hide_after_note = false
		set_shown(false)
		return
	if _open_button.visible:
		_refresh_elapsed()


func _refresh_elapsed() -> void:
	var seconds := (Time.get_ticks_msec() - _started_msec) / MSEC_PER_SECOND
	var text := WAITING_TEXT % [seconds / SECONDS_PER_MINUTE, seconds % SECONDS_PER_MINUTE]
	if _label.text != text:
		_label.text = text
