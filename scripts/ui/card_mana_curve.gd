class_name CardManaCurve
extends Control
## デッキのコスト別の枚数を棒グラフで示す(GameDesign.md 9章)。
## 20枚のデッキではコストの配分が構築の中心であり、数えなくても分かる状態にする。

const MIN_COST := 1
const MAX_COST := 10
## 目盛りの上限。これを超える本数が出たら、その本数まで伸ばす。
const BASE_SCALE := 6

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
	var rect := Rect2(Vector2.ZERO, size)
	draw_rect(rect, Color(0.09, 0.08, 0.1, 0.82))
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
	for cost in range(MIN_COST, MAX_COST + 1):
		var index := cost - MIN_COST
		var count: int = _counts[cost]
		var height := area.size.y * float(count) / float(peak)
		var x := area.position.x + index * step + (step - bar_width) * 0.5
		var bar := Rect2(x, area.end.y - height, bar_width, height)
		draw_rect(Rect2(x, area.position.y, bar_width, area.size.y), Color(1, 1, 1, 0.04))
		if count > 0:
			draw_rect(bar, CardView.MANA_BLUE)
			_label(
				Vector2(x + bar_width * 0.5 - 5, bar.position.y - 6),
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


func _label(pos: Vector2, text: String, font_size: int, color: Color) -> void:
	draw_string(_font, pos, text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, color)
