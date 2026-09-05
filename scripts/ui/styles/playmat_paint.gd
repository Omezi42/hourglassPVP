class_name PlaymatPaint
extends RefCounted
## プレイマットを描く(GameDesign.md 9章)。
##
## **対局の卓とショップの見本で同じ関数を通す。**別々に描くと、買う前に見た絵と
## 実際に敷かれる絵が食い違う(そうなったら見本の意味が無い)。
##
## `UiPaint` と違い**第1引数に `CanvasItem` を取る**(`RoomPaint` / `InkFigure` と同じ流儀)。

## 縁飾りを内側へ入れる量。
const INSET := 9.0
## 模様の濃さ。**ここを上げると駒と数値のコントラストが落ちる**ため、
## 見た目の派手さより先にこの上限を守る(GameDesign.md 9章)。
const WEAVE_ALPHA := 0.16
const WEAVE_ALPHA_SOFT := 0.08


static func draw_mat(ci: CanvasItem, rect: Rect2, mat_id: String) -> void:
	if mat_id == PlaymatLibrary.NONE_ID:
		return
	var mat := PlaymatLibrary.get_mat(mat_id)
	var base: Color = mat["base"]
	UiPaint.fill_gradient_polygon(
		ci.get_canvas_item(),
		UiPaint.rounded_rect_points_uniform(rect, 4.0, 3),
		rect,
		[[0.0, base.lightened(0.10)], [0.55, base], [1.0, base.darkened(0.22)]]
	)
	_draw_weave(ci, rect, mat)
	_draw_border(ci, rect, mat)
	UiPaint.apply_grain(ci.get_canvas_item(), rect, 0.055)


## 縁飾り。マットが「敷いてある布」に見えるための二重線と、豪華な品だけの隅飾り。
static func _draw_border(ci: CanvasItem, rect: Rect2, mat: Dictionary) -> void:
	var edge: Color = mat["edge"]
	var inset := rect.grow(-INSET)
	ci.draw_rect(inset, Color(edge, 0.70), false, 2.0)
	ci.draw_rect(inset.grow(-5.0), Color(edge, 0.36), false, 1.2)
	if not bool(mat.get("corners", false)):
		return
	# 隅の箔飾り。**値段の段(1500 / 3000)を見た目で分ける唯一の手がかり**にする。
	var foil: Color = mat["foil"]
	var arm := 34.0
	for corner in [
		[inset.position, Vector2(1, 1)],
		[Vector2(inset.end.x, inset.position.y), Vector2(-1, 1)],
		[Vector2(inset.position.x, inset.end.y), Vector2(1, -1)],
		[inset.end, Vector2(-1, -1)],
	]:
		var c: Vector2 = corner[0]
		var d: Vector2 = corner[1]
		ci.draw_line(c, c + Vector2(arm * d.x, 0), Color(foil, 0.55), 2.6)
		ci.draw_line(c, c + Vector2(0, arm * d.y), Color(foil, 0.55), 2.6)
		ci.draw_line(
			c + Vector2(arm * d.x, 0),
			c + Vector2(arm * 0.5 * d.x, arm * 0.5 * d.y),
			Color(foil, 0.40),
			2.0
		)
		ci.draw_line(
			c + Vector2(0, arm * d.y),
			c + Vector2(arm * 0.5 * d.x, arm * 0.5 * d.y),
			Color(foil, 0.40),
			2.0
		)


static func _draw_weave(ci: CanvasItem, rect: Rect2, mat: Dictionary) -> void:
	match int(mat["weave"]):
		PlaymatLibrary.Weave.RIPPLE:
			_ripple(ci, rect, mat["edge"])
		PlaymatLibrary.Weave.LATTICE:
			_lattice(ci, rect, mat["edge"])
		PlaymatLibrary.Weave.MASONRY:
			_masonry(ci, rect, mat["edge"])
		PlaymatLibrary.Weave.STARS:
			_stars(ci, rect, mat["edge"], mat["foil"])
		_:
			_scroll(ci, rect, mat["edge"], mat["foil"])


## 砂紋。手前の縁を中心に広がる弧。
static func _ripple(ci: CanvasItem, rect: Rect2, edge: Color) -> void:
	var focus := Vector2(rect.get_center().x, rect.end.y)
	for i in 9:
		var r := 60.0 + i * 46.0
		UiPaint.draw_ellipse_ring(
			ci.get_canvas_item(), focus, Vector2(r, r * 0.42), Color(edge, WEAVE_ALPHA), 2.0, 40
		)


## 織り。斜めの格子。
static func _lattice(ci: CanvasItem, rect: Rect2, edge: Color) -> void:
	var x := rect.position.x - rect.size.y
	while x < rect.end.x:
		ci.draw_line(
			Vector2(x, rect.end.y),
			Vector2(x + rect.size.y, rect.position.y),
			Color(edge, WEAVE_ALPHA * 0.8),
			1.4
		)
		ci.draw_line(
			Vector2(x, rect.position.y),
			Vector2(x + rect.size.y, rect.end.y),
			Color(edge, WEAVE_ALPHA_SOFT),
			1.4
		)
		x += 26.0


## 石畳。段ごとに半分ずらした矩形。
static func _masonry(ci: CanvasItem, rect: Rect2, edge: Color) -> void:
	var w := 92.0
	var h := 46.0
	var row := 0
	var y := rect.position.y
	while y < rect.end.y:
		var offset: float = 0.0 if row % 2 == 0 else w * 0.5
		var x := rect.position.x - w + offset
		while x < rect.end.x:
			ci.draw_rect(
				Rect2(x + 2, y + 2, w - 4, h - 4), Color(edge, WEAVE_ALPHA * 0.8), false, 1.4
			)
			x += w
		y += h
		row += 1


## 星図。散らした点と、それを結ぶ細い線(星座に見立てる)。
static func _stars(ci: CanvasItem, rect: Rect2, edge: Color, foil: Color) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 20260904
	var points := PackedVector2Array()
	for i in 46:
		points.append(
			Vector2(
				rng.randf_range(rect.position.x + 12.0, rect.end.x - 12.0),
				rng.randf_range(rect.position.y + 12.0, rect.end.y - 12.0)
			)
		)
	# 近い星どうしだけを結ぶ。全部を結ぶと網になって盤面が読みにくくなる。
	for i in points.size():
		for j in range(i + 1, points.size()):
			if points[i].distance_to(points[j]) < 88.0:
				ci.draw_line(points[i], points[j], Color(edge, WEAVE_ALPHA_SOFT), 1.0)
	for i in points.size():
		var r: float = 1.2 if i % 3 else 2.2
		ci.draw_circle(points[i], r, Color(foil, WEAVE_ALPHA + 0.10))


## 唐草。左右対称に巻いた蔓を、上下の縁へ沿って流す。
static func _scroll(ci: CanvasItem, rect: Rect2, edge: Color, foil: Color) -> void:
	for side in [0, 1]:
		var base_y: float = rect.position.y + 26.0 if side == 0 else rect.end.y - 26.0
		var dir: float = 1.0 if side == 0 else -1.0
		var curve := PackedVector2Array()
		var x := rect.position.x + 16.0
		while x < rect.end.x - 16.0:
			var t := (x - rect.position.x) / 74.0
			curve.append(Vector2(x, base_y + sin(t) * 13.0 * dir))
			x += 5.0
		if curve.size() > 1:
			ci.draw_polyline(curve, Color(edge, WEAVE_ALPHA + 0.06), 2.0)
		# 巻きひげ。1周期ごとに小さな渦を落とす。
		var cx := rect.position.x + 16.0
		while cx < rect.end.x - 16.0:
			UiPaint.draw_ring(
				ci.get_canvas_item(),
				Vector2(cx, base_y + 20.0 * dir),
				9.0,
				Color(foil, WEAVE_ALPHA),
				1.6,
				14
			)
			cx += 148.0
	# 中ほどの菱形の連なり。
	var y := rect.get_center().y
	var mx := rect.position.x + 40.0
	while mx < rect.end.x - 40.0:
		var c := Vector2(mx, y)
		(
			ci
			. draw_polyline(
				PackedVector2Array(
					[
						c + Vector2(0, -7),
						c + Vector2(7, 0),
						c + Vector2(0, 7),
						c + Vector2(-7, 0),
						c + Vector2(0, -7),
					]
				),
				Color(foil, WEAVE_ALPHA_SOFT + 0.04),
				1.4
			)
		)
		mx += 56.0
