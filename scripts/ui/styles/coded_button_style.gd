class_name CodedButtonStyle
extends StyleBox
## コード描画のボタンの面(GameDesign.md 9章「ボタンは役割で面を変える」/ Architecture.md 4.0節)。
## 主 = 真鍮の面(`filled`)/ 副 = 硝子の面(既定)/ 取り返せない操作 = 硝子に赤い縁(`danger`)。
## 押せない状態は面を変えず、字と縁だけを沈める。素材そのものは `UiKit` が描く。
##
## 乗る・押すの動きは `hover_amount` / `press_amount`(0〜1)で描き分ける。`ButtonFeel` が
## ボタンごとの複製を持たせて尺つきで動かし、そのときは `bind_button()` で渡されたボタンから
## 押せない・選ばれている(トグル)を描くたびに読む。`.tres` をそのまま当てたボタンは
## `variant` の4状態が一瞬で切り替わる。

enum State { NORMAL, HOVER, PRESSED, DISABLED }
enum Shape { ROUNDED_RECT, CIRCLE, PILL, CHEVRON_LEFT }
## 紋章の配置。値は `.tres` が整数で保存する。いま描き分けるのは CENTER と RIGHT_INSET。
enum EmblemPlacement { CENTER, UPPER, RIGHT_INSET, TOP_BADGE }

## 乗ったとき面が浮く量(px)と、押したとき面が縮む倍率。
const LIFT := 2.0
const PRESS_SCALE := 0.97
## 押したとき上の光の膜が消える(硝子の面の `film`)。
const PRESSED_FILM := 0.0
## 押せないボタンの縁の濃さ。
const DISABLED_RIM_ALPHA := 0.45
## 選ばれている(トグルが入っている)ボタンの縁の照り。
const SELECTED_LIT := 0.7
## 影の深さ(硝子のボタンは面より浅く)。
const BUTTON_LIFT := 0.6
## 面の内側で中身を描いてよい範囲までの余白(縁の太さへ足す)。
const INNER_PAD := 3.0

## CHEVRON_LEFT の肩(尖端から斜辺でつながる直線の終わり)の位置。幅に対する比。
const CHEVRON_SHOULDER_RATIO := 0.34
const CHEVRON_SEGMENTS := 6

const EMBLEM_CENTER_SIZE_RATIO := 0.40
const EMBLEM_RIGHT_INSET_MARGIN := 26.0
const EMBLEM_RIGHT_INSET_SIZE_RATIO := 0.28

## 古い呼び出し(`HomeTile`)が読む、押し込みの沈み。
const PANEL_PRESSED_SINK := 2.0

@export var filled: bool = false
@export var variant: State = State.NORMAL
@export var shape: Shape = Shape.ROUNDED_RECT
@export var emblem: UiPaint.Emblem = UiPaint.Emblem.NONE
@export var emblem_placement: EmblemPlacement = EmblemPlacement.CENTER
@export var danger: bool = false

var hover_amount := 0.0
var press_amount := 0.0

var _button: WeakRef


## このスタイルを持つボタン。押せない・選ばれているを描くたびに読む(`ButtonFeel`)。
func bind_button(button: BaseButton) -> void:
	_button = weakref(button)


func _draw(to_canvas_item: RID, rect: Rect2) -> void:
	var hover := hover_amount
	var press := press_amount
	var disabled := variant == State.DISABLED
	var selected := false
	var button: BaseButton = _button.get_ref() if _button != null else null
	if button != null:
		disabled = button.disabled
		selected = button.toggle_mode and button.button_pressed
	else:
		hover = 1.0 if variant == State.HOVER else 0.0
		press = 1.0 if variant == State.PRESSED else 0.0
	if disabled:
		hover = 0.0
		press = 0.0

	var face := rect
	face.position.y -= LIFT * hover * (1.0 - press)
	var scaled := face.size * lerpf(1.0, PRESS_SCALE, press)
	face = Rect2(face.get_center() - scaled * 0.5, scaled)

	if filled:
		_draw_brass(to_canvas_item, face, press, hover, disabled)
	else:
		_draw_glass(to_canvas_item, face, press, hover, disabled, selected)
	if emblem != UiPaint.Emblem.NONE:
		_draw_emblem(to_canvas_item, face, disabled)


func _draw_brass(ci: RID, face: Rect2, press: float, hover: float, disabled: bool) -> void:
	if shape == Shape.CHEVRON_LEFT:
		UiKit.shadow(ci, face, _corner(face), UiKit.shadow_blur(face), UiKit.BRASS_SHADOW_ALPHA)
		UiKit.brass_shape(ci, _chevron(face), face, press, hover, disabled)
		return
	UiKit.brass(ci, face, _corner(face), press, hover, disabled)


func _draw_glass(
	ci: RID, face: Rect2, press: float, hover: float, disabled: bool, selected: bool
) -> void:
	var lit := maxf(hover, SELECTED_LIT if selected else 0.0)
	var rim: Array = []
	if danger:
		rim = UiKit.rim_color(UiPalette.FOE.lerp(UiPalette.DANGER_TEXT, hover))
	elif selected:
		rim = UiKit.rim_color(UiPalette.SAND_HI)
	if disabled:
		rim = _faded(UiKit.rim_brass() if rim.is_empty() else rim)
	var film := lerpf(1.0, PRESSED_FILM, press)
	var lift := BUTTON_LIFT * (1.0 + hover) * (1.0 - press)
	if shape == Shape.CHEVRON_LEFT:
		UiKit.shadow(ci, face, _corner(face), UiKit.shadow_blur(face) * lift, UiKit.SHADOW_ALPHA)
		UiKit.glass_shape(ci, _chevron(face), face, UiKit.GLASS_ALPHA, rim, lit, film)
		return
	UiKit.glass(ci, face, _corner(face), lift, UiKit.GLASS_ALPHA, rim, lit, film)


func _draw_emblem(ci: RID, face: Rect2, disabled: bool) -> void:
	var tint := UiPalette.BRASS_INK if filled else UiPalette.GOLD
	if disabled:
		tint = UiPalette.FAINT
	if emblem_placement == EmblemPlacement.RIGHT_INSET:
		var side: float = face.size.y * EMBLEM_RIGHT_INSET_SIZE_RATIO
		var at := Vector2(face.end.x - EMBLEM_RIGHT_INSET_MARGIN - side, face.get_center().y)
		UiPaint.draw_emblem(ci, emblem, at, side, tint)
		return
	var size: float = minf(face.size.x, face.size.y) * EMBLEM_CENTER_SIZE_RATIO
	UiPaint.draw_emblem(ci, emblem, face.get_center(), size, tint)


func _corner(rect: Rect2) -> float:
	match shape:
		Shape.CIRCLE:
			return minf(rect.size.x, rect.size.y) * 0.5
		Shape.PILL:
			return rect.size.y * 0.5
		Shape.CHEVRON_LEFT:
			return UiKit.radius(rect)
		_:
			return UiKit.button_radius(rect)


func _chevron(rect: Rect2) -> PackedVector2Array:
	return UiPaint.chevron_left_points(
		rect, UiKit.radius(rect), CHEVRON_SEGMENTS, CHEVRON_SHOULDER_RATIO
	)


static func _faded(stops: Array) -> Array:
	var result := []
	for stop in stops:
		var color: Color = stop[1]
		result.append([stop[0], Color(UiPaint.disabled_tone(color), DISABLED_RIM_ALPHA)])
	return result


## 角の丸み(ROUNDED_RECT)。ボタンに重ねて縁を描く側(選択の枠など)が角をそろえるのに使う。
static func corner_radius(rect: Rect2) -> float:
	return UiKit.button_radius(rect)


## 縁の太さ。
static func frame_thickness(rect: Rect2) -> float:
	return UiKit.line_w(rect)


## **ボタンの中身を描いてよい範囲**(縁の内側)。紋章や透かしを矩形いっぱいに描くと縁へ
## 載り上がるため、内側の矩形はここが唯一の出どころになる。
static func inner_rect(rect: Rect2) -> Rect2:
	return rect.grow(-(UiKit.line_w(rect) + INNER_PAD))
