class_name FlipRightGauge
extends Control
## 反転権(GameDesign.md 2章)ボタンの下に置く彫り込みの小さな札。
## 自分・相手それぞれの残り回数を、総回数ぶんの粒で並べて示す。

const GAUGE_SIZE := Vector2(108.0, 48.0)
const CORNER_RADIUS := 8.0
const PIP_RADIUS := 5.0
const PIP_STEP := 13.5
const PIP_START_X := 42.0
const PIP_SEGMENTS := 16
const PIP_EMPTY := Color(1, 1, 1, 0.10)
const ROW_Y := [13.0, 35.0]
const LABEL_X := 8.0
const LABEL_FONT_SIZE := UiPalette.T_MICRO
## 刻み線で粒が増えたとき、着いた粒の周りへ広がる輪(尺と、輪が広がる幅)。
const LAND_DURATION := 0.5
const LAND_RING_REACH := 7.0
const LAND_RING_WIDTH := 1.6
const OWN := 0
const FOE := 1

var _totals := [0, 0]
## 状態が持つ残り回数と、いま粒として見せている数。刻み線で増えた粒は、光が着くまで見せない。
var _real := [0, 0]
var _shown := [0, 0]
## 光が飛んでいる数と、状態の更新より先に着いた光の数(行ごと)。
var _flying := [0, 0]
var _credit := [0, 0]
var _seeded := false
var _land_row := -1
var _land_index := 0
var _land_left := 0.0
var _land_tween: Tween
var _font: Font


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	custom_minimum_size = GAUGE_SIZE
	size = GAUGE_SIZE


func _ready() -> void:
	_font = get_theme_default_font()
	if _font == null:
		_font = ThemeDB.fallback_font


func set_counts(own_remaining: int, own_total: int, foe_remaining: int, foe_total: int) -> void:
	_totals = [own_total, foe_total]
	var remaining := [own_remaining, foe_remaining]
	for row in 2:
		_apply(row, remaining[row])
	_seeded = true
	queue_redraw()


## 前の対局の数を消す。次の `set_counts()` を最初の1回として扱う。
func reset() -> void:
	if _land_tween != null and _land_tween.is_valid():
		_land_tween.kill()
	_real = [0, 0]
	_shown = [0, 0]
	_flying = [0, 0]
	_credit = [0, 0]
	_seeded = false
	_land_row = -1
	queue_redraw()


## 刻み線の光を迎える。**次に増える粒の位置**(全体座標)を返す。その粒は `land()` までは見せない。
func expect_gain(is_own: bool) -> Vector2:
	var row := OWN if is_own else FOE
	var index: int = _shown[row] + _flying[row]
	_flying[row] += 1
	return get_global_transform() * _pip_center(row, index)


## 光が着いた。held していた粒を見せ、着いた粒の周りへ輪を広げる。
func land(is_own: bool) -> void:
	var row := OWN if is_own else FOE
	_flying[row] = maxi(_flying[row] - 1, 0)
	if _shown[row] < _real[row]:
		_land_index = _shown[row]
		_shown[row] += 1
	else:
		_credit[row] += 1
		_land_index = maxi(_shown[row] - 1, 0)
	_land_row = row
	if _land_tween != null and _land_tween.is_valid():
		_land_tween.kill()
	_land_tween = create_tween()
	_land_tween.tween_method(_set_land_left, 1.0, 0.0, LAND_DURATION)
	queue_redraw()


func _set_land_left(value: float) -> void:
	_land_left = value
	queue_redraw()


func _apply(row: int, new_remaining: int) -> void:
	if not _seeded:
		_real[row] = new_remaining
		_shown[row] = new_remaining
		return
	var gained: int = new_remaining - _real[row]
	_real[row] = new_remaining
	if gained <= 0:
		_shown[row] = mini(_shown[row], new_remaining)
		return
	var early := mini(_credit[row], gained)
	_credit[row] -= early
	_shown[row] += early
	gained -= early
	var held := mini(_flying[row], gained)
	_shown[row] += gained - held


func _pip_center(row: int, index: int) -> Vector2:
	return Vector2(PIP_START_X + index * PIP_STEP, ROW_Y[row])


func _draw() -> void:
	UiKit.well(get_canvas_item(), Rect2(Vector2.ZERO, size), CORNER_RADIUS)
	_draw_row(OWN, "自分")
	_draw_row(FOE, "相手")


## 語(自分/相手)の右へ、総回数ぶんの粒を並べる。相手の行も同じ語彙で描き、
## 色でなく行頭の語だけで区別する。効果やソロの恩恵で総回数を超えて得た残りも粒で見せる。
func _draw_row(row: int, label_text: String) -> void:
	if _font == null:
		return
	var y: float = ROW_Y[row]
	var remaining: int = _shown[row]
	var total: int = _totals[row]
	var ci := get_canvas_item()
	var baseline := (
		y + (_font.get_ascent(LABEL_FONT_SIZE) - _font.get_descent(LABEL_FONT_SIZE)) * 0.5
	)
	draw_string(
		_font,
		Vector2(LABEL_X, baseline),
		label_text,
		HORIZONTAL_ALIGNMENT_LEFT,
		-1,
		LABEL_FONT_SIZE,
		UiPalette.MUTED
	)
	for i in maxi(total, remaining):
		var pip := UiKit.ellipse(
			Vector2(PIP_START_X + i * PIP_STEP, y), Vector2(PIP_RADIUS, PIP_RADIUS), PIP_SEGMENTS
		)
		if i < remaining:
			UiKit.vgrad(ci, pip, [[0.0, UiPalette.GOLD_HI], [1.0, UiPalette.SAND_DEEP]], true)
		else:
			UiKit.fill(ci, pip, PIP_EMPTY)
	if row == _land_row and _land_left > 0.0:
		var reach := PIP_RADIUS + LAND_RING_REACH * (1.0 - _land_left)
		ShapePaint.circle(
			ci,
			_pip_center(row, _land_index),
			reach,
			Color(UiPalette.GOLD_HI, 0.8 * _land_left),
			false,
			LAND_RING_WIDTH,
			true
		)
