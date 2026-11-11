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

## 額の太さ。細い暗い縁と真鍮の線だけにする(太い額は駒より目立つため。GameDesign.md 9章)。
const FRAME_WIDTH := 13.0
const DIVIDER_RATIO := 0.5
const RAIL_WIDTH := 2.4
const RAIL_SHADOW := Color(0, 0, 0, 0.5)
const RAIL_INSET := 6.0
const MEDALLION_OUTER_RADIUS := 19.0
const MEDALLION_INNER_RADIUS := 14.0
const MEDALLION_SPOKES := 4
const FRAME_STOPS := [[0.0, Color(0.30, 0.20, 0.13)], [1.0, Color(0.13, 0.08, 0.05)]]
const FRAME_EDGE_WIDTH := 2.0
const FELT_LINE_WIDTH := 2.0
const FELT_STOPS := [
	[0.0, Color(0.07, 0.09, 0.19)], [0.5, Color(0.10, 0.13, 0.27)], [1.0, Color(0.12, 0.16, 0.33)]
]
## 卓の中央へ落ちる光(吊りランプ)。大きさは卓の大きさに対する比。
const FELT_COOL_GLOW := Color(0.55, 0.65, 1.0, 0.10)
const FELT_COOL_RATIO := 0.46
const FELT_WARM_GLOW := Color(1.0, 0.85, 0.6, 0.07)
const FELT_WARM_RATIO := 0.3
## 四隅の金の唐草(フェルトの隅の小さな弧と点)。
const CORNER_ARC_RADIUS := 20.0
const CORNER_ARC_INSET := 10.0
const CORNER_DOT_RADIUS := 2.2
const CORNER_ALPHA := 0.5

## 奥行き(GameDesign.md 9章「対局画面の再構築」)。奥(上)の辺を左右それぞれこの
## 分だけ狭め、卓を「手前が広く奥が狭い」台形として描く。
const PERSPECTIVE_INSET := 22.0
const FRAME_CORNER_RADIUS := 10.0

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
	var mid := inner.position.y + inner.size.y * DIVIDER_RATIO
	_place_mat(_foe_layer, inner.position.y, mid)
	_place_mat(_own_layer, mid, inner.end.y)
	_foe_layer.queue_redraw()
	_own_layer.queue_redraw()
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
	_draw_frame_ring(ci)
	_draw_rail(ci)


## 額。**外側の台形−内側の台形のリング**として、マットより手前(`_rail_layer`)へ
## 描く。矩形のままのマットの隅がリングの内側の縁より外へはみ出さないため、上から覆い隠せる。
## 外周と内周の点列を同じ分割数で作り、対応する点どうしを結んで四角形の帯を1周ぶん敷き詰める。
func _draw_frame_ring(ci: RID) -> void:
	var outer_rect := Rect2(Vector2.ZERO, size)
	var inner_rect := outer_rect.grow(-FRAME_WIDTH)
	var outer_points := _trapezoid_points(outer_rect, PERSPECTIVE_INSET, FRAME_CORNER_RADIUS, 6)
	var inner_points := _trapezoid_points(
		inner_rect, PERSPECTIVE_INSET, FRAME_CORNER_RADIUS * 0.5, 6
	)
	var count := mini(outer_points.size(), inner_points.size())
	for i in count:
		var j := (i + 1) % count
		var quad := PackedVector2Array(
			[outer_points[i], outer_points[j], inner_points[j], inner_points[i]]
		)
		UiPaint.fill_gradient_polygon(ci, quad, outer_rect, FRAME_STOPS)
	UiKit.stroke(ci, outer_points, UiPalette.BRASS_INK, FRAME_EDGE_WIDTH)
	# フェルトの縁の真鍮の線(奥が沈み、手前が明るい)。
	UiKit.stroke_grad(
		ci, inner_points, [[0.0, UiPalette.BRASS], [1.0, UiPalette.GOLD]], FELT_LINE_WIDTH
	)
	_draw_corner_scrolls(ci, inner_rect)


## 額の内側を濃紺のフェルトとして描く。奥(相手の側)を沈め、吊りランプの光を卓の中央へ落とす。
## マット「なし」のときはこのフェルトがそのまま見える。
func _draw_felt(ci: RID) -> void:
	var inner := Rect2(Vector2.ZERO, size).grow(-FRAME_WIDTH)
	var points := _trapezoid_points(inner, PERSPECTIVE_INSET, FRAME_CORNER_RADIUS * 0.5, 6)
	UiPaint.fill_gradient_polygon(ci, points, inner, FELT_STOPS)
	var mid := Vector2(size.x * 0.5, size.y * DIVIDER_RATIO)
	UiKit.glow(ci, mid, size * FELT_COOL_RATIO, FELT_COOL_GLOW)
	UiKit.glow(ci, mid - Vector2(0, size.y * 0.1), size * FELT_WARM_RATIO, FELT_WARM_GLOW)


## マットの層を、卓の上端からの高さ `top`〜`bottom` の帯へ置く。**層の左右の端は、その帯の上端での
## 額の外側の斜辺に合わせる**(額は細いため、内側の矩形いっぱいに敷くと隅が額の外へはみ出す)。
## 模様の縁は額の内側の斜辺に沿わせる(`top_inset` / `bottom_inset`)。
func _place_mat(layer: MatLayer, top: float, bottom: float) -> void:
	var left := _outer_edge_x(top)
	layer.position = Vector2(left, top)
	layer.size = Vector2(size.x - left * 2.0, bottom - top)
	layer.top_inset = _inner_edge_x(top) - left
	layer.bottom_inset = _inner_edge_x(bottom) - left


## 額の外側・内側の斜辺の、高さ `y` での左端のx(右端は左右対称)。
func _outer_edge_x(y: float) -> float:
	return PERSPECTIVE_INSET * (1.0 - y / maxf(size.y, 1.0))


func _inner_edge_x(y: float) -> float:
	var span := maxf(size.y - FRAME_WIDTH * 2.0, 1.0)
	return FRAME_WIDTH + PERSPECTIVE_INSET * (1.0 - (y - FRAME_WIDTH) / span)


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


## 四隅に添える金の唐草。フェルトの隅へ小さな弧と点を置く。
func _draw_corner_scrolls(ci: RID, rect: Rect2) -> void:
	var color := Color(UiPalette.GOLD, CORNER_ALPHA)
	var inset := PERSPECTIVE_INSET
	var pad := CORNER_ARC_INSET
	var corners := [
		[Vector2(rect.position.x + inset + pad, rect.position.y + pad), 0.0],
		[Vector2(rect.end.x - inset - pad, rect.position.y + pad), PI * 0.5],
		[Vector2(rect.end.x - pad, rect.end.y - pad), PI],
		[Vector2(rect.position.x + pad, rect.end.y - pad), PI * 1.5],
	]
	for corner in corners:
		var at: Vector2 = corner[0]
		var angle: float = corner[1]
		var center := (
			at + Vector2(cos(angle + PI * 0.25), sin(angle + PI * 0.25)) * CORNER_ARC_RADIUS
		)
		ShapePaint.arc(
			ci, center, CORNER_ARC_RADIUS, angle + PI, angle + PI * 1.5, 12, color, 1.2, true
		)
		ShapePaint.circle(ci, at, CORNER_DOT_RADIUS, UiPalette.GOLD)


## 中央のレールと紋章。**陣地の境目**を真鍮の細い線として通し、盤面が対面していることを示す。
## 紋章の印は押すと歯車が回る(GameDesign.md 9章「QOL」)。
func _draw_rail(ci: RID) -> void:
	var y := size.y * DIVIDER_RATIO
	var side := FRAME_WIDTH + PERSPECTIVE_INSET * (1.0 - DIVIDER_RATIO) + RAIL_INSET
	var left := Vector2(side, y)
	var right := Vector2(size.x - side, y)
	var center := Vector2(size.x * 0.5, y)
	var drop := Vector2(0, RAIL_WIDTH * 0.8)
	ShapePaint.polyline(
		ci, PackedVector2Array([left + drop, right + drop]), RAIL_SHADOW, RAIL_WIDTH, true
	)
	ShapePaint.polyline_colors(
		ci,
		PackedVector2Array([left, center, right]),
		PackedColorArray([UiPalette.BRASS, UiPalette.GOLD_HI, UiPalette.BRASS]),
		RAIL_WIDTH,
		true
	)
	var glow: float = _medallion_glow
	UiKit.seal(
		ci,
		center,
		MEDALLION_OUTER_RADIUS,
		UiPaint.HOURGLASS_ICON,
		UiPalette.GOLD.lerp(UiPalette.GOLD_HI, glow)
	)
	# 歯車の意匠(押すと回る)。印の縁へ短い刻みを打つ。
	for i in MEDALLION_SPOKES:
		var rad := _medallion_angle + i * (TAU / float(MEDALLION_SPOKES))
		var dir := Vector2(cos(rad), sin(rad))
		_rail_layer.draw_line(
			center + dir * MEDALLION_INNER_RADIUS,
			center + dir * MEDALLION_OUTER_RADIUS,
			Color(UiPalette.GOLD, 0.45 + glow * 0.4),
			1.5
		)


## マット1枚ぶんの層。**模様が矩形の外へ出ないよう `clip_contents` を立てる。**
class MatLayer:
	extends Control

	var mat_id := PlaymatLibrary.DEFAULT_ID:
		set(value):
			mat_id = value
			queue_redraw()
	## 上辺・下辺を左右へ狭める量(台形の額に沿わせるため)。既定0は矩形のまま。
	var top_inset := 0.0
	var bottom_inset := 0.0

	func _init() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		clip_contents = true

	func _draw() -> void:
		PlaymatPaint.draw_mat(self, Rect2(Vector2.ZERO, size), mat_id, top_inset, bottom_inset)
