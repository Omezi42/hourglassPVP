class_name LabThemeBand
extends Control
## 掲示板〈ラボ〉の上部の帯(GameDesign.md 29章)。募集中の回はお題・締切までの残り・
## 残りの票数と「案を出す」を、締め切った回はお題・期間・結果と前後の回への送りを出す。

signal submit_requested
signal step_requested(delta: int)

const PANEL_STYLE := "res://resources/theme/content_panel.tres"
const TEXT_LEFT := 32.0
const CAPTION_Y := 40.0
const TITLE_Y := 82.0
const DETAIL_Y := 114.0
const DETAIL_WIDTH := 640.0
const DIVIDER_X := 700.0
const DIVIDER_TOP := 26.0
const SIDE_LEFT := 728.0
const DEADLINE_Y := 58.0
const VOTES_Y := 102.0
const VALUE_GAP := 12.0
const PIP_RADIUS := 10.0
const PIP_STEP := 30.0
const PIP_RING := 2.5
const PIP_SEGMENTS := 24
const SUBMIT_RECT := Rect2(988, 34, 216, 64)
const NOTE_Y := 124.0
const STEP_SIZE := Vector2(64, 56)
const PREV_POS := Vector2(1060, 42)
const NEXT_POS := Vector2(1140, 42)
const CAPTION_FONT_SIZE := 15
const TITLE_FONT_SIZE := 32
const DETAIL_FONT_SIZE := 17
const VALUE_FONT_SIZE := 22
const NOTE_FONT_SIZE := 13
const DIVIDER_COLOR := Color(0.85, 0.62, 0.22, 0.3)
const PIP_EMPTY := Color(0.68, 0.65, 0.60, 0.55)

var _font: Font
var _panel_style: StyleBox
var _closed := false
var _title := ""
var _detail := ""
var _deadline_text := ""
var _votes_left := 0
var _period_text := ""
var _result_text := ""
var _note := ""
var _submit_button: Button
var _prev_button: Button
var _next_button: Button


func _ready() -> void:
	_font = get_theme_default_font()
	_panel_style = load(PANEL_STYLE)
	mouse_filter = Control.MOUSE_FILTER_IGNORE

	_submit_button = CodedButton.make("案を出す", SUBMIT_RECT.size)
	CodedButton.apply_styles(_submit_button, "primary_action")
	_submit_button.position = SUBMIT_RECT.position
	_submit_button.pressed.connect(func() -> void: submit_requested.emit())
	add_child(_submit_button)

	_prev_button = CodedButton.make("‹", STEP_SIZE)
	_prev_button.position = PREV_POS
	_prev_button.pressed.connect(func() -> void: step_requested.emit(1))
	add_child(_prev_button)
	_next_button = CodedButton.make("›", STEP_SIZE)
	_next_button.position = NEXT_POS
	_next_button.pressed.connect(func() -> void: step_requested.emit(-1))
	add_child(_next_button)


## 募集中の回。`note` は「案を出す」を押せない理由(空なら出さない)。
func show_open(
	title: String,
	detail: String,
	deadline_text: String,
	votes_left: int,
	submit_label: String,
	submit_enabled: bool,
	note: String
) -> void:
	_closed = false
	_title = title
	_detail = detail
	_deadline_text = deadline_text
	_votes_left = votes_left
	_note = note
	_submit_button.visible = true
	_submit_button.text = submit_label
	_submit_button.disabled = not submit_enabled
	_prev_button.visible = false
	_next_button.visible = false
	queue_redraw()


## 締め切った回。`has_older` / `has_newer` は前後の回へ送れるかどうか。
func show_closed(
	title: String,
	detail: String,
	period_text: String,
	result_text: String,
	has_older: bool,
	has_newer: bool
) -> void:
	_closed = true
	_title = title
	_detail = detail
	_period_text = period_text
	_result_text = result_text
	_note = ""
	_submit_button.visible = false
	_prev_button.visible = true
	_next_button.visible = true
	_prev_button.disabled = not has_older
	_next_button.disabled = not has_newer
	queue_redraw()


func _draw() -> void:
	if _panel_style != null:
		draw_style_box(_panel_style, Rect2(Vector2.ZERO, size))
	var caption := "過去のお題" if _closed else "今回のお題"
	_text(caption, Vector2(TEXT_LEFT, CAPTION_Y), CAPTION_FONT_SIZE, UiPalette.GLOW_AMBER)
	draw_string(
		_font,
		Vector2(TEXT_LEFT, TITLE_Y),
		_title,
		HORIZONTAL_ALIGNMENT_LEFT,
		DIVIDER_X - TEXT_LEFT * 2.0,
		TITLE_FONT_SIZE,
		UiPalette.TEXT_OFFWHITE
	)
	draw_string(
		_font,
		Vector2(TEXT_LEFT, DETAIL_Y),
		_detail,
		HORIZONTAL_ALIGNMENT_LEFT,
		DETAIL_WIDTH,
		DETAIL_FONT_SIZE,
		UiPalette.TEXT_MUTED
	)
	draw_line(
		Vector2(DIVIDER_X, DIVIDER_TOP),
		Vector2(DIVIDER_X, size.y - DIVIDER_TOP),
		DIVIDER_COLOR,
		1.0
	)
	if _closed:
		_pair("期間", _period_text, DEADLINE_Y)
		_pair("結果", _result_text, VOTES_Y)
		return
	_pair("締切まで", _deadline_text, DEADLINE_Y)
	var right := _text("残りの票", Vector2(SIDE_LEFT, VOTES_Y), CAPTION_FONT_SIZE, UiPalette.TEXT_MUTED)
	for i in LabRules.VOTES_PER_ROUND:
		var center := Vector2(
			right + VALUE_GAP + PIP_RADIUS + i * PIP_STEP, VOTES_Y - PIP_RADIUS * 0.6
		)
		if i < _votes_left:
			UiPaint.fill_circle(
				get_canvas_item(), center, PIP_RADIUS, UiPalette.GLOW_AMBER, PIP_SEGMENTS
			)
		else:
			UiPaint.draw_ring(
				get_canvas_item(), center, PIP_RADIUS, PIP_EMPTY, PIP_RING, PIP_SEGMENTS
			)
	if not _note.is_empty():
		draw_string(
			_font,
			Vector2(SUBMIT_RECT.position.x, NOTE_Y),
			_note,
			HORIZONTAL_ALIGNMENT_CENTER,
			SUBMIT_RECT.size.x,
			NOTE_FONT_SIZE,
			UiPalette.TEXT_MUTED
		)


func _pair(caption: String, value: String, baseline: float) -> void:
	var right := _text(
		caption, Vector2(SIDE_LEFT, baseline), CAPTION_FONT_SIZE, UiPalette.TEXT_MUTED
	)
	_text(value, Vector2(right + VALUE_GAP, baseline), VALUE_FONT_SIZE, UiPalette.TEXT_OFFWHITE)


## 1行描き、右端のx座標を返す。
func _text(text: String, at: Vector2, font_size: int, color: Color) -> float:
	draw_string(_font, at, text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, color)
	return at.x + _font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x
