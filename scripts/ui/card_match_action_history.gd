class_name CardMatchActionHistory
extends Control
## 直近のアクション履歴プレビュー(GameDesign.md 9章)。
## 画面左の余白に直近4件の行動(設置/攻撃/反転/砂術)をミニタイルで視覚的に並べる。

const TILE_SIZE := Vector2(140, 34)
const TILE_GAP := 6.0
const MAX_TILES := 4
const TILE_RADIUS := 4.0

var _screen: CardMatchScreen
var _font: Font
var _items: Array[Dictionary] = []


func _init(screen: CardMatchScreen) -> void:
	_screen = screen
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func _ready() -> void:
	_font = TextGlyphs.ui_font()
	custom_minimum_size = Vector2(TILE_SIZE.x, (TILE_SIZE.y + TILE_GAP) * MAX_TILES)
	size = custom_minimum_size
	# 盤面左側の余白(x=24, y=180)に配置
	position = Vector2(24.0, 180.0)


## 1手を積む。**文言の組み立てもここが持つ**——押し込む側(対局画面)が持つと、
## 自分の手と相手の手で別々に書くことになり、片方だけ古くなる。
func push_action(side: int, action: Dictionary) -> void:
	var item := {
		"side": side,
		"text": summarize(action),
		"time": Time.get_ticks_msec(),
	}
	_items.push_front(item)
	if _items.size() > MAX_TILES:
		_items.pop_back()
	queue_redraw()


## アクション辞書を短い1行にまとめる。
static func summarize(action: Dictionary) -> String:
	match String(action.get("type", "")):
		"play":
			return "設置"
		"attack":
			return "攻撃"
		"flip":
			return "反転"
		"cast":
			return "砂術"
		"end_turn":
			return "ターン終了"
		"time_up":
			return "時間切れ"
		"coin":
			return "コイン"
		"surrender":
			return "投了"
		"mulligan":
			return "マリガン"
	return String(action.get("type", "?"))


func clear() -> void:
	_items.clear()
	queue_redraw()


func _draw() -> void:
	if _items.is_empty() or _screen.state == null:
		return

	var ci := get_canvas_item()
	for i in _items.size():
		var item: Dictionary = _items[i]
		var y := i * (TILE_SIZE.y + TILE_GAP)
		var rect := Rect2(Vector2(0, y), TILE_SIZE)
		var points := UiPaint.rounded_rect_points_uniform(rect, TILE_RADIUS, 4)

		var is_own: bool = item["side"] == _screen.my_side
		var border_color := UiPalette.BRASS_LIGHT if is_own else UiPalette.BRASS_MID
		var text_color := UiPalette.TEXT_OFFWHITE if is_own else UiPalette.TEXT_MUTED

		# 背景
		var bg_top := Color(0.14, 0.12, 0.11, 0.85) if is_own else Color(0.18, 0.10, 0.10, 0.85)
		var bg_bottom := Color(0.08, 0.07, 0.06, 0.90)
		UiPaint.fill_gradient_polygon(ci, points, rect, [[0.0, bg_top], [1.0, bg_bottom]])

		var outline := points.duplicate()
		outline.append(points[0])
		draw_polyline(outline, border_color, 1.0, true)

		# 左端のプレイヤー色バー
		var indicator_color := UiPalette.GLOW_AMBER if is_own else UiPalette.WARNING_RED
		draw_line(Vector2(3, y + 4), Vector2(3, y + TILE_SIZE.y - 4), indicator_color, 2.5)

		# テキスト(短縮表示)
		var text: String = item["text"]
		if text.length() > 10:
			text = text.left(9) + "…"
		draw_string(_font, Vector2(10, y + 22), text, HORIZONTAL_ALIGNMENT_LEFT, -1, 12, text_color)
