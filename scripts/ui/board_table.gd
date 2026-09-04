class_name BoardTable
extends Control
## 対局盤面の卓(GameDesign.md 9章)。**木の額 / その内側に敷いたプレイマット /
## 中央を通る真鍮のレール**の3層で作る。
##
## 以前は平らな暗い台形1枚で、面が塗られていても「物を置き合う卓」には見えていなかった。
## 3層にすることで、駒が卓の上の物として読める。
##
## **マットは自分と相手で別々に敷く**(上半分が相手 / 下半分が自分)。描画そのものは
## `PlaymatPaint` が持ち、ショップの見本と同じ関数を通す(買う前に見た絵と食い違わないため)。
##
## 色は `UiPalette`、点列の生成は `UiPaint` を経由する。`Control._draw()` は
## `CanvasItem` の `draw_*` を直接呼べるため、RID を取る `UiPaint` へは
## `self.get_canvas_item()` を渡す。

## 木の額の太さ。
const FRAME_WIDTH := 14.0
const DIVIDER_RATIO := 0.5
const RAIL_HEIGHT := 10.0
const MEDALLION_OUTER_RADIUS := 26.0
const MEDALLION_INNER_RADIUS := 15.0

## 上半分(相手)と下半分(自分)へ敷くマット。既定は「砂の海」。
var foe_mat := PlaymatLibrary.DEFAULT_ID:
	set(value):
		foe_mat = value
		if _foe_layer != null:
			_foe_layer.mat_id = value
var own_mat := PlaymatLibrary.DEFAULT_ID:
	set(value):
		own_mat = value
		if _own_layer != null:
			_own_layer.mat_id = value

## マットは**切り抜きの効く層**として持つ(下記)。
var _foe_layer: MatLayer
var _own_layer: MatLayer
var _rail_layer: Control
var _medallion_angle := 0.0
var _medallion_glow := 0.0
var _tween: Tween


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_PASS
	_build_layers()


## **マットは切り抜きの効く層として敷く。**模様(砂紋の弧・唐草の蔓)は矩形の外まで
## 伸びるため、`_draw()` で直に描くと卓の外——情報帯や手札の上——へ漏れる
## (実際に漏れた)。`clip_contents` を立てた `Control` を1枚ずつ置いて内側で描かせる。
##
## **層は子ノードにする。**`Control._draw()` は自分の子より背面に描かれるため、
## 木の額はこのクラスが描き、その上へマット、さらにその上へレールの層を重ねる。
func _build_layers() -> void:
	_foe_layer = MatLayer.new()
	_foe_layer.mat_id = foe_mat
	add_child(_foe_layer)
	_own_layer = MatLayer.new()
	_own_layer.mat_id = own_mat
	add_child(_own_layer)
	_rail_layer = Control.new()
	_rail_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_rail_layer.draw.connect(_draw_rail_layer)
	add_child(_rail_layer)
	_layout_layers()


func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED:
		_layout_layers()


func _layout_layers() -> void:
	if _foe_layer == null:
		return
	var inner := Rect2(Vector2.ZERO, size).grow(-FRAME_WIDTH)
	var half := inner.size.y * DIVIDER_RATIO
	_foe_layer.position = inner.position
	_foe_layer.size = Vector2(inner.size.x, half)
	_own_layer.position = Vector2(inner.position.x, inner.position.y + half)
	_own_layer.size = Vector2(inner.size.x, half)
	_rail_layer.position = Vector2.ZERO
	_rail_layer.size = size
	_rail_layer.queue_redraw()


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		if mb.pressed and mb.button_index == MOUSE_BUTTON_LEFT:
			var center := Vector2(size.x * 0.5, size.y * DIVIDER_RATIO)
			if mb.position.distance_to(center) <= MEDALLION_OUTER_RADIUS + 10.0:
				_interact_medallion()


func _interact_medallion() -> void:
	if _tween != null and _tween.is_valid():
		_tween.kill()
	_tween = create_tween()
	(
		_tween
		. parallel()
		. tween_property(self, "_medallion_angle", _medallion_angle + PI * 0.5, 0.35)
		. set_trans(Tween.TRANS_BACK)
		. set_ease(Tween.EASE_OUT)
	)
	_tween.parallel().tween_property(self, "_medallion_glow", 1.0, 0.1)
	_tween.chain().tween_property(self, "_medallion_glow", 0.0, 0.25)


func _process(_delta: float) -> void:
	if _medallion_glow > 0.0 or (_tween != null and _tween.is_valid()):
		if _rail_layer != null:
			_rail_layer.queue_redraw()


## 木の額だけを描く。マットとレールは層(子)が描く。
func _draw() -> void:
	_draw_frame(get_canvas_item())


func _draw_rail_layer() -> void:
	var ci := _rail_layer.get_canvas_item()
	UiPaint.draw_inner_shadow(
		ci, Rect2(Vector2.ZERO, size).grow(-FRAME_WIDTH), 6.0, 6, 9, Color(0, 0, 0), 0.85
	)
	_draw_rail(ci)


## 木の額。卓の外周を囲う枠で、マットはこの内側へ敷く。
func _draw_frame(ci: RID) -> void:
	var rect := Rect2(Vector2.ZERO, size)
	var points := UiPaint.rounded_rect_points_uniform(rect, 18.0, 8)
	(
		UiPaint
		. fill_gradient_polygon(
			ci,
			points,
			rect,
			[
				[0.0, RoomPaint.WOOD_TOP.lightened(0.10)],
				[0.5, RoomPaint.WOOD_MID],
				[1.0, RoomPaint.WOOD_DARK],
			]
		)
	)
	UiPaint.apply_grain(ci, rect, 0.07)
	UiPaint.draw_bevel(ci, points, Color(0.60, 0.47, 0.28), Color(0.05, 0.03, 0.02), 3.0, false)


## 中央のレールと紋章。**陣地の境目**を真鍮の物体として通し、盤面が対面していることを示す。
func _draw_rail(ci: RID) -> void:
	var y := size.y * DIVIDER_RATIO
	var rail := Rect2(
		FRAME_WIDTH + 6.0, y - RAIL_HEIGHT * 0.5, size.x - (FRAME_WIDTH + 6.0) * 2.0, RAIL_HEIGHT
	)
	(
		UiPaint
		. fill_gradient_polygon(
			ci,
			UiPaint.rounded_rect_points_uniform(rail, RAIL_HEIGHT * 0.5, 4),
			rail,
			[
				[0.0, UiPalette.BRASS_HIGHLIGHT],
				[0.45, UiPalette.BRASS_MID],
				[1.0, UiPalette.BRASS_DARK],
			]
		)
	)
	var center := Vector2(size.x * 0.5, y)
	var glow: float = _medallion_glow
	(
		UiPaint
		. fill_gradient_polygon(
			ci,
			UiPaint.circle_points(center, MEDALLION_OUTER_RADIUS, 26),
			Rect2(
				center - Vector2(MEDALLION_OUTER_RADIUS, MEDALLION_OUTER_RADIUS),
				Vector2(MEDALLION_OUTER_RADIUS, MEDALLION_OUTER_RADIUS) * 2.0
			),
			[
				[0.0, UiPalette.BRASS_LIGHT.lerp(UiPalette.BRASS_HIGHLIGHT, glow)],
				[1.0, UiPalette.BRASS_DARK],
			]
		)
	)
	UiPaint.draw_ring(ci, center, MEDALLION_OUTER_RADIUS, Color(0.05, 0.035, 0.02), 2.4, 26)
	var emblem := UserProfileLibrary.get_icon_texture(UserProfileLibrary.DEFAULT_ICON_ID)
	if emblem != null:
		_rail_layer.draw_texture_rect(
			emblem,
			Rect2(center - Vector2(17, 17), Vector2(34, 34)),
			false,
			Color(0.16, 0.10, 0.04).lerp(Color(0.42, 0.28, 0.10), glow)
		)
	# 歯車の意匠(押すと回る)。
	for i in 4:
		var rad := _medallion_angle + i * (PI * 0.5)
		var dir := Vector2(cos(rad), sin(rad))
		_rail_layer.draw_line(
			center + dir * MEDALLION_INNER_RADIUS,
			center + dir * MEDALLION_OUTER_RADIUS,
			Color(0.10, 0.065, 0.03, 0.75 + glow * 0.25),
			2.0
		)


## マット1枚ぶんの層。**模様が矩形の外へ出ないよう `clip_contents` を立てる。**
class MatLayer:
	extends Control

	var mat_id := PlaymatLibrary.DEFAULT_ID:
		set(value):
			mat_id = value
			queue_redraw()

	func _init() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		clip_contents = true

	func _draw() -> void:
		PlaymatPaint.draw_mat(self, Rect2(Vector2.ZERO, size), mat_id)
