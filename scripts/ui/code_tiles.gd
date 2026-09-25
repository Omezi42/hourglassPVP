class_name CodeTiles
extends Control
## 数字だけのコード(ルームコード・デッキコード)を1桁ずつの升に描く(GameDesign.md 9章・11章)。
##
## `editable` のときは透明な `LineEdit` を全面へ重ねて入力を受ける。文字は升が描くため、
## `LineEdit` 自身の文字・枠・カーソルは見せない。

signal submitted

const TILE_GAP_RATIO := 0.2
const TILE_RADIUS_RATIO := 0.1
const DIGIT_SIZE_RATIO := 0.62
const DIGIT_BASELINE_RATIO := 0.24
const CURSOR_HALF_RATIO := 0.18
const CURSOR_INSET_RATIO := 0.16
const TILE_TOP := Color(0.04, 0.035, 0.04)
const TILE_BOTTOM := Color(0.11, 0.10, 0.12)
const RIM_SHADE := Color(0, 0, 0, 0.6)
const CURSOR_ALPHA := 0.85

## 升の数。組み立てた直後(`make_editable()` より前)に決める。
var digits := RoomMatch.CODE_LENGTH

var code := "":
	set(value):
		code = value
		queue_redraw()

var input: LineEdit
var _font: Font


func _ready() -> void:
	_font = get_theme_default_font()
	mouse_filter = Control.MOUSE_FILTER_IGNORE


## 入力を受ける升にする。呼ぶのは組み立てた直後の1回。
func make_editable(prompt_title: String) -> void:
	input = LineEdit.new()
	input.anchor_right = 1.0
	input.anchor_bottom = 1.0
	input.max_length = digits
	input.virtual_keyboard_type = LineEdit.KEYBOARD_TYPE_NUMBER
	input.context_menu_enabled = false
	input.caret_blink = false
	var clear := Color(0, 0, 0, 0)
	for color_name in ["font_color", "caret_color", "selection_color", "font_placeholder_color"]:
		input.add_theme_color_override(color_name, clear)
	input.add_theme_constant_override("outline_size", 0)
	for style_name in ["normal", "focus", "read_only"]:
		input.add_theme_stylebox_override(style_name, StyleBoxEmpty.new())
	input.text_changed.connect(_on_text_changed)
	input.text_submitted.connect(func(_text: String) -> void: submitted.emit())
	input.focus_entered.connect(queue_redraw)
	input.focus_exited.connect(queue_redraw)
	MobileTextInput.wire(input, prompt_title)
	add_child(input)


func set_editable(editable: bool) -> void:
	if input != null:
		input.editable = editable
		input.mouse_filter = (
			Control.MOUSE_FILTER_STOP if editable else Control.MOUSE_FILTER_IGNORE
		)
		queue_redraw()


## 数字以外は落とす(コードは数字しか取りえないため)。
func _on_text_changed(text: String) -> void:
	var kept := ""
	for ch in text:
		if ch >= "0" and ch <= "9":
			kept += ch
	if kept != text:
		input.text = kept
		input.caret_column = kept.length()
	code = kept


func _draw() -> void:
	var rid := get_canvas_item()
	var count := digits
	var tile_w := size.x / (count + (count - 1) * TILE_GAP_RATIO)
	var tile := Vector2(tile_w, size.y)
	var radius := tile_w * TILE_RADIUS_RATIO
	var show_cursor := input != null and input.editable and input.has_focus()
	for i in count:
		var rect := Rect2(Vector2((tile_w * (1.0 + TILE_GAP_RATIO)) * i, 0), tile)
		var points := UiPaint.rounded_rect_points_uniform(rect, radius, 6)
		UiPaint.fill_gradient_polygon(rid, points, rect, [[0.0, TILE_TOP], [1.0, TILE_BOTTOM]])
		UiPaint.draw_inner_shadow(rid, rect, radius, 6, 6, Color.BLACK, 0.8)
		UiPaint.draw_bevel(rid, points, RIM_SHADE, UiPalette.BRASS_RIM_LIGHT, 2.0, false)
		if i < code.length():
			draw_string(
				_font,
				Vector2(rect.position.x, rect.get_center().y + tile.y * DIGIT_BASELINE_RATIO),
				code[i],
				HORIZONTAL_ALIGNMENT_CENTER,
				rect.size.x,
				int(tile.y * DIGIT_SIZE_RATIO),
				UiPalette.BRASS_HIGHLIGHT
			)
		elif i == code.length() and show_cursor:
			var y := rect.end.y - tile.y * CURSOR_INSET_RATIO
			var half := tile_w * CURSOR_HALF_RATIO
			draw_line(
				Vector2(rect.get_center().x - half, y),
				Vector2(rect.get_center().x + half, y),
				Color(UiPalette.GLOW_AMBER, CURSOR_ALPHA),
				3.0
			)
