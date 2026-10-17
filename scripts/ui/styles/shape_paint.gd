class_name ShapePaint
extends RefCounted
## 面・輪・線を三角形の primitive で描く(Architecture.md 10.10.3節)。**ポリゴン系の描画は必ずここを通す。**
##
## Godot の `draw_polygon` / `draw_colored_polygon` / `draw_polyline` / `draw_arc` / `draw_circle`
## (`canvas_item_add_polygon` / `_polyline`)は、描き直すたびにGLのバッファとVAOを作り直す。
## Web版(Emscripten)はその番号を再利用せず表を延ばし続けるため、描き直すほどメモリが積み上がり、
## スマホのブラウザが落ちる(Pitfalls.md)。primitive・矩形・線・文字・テクスチャは番号を使わない。
##
## 引数の並びは CanvasItem の同名の `draw_*` と同じにしてある(先頭に描き先の RID を足しただけ)。
## `tools/check.sh` が `scripts/` からのポリゴン系の直接呼び出しを見張る。

## 線の縁をぼかす幅(Godot の線のアンチエイリアスと同じ1px)。
const FEATHER := 1.0
## 鋭角の継ぎ目で角が伸びすぎないよう、継ぎ目の伸びを線幅のこの倍までに抑える。
const MITER_LIMIT := 4.0
## `circle()` の分割数。半径に比例させ、小さい円は粗く・大きい円は細かくする。
const CIRCLE_SEGMENTS_PER_PX := 1.5
const CIRCLE_MIN_SEGMENTS := 12
const CIRCLE_MAX_SEGMENTS := 64

static var _tri_points := PackedVector2Array([Vector2.ZERO, Vector2.ZERO, Vector2.ZERO])
static var _tri_colors := PackedColorArray([Color.WHITE, Color.WHITE, Color.WHITE])
static var _quad_points := PackedVector2Array(
	[Vector2.ZERO, Vector2.ZERO, Vector2.ZERO, Vector2.ZERO]
)
static var _quad_colors := PackedColorArray([Color.WHITE, Color.WHITE, Color.WHITE, Color.WHITE])


## `draw_colored_polygon(points, color)` の代わり。
static func colored_polygon(ci: RID, points: PackedVector2Array, color: Color) -> void:
	polygon(ci, points, PackedColorArray([color]))


## `draw_polygon(points, colors)` の代わり。`colors` は頂点ごと(1色だけでもよい)。
static func polygon(ci: RID, points: PackedVector2Array, colors: PackedColorArray) -> void:
	if points.size() < 3 or colors.is_empty():
		return
	var indices := Geometry2D.triangulate_polygon(points)
	var single := colors.size() < points.size()
	for t in range(0, indices.size(), 3):
		var a := indices[t]
		var b := indices[t + 1]
		var c := indices[t + 2]
		_tri_points[0] = points[a]
		_tri_points[1] = points[b]
		_tri_points[2] = points[c]
		_tri_colors[0] = colors[0] if single else colors[a]
		_tri_colors[1] = colors[0] if single else colors[b]
		_tri_colors[2] = colors[0] if single else colors[c]
		RenderingServer.canvas_item_add_primitive(
			ci, _tri_points, _tri_colors, PackedVector2Array(), RID()
		)


## `draw_polyline(points, color, width, antialiased)` の代わり。
## 先頭と末尾が同じ点なら閉じた輪として継ぎ目をつなぐ。
static func polyline(
	ci: RID, points: PackedVector2Array, color: Color, width := -1.0, antialiased := false
) -> void:
	polyline_colors(ci, points, PackedColorArray([color]), width, antialiased)


## `draw_polyline_colors` / `canvas_item_add_polyline` の代わり。`colors` は頂点ごと(1色だけでもよい)。
static func polyline_colors(
	ci: RID,
	points: PackedVector2Array,
	colors: PackedColorArray,
	width := -1.0,
	antialiased := false
) -> void:
	if points.size() < 2 or colors.is_empty():
		return
	var single := colors.size() < points.size()
	if width <= 0.0:
		for i in points.size() - 1:
			var color := colors[0] if single else colors[i]
			RenderingServer.canvas_item_add_line(ci, points[i], points[i + 1], color, -1.0)
		return
	var path := points
	var tint := colors
	var closed := points.size() > 2 and points[0].is_equal_approx(points[points.size() - 1])
	if closed:
		path = points.slice(0, points.size() - 1)
		if not single:
			tint = colors.slice(0, colors.size() - 1)
	var count := path.size()
	var offsets := _miter_offsets(path, closed)
	var half := width * 0.5
	var feather := FEATHER * minf(width, 1.0)
	var segments := count if closed else count - 1
	for i in segments:
		var j := (i + 1) % count
		var ci_color := tint[0] if single else tint[i]
		var cj_color := tint[0] if single else tint[j]
		var li := path[i] + offsets[i] * half
		var lj := path[j] + offsets[j] * half
		var ri := path[i] - offsets[i] * half
		var rj := path[j] - offsets[j] * half
		_quad(ci, li, lj, rj, ri, ci_color, cj_color, cj_color, ci_color)
		if antialiased:
			var clear_i := Color(ci_color, 0.0)
			var clear_j := Color(cj_color, 0.0)
			var lfi := path[i] + offsets[i] * (half + feather)
			var lfj := path[j] + offsets[j] * (half + feather)
			var rfi := path[i] - offsets[i] * (half + feather)
			var rfj := path[j] - offsets[j] * (half + feather)
			_quad(ci, lfi, lfj, lj, li, clear_i, clear_j, cj_color, ci_color)
			_quad(ci, ri, rj, rfj, rfi, ci_color, cj_color, clear_j, clear_i)


## `draw_arc(center, radius, start_angle, end_angle, point_count, color, width, antialiased)` の代わり。
static func arc(
	ci: RID,
	center: Vector2,
	radius: float,
	start_angle: float,
	end_angle: float,
	point_count: int,
	color: Color,
	width := -1.0,
	antialiased := false
) -> void:
	if point_count < 2:
		return
	var points := PackedVector2Array()
	for i in point_count:
		var angle := lerpf(start_angle, end_angle, float(i) / float(point_count - 1))
		points.append(center + Vector2(cos(angle), sin(angle)) * radius)
	polyline(ci, points, color, width, antialiased)


## `draw_circle(position, radius, color, filled, width, antialiased)` の代わり。
static func circle(
	ci: RID,
	position: Vector2,
	radius: float,
	color: Color,
	filled := true,
	width := -1.0,
	antialiased := false
) -> void:
	if radius <= 0.0:
		return
	var segments := clampi(
		int(radius * CIRCLE_SEGMENTS_PER_PX), CIRCLE_MIN_SEGMENTS, CIRCLE_MAX_SEGMENTS
	)
	var points := PackedVector2Array()
	for i in segments + 1:
		var angle := TAU * float(i % segments) / float(segments)
		points.append(position + Vector2(cos(angle), sin(angle)) * radius)
	if not filled:
		polyline(ci, points, color, width, antialiased)
		return
	_fan(ci, position, points, color)
	if antialiased:
		for i in segments:
			var a := points[i]
			var b := points[i + 1]
			var fa := position + (a - position).normalized() * (radius + FEATHER)
			var fb := position + (b - position).normalized() * (radius + FEATHER)
			_quad(ci, a, b, fb, fa, color, color, Color(color, 0.0), Color(color, 0.0))


## `draw_dashed_line(from, to, color, width, dash)` の代わり。
static func dashed_line(
	ci: RID, from: Vector2, to: Vector2, color: Color, width := -1.0, dash := 2.0
) -> void:
	var length := from.distance_to(to)
	if length <= 0.0 or dash <= 0.0:
		return
	var step := (to - from) / length
	var at := 0.0
	while at < length:
		var end := minf(at + dash, length)
		RenderingServer.canvas_item_add_line(ci, from + step * at, from + step * end, color, width)
		at += dash * 2.0


## 中心から外周への扇。`rim` は閉じた点列(先頭と末尾が同じ点)。
static func _fan(ci: RID, center: Vector2, rim: PackedVector2Array, color: Color) -> void:
	_tri_colors.fill(color)
	_tri_points[0] = center
	for i in rim.size() - 1:
		_tri_points[1] = rim[i]
		_tri_points[2] = rim[i + 1]
		RenderingServer.canvas_item_add_primitive(
			ci, _tri_points, _tri_colors, PackedVector2Array(), RID()
		)


static func _quad(
	ci: RID,
	a: Vector2,
	b: Vector2,
	c: Vector2,
	d: Vector2,
	ca: Color,
	cb: Color,
	cc: Color,
	cd: Color
) -> void:
	_quad_points[0] = a
	_quad_points[1] = b
	_quad_points[2] = c
	_quad_points[3] = d
	_quad_colors[0] = ca
	_quad_colors[1] = cb
	_quad_colors[2] = cc
	_quad_colors[3] = cd
	RenderingServer.canvas_item_add_primitive(
		ci, _quad_points, _quad_colors, PackedVector2Array(), RID()
	)


## 各頂点で線の左側へ向かう向き(継ぎ目は角の二等分線、長さは線幅を保つ倍率込み)。
static func _miter_offsets(path: PackedVector2Array, closed: bool) -> PackedVector2Array:
	var count := path.size()
	var offsets := PackedVector2Array()
	offsets.resize(count)
	for i in count:
		var has_prev := closed or i > 0
		var has_next := closed or i < count - 1
		var prev_normal := Vector2.ZERO
		var next_normal := Vector2.ZERO
		if has_prev:
			prev_normal = _normal(path[(i - 1 + count) % count], path[i])
		if has_next:
			next_normal = _normal(path[i], path[(i + 1) % count])
		if not has_prev:
			offsets[i] = next_normal
		elif not has_next:
			offsets[i] = prev_normal
		else:
			var miter := (prev_normal + next_normal).normalized()
			if miter == Vector2.ZERO:
				miter = next_normal
			var stretch := minf(1.0 / maxf(miter.dot(next_normal), 1.0 / MITER_LIMIT), MITER_LIMIT)
			offsets[i] = miter * stretch
	return offsets


static func _normal(from: Vector2, to: Vector2) -> Vector2:
	var direction := (to - from).normalized()
	return Vector2(-direction.y, direction.x)
