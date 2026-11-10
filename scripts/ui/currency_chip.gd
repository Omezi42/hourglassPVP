class_name CurrencyChip
extends Control
## 砂金の残高を出す硝子の小さな札(GameDesign.md 9章・15章)。左に金貨の印、「砂金」、右に残高。
## **残高の見た目と文字列をここへ集める**(画面ごとに表記が割れないように)。
##
## 増えたときは短く脈打たせ、数字を数え上げる。**出す情報は増やさない**——
## 対局で得た額は結果パネルが1行で示しており(15章)、ここは残高だけを持つ。

## 数え上げにかける時間。長いと画面を離れるまでに終わらない。
const COUNT_DURATION := 0.5
## 増えたときの脈。縁を照りへ寄せてから戻す。
const PULSE_DURATION := 0.45
const HEIGHT := 34.0
## 金貨の半径・数値と単位の字の大きさ(いずれも札の高さに対する比)。
## **単位より数値を大きくする**——残高そのものが読みたいもので、「砂金」は毎回同じ語のため。
const COIN_RATIO := 0.34
const COIN_ICON_RATIO := 0.2
const VALUE_RATIO := 0.40
const UNIT_RATIO := 0.28
const VALUE_MIN_SIZE := UiPalette.T_SMALL
const UNIT_MIN_SIZE := UiPalette.T_MICRO
## 金貨と単位のあいだ・単位と数値のあいだ・右端の余白(高さに対する比)。
const COIN_GAP_RATIO := 0.06
const VALUE_GAP_RATIO := 0.30
const RIGHT_PAD_RATIO := 0.38
const LIFT := 0.6
const PULSE_GLOW := Color(1.0, 0.82, 0.45, 0.35)

## 大きさの倍率(`height_override` が無いときの高さへ掛ける)。
var scale_factor := 1.0:
	set(value):
		scale_factor = maxf(value, 0.1)
		if _font != null:
			_relayout()
		queue_redraw()
## 面の高さを外から決める(0 なら倍率から求める)。ホームのヘッダーでは他の部品と高さを揃える。
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


## 着地の合図(GameDesign.md 9章)。**数値は変えない**——飛んできた粒が届いた瞬間に
## 脈だけを出す。実際の残高反映は、呼び出し側が別途 `set_amount()` で行う
## (ミッション受取は通信が確定するまで正しい残高を知らないため、脈と数値を分けている)。
func bump() -> void:
	if _tween != null and _tween.is_valid():
		_tween.kill()
	_tween = create_tween()
	_tween.tween_method(_set_pulse, 1.0, 0.0, PULSE_DURATION)


## 桁が増えても文字が枠から出ないよう、幅は中身から決める。
func _relayout() -> void:
	if _font == null:
		return
	var height := _height()
	custom_minimum_size.y = height
	custom_minimum_size.x = (
		height * (1.0 + COIN_GAP_RATIO + VALUE_GAP_RATIO + RIGHT_PAD_RATIO)
		+ _text_width(CurrencyRules.CURRENCY_NAME, _unit_font_size())
		+ _text_width(_value_text(), _font_size())
	)
	size.x = custom_minimum_size.x


func _draw() -> void:
	if _font == null:
		return
	var ci := get_canvas_item()
	var height := _height()
	var rect := Rect2(Vector2(0.0, (size.y - height) * 0.5), Vector2(size.x, height))
	var mid := rect.get_center().y
	UiKit.glass(ci, rect, height * 0.5, LIFT, UiKit.GLASS_ALPHA, [], _pulse)
	var coin := Vector2(rect.position.x + height * 0.5, mid)
	var coin_radius := height * COIN_RATIO
	if _pulse > 0.0:
		UiKit.glow(ci, coin, Vector2.ONE * height, Color(PULSE_GLOW, PULSE_GLOW.a * _pulse))
	UiKit.vgrad(
		ci,
		UiKit.ellipse(coin, Vector2(coin_radius, coin_radius)),
		[[0.0, UiPalette.SAND_HI], [1.0, UiPalette.SAND_DEEP]],
		true
	)
	var icon := height * COIN_ICON_RATIO
	draw_texture_rect(
		UiPaint.HOURGLASS_ICON,
		Rect2(coin - Vector2(icon, icon), Vector2(icon, icon) * 2.0),
		false,
		UiPalette.BRASS_INK
	)
	var unit_size := _unit_font_size()
	var unit_x := rect.position.x + height * (1.0 + COIN_GAP_RATIO)
	draw_string(
		_font,
		Vector2(unit_x, _baseline(mid, unit_size)),
		CurrencyRules.CURRENCY_NAME,
		HORIZONTAL_ALIGNMENT_LEFT,
		-1,
		unit_size,
		UiPalette.MUTED
	)
	var value_size := _font_size()
	draw_string(
		_font,
		Vector2(rect.position.x, _baseline(mid, value_size)),
		_value_text(),
		HORIZONTAL_ALIGNMENT_RIGHT,
		rect.size.x - height * RIGHT_PAD_RATIO,
		value_size,
		UiPalette.IVORY.lerp(Color.WHITE, _pulse)
	)


## 行の上下の中央が `mid` に来る基準線。
func _baseline(mid: float, px: int) -> float:
	return mid + (_font.get_ascent(px) - _font.get_descent(px)) * 0.5


func _font_size() -> int:
	return maxi(roundi(_height() * VALUE_RATIO), VALUE_MIN_SIZE)


func _unit_font_size() -> int:
	return maxi(roundi(_height() * UNIT_RATIO), UNIT_MIN_SIZE)


func _value_text() -> String:
	return CurrencyRules.amount_text(roundi(_shown))


func _text_width(text: String, font_size: int) -> float:
	return _font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x


## 面の高さ。`height_override` が優先で、無ければ倍率から求める。
func _height() -> float:
	return height_override if height_override > 0.0 else HEIGHT * scale_factor
