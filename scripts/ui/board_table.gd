class_name BoardTable
extends Control
## 対局盤面の卓(GameDesign.md 9章)。**濃紺のフェルト(背面) / その上に敷いた
## プレイマット / 木の額とレール(前面)**の3層で作る。
##
## 以前は平らな暗い台形1枚で、面が塗られていても「物を置き合う卓」には見えていなかった。
## 3層にすることで、駒が卓の上の物として読める。
##
## **木の額はマットより手前(前面)に描く**(GameDesign.md 9章「対局画面の再構築」)。
## 卓は台形だがマットの層は矩形のまま(狭めない)のため、そのままだと矩形の隅が
## 額の内側の斜辺からはみ出す。額を「外側の台形−内側の台形」のリングとしてマットより
## 前へ描くことで、そのはみ出しを上から覆い隠す(`_draw_frame_ring()`)。
##
## **マットは自分と相手で別々に敷く**(上半分が相手 / 下半分が自分)。描画そのものは
## `PlaymatPaint` が持ち、ショップの見本と同じ関数を通す(買う前に見た絵と食い違わないため)。
##
## 色は `UiPalette`、点列の生成は `UiPaint` を経由する。`Control._draw()` は
## `CanvasItem` の `draw_*` を直接呼べるため、RID を取る `UiPaint` へは
## `self.get_canvas_item()` を渡す。

## 木の額の太さ。
const FRAME_WIDTH := 20.0
const DIVIDER_RATIO := 0.5
const RAIL_HEIGHT := 10.0
const MEDALLION_OUTER_RADIUS := 26.0
const MEDALLION_INNER_RADIUS := 15.0

## 奥行き(GameDesign.md 9章「対局画面の再構築」)。奥(上)の辺を左右それぞれこの
## 分だけ狭め、卓を「手前が広く奥が狭い」台形として描く。
const PERSPECTIVE_INSET := 22.0
const FRAME_CORNER_RADIUS := 10.0
const CORNER_SCROLL_SIZE := 40.0

## 上半分(相手)と下半分(自分)へ敷くマット。既定は「なし」(何も敷かない)。
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
## このクラスはフェルトだけを描き、その上へマット、さらにその上へ木の額(リング)と
## レールを描く `_rail_layer` を重ねる(額がマット矩形の隅を覆い隠せるようにするため)。
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


## マットの層(GameDesign.md 9章「対局画面の再構築」)。**各半分の最も広い幅**
## (=矩形のまま、狭めない)に戻す。額が台形のため矩形のままだと隅がはみ出すが、
## それは前面の額のリング(`_draw_frame_ring()`)が上から覆い隠す。
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


## 背面には濃紺のフェルト(床側)だけを描く。木の額はマットより手前(`_rail_layer`)
## へ回し、矩形のマットの隅を上から覆い隠す(GameDesign.md 9章「対局画面の再構築」)。
func _draw() -> void:
	_draw_felt(get_canvas_item())


func _draw_rail_layer() -> void:
	var ci := _rail_layer.get_canvas_item()
	var inner := Rect2(Vector2.ZERO, size).grow(-FRAME_WIDTH)
	_draw_frame_ring(ci)
	UiPaint.draw_inner_shadow(ci, inner, 6.0, 6, 9, Color(0, 0, 0), 0.85)
	_draw_rail(ci)


## 木の額。**外側の台形−内側の台形のリング**として、マットより手前(`_rail_layer`)へ
## 描く(GameDesign.md 9章「対局画面の再構築」)。矩形のままのマットの隅がリングの
## 内側の縁より外へはみ出さないため、上から覆い隠せる。外周と内周の点列を
## 同じ分割数で作り、対応する点どうしを結んで四角形の帯を1周ぶん敷き詰める。
func _draw_frame_ring(ci: RID) -> void:
	var outer_rect := Rect2(Vector2.ZERO, size)
	var inner_rect := outer_rect.grow(-FRAME_WIDTH)
	var outer_points := _trapezoid_points(outer_rect, PERSPECTIVE_INSET, FRAME_CORNER_RADIUS, 6)
	var inner_points := _trapezoid_points(
		inner_rect, PERSPECTIVE_INSET, FRAME_CORNER_RADIUS * 0.5, 6
	)
	var stops := [
		[0.0, RoomPaint.WOOD_TOP.lightened(0.22)],
		[0.5, RoomPaint.WOOD_TOP],
		[1.0, RoomPaint.WOOD_MID],
	]
	var count := mini(outer_points.size(), inner_points.size())
	for i in count:
		var j := (i + 1) % count
		var quad := PackedVector2Array(
			[outer_points[i], outer_points[j], inner_points[j], inner_points[i]]
		)
		UiPaint.fill_gradient_polygon(ci, quad, outer_rect, stops)
	# グレインは額の帯だけへ(felt/マットの中心まで洗わないよう、四辺の帯に留める)。
	var band := FRAME_WIDTH + PERSPECTIVE_INSET
	UiPaint.apply_grain(ci, Rect2(0.0, 0.0, size.x, band), 0.07)
	UiPaint.apply_grain(ci, Rect2(0.0, size.y - band, size.x, band), 0.07)
	UiPaint.apply_grain(ci, Rect2(0.0, 0.0, band, size.y), 0.07)
	UiPaint.apply_grain(ci, Rect2(size.x - band, 0.0, band, size.y), 0.07)
	UiPaint.draw_bevel(
		ci, outer_points, Color(0.60, 0.47, 0.28), Color(0.05, 0.03, 0.02), 3.0, false
	)
	_draw_corner_scrolls(ci, outer_rect)


## 額の内側を濃紺のフェルトとして描く(GameDesign.md 9章「対局画面の再構築」)。
## 上端が明るく下端がわずかに暗いのはこのグラデーション自体が持つ
## (以前の `_draw_ambient_light()` はここへ統合した)。マット「なし」のときは
## このフェルトがそのまま見える。
func _draw_felt(ci: RID) -> void:
	var inner := Rect2(Vector2.ZERO, size).grow(-FRAME_WIDTH)
	var points := _trapezoid_points(inner, PERSPECTIVE_INSET, FRAME_CORNER_RADIUS * 0.5, 6)
	UiPaint.fill_gradient_polygon(
		ci, points, inner, [[0.0, UiPalette.FELT_NAVY_TOP], [1.0, UiPalette.FELT_NAVY_BOTTOM]]
	)
	UiPaint.apply_grain(ci, inner, 0.06)


## 台形の外周点列。奥(上)の辺を `inset` ぶん左右へ狭め、4隅を半径 `radius` の
## 二次ベジエで丸める(角丸矩形のように直角ではないため、専用の生成関数を持つ)。
func _trapezoid_points(
	rect: Rect2, inset: float, radius: float, segments: int
) -> PackedVector2Array:
	var corners: Array[Vector2] = [
		Vector2(rect.position.x + inset, rect.position.y),
		Vector2(rect.end.x - inset, rect.position.y),
		rect.end,
		Vector2(rect.position.x, rect.end.y),
	]
	var points := PackedVector2Array()
	var count := corners.size()
	for i in count:
		var prev: Vector2 = corners[(i - 1 + count) % count]
		var curr: Vector2 = corners[i]
		var next: Vector2 = corners[(i + 1) % count]
		var edge_in: float = (curr - prev).length()
		var edge_out: float = (next - curr).length()
		var r: float = minf(radius, minf(edge_in, edge_out) * 0.4)
		var dir_in := (curr - prev).normalized()
		var dir_out := (next - curr).normalized()
		var p_in := curr - dir_in * r
		var p_out := curr + dir_out * r
		for s in range(segments + 1):
			var t: float = float(s) / float(segments)
			# 二次ベジエ(制御点=元の角)で角丸に近づける。
			points.append(p_in.lerp(curr, t).lerp(curr.lerp(p_out, t), t))
	return UiPaint.dedupe_ring(points)


## 四隅に添える金の唐草。額(木の面)の上へ小さな渦として重ねる。
func _draw_corner_scrolls(ci: RID, rect: Rect2) -> void:
	var color := Color(UiPalette.BRASS_HIGHLIGHT, 0.35)
	var corners := [
		[Vector2(rect.position.x + PERSPECTIVE_INSET, rect.position.y), Vector2(1, 1)],
		[Vector2(rect.end.x - PERSPECTIVE_INSET, rect.position.y), Vector2(-1, 1)],
		[rect.end, Vector2(-1, -1)],
		[Vector2(rect.position.x, rect.end.y), Vector2(1, -1)],
	]
	for corner in corners:
		var origin: Vector2 = corner[0]
		var dir: Vector2 = corner[1]
		var base := origin + dir * (CORNER_SCROLL_SIZE * 0.42)
		UiPaint.draw_ring(ci, base, CORNER_SCROLL_SIZE * 0.22, color, 1.6, 16)
		UiPaint.draw_ring(
			ci, base + dir * CORNER_SCROLL_SIZE * 0.24, CORNER_SCROLL_SIZE * 0.11, color, 1.3, 12
		)
		var curve := PackedVector2Array()
		for i in 9:
			var t: float = float(i) / 8.0
			var angle: float = lerpf(PI, PI * 1.85, t)
			curve.append(
				base + Vector2(cos(angle) * dir.x, sin(angle) * dir.y) * CORNER_SCROLL_SIZE * 0.3
			)
		# `ci` は呼び出し元のレイヤーの canvas item のため、`self.draw_polyline()` ではなく
		# `RenderingServer` 経由で描く(`_draw_frame_ring()` からは前面のレイヤーを渡すため)。
		var curve_colors := PackedColorArray()
		curve_colors.resize(curve.size())
		curve_colors.fill(color)
		RenderingServer.canvas_item_add_polyline(ci, curve, curve_colors, 1.3, true)


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
