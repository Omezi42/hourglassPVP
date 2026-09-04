class_name RoomPaint
extends RefCounted
## 画面の下地を「場所」として描くための部品(GameDesign.md 9章)。
##
## 無地のグラデーション(`ScreenBackdrop`)だけでは、どの画面も同じ暗がりに見える。
## 工房の板壁が効いたのは、そこが**作業場という場所**として読めたためであり、
## 同じ手当てを他の画面へも広げる。**ただし画面ごとに壁を描き起こさない。**
## ここが板壁・棚・引き出し・窓・幕といった部品を持ち、各画面はそれを組み合わせるだけにする。
##
## `UiPaint` と違い**第1引数に `CanvasItem` を取る**(`InkFigure` と同じ流儀)。
## `draw_line()` などのインスタンス側の描画と、`UiPaint` の RID 側の描画の両方を使うため。

const WALL_LIGHT := Color(0.20, 0.140, 0.098)
const WALL_DARK := Color(0.095, 0.062, 0.043)
const SEAM := Color(0.045, 0.028, 0.018, 0.9)
const WOOD_TOP := Color(0.40, 0.265, 0.155)
const WOOD_MID := Color(0.31, 0.20, 0.115)
const WOOD_DARK := Color(0.19, 0.12, 0.068)
const BACK_PANEL := Color(0.075, 0.05, 0.036, 1.0)
const RIVET := Color(0.80, 0.65, 0.36, 1.0)
const LAMP_WARM := Color(1.0, 0.82, 0.48)
const PLANK_WIDTH := 88.0
const GRAIN_ALPHA := 0.075


## 板壁。縦板を並べ、板ごとに色をわずかに散らして継ぎ目へ影を落とす。
## `tint` で場所ごとの色味を変える(書庫は青緑寄り、金庫室は灰色寄り、など)。
static func wall(ci: CanvasItem, rect: Rect2, seed_value: int, tint: Color = Color.WHITE) -> void:
	var rid := ci.get_canvas_item()
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	var x := rect.position.x
	while x < rect.end.x:
		var tone := rng.randf_range(-0.022, 0.022)
		var base := Color(WALL_LIGHT.r + tone, WALL_LIGHT.g + tone * 0.7, WALL_LIGHT.b + tone * 0.5)
		var top := base * tint
		var plank := Rect2(x, rect.position.y, PLANK_WIDTH, rect.size.y)
		UiPaint.fill_gradient_polygon(
			rid,
			UiPaint.rounded_rect_points_uniform(plank, 0.0, 1),
			plank,
			[[0.0, top], [0.55, top.lerp(WALL_DARK * tint, 0.45)], [1.0, WALL_DARK * tint]]
		)
		for i in 3:
			var gx := x + PLANK_WIDTH * (0.2 + 0.3 * i) + rng.randf_range(-6.0, 6.0)
			ci.draw_line(
				Vector2(gx, rect.position.y), Vector2(gx, rect.end.y), Color(0, 0, 0, 0.10), 1.0
			)
		ci.draw_line(Vector2(x, rect.position.y), Vector2(x, rect.end.y), SEAM, 2.0)
		ci.draw_line(
			Vector2(x + 1.5, rect.position.y),
			Vector2(x + 1.5, rect.end.y),
			Color(1, 0.85, 0.6, 0.05),
			1.0
		)
		for ratio in [0.12, 0.65]:
			var ny: float = rect.position.y + rect.size.y * ratio
			ci.draw_circle(Vector2(x + PLANK_WIDTH * 0.5, ny), 2.0, Color(0.05, 0.04, 0.03, 0.8))
			ci.draw_circle(
				Vector2(x + PLANK_WIDTH * 0.5 - 0.6, ny - 0.6), 1.1, Color(0.5, 0.42, 0.3, 0.55)
			)
		x += PLANK_WIDTH
	UiPaint.apply_grain(rid, rect, GRAIN_ALPHA)


## 壁で噛み合う歯車。工房・時計まわりの画面に置く。
static func gear(
	ci: CanvasItem, center: Vector2, radius: float, teeth: int, phase: float, alpha: float
) -> void:
	var rid := ci.get_canvas_item()
	var points := PackedVector2Array()
	var steps := teeth * 4
	for i in range(steps):
		var t := float(i) / float(steps)
		var a := TAU * t + phase
		# 台形の歯。1周期を「歯・谷」の矩形波として半径へ乗せる。
		var wave := sin(TAU * t * teeth)
		var r: float = radius * (0.82 + 0.18 * clampf(wave * 3.0, -1.0, 1.0))
		points.append(center + Vector2(cos(a), sin(a)) * r)
	ci.draw_colored_polygon(points, Color(0.65, 0.5, 0.28, alpha))
	UiPaint.draw_ring(rid, center, radius * 0.42, Color(0.7, 0.55, 0.3, alpha), 5.0, 30)
	UiPaint.draw_ring(rid, center, radius * 0.12, Color(0.7, 0.55, 0.3, alpha), 4.0, 16)
	for i in 5:
		var spoke := TAU * float(i) / 5.0 + phase
		ci.draw_line(
			center + Vector2(cos(spoke), sin(spoke)) * radius * 0.14,
			center + Vector2(cos(spoke), sin(spoke)) * radius * 0.40,
			Color(0.7, 0.55, 0.3, alpha),
			4.0
		)


## 作業灯。**光そのものは描かず、当たった面だけを明るくする。**
static func lamp(ci: CanvasItem, src: Vector2, height: float, span: float) -> void:
	for i in 14:
		var t := float(i) / 13.0
		var next_t: float = minf(t + 1.0 / 13.0, 1.0)
		var half := lerpf(90.0, span, t)
		var next_half := lerpf(90.0, span, next_t)
		(
			ci
			. draw_colored_polygon(
				PackedVector2Array(
					[
						Vector2(src.x - half, lerpf(src.y, height, t)),
						Vector2(src.x + half, lerpf(src.y, height, t)),
						Vector2(src.x + next_half, lerpf(src.y, height, next_t)),
						Vector2(src.x - next_half, lerpf(src.y, height, next_t)),
					]
				),
				Color(LAMP_WARM, 0.055 * (1.0 - t))
			)
		)


## 吊り看板。2本の鎖で梁から下げた真鍮のプレートへ、彫り込んだ文字を載せる。
static func sign(ci: CanvasItem, rect: Rect2, font: Font, label: String, font_size: int) -> void:
	var rid := ci.get_canvas_item()
	for cx in [rect.position.x + 44.0, rect.end.x - 44.0]:
		for i in 4:
			UiPaint.draw_ring(
				rid,
				Vector2(cx, rect.position.y - 20.0 + i * 5.0),
				3.4,
				Color(0.55, 0.45, 0.3),
				2.0,
				10
			)
	var points := UiPaint.rounded_rect_points_uniform(rect, 10.0, 8)
	(
		UiPaint
		. fill_gradient_polygon(
			rid,
			points,
			rect,
			[
				[0.0, UiPalette.BRASS_HIGHLIGHT],
				[0.22, UiPalette.BRASS_LIGHT],
				[0.62, UiPalette.BRASS_MID],
				[0.88, UiPalette.BRASS_DARK],
				[1.0, UiPalette.BRASS_BOUNCE],
			]
		)
	)
	UiPaint.draw_bevel(rid, points, UiPalette.BRASS_HIGHLIGHT, UiPalette.OUTLINE_DARK, 2.4, false)
	UiPaint.apply_grain(rid, rect, 0.07)
	# 彫り込んだ文字に見せるため、暗い影を1pxずらして先に敷く。
	var baseline := rect.get_center().y + float(font_size) * 0.4
	var alignment := HORIZONTAL_ALIGNMENT_CENTER
	ci.draw_string(
		font,
		Vector2(rect.position.x, baseline),
		label,
		alignment,
		rect.size.x,
		font_size,
		Color(0.10, 0.06, 0.03)
	)
	ci.draw_string(
		font,
		Vector2(rect.position.x, baseline - 1.0),
		label,
		alignment,
		rect.size.x,
		font_size,
		Color(0.98, 0.90, 0.72)
	)


## 木箱。`hollow` なら奥まった背板(物を並べる棚)、そうでなければ木の天板(作業台)。
static func wood_box(ci: CanvasItem, rect: Rect2, hollow: bool) -> void:
	var rid := ci.get_canvas_item()
	if hollow:
		UiPaint.fill_gradient_polygon(
			rid,
			UiPaint.rounded_rect_points_uniform(rect, 8.0, 6),
			rect,
			[[0.0, BACK_PANEL.darkened(0.35)], [1.0, BACK_PANEL]]
		)
		for i in 7:
			var bx: float = rect.position.x + rect.size.x * float(i) / 7.0
			ci.draw_line(
				Vector2(bx, rect.position.y),
				Vector2(bx, rect.end.y),
				Color(0.13, 0.09, 0.06, 0.55),
				2.0
			)
		UiPaint.draw_inner_shadow(rid, rect, 8.0, 8, 8, Color(0, 0, 0), 0.75)
	else:
		var top := Rect2(rect.position, Vector2(rect.size.x, 26))
		UiPaint.fill_gradient_polygon(
			rid,
			UiPaint.rounded_rect_points(top, 8.0, 8.0, 0.0, 0.0, 6),
			top,
			[[0.0, WOOD_TOP.lightened(0.16)], [1.0, WOOD_TOP]]
		)
		var body := Rect2(rect.position + Vector2(0, 26), rect.size - Vector2(0, 26))
		UiPaint.fill_gradient_polygon(
			rid,
			UiPaint.rounded_rect_points(body, 0.0, 0.0, 10.0, 10.0, 6),
			body,
			[[0.0, WOOD_MID], [0.75, WOOD_MID.darkened(0.18)], [1.0, WOOD_DARK]]
		)
		UiPaint.apply_grain(rid, rect, 0.06)


## 木箱の上端へ渡す帯。**ラベルはこの木の上へ焼く**——棚の内側は奥行きのために
## 暗く落としてあり、そこへ焼印を置くと文字が沈んで読めない。
static func box_band(ci: CanvasItem, rect: Rect2, height: float, font: Font, label: String) -> void:
	var rid := ci.get_canvas_item()
	var band := Rect2(rect.position.x + 3, rect.position.y + 3, rect.size.x - 6, height)
	UiPaint.fill_gradient_polygon(
		rid,
		UiPaint.rounded_rect_points(band, 6.0, 6.0, 0.0, 0.0, 6),
		band,
		[[0.0, WOOD_TOP.lightened(0.10)], [0.7, WOOD_MID], [1.0, WOOD_DARK]]
	)
	UiPaint.apply_grain(rid, band, 0.06)
	ci.draw_line(
		band.position, Vector2(band.end.x, band.position.y), Color(1, 0.9, 0.72, 0.28), 1.5
	)
	for i in 6:
		ci.draw_line(
			Vector2(band.position.x, band.end.y + i),
			Vector2(band.end.x, band.end.y + i),
			Color(0, 0, 0, 0.30 * (1.0 - float(i) / 6.0)),
			1.0
		)
	if label.is_empty():
		return
	# 焼印。木へ焼き付けた文字に見せるため、暗く沈ませてから薄い縁を出す。
	var at := band.position + Vector2(20, 8)
	ci.draw_string(
		font,
		at + Vector2(1, 25),
		label,
		HORIZONTAL_ALIGNMENT_LEFT,
		-1,
		20,
		Color(0.62, 0.46, 0.26, 0.35)
	)
	ci.draw_string(
		font,
		at + Vector2(0, 24),
		label,
		HORIZONTAL_ALIGNMENT_LEFT,
		-1,
		20,
		Color(0.13, 0.075, 0.04)
	)


## 木箱の枠。四辺へ真鍮の角金具を回す。
static func box_frame(ci: CanvasItem, rect: Rect2) -> void:
	var rid := ci.get_canvas_item()
	var points := UiPaint.rounded_rect_points_uniform(rect, 8.0, 6)
	UiPaint.draw_bevel(rid, points, Color(0.58, 0.46, 0.30), Color(0.04, 0.025, 0.015), 3.0, false)
	var arm := 26.0
	for corner in [
		[rect.position, Vector2(1, 1)],
		[Vector2(rect.end.x, rect.position.y), Vector2(-1, 1)],
		[Vector2(rect.position.x, rect.end.y), Vector2(1, -1)],
		[rect.end, Vector2(-1, -1)],
	]:
		var c: Vector2 = corner[0]
		var d: Vector2 = corner[1]
		ci.draw_line(c, c + Vector2(arm * d.x, 0), RIVET.darkened(0.15), 4.0)
		ci.draw_line(c, c + Vector2(0, arm * d.y), RIVET.darkened(0.15), 4.0)
		ci.draw_circle(c + d * 9.0, 3.0, RIVET)


## 本棚。背表紙の並びだけを影として置く(壁の飾りであり、読ませるものではない)。
static func bookshelf(ci: CanvasItem, rect: Rect2, seed_value: int) -> void:
	var rid := ci.get_canvas_item()
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	UiPaint.fill_gradient_polygon(
		rid,
		UiPaint.rounded_rect_points_uniform(rect, 4.0, 4),
		rect,
		[[0.0, Color(0.055, 0.038, 0.028)], [1.0, Color(0.03, 0.02, 0.014)]]
	)
	var shelves := maxi(int(rect.size.y / 96.0), 1)
	var shelf_h := rect.size.y / float(shelves)
	for s in shelves:
		var top := rect.position.y + s * shelf_h
		var x := rect.position.x + 6.0
		while x < rect.end.x - 12.0:
			var w := rng.randf_range(9.0, 20.0)
			var h := shelf_h * rng.randf_range(0.52, 0.80)
			var hue := rng.randf_range(0.0, 1.0)
			var spine := Color.from_hsv(hue, 0.32, rng.randf_range(0.16, 0.30))
			ci.draw_rect(Rect2(x, top + shelf_h - 12.0 - h, w, h), spine)
			ci.draw_rect(Rect2(x, top + shelf_h - 12.0 - h, 1.0, h), spine.lightened(0.25))
			x += w + 2.0
		# 棚板。
		var board := Rect2(rect.position.x + 2.0, top + shelf_h - 12.0, rect.size.x - 4.0, 8.0)
		UiPaint.fill_gradient_polygon(
			rid,
			UiPaint.rounded_rect_points_uniform(board, 2.0, 2),
			board,
			[[0.0, WOOD_TOP.darkened(0.25)], [1.0, WOOD_DARK]]
		)
	UiPaint.draw_inner_shadow(rid, rect, 4.0, 4, 7, Color(0, 0, 0), 0.8)


## 真鍮の引き出しの列。記録を仕舞っておく部屋(戦績・リプレイ)の壁に置く。
static func drawers(ci: CanvasItem, rect: Rect2, cols: int, rows: int) -> void:
	var rid := ci.get_canvas_item()
	var cell := Vector2(rect.size.x / float(cols), rect.size.y / float(rows))
	for row in rows:
		for col in cols:
			var face := Rect2(
				rect.position + Vector2(col * cell.x, row * cell.y) + Vector2(3, 3),
				cell - Vector2(6, 6)
			)
			var points := UiPaint.rounded_rect_points_uniform(face, 3.0, 3)
			UiPaint.fill_gradient_polygon(
				rid,
				points,
				face,
				[
					[0.0, Color(0.135, 0.098, 0.062)],
					[0.6, Color(0.10, 0.072, 0.046)],
					[1.0, Color(0.06, 0.042, 0.026)]
				]
			)
			UiPaint.draw_bevel(
				rid, points, Color(0.42, 0.34, 0.20, 0.7), Color(0, 0, 0, 0.8), 1.4, false
			)
			# 取っ手。
			var handle := Vector2(face.get_center().x, face.get_center().y + 2.0)
			UiPaint.draw_ring(rid, handle, cell.y * 0.16, Color(0.52, 0.42, 0.24), 3.0, 14)
