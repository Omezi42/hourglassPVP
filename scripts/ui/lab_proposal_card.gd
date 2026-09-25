class_name LabProposalCard
extends Control
## 掲示板〈ラボ〉一覧の1件(GameDesign.md 29章)。種別・カード名・説明の冒頭を出し、
## 右端は表示の場面ごとに描き分ける(募集中=投票済みの印、締切後=得票数、自分の投稿=状態)。
## 押すと `opened` を出す(詳細パネルを開くのは画面の役目)。

signal opened(proposal_id: String)

enum Mode { OPEN, RANKED, MINE }

const CARD_SIZE := Vector2(604, 124)
const CORNER_RADIUS := 12.0
const FRAME_THICKNESS := 5.0
const PAD := 20.0
const CHIP_TOP := 18.0
const CHIP_HEIGHT := 26.0
const CHIP_PAD_X := 10.0
const CHIP_RADIUS := 6.0
const CHIP_SEGMENTS := 4
const NAME_GAP := 12.0
const NAME_BASELINE := 40.0
const DESCRIPTION_TOP := 54.0
const DESCRIPTION_LINES := 2
const SIDE_WIDTH := 116.0
const SIDE_RULE_ALPHA := 0.22
const CHIP_FONT_SIZE := 14
const NAME_FONT_SIZE := 24
const DESCRIPTION_FONT_SIZE := 16
const COUNT_FONT_SIZE := 34
const UNIT_FONT_SIZE := 16
const RANK_FONT_SIZE := 14
const STATUS_FONT_SIZE := 17
const MARK_SIZE := 14.0
const MARK_Y := 50.0
const MARK_LABEL_Y := 90.0
const COUNT_Y := 74.0
const RANK_Y := 34.0
const STATUS_Y := 68.0
const CAPTION_Y := 104.0
const CHEVRON_HALF := 8.0
const CHEVRON_WIDTH := 3.0
const ADOPTED_RING := 2.0
const HOURGLASS_CHIP := Color(0.62, 0.45, 0.2, 1.0)
const SPELL_CHIP := Color(0.24, 0.33, 0.58, 1.0)
const CHEVRON_COLOR := Color(0.68, 0.65, 0.60, 0.6)

var proposal_id := ""

var _face: Control
var _description: Label
var _font: Font
var _panel_style: CodedPanelStyle
var _press_tracker := PressTracker.new()
var _rest_position := Vector2.ZERO
var _hovering := false
var _mode := Mode.OPEN
var _name := ""
var _is_spell := false
var _voted := false
var _count := 0
var _rank := 0
var _adopted := false
var _status_text := ""
var _status_color := UiPalette.TEXT_OFFWHITE
var _caption := ""


func _init() -> void:
	custom_minimum_size = CARD_SIZE
	size = CARD_SIZE
	mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	_panel_style = CodedPanelStyle.new()
	_panel_style.corner_radius = CORNER_RADIUS
	_panel_style.frame_thickness = FRAME_THICKNESS

	_face = Control.new()
	_face.size = CARD_SIZE
	_face.pivot_offset = CARD_SIZE / 2.0
	_face.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_face.draw.connect(_paint)
	add_child(_face)

	_description = Label.new()
	_description.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_description.position = Vector2(PAD, DESCRIPTION_TOP)
	_description.size = Vector2(CARD_SIZE.x - PAD * 2.0 - SIDE_WIDTH, 0)
	_description.max_lines_visible = DESCRIPTION_LINES
	_description.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	_description.clip_text = true
	_description.add_theme_font_size_override("font_size", DESCRIPTION_FONT_SIZE)
	_description.add_theme_color_override("font_color", UiPalette.TEXT_MUTED)
	_description.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_face.add_child(_description)


func _ready() -> void:
	_font = get_theme_default_font()
	mouse_entered.connect(_on_hover_changed.bind(true))
	mouse_exited.connect(_on_hover_changed.bind(false))


## 募集中:得票数は伏せ、自分が入れた案にだけ印を出す。
func show_open(proposal: Dictionary, voted: bool) -> void:
	_fill(proposal, Mode.OPEN)
	_voted = voted


## 締切後:順位と得票数。採用した案は枠を琥珀で囲む。
func show_ranked(proposal: Dictionary, rank: int, adopted: bool) -> void:
	_fill(proposal, Mode.RANKED)
	_rank = rank
	_adopted = adopted


## 自分の投稿:状態の文言。`caption` は説明の下に添えるお題(大会の案は空)。
func show_mine(
	proposal: Dictionary, status_text: String, status_color: Color, caption: String
) -> void:
	_fill(proposal, Mode.MINE)
	_caption = caption
	_description.max_lines_visible = 1 if not caption.is_empty() else DESCRIPTION_LINES
	_status_text = status_text
	_status_color = status_color
	_adopted = str(proposal.get("result", "")) == "adopted"


func mark_voted() -> void:
	_voted = true
	_face.queue_redraw()


func _fill(proposal: Dictionary, mode: Mode) -> void:
	proposal_id = str(proposal.get("id", ""))
	_mode = mode
	_name = str(proposal.get("card_name", ""))
	_is_spell = str(proposal.get("card_kind", "")) == "spell"
	_count = int(proposal.get("good_count", 0))
	_description.text = str(proposal.get("description", "")).replace("\n", " ")
	_voted = false
	_adopted = false
	_caption = ""
	_description.max_lines_visible = DESCRIPTION_LINES
	_face.queue_redraw()


func _gui_input(event: InputEvent) -> void:
	match _press_tracker.feed(event, size):
		PressTracker.Result.PRESSED:
			ClickArea.animate_press(_face, true)
		PressTracker.Result.CONFIRMED:
			ClickArea.animate_press(_face, false)
			opened.emit(proposal_id)
		PressTracker.Result.CANCELED:
			ClickArea.animate_press(_face, false)


func _on_hover_changed(hovering: bool) -> void:
	_hovering = hovering
	ClickArea.animate_hover(_face, hovering, _rest_position)


func _paint() -> void:
	var rect := Rect2(Vector2.ZERO, CARD_SIZE)
	_face.draw_style_box(_panel_style, rect)
	var ci := _face.get_canvas_item()
	if _adopted:
		var ring := UiPaint.rounded_rect_points_uniform(
			rect.grow(-1.0), CORNER_RADIUS, CHIP_SEGMENTS
		)
		ring.append(ring[0])
		_face.draw_polyline(ring, UiPalette.GLOW_AMBER, ADOPTED_RING, true)

	var chip_text := "砂術" if _is_spell else "砂時計"
	var chip_width := (
		_font.get_string_size(chip_text, HORIZONTAL_ALIGNMENT_LEFT, -1, CHIP_FONT_SIZE).x
		+ CHIP_PAD_X * 2.0
	)
	var chip := Rect2(PAD, CHIP_TOP, chip_width, CHIP_HEIGHT)
	var chip_color := SPELL_CHIP if _is_spell else HOURGLASS_CHIP
	UiPaint.fill_gradient_polygon(
		ci,
		UiPaint.rounded_rect_points_uniform(chip, CHIP_RADIUS, CHIP_SEGMENTS),
		chip,
		[[0.0, chip_color.lightened(0.15)], [1.0, chip_color.darkened(0.2)]]
	)
	_face.draw_string(
		_font,
		Vector2(chip.position.x, chip.end.y - (CHIP_HEIGHT - CHIP_FONT_SIZE) * 0.5 - 2.0),
		chip_text,
		HORIZONTAL_ALIGNMENT_CENTER,
		chip.size.x,
		CHIP_FONT_SIZE,
		UiPalette.TEXT_OFFWHITE
	)
	var name_left := chip.end.x + NAME_GAP
	_face.draw_string(
		_font,
		Vector2(name_left, NAME_BASELINE),
		_name,
		HORIZONTAL_ALIGNMENT_LEFT,
		CARD_SIZE.x - SIDE_WIDTH - name_left,
		NAME_FONT_SIZE,
		UiPalette.TEXT_OFFWHITE
	)

	var side_left := CARD_SIZE.x - SIDE_WIDTH
	var side_center := side_left + SIDE_WIDTH * 0.5 - FRAME_THICKNESS
	_face.draw_line(
		Vector2(side_left, PAD),
		Vector2(side_left, CARD_SIZE.y - PAD),
		Color(UiPalette.GLOW_AMBER, SIDE_RULE_ALPHA),
		1.0
	)
	match _mode:
		Mode.OPEN:
			_paint_open_side(ci, side_center)
		Mode.RANKED:
			_paint_count_side(side_left, side_center)
		Mode.MINE:
			_centered(_status_text, side_left, STATUS_Y, STATUS_FONT_SIZE, _status_color)
			if not _caption.is_empty():
				_face.draw_string(
					_font,
					Vector2(PAD, CAPTION_Y),
					_caption,
					HORIZONTAL_ALIGNMENT_LEFT,
					side_left - PAD * 2.0,
					RANK_FONT_SIZE,
					UiPalette.GLOW_AMBER
				)


func _paint_open_side(ci: RID, side_center: float) -> void:
	if _voted:
		UiPaint.draw_emblem(ci, UiPaint.Emblem.CHECK, Vector2(side_center, MARK_Y), MARK_SIZE)
		_centered(
			"投票済み", CARD_SIZE.x - SIDE_WIDTH, MARK_LABEL_Y, RANK_FONT_SIZE, UiPalette.GLOW_AMBER
		)
		return
	var tip := Vector2(side_center + CHEVRON_HALF * 0.5, CARD_SIZE.y * 0.5)
	(
		_face
		. draw_polyline(
			PackedVector2Array(
				[
					tip + Vector2(-CHEVRON_HALF, -CHEVRON_HALF),
					tip,
					tip + Vector2(-CHEVRON_HALF, CHEVRON_HALF),
				]
			),
			CHEVRON_COLOR,
			CHEVRON_WIDTH,
			true
		)
	)


func _paint_count_side(side_left: float, _side_center: float) -> void:
	var rank_color := UiPalette.GLOW_AMBER if _adopted else UiPalette.TEXT_MUTED
	var rank_text := "採用・%d位" % _rank if _adopted else "%d位" % _rank
	_centered(rank_text, side_left, RANK_Y, RANK_FONT_SIZE, rank_color)
	var count_text := str(_count)
	var count_width := (
		_font.get_string_size(count_text, HORIZONTAL_ALIGNMENT_LEFT, -1, COUNT_FONT_SIZE).x
	)
	var unit_width := _font.get_string_size("票", HORIZONTAL_ALIGNMENT_LEFT, -1, UNIT_FONT_SIZE).x
	var left := side_left + (SIDE_WIDTH - FRAME_THICKNESS - count_width - unit_width) * 0.5
	_face.draw_string(
		_font,
		Vector2(left, COUNT_Y + COUNT_FONT_SIZE * 0.5),
		count_text,
		HORIZONTAL_ALIGNMENT_LEFT,
		-1,
		COUNT_FONT_SIZE,
		UiPalette.TEXT_OFFWHITE
	)
	_face.draw_string(
		_font,
		Vector2(left + count_width + 2.0, COUNT_Y + COUNT_FONT_SIZE * 0.5),
		"票",
		HORIZONTAL_ALIGNMENT_LEFT,
		-1,
		UNIT_FONT_SIZE,
		UiPalette.TEXT_MUTED
	)


func _centered(text: String, left: float, baseline: float, font_size: int, color: Color) -> void:
	_face.draw_string(
		_font,
		Vector2(left, baseline),
		text,
		HORIZONTAL_ALIGNMENT_CENTER,
		SIDE_WIDTH - FRAME_THICKNESS,
		font_size,
		color
	)
