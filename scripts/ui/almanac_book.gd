class_name AlmanacBook
extends Control
## 砂時計図鑑の下地(GameDesign.md 9章)。**机に開いた見開きの本**として描く。
##
## カードを並べるだけの表ではなく「集めたものを綴じておく場所」に見せるための器で、
## 一覧と解説はこの上へ子として重ねる(`Control._draw()` は自分の子より背面に描かれる)。

const SCREEN_SIZE := Vector2(1280, 720)
## 本の外形。上に操作を置く余地(戻る・並び替え)を残して机を見せる。
const BOOK := Rect2(52, 96, 1176, 604)
## 綴じ目のx。左右のページはここを境に開く。
const SPINE := 640.0
## 紙のページ(本の内側)。左右それぞれ。
const LEFT_PAGE := Rect2(70, 114, 552, 568)
const RIGHT_PAGE := Rect2(642, 114, 568, 568)

const DESK_TOP := Color(0.16, 0.11, 0.075)
const DESK_BOTTOM := Color(0.065, 0.045, 0.032)
const COVER_TOP := Color(0.30, 0.065, 0.075)
const COVER_BOTTOM := Color(0.135, 0.022, 0.030)
const GOLD_DIM := Color(0.52, 0.40, 0.18, 1.0)
const PAPER_TOP := Color(0.90, 0.845, 0.70)
const PAPER_BOTTOM := Color(0.775, 0.695, 0.535)


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	# **`set_anchors_preset()` は使わない**(Architecture.md 11章)。コードで生成した
	# 直後のサイズ0のノードへ使うと0のまま固定され、何も描かれない。
	size = SCREEN_SIZE


func _draw() -> void:
	_draw_desk()
	_draw_cover()
	_draw_pages()
	_draw_spine()


## 机。上から光が当たった暗い木。
func _draw_desk() -> void:
	for i in 22:
		var t := float(i) / 21.0
		draw_rect(
			Rect2(0, t * SCREEN_SIZE.y, SCREEN_SIZE.x, SCREEN_SIZE.y / 22.0 + 1.0),
			DESK_TOP.lerp(DESK_BOTTOM, t)
		)
	for i in 9:
		var y := 30.0 + i * 82.0
		draw_line(Vector2(0, y), Vector2(SCREEN_SIZE.x, y), Color(0, 0, 0, 0.22), 2.0)
	UiPaint.apply_grain(get_canvas_item(), Rect2(Vector2.ZERO, SCREEN_SIZE), 0.07)
	# 本が机へ落とす影。
	var shade := BOOK.grow(18)
	for i in 16:
		UiPaint.fill_gradient_polygon(
			get_canvas_item(),
			UiPaint.rounded_rect_points_uniform(shade.grow(-float(i) * 1.2), 10.0, 6),
			shade,
			[[0.0, Color(0, 0, 0, 0.05)], [1.0, Color(0, 0, 0, 0.05)]]
		)


## 革の表紙。紙より一回り大きく、金の空押しで縁取る。
func _draw_cover() -> void:
	var points := UiPaint.rounded_rect_points_uniform(BOOK, 12.0, 8)
	UiPaint.fill_gradient_polygon(
		get_canvas_item(), points, BOOK, [[0.0, COVER_TOP], [1.0, COVER_BOTTOM]]
	)
	UiPaint.apply_grain(get_canvas_item(), BOOK, 0.10)
	UiPaint.draw_bevel(
		get_canvas_item(), points, Color(0.52, 0.16, 0.16), Color(0.05, 0.01, 0.01), 2.5, false
	)
	var inner := BOOK.grow(-9)
	_outline(UiPaint.rounded_rect_points_uniform(inner, 8.0, 6), GOLD_DIM, 2.0)
	_outline(
		UiPaint.rounded_rect_points_uniform(inner.grow(-5), 6.0, 6), Color(GOLD_DIM, 0.55), 1.0
	)


## 紙。左右のページを別々に敷き、外側の小口へ紙の束を描く。
func _draw_pages() -> void:
	for page in [LEFT_PAGE, RIGHT_PAGE]:
		UiPaint.fill_gradient_polygon(
			get_canvas_item(),
			UiPaint.rounded_rect_points_uniform(page, 4.0, 5),
			page,
			[[0.0, PAPER_TOP], [1.0, PAPER_BOTTOM]]
		)
		UiPaint.apply_grain(get_canvas_item(), page, 0.09)
	# 小口(紙の束)。外側の端へ細い線を重ねる。
	for i in 9:
		var a := 0.30 * (1.0 - float(i) / 9.0)
		draw_line(
			Vector2(LEFT_PAGE.position.x - i, LEFT_PAGE.position.y + i),
			Vector2(LEFT_PAGE.position.x - i, LEFT_PAGE.end.y - i),
			Color(0.42, 0.33, 0.22, a),
			1.0
		)
		draw_line(
			Vector2(RIGHT_PAGE.end.x + i, RIGHT_PAGE.position.y + i),
			Vector2(RIGHT_PAGE.end.x + i, RIGHT_PAGE.end.y - i),
			Color(0.42, 0.33, 0.22, a),
			1.0
		)
	# 紙のシミ。同じ位置に重ねず、散らして薄く。
	var rng := RandomNumberGenerator.new()
	rng.seed = 4211
	for i in 14:
		var at := Vector2(
			rng.randf_range(BOOK.position.x + 40, BOOK.end.x - 40),
			rng.randf_range(BOOK.position.y + 40, BOOK.end.y - 40)
		)
		UiPaint.fill_ellipse(
			get_canvas_item(),
			at,
			Vector2(rng.randf_range(14, 42), rng.randf_range(9, 26)),
			Color(0.55, 0.42, 0.22, 0.055),
			20
		)


## 綴じ目。中央へ向かって沈む影を左右対称に落とす。
func _draw_spine() -> void:
	for i in 22:
		var t := float(i) / 21.0
		var a := 0.34 * (1.0 - t)
		var w := 2.0 + t * 26.0
		for side in [-1.0, 1.0]:
			draw_line(
				Vector2(SPINE + side * w, BOOK.position.y + 20),
				Vector2(SPINE + side * w, BOOK.end.y - 20),
				Color(0.20, 0.12, 0.05, a),
				2.0
			)
	draw_line(
		Vector2(SPINE, BOOK.position.y + 20),
		Vector2(SPINE, BOOK.end.y - 20),
		Color(0.16, 0.09, 0.04, 0.5),
		3.0
	)


func _outline(points: PackedVector2Array, color: Color, width: float) -> void:
	var closed := points.duplicate()
	closed.append(points[0])
	draw_polyline(closed, color, width)
