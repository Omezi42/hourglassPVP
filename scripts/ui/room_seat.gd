class_name RoomSeat
extends Control
## ルームマッチの部屋の中の1席(GameDesign.md 11章)。アイコン・称号・表示名と、
## 自分の席なら使用デッキを描く。相手のデッキは出さない。
## `empty` の間は空席として、点線の枠と巡回ドット付きの文言を描く。

const PANEL_STYLE := "res://resources/theme/content_panel.tres"
const PORTRAIT_CENTER := Vector2(96, 120)
const PORTRAIT_RADIUS := 60.0
const PORTRAIT_RING := 5.0
const TEXT_LEFT := 180.0
const ROLE_Y := 60.0
const TITLE_Y := 92.0
const NAME_Y := 134.0
const DECK_RULE_Y := 196.0
const DECK_LABEL_Y := 224.0
const DECK_NAME_Y := 254.0
const HIDDEN_NOTE_Y := 240.0
const INNER_LEFT := 32.0
const DECK_RULE_RIGHT := 364.0
const ROLE_FONT_SIZE := UiPalette.T_BODY
const TITLE_FONT_SIZE := UiPalette.T_BODY
const NAME_FONT_SIZE := UiPalette.T_HEAD
const DECK_LABEL_FONT_SIZE := UiPalette.T_SMALL
const DECK_NAME_FONT_SIZE := UiPalette.T_LEAD
const NOTE_FONT_SIZE := UiPalette.T_BODY
const WAIT_FONT_SIZE := UiPalette.T_LEAD
const WAIT_HINT_FONT_SIZE := UiPalette.T_BODY
const WAIT_Y := 130.0
const WAIT_HINT_Y := 162.0
const EMPTY_RADIUS := 14.0
const DASH := 9.0
const DASH_ALPHA := 0.5
const EMPTY_RING_ALPHA := 0.45
const EMPTY_MARK_ALPHA := 0.6
const EMPTY_MARK_FONT_SIZE := UiPalette.T_TITLE
## 席の右下へ置く「変更」ボタンの位置(`CardRoomScreen` が子として置く)。
const DECK_BUTTON_RECT := Rect2(396, 196, 120, 52)
const HIDDEN_DECK_NOTE := "デッキは対局が始まるまで伏せられます"

var role := ""
var display_name := ""
var title_id := UserProfileLibrary.DEFAULT_TITLE_ID
var icon_id := UserProfileLibrary.DEFAULT_ICON_ID
## 空文字なら相手の席として「伏せられます」を出す。
var deck_name := ""
var empty := false
var waiting_text := ""
var waiting_hint := ""

var _font: Font
var _panel_style: StyleBox
var _dots := 0
var _elapsed := 0.0


func _ready() -> void:
	_font = get_theme_default_font()
	_panel_style = load(PANEL_STYLE)
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func show_player(
	p_role: String, p_name: String, p_title: String, p_icon: String, p_deck: String
) -> void:
	role = p_role
	display_name = p_name
	title_id = p_title
	icon_id = p_icon
	deck_name = p_deck
	empty = false
	set_process(false)
	queue_redraw()


func show_empty(text: String, hint: String) -> void:
	empty = true
	waiting_text = text
	waiting_hint = hint
	_dots = 0
	_elapsed = 0.0
	set_process(true)
	queue_redraw()


func _process(delta: float) -> void:
	_elapsed += delta
	if _elapsed < EmptyState.DOTS_INTERVAL:
		return
	_elapsed = 0.0
	_dots = (_dots + 1) % (EmptyState.DOTS_MAX + 1)
	queue_redraw()


func _draw() -> void:
	if empty:
		_draw_empty()
	else:
		_draw_player()


func _draw_player() -> void:
	var rid := get_canvas_item()
	if _panel_style != null:
		draw_style_box(_panel_style, Rect2(Vector2.ZERO, size))
	UiKit.seal(rid, PORTRAIT_CENTER, PORTRAIT_RADIUS, null)
	var tex := UserProfileLibrary.get_icon_texture(icon_id)
	if tex != null:
		var r := PORTRAIT_RADIUS - PORTRAIT_RING - 1.0
		draw_texture_rect(
			tex, Rect2(PORTRAIT_CENTER - Vector2.ONE * r, Vector2.ONE * r * 2.0), false
		)
	UiKit.stroke_grad(
		rid,
		UiKit.ellipse(PORTRAIT_CENTER, Vector2.ONE * (PORTRAIT_RADIUS - PORTRAIT_RING * 0.5)),
		UiKit.rim_brass(),
		PORTRAIT_RING
	)
	_text(Vector2(TEXT_LEFT, ROLE_Y), role, ROLE_FONT_SIZE, UiPalette.SAND)
	_text(
		Vector2(TEXT_LEFT, TITLE_Y),
		UserProfileLibrary.get_title_display(title_id),
		TITLE_FONT_SIZE,
		UiPalette.MUTED
	)
	_text(Vector2(TEXT_LEFT, NAME_Y), display_name, NAME_FONT_SIZE, UiPalette.IVORY)
	if deck_name == "":
		_text(Vector2(INNER_LEFT, HIDDEN_NOTE_Y), HIDDEN_DECK_NOTE, NOTE_FONT_SIZE, UiPalette.MUTED)
		return
	UiKit.rule(rid, Vector2(INNER_LEFT - 4.0, DECK_RULE_Y), Vector2(DECK_RULE_RIGHT, DECK_RULE_Y))
	_text(Vector2(INNER_LEFT, DECK_LABEL_Y), "使用デッキ", DECK_LABEL_FONT_SIZE, UiPalette.MUTED)
	_text(Vector2(INNER_LEFT, DECK_NAME_Y), deck_name, DECK_NAME_FONT_SIZE, UiPalette.IVORY)


## 空席。沈んだ面に点線の枠を回し、まだ誰も座っていないことを示す。
func _draw_empty() -> void:
	var rid := get_canvas_item()
	var rect := Rect2(Vector2.ZERO, size)
	UiKit.well(rid, rect, EMPTY_RADIUS)
	var dash_color := Color(UiPalette.GOLD, DASH_ALPHA)
	var x := EMPTY_RADIUS
	while x < size.x - EMPTY_RADIUS:
		var x2 := minf(x + DASH, size.x - EMPTY_RADIUS)
		draw_line(Vector2(x, 0), Vector2(x2, 0), dash_color, 2.0)
		draw_line(Vector2(x, size.y), Vector2(x2, size.y), dash_color, 2.0)
		x += DASH * 2.0
	var y := EMPTY_RADIUS
	while y < size.y - EMPTY_RADIUS:
		var y2 := minf(y + DASH, size.y - EMPTY_RADIUS)
		draw_line(Vector2(0, y), Vector2(0, y2), dash_color, 2.0)
		draw_line(Vector2(size.x, y), Vector2(size.x, y2), dash_color, 2.0)
		y += DASH * 2.0
	UiKit.stroke(
		rid,
		UiKit.ellipse(PORTRAIT_CENTER, Vector2.ONE * PORTRAIT_RADIUS),
		Color(UiPalette.GOLD, EMPTY_RING_ALPHA),
		UiKit.LINE_MIN
	)
	draw_string(
		_font,
		PORTRAIT_CENTER + Vector2(-PORTRAIT_RADIUS, EMPTY_MARK_FONT_SIZE * 0.35),
		"?",
		HORIZONTAL_ALIGNMENT_CENTER,
		PORTRAIT_RADIUS * 2.0,
		EMPTY_MARK_FONT_SIZE,
		Color(UiPalette.MUTED, EMPTY_MARK_ALPHA)
	)
	_text(
		Vector2(TEXT_LEFT, WAIT_Y),
		waiting_text + ".".repeat(_dots),
		WAIT_FONT_SIZE,
		UiPalette.IVORY
	)
	_text(Vector2(TEXT_LEFT, WAIT_HINT_Y), waiting_hint, WAIT_HINT_FONT_SIZE, UiPalette.MUTED)


func _text(at: Vector2, text: String, font_size: int, color: Color) -> void:
	draw_string(
		_font, at, text, HORIZONTAL_ALIGNMENT_LEFT, size.x - at.x - INNER_LEFT, font_size, color
	)
