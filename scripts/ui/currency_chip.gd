class_name CurrencyChip
extends Control
## 砂金の残高を出す真鍮のチップ(GameDesign.md 9章・15章)。
##
## 以前は画面ごとに枠を持たない `Label` を1つ置いており、周りが真鍮の部品で組まれた
## ホームのヘッダーやショップのヘッダーで、そこだけ文字が浮いていた。表記も画面ごとに
## 「砂金:0」「砂金 0」「砂金: 0」と割れていたため、**残高の見た目と文字列をここへ集める**。
##
## 増えたときは短く脈打たせ、数字を数え上げる。**出す情報は増やさない**——
## 対局で得た額は結果パネルが1行で示しており(15章)、ここは残高だけを持つ。

## 数え上げにかける時間。長いと画面を離れるまでに終わらない。
const COUNT_DURATION := 0.5
## 増えたときの脈。地の色を琥珀へ寄せてから戻す。
const PULSE_DURATION := 0.45
const HEIGHT := 34.0
const PAD_X := 12.0
const EMBLEM_SIZE := 18.0
const GAP := 7.0
## 数値の字の大きさ。**単位より数値を大きくする**——残高そのものが読みたいもので、
## 「砂金」は毎回同じ語であり、同じ大きさで並べると数値がそのぶん埋もれる。
const FONT_SIZE := 18
## 単位「砂金」の字の大きさ(数値に対する比)。
const UNIT_RATIO := 0.72
const CORNER := 8.0
## 紋章と文字を隔てる縦の細線。**紋章がただ左に置いてあるだけに見えないようにする。**
const DIVIDER_WIDTH := 1.0
const DIVIDER_INSET := 0.24
## 単位と数値のあいだ、紋章と仕切りのあいだ。
const UNIT_GAP := 6.0
const DIVIDER_GAP := 8.0

## 大きさの倍率。**ホーム画面のヘッダーだけ大きく出す**——面積に余裕があり、残高は
## 「押す前に分かるべきこと」の代表(GameDesign.md 9章)であるため。ショップのヘッダーは
## 主アクションの位置へ収めるので既定のまま。
var scale_factor := 1.0:
	set(value):
		scale_factor = maxf(value, 0.1)
		if _font != null:
			_relayout()
		queue_redraw()
## 面の高さを外から決める(0 なら倍率から求める)。**ホームのヘッダーでは名札と高さを
## 揃える**——左右で背丈が違うと、同じ帯に載っているものとして読めない。
var height_override := 0.0:
	set(value):
		height_override = maxf(value, 0.0)
		if _font != null:
			_relayout()
		queue_redraw()

var _amount := 0
## 表示中の値。数え上げの途中は残高と食い違う。
var _shown := 0.0
var _pulse := 0.0
var _font: Font
var _tween: Tween


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_font = get_theme_default_font()
	_relayout()


## 残高を入れ直す。`animate` が偽なら数え上げも脈も出さない(画面を開いた直後など、
## 増えたわけではないときに脈を出すと、何かを得たように読める)。
func set_amount(value: int, animate := true) -> void:
	var grew := animate and value > _amount
	_amount = value
	if _tween != null and _tween.is_valid():
		_tween.kill()
	if not grew:
		_shown = float(value)
		_pulse = 0.0
		_relayout()
		queue_redraw()
		return
	_tween = create_tween()
	_tween.set_parallel(true)
	_tween.tween_method(_set_shown, _shown, float(value), COUNT_DURATION)
	_tween.tween_method(_set_pulse, 1.0, 0.0, PULSE_DURATION)


func _set_shown(value: float) -> void:
	_shown = value
	_relayout()
	queue_redraw()


func _set_pulse(value: float) -> void:
	_pulse = value
	queue_redraw()


## 桁が増えても文字が枠から出ないよう、幅は中身から決める。
func _relayout() -> void:
	if _font == null:
		return
	var unit_width := _text_width(CurrencyRules.CURRENCY_NAME, _unit_font_size())
	var value_width := _text_width(_value_text(), _font_size())
	custom_minimum_size.y = _height()
	custom_minimum_size.x = (
		(PAD_X * 2.0 + EMBLEM_SIZE + DIVIDER_GAP * 2.0 + UNIT_GAP) * scale_factor
		+ unit_width
		+ value_width
	)
	size.x = custom_minimum_size.x


func _draw() -> void:
	if _font == null:
		return
	var ci := get_canvas_item()
	var height := _height()
	var rect := Rect2(Vector2(0.0, (size.y - height) * 0.5), Vector2(size.x, height))
	var points := UiPaint.rounded_rect_points_uniform(rect, CORNER * scale_factor, 6)
	var top := UiPalette.NAMEPLATE_PANEL_TOP.lerp(UiPalette.PANEL_AMBER_TOP, _pulse * 0.5)
	var bottom := UiPalette.NAMEPLATE_PANEL_BOTTOM.lerp(UiPalette.PANEL_AMBER_TOP, _pulse * 0.4)
	UiPaint.fill_gradient_polygon(ci, points, rect, [[0.0, top], [1.0, bottom]])
	UiPaint.apply_grain(ci, rect, 0.06)
	# 面取り。**平坦な1色の枠にしない**ための処理で、他の真鍮の部品と揃える。
	UiPaint.draw_bevel(
		ci,
		points,
		UiPalette.BRASS_HIGHLIGHT.lerp(Color(1, 1, 1, 1), _pulse * 0.6),
		UiPalette.BRASS_DARK,
		maxf(1.5 * scale_factor, 1.0),
		false
	)
	var outline := points.duplicate()
	outline.append(points[0])
	draw_polyline(outline, UiPalette.BRASS_MID.lerp(UiPalette.BRASS_HIGHLIGHT, _pulse), 2.0, true)

	var emblem := EMBLEM_SIZE * scale_factor
	var center := Vector2(
		rect.position.x + PAD_X * scale_factor + emblem * 0.5, rect.get_center().y
	)
	UiPaint.draw_emblem(ci, UiPaint.Emblem.HOURGLASS, center, emblem)

	var divider_x: float = center.x + emblem * 0.5 + DIVIDER_GAP * scale_factor
	var inset: float = rect.size.y * DIVIDER_INSET
	draw_line(
		Vector2(divider_x, rect.position.y + inset),
		Vector2(divider_x, rect.end.y - inset),
		Color(UiPalette.BRASS_MID, 0.7),
		DIVIDER_WIDTH * scale_factor
	)

	var baseline: float = rect.get_center().y + float(_font_size()) * 0.36
	var unit_x: float = divider_x + DIVIDER_GAP * scale_factor
	draw_string(
		_font,
		Vector2(unit_x, baseline),
		CurrencyRules.CURRENCY_NAME,
		HORIZONTAL_ALIGNMENT_LEFT,
		-1,
		_unit_font_size(),
		Color(UiPalette.BRASS_HIGHLIGHT, 0.72)
	)
	var value_x: float = (
		unit_x
		+ _text_width(CurrencyRules.CURRENCY_NAME, _unit_font_size())
		+ UNIT_GAP * scale_factor
	)
	# 数値は影を1pxずらして敷いてから重ねる(明るい真鍮の上でも輪郭が立つ)。
	var color := UiPalette.BRASS_HIGHLIGHT.lerp(Color(1, 1, 1, 1), _pulse)
	draw_string(
		_font,
		Vector2(value_x + 1.0, baseline + 1.0),
		_value_text(),
		HORIZONTAL_ALIGNMENT_LEFT,
		-1,
		_font_size(),
		Color(0.16, 0.11, 0.05, 0.55)
	)
	draw_string(
		_font,
		Vector2(value_x, baseline),
		_value_text(),
		HORIZONTAL_ALIGNMENT_LEFT,
		-1,
		_font_size(),
		color
	)


## 倍率を掛けた字の大きさ。
func _font_size() -> int:
	return int(round(float(FONT_SIZE) * scale_factor))


## 単位の字の大きさ。
func _unit_font_size() -> int:
	return maxi(int(round(float(_font_size()) * UNIT_RATIO)), 10)


func _value_text() -> String:
	return CurrencyRules.amount_text(roundi(_shown))


func _text_width(text: String, font_size: int) -> float:
	return _font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x


## 面の高さ。`height_override` が優先で、無ければ倍率から求める。
func _height() -> float:
	return height_override if height_override > 0.0 else HEIGHT * scale_factor
