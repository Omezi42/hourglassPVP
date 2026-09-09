class_name ResumeBand
extends Button
## 「前回の対局へ戻る」の帯(GameDesign.md 9章・11章)。
##
## 以前は他の入口と同じ `HomeTile` として縦の列へ差し込んでいたが、**同じ見た目の札では
## 急ぐ用件だと分からず、切断した人がいちばん見つけにくい場所にあった**。たたかうタブの
## 最上段へ横長の帯として渡し、琥珀の縁と赤い印で他の入口と区別する。
##
## **戻れる対局があるときだけ出す。**無いときは `visible = false` にして、
## その分だけ下の枠を上へ寄せる(`BattleTab._layout()`)。

const CORNER_RADIUS := 10.0
const CORNER_SEGMENTS := 6
const BORDER_WIDTH := 2.0
const PADDING := 20.0
const DOT_RADIUS := 6.0
const DOT_SEGMENTS := 12
const FONT_SIZE := 20
const ACTION_FONT_SIZE := 18
## 地の色。琥珀へ寄せた暗い面にして、真鍮の札と同じ系統に見えないようにする。
const FILL_STOPS := [
	[0.0, Color(0.31, 0.21, 0.07, 0.94)],
	[0.5, Color(0.25, 0.17, 0.06, 0.94)],
	[1.0, Color(0.19, 0.13, 0.05, 0.94)],
]
const DOT_COLOR := Color(0.93, 0.36, 0.28)
const TEXT_COLOR := Color(0.96, 0.94, 0.89)
const ACTION_COLOR := Color(0.96, 0.82, 0.45)
const NOTICE_TEXT := "途中の対局が残っています"
const ACTION_TEXT := "前回の対局へ戻る  →"

var _font: Font


static func make(rect: Rect2) -> ResumeBand:
	var band := ResumeBand.new()
	band.position = rect.position
	band.size = rect.size
	band.custom_minimum_size = rect.size
	band.visible = false
	return band


func _init() -> void:
	# 文言は自前で描く(左右へ別の文を置くため、native の1行では収まらない)。
	text = ""
	mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	# テーマ既定の平坦なボタンの面を消す。面はすべて `_draw()` が描く。
	var empty := StyleBoxEmpty.new()
	for state in ["normal", "hover", "pressed", "disabled", "focus"]:
		add_theme_stylebox_override(state, empty)


func _ready() -> void:
	_font = get_theme_default_font()
	if _font == null:
		_font = ThemeDB.fallback_font


func _draw() -> void:
	if _font == null:
		return
	var rect := Rect2(Vector2.ZERO, size)
	var ci := get_canvas_item()
	var points := UiPaint.rounded_rect_points_uniform(rect, CORNER_RADIUS, CORNER_SEGMENTS)
	var stops: Array = FILL_STOPS
	if is_hovered():
		stops = []
		for stop in FILL_STOPS:
			stops.append([stop[0], (stop[1] as Color) + Color(0.05, 0.035, 0.01, 0.0)])
	UiPaint.fill_gradient_polygon(ci, points, rect, stops)
	UiPaint.apply_grain(ci, rect, 0.06)
	# 縁は琥珀。**他の入口(真鍮の額縁)と系統を変える**ことで、押す前に性質の違いが読める。
	RenderingServer.canvas_item_add_polyline(
		ci,
		points + PackedVector2Array([points[0]]),
		_border_colors(points.size() + 1),
		BORDER_WIDTH
	)
	var mid: float = size.y * 0.5
	UiPaint.fill_circle(ci, Vector2(PADDING + DOT_RADIUS, mid), DOT_RADIUS, DOT_COLOR, DOT_SEGMENTS)
	draw_string(
		_font,
		Vector2(PADDING + DOT_RADIUS * 2.0 + 12.0, mid + float(FONT_SIZE) * 0.36),
		NOTICE_TEXT,
		HORIZONTAL_ALIGNMENT_LEFT,
		-1,
		FONT_SIZE,
		TEXT_COLOR
	)
	var action_width: float = (
		_font.get_string_size(ACTION_TEXT, HORIZONTAL_ALIGNMENT_LEFT, -1, ACTION_FONT_SIZE).x
	)
	draw_string(
		_font,
		Vector2(size.x - PADDING - action_width, mid + float(ACTION_FONT_SIZE) * 0.36),
		ACTION_TEXT,
		HORIZONTAL_ALIGNMENT_LEFT,
		-1,
		ACTION_FONT_SIZE,
		ACTION_COLOR
	)


## 上半分を明るく、下半分を暗くした縁の色。面取りと同じ考え方で、平坦な1色の枠に
## しないためだけの処理。
func _border_colors(count: int) -> PackedColorArray:
	var colors := PackedColorArray()
	colors.resize(count)
	for i in count:
		var bright: bool = i < count / 2
		colors[i] = UiPalette.BRASS_HIGHLIGHT if bright else UiPalette.BRASS_DARK
	return colors
