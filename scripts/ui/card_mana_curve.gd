class_name CardManaCurve
extends Control
## デッキのコスト別の枚数を棒グラフで示す(GameDesign.md 9章)。
## 20枚のデッキではコストの配分が構築の中心であり、数えなくても分かる状態にする。

const MIN_COST := 1
const MAX_COST := 10
## 目盛りの上限。これを超える本数が出たら、その本数まで伸ばす。
const BASE_SCALE := 6
## 棒の角丸と質感。無地の矩形を並べるだけだと平坦に見えるため、他のコード描画UIと
## 同じ手当て(角丸 + 縦グラデーション + 溝の落ち込み)を掛ける。
const BAR_RADIUS := 4.0
const TRACK_COLOR_TOP := Color(0.06, 0.05, 0.06, 0.9)
const TRACK_COLOR_BOTTOM := Color(0.13, 0.12, 0.14, 0.9)

var _counts: Array[int] = []
var _font: Font


func _ready() -> void:
	_font = get_theme_default_font()
	if _font == null:
		_font = ThemeDB.fallback_font
	queue_redraw()


func show_deck(deck: Array) -> void:
	_counts = []
	_counts.resize(MAX_COST + 1)
	for card in deck:
		var cost: int = clampi(card.cost, MIN_COST, MAX_COST)
		_counts[cost] += 1
	queue_redraw()


func _draw() -> void:
	var ci := get_canvas_item()
	var rect := Rect2(Vector2.ZERO, size)
	draw_rect(rect, Color(0.09, 0.08, 0.1, 0.82))
	UiPaint.apply_grain(ci, rect, 0.05)
	draw_rect(rect, UiPalette.GLOW_AMBER, false, 2.0)
	_label(Vector2(20, 34), "マナカーブ", 22, UiPalette.TEXT_OFFWHITE)
	if _counts.is_empty():
		return
	var peak := BASE_SCALE
	for count in _counts:
		peak = maxi(peak, count)
	var columns := MAX_COST - MIN_COST + 1
	var area := Rect2(24, 56, size.x - 48, size.y - 104)
	var step := area.size.x / float(columns)
	var bar_width := step * 0.62
	draw_line(
		Vector2(area.position.x, area.end.y),
		Vector2(area.end.x, area.end.y),
		Color(UiPalette.BRASS_MID, 0.8),
		1.5
	)
	for cost in range(MIN_COST, MAX_COST + 1):
		var index := cost - MIN_COST
		var count: int = _counts[cost]
		var x := area.position.x + index * step + (step - bar_width) * 0.5
		_draw_track(ci, Rect2(x, area.position.y, bar_width, area.size.y))
		if count > 0:
			var height := area.size.y * float(count) / float(peak)
			_draw_bar(ci, Rect2(x, area.end.y - height, bar_width, height))
			_label(
				Vector2(x + bar_width * 0.5 - 5, area.end.y - height - 6),
				str(count),
				16,
				UiPalette.TEXT_OFFWHITE
			)
		_label(
			Vector2(x + bar_width * 0.5 - 5, area.end.y + 22),
			str(cost),
			16,
			UiPalette.BRASS_HIGHLIGHT
		)


## 目盛りの溝。棒が立っていない列でも、そこに枠があることを示す。
func _draw_track(ci: RID, rect: Rect2) -> void:
	var points := UiPaint.rounded_rect_points_uniform(rect, BAR_RADIUS, 4)
	UiPaint.fill_gradient_polygon(
		ci, points, rect, [[0.0, TRACK_COLOR_TOP], [1.0, TRACK_COLOR_BOTTOM]]
	)
	UiPaint.draw_inner_shadow(ci, rect, BAR_RADIUS, 4, 2, Color(0, 0, 0, 1), 0.35)


func _draw_bar(ci: RID, rect: Rect2) -> void:
	if rect.size.y <= 0.0:
		return
	var radius: float = minf(BAR_RADIUS, rect.size.y * 0.5)
	var points := UiPaint.rounded_rect_points_uniform(rect, radius, 4)
	var top := CardView.MANA_BLUE.lightened(0.3)
	UiPaint.fill_gradient_polygon(
		ci,
		points,
		rect,
		[[0.0, top], [0.6, CardView.MANA_BLUE], [1.0, CardView.MANA_BLUE.darkened(0.3)]]
	)
	draw_line(
		Vector2(rect.position.x + 2.0, rect.position.y + 1.5),
		Vector2(rect.end.x - 2.0, rect.position.y + 1.5),
		Color(1, 1, 1, 0.4),
		1.5
	)


func _label(pos: Vector2, text: String, font_size: int, color: Color) -> void:
	draw_string(_font, pos, text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, color)
