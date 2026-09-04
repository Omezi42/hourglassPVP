class_name WorkshopBackdrop
extends Control
## 時計工房(デッキ編集画面)の下地(GameDesign.md 9章)。板壁の作業場に、
## 左=在庫棚 / 右=組立台 の木箱を据える。
##
## **一覧と棚はこの上へ子として重ねる**(`Control._draw()` は自分の子より背面に描かれる)。
## 看板・棚板・枠までをここが描き、画面側は中身だけを置く。

const SCREEN_SIZE := Vector2(1280, 720)
## 在庫棚と組立台。**左を狭め右を広く取る**——右は段へ6本前後を横に並べるため、
## 一覧と同じ幅では1本が55pxまで縮む。
const SHELF_RECT := Rect2(26, 112, 566, 586)
const BENCH_RECT := Rect2(610, 112, 644, 586)
## 木箱の上端へ渡す帯。ラベルはこの木の上へ焼く。
const BAND_HEIGHT := 48.0
## 吊り看板。
const SIGN_RECT := Rect2(464, 22, 352, 62)

const WALL_LIGHT := Color(0.20, 0.140, 0.098)
const WALL_DARK := Color(0.095, 0.062, 0.043)
const SEAM := Color(0.045, 0.028, 0.018, 0.9)
const WOOD_TOP := Color(0.40, 0.265, 0.155)
const WOOD_MID := Color(0.31, 0.20, 0.115)
const WOOD_DARK := Color(0.19, 0.12, 0.068)
const BACK_PANEL := Color(0.075, 0.05, 0.036, 1.0)
const RIVET := Color(0.80, 0.65, 0.36, 1.0)
const LAMP_WARM := Color(1.0, 0.82, 0.48)

var _font: Font


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	# **`set_anchors_preset()` は使わない**(Architecture.md 11章)。
	size = SCREEN_SIZE
	_font = get_theme_default_font()
	if _font == null:
		_font = ThemeDB.fallback_font


func _draw() -> void:
	_draw_wall()
	_draw_gears()
	_draw_lamp()
	_draw_sign()
	_draw_box(SHELF_RECT, "在  庫  棚", true)
	_draw_box(BENCH_RECT, "", false)


## 板壁。縦板を並べ、板ごとに色をわずかに散らして継ぎ目へ影を落とす。
func _draw_wall() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 913
	var plank := 88.0
	var x := 0.0
	while x < SCREEN_SIZE.x:
		var tone := rng.randf_range(-0.022, 0.022)
		var top := Color(WALL_LIGHT.r + tone, WALL_LIGHT.g + tone * 0.7, WALL_LIGHT.b + tone * 0.5)
		var rect := Rect2(x, 0, plank, SCREEN_SIZE.y)
		UiPaint.fill_gradient_polygon(
			get_canvas_item(),
			UiPaint.rounded_rect_points_uniform(rect, 0.0, 1),
			rect,
			[[0.0, top], [0.55, top.lerp(WALL_DARK, 0.45)], [1.0, WALL_DARK]]
		)
		for i in 3:
			var gx := x + plank * (0.2 + 0.3 * i) + rng.randf_range(-6.0, 6.0)
			draw_line(Vector2(gx, 0), Vector2(gx, SCREEN_SIZE.y), Color(0, 0, 0, 0.10), 1.0)
		draw_line(Vector2(x, 0), Vector2(x, SCREEN_SIZE.y), SEAM, 2.0)
		draw_line(
			Vector2(x + 1.5, 0), Vector2(x + 1.5, SCREEN_SIZE.y), Color(1, 0.85, 0.6, 0.05), 1.0
		)
		for ny in [86.0, 470.0]:
			draw_circle(Vector2(x + plank * 0.5, ny), 2.0, Color(0.05, 0.04, 0.03, 0.8))
			draw_circle(Vector2(x + plank * 0.5 - 0.6, ny - 0.6), 1.1, Color(0.5, 0.42, 0.3, 0.55))
		x += plank
	UiPaint.apply_grain(get_canvas_item(), Rect2(Vector2.ZERO, SCREEN_SIZE), 0.075)


## 壁で噛み合う歯車。工房であることを背景だけで伝える。
func _draw_gears() -> void:
	_gear(Vector2(1180, 92), 78.0, 14, 0.0, 0.16)
	_gear(Vector2(1258, 196), 46.0, 9, 0.22, 0.13)
	_gear(Vector2(86, 636), 62.0, 12, 0.1, 0.12)


func _gear(center: Vector2, radius: float, teeth: int, phase: float, alpha: float) -> void:
	var points := PackedVector2Array()
	var steps := teeth * 4
	for i in range(steps):
		var t := float(i) / float(steps)
		var a := TAU * t + phase
		# 台形の歯。1周期を「歯・谷」の矩形波として半径へ乗せる。
		var wave := sin(TAU * t * teeth)
		var r: float = radius * (0.82 + 0.18 * clampf(wave * 3.0, -1.0, 1.0))
		points.append(center + Vector2(cos(a), sin(a)) * r)
	draw_colored_polygon(points, Color(0.65, 0.5, 0.28, alpha))
	UiPaint.draw_ring(
		get_canvas_item(), center, radius * 0.42, Color(0.7, 0.55, 0.3, alpha), 5.0, 30
	)
	UiPaint.draw_ring(
		get_canvas_item(), center, radius * 0.12, Color(0.7, 0.55, 0.3, alpha), 4.0, 16
	)
	for i in 5:
		var spoke := TAU * float(i) / 5.0 + phase
		draw_line(
			center + Vector2(cos(spoke), sin(spoke)) * radius * 0.14,
			center + Vector2(cos(spoke), sin(spoke)) * radius * 0.40,
			Color(0.7, 0.55, 0.3, alpha),
			4.0
		)


## 作業灯。右上から差して組立台を照らす。光そのものは描かず、当たった面だけを明るくする。
func _draw_lamp() -> void:
	var src := Vector2(1010, -40)
	var span := 460.0
	for i in 14:
		var t := float(i) / 13.0
		var next_t: float = minf(t + 1.0 / 13.0, 1.0)
		var y := lerpf(0.0, SCREEN_SIZE.y, t)
		var next_y := lerpf(0.0, SCREEN_SIZE.y, next_t)
		var half := lerpf(90.0, span, t)
		var next_half := lerpf(90.0, span, next_t)
		draw_colored_polygon(
			PackedVector2Array(
				[
					Vector2(src.x - half, y),
					Vector2(src.x + half, y),
					Vector2(src.x + next_half, next_y),
					Vector2(src.x - next_half, next_y),
				]
			),
			Color(LAMP_WARM, 0.055 * (1.0 - t))
		)


## 吊り看板。2本の鎖で梁から下げた真鍮のプレート。
func _draw_sign() -> void:
	for cx in [SIGN_RECT.position.x + 44.0, SIGN_RECT.end.x - 44.0]:
		for i in 4:
			UiPaint.draw_ring(
				get_canvas_item(), Vector2(cx, 2.0 + i * 5.0), 3.4, Color(0.55, 0.45, 0.3), 2.0, 10
			)
	var points := UiPaint.rounded_rect_points_uniform(SIGN_RECT, 10.0, 8)
	(
		UiPaint
		. fill_gradient_polygon(
			get_canvas_item(),
			points,
			SIGN_RECT,
			[
				[0.0, UiPalette.BRASS_HIGHLIGHT],
				[0.22, UiPalette.BRASS_LIGHT],
				[0.62, UiPalette.BRASS_MID],
				[0.88, UiPalette.BRASS_DARK],
				[1.0, UiPalette.BRASS_BOUNCE],
			]
		)
	)
	UiPaint.draw_bevel(
		get_canvas_item(), points, UiPalette.BRASS_HIGHLIGHT, UiPalette.OUTLINE_DARK, 2.4, false
	)
	UiPaint.apply_grain(get_canvas_item(), SIGN_RECT, 0.07)
	# 彫り込んだ文字に見せるため、暗い影を1pxずらして先に敷く。
	var baseline := SIGN_RECT.get_center().y + 12.0
	draw_string(
		_font,
		Vector2(SIGN_RECT.position.x, baseline),
		"時計工房",
		HORIZONTAL_ALIGNMENT_CENTER,
		SIGN_RECT.size.x,
		30,
		Color(0.10, 0.06, 0.03)
	)
	draw_string(
		_font,
		Vector2(SIGN_RECT.position.x, baseline - 1.0),
		"時計工房",
		HORIZONTAL_ALIGNMENT_CENTER,
		SIGN_RECT.size.x,
		30,
		Color(0.98, 0.90, 0.72)
	)


## 木箱。`hollow` なら奥まった背板(在庫棚)、そうでなければ木の天板(組立台)。
func _draw_box(rect: Rect2, label: String, hollow: bool) -> void:
	if hollow:
		UiPaint.fill_gradient_polygon(
			get_canvas_item(),
			UiPaint.rounded_rect_points_uniform(rect, 8.0, 6),
			rect,
			[[0.0, BACK_PANEL.darkened(0.35)], [1.0, BACK_PANEL]]
		)
		for i in 7:
			var bx: float = rect.position.x + rect.size.x * float(i) / 7.0
			draw_line(
				Vector2(bx, rect.position.y),
				Vector2(bx, rect.end.y),
				Color(0.13, 0.09, 0.06, 0.55),
				2.0
			)
		UiPaint.draw_inner_shadow(get_canvas_item(), rect, 8.0, 8, 8, Color(0, 0, 0), 0.75)
	else:
		var top := Rect2(rect.position, Vector2(rect.size.x, 26))
		UiPaint.fill_gradient_polygon(
			get_canvas_item(),
			UiPaint.rounded_rect_points(top, 8.0, 8.0, 0.0, 0.0, 6),
			top,
			[[0.0, WOOD_TOP.lightened(0.16)], [1.0, WOOD_TOP]]
		)
		var body := Rect2(rect.position + Vector2(0, 26), rect.size - Vector2(0, 26))
		UiPaint.fill_gradient_polygon(
			get_canvas_item(),
			UiPaint.rounded_rect_points(body, 0.0, 0.0, 10.0, 10.0, 6),
			body,
			[[0.0, WOOD_MID], [0.75, WOOD_MID.darkened(0.18)], [1.0, WOOD_DARK]]
		)
		UiPaint.apply_grain(get_canvas_item(), rect, 0.06)
	_draw_band(rect, label)
	_frame_box(rect)


## 木箱の上端へ渡す帯。**ラベルはこの木の上へ焼く**——棚の内側は奥行きのために
## 暗く落としてあり、そこへ焼印を置くと文字が沈んで読めない。
func _draw_band(rect: Rect2, label: String) -> void:
	var band := Rect2(rect.position.x + 3, rect.position.y + 3, rect.size.x - 6, BAND_HEIGHT)
	UiPaint.fill_gradient_polygon(
		get_canvas_item(),
		UiPaint.rounded_rect_points(band, 6.0, 6.0, 0.0, 0.0, 6),
		band,
		[[0.0, WOOD_TOP.lightened(0.10)], [0.7, WOOD_MID], [1.0, WOOD_DARK]]
	)
	UiPaint.apply_grain(get_canvas_item(), band, 0.06)
	draw_line(band.position, Vector2(band.end.x, band.position.y), Color(1, 0.9, 0.72, 0.28), 1.5)
	for i in 6:
		draw_line(
			Vector2(band.position.x, band.end.y + i),
			Vector2(band.end.x, band.end.y + i),
			Color(0, 0, 0, 0.30 * (1.0 - float(i) / 6.0)),
			1.0
		)
	if label.is_empty():
		return
	# 焼印。木へ焼き付けた文字に見せるため、暗く沈ませてから薄い縁を出す。
	var at := band.position + Vector2(20, 8)
	draw_string(
		_font,
		at + Vector2(1, 25),
		label,
		HORIZONTAL_ALIGNMENT_LEFT,
		-1,
		20,
		Color(0.62, 0.46, 0.26, 0.35)
	)
	draw_string(
		_font,
		at + Vector2(0, 24),
		label,
		HORIZONTAL_ALIGNMENT_LEFT,
		-1,
		20,
		Color(0.13, 0.075, 0.04)
	)


## 木箱の枠。四辺へ真鍮の角金具を回す。
func _frame_box(rect: Rect2) -> void:
	var points := UiPaint.rounded_rect_points_uniform(rect, 8.0, 6)
	UiPaint.draw_bevel(
		get_canvas_item(), points, Color(0.58, 0.46, 0.30), Color(0.04, 0.025, 0.015), 3.0, false
	)
	var arm := 26.0
	for corner in [
		[rect.position, Vector2(1, 1)],
		[Vector2(rect.end.x, rect.position.y), Vector2(-1, 1)],
		[Vector2(rect.position.x, rect.end.y), Vector2(1, -1)],
		[rect.end, Vector2(-1, -1)],
	]:
		var c: Vector2 = corner[0]
		var d: Vector2 = corner[1]
		draw_line(c, c + Vector2(arm * d.x, 0), RIVET.darkened(0.15), 4.0)
		draw_line(c, c + Vector2(0, arm * d.y), RIVET.darkened(0.15), 4.0)
		draw_circle(c + d * 9.0, 3.0, RIVET)
