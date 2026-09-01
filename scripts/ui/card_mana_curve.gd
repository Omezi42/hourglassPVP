class_name CardManaCurve
extends Control
## デッキのコスト別の枚数を棒グラフで示す(GameDesign.md 9章)。
## 20枚のデッキではコストの配分が構築の中心であり、数えなくても分かる状態にする。

const MIN_COST := 1
const MAX_COST := 10
## 目盛りを出すコストの下限。プールの最大コストがこれより小さくても、ここまでは並べる
## (棒が2〜3本しか無いと、グラフではなく数字の列に見えるため)。
const MIN_COLUMNS := 6
## 目盛りの上限。これを超える本数が出たら、その本数まで伸ばす。
const BASE_SCALE := 6
## 棒の角丸と質感。無地の矩形を並べるだけだと平坦に見えるため、他のコード描画UIと
## 同じ手当て(角丸 + 縦グラデーション + 溝の落ち込み)を掛ける。
const BAR_RADIUS := 4.0
const TRACK_COLOR_TOP := Color(0.06, 0.05, 0.06, 0.9)
const TRACK_COLOR_BOTTOM := Color(0.13, 0.12, 0.14, 0.9)

## 低背版。デッキ編集は右カラムの下半分しか使えないため、見出しを左へ寄せて
## 棒と目盛りだけの高さへ詰める。**コストの配分は棒の形で読むもの**であり、
## 高さを削っても役割は保てる(GameDesign.md 9章)。
var compact := false

var _counts: Array[int] = []
## 目盛りの右端。**プールに実在するコストの範囲だけ**を出す(GameDesign.md 9章)。
## 常に1〜10を並べると、最大コストが6の現状では半分が空欄になる。
var _display_max := MIN_COLUMNS
var _font: Font


func _ready() -> void:
	_font = get_theme_default_font()
	if _font == null:
		_font = ThemeDB.fallback_font
	queue_redraw()


func show_deck(deck: Array) -> void:
	_counts = []
	_counts.resize(MAX_COST + 1)
	_display_max = _pool_max_cost()
	for card in deck:
		var cost: int = clampi(card.cost, MIN_COST, MAX_COST)
		_counts[cost] += 1
	queue_redraw()


func _draw() -> void:
	var ci := get_canvas_item()
	var rect := Rect2(Vector2.ZERO, size)
	draw_rect(rect, Color(0.09, 0.08, 0.1, 0.82))
	UiPaint.apply_grain(ci, rect, 0.05)
	draw_rect(rect, UiPalette.GLOW_AMBER, false, 1.5)
	_label(Vector2(14, 20), "マナカーブ", 15, UiPalette.TEXT_OFFWHITE)
	if _counts.is_empty():
		return
	var peak := BASE_SCALE
	for count in _counts:
		peak = maxi(peak, count)
	var columns := _display_max - MIN_COST + 1
	# 棒グラフの描画領域。上下に余白を取り、棒の上の枚数と下のコスト値が収まる高さにする。
	var area := Rect2(16, 28, size.x - 32, size.y - 56)
	var step := area.size.x / float(columns)
	var bar_width := step * 0.65
	draw_line(
		Vector2(area.position.x, area.end.y),
		Vector2(area.end.x, area.end.y),
		Color(UiPalette.BRASS_MID, 0.8),
		1.5
	)
	for cost in range(MIN_COST, _display_max + 1):
		var index := cost - MIN_COST
		var count: int = _counts[cost]
		var x := area.position.x + index * step + (step - bar_width) * 0.5
		_draw_track(ci, Rect2(x, area.position.y, bar_width, area.size.y))
		if count > 0:
			var height := area.size.y * float(count) / float(peak)
			_draw_bar(ci, Rect2(x, area.end.y - height, bar_width, height))
			_label(
				Vector2(x, area.end.y - height - 5),
				str(count),
				14,
				UiPalette.TEXT_OFFWHITE,
				bar_width
			)
		_label(
			Vector2(x, area.end.y + 18),
			str(cost),
			14,
			UiPalette.BRASS_HIGHLIGHT,
			bar_width
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


## 数字は棒の幅に対して中央揃えで描く(半角の幅を決め打ちで引くと2桁でずれる)。
func _label(pos: Vector2, text: String, font_size: int, color: Color, width: float = -1.0) -> void:
	var align := HORIZONTAL_ALIGNMENT_CENTER if width > 0.0 else HORIZONTAL_ALIGNMENT_LEFT
	draw_string(_font, pos, text, align, width, font_size, color)


## プールに実在する最大のコスト。
func _pool_max_cost() -> int:
	var top := MIN_COLUMNS
	for card in CardLibrary.all_cards():
		top = maxi(top, mini(card.cost, MAX_COST))
	return top
