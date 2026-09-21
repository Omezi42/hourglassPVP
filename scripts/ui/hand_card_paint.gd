class_name HandCardPaint
extends RefCounted
## 手札の札の描画(GameDesign.md 9章「手札は紙の札」)。`CardView.Mode.HAND` の `_draw()` から
## `draw(view)` を呼ぶ。`CardViewPaint` と同じく第1引数に `CardView` を取る static だけの層で、
## 状態(選択・ホバー・有効/無効)は `CardView` が持つ。
##
## 札は上から「絵の窓 / 名前の帯 / キーワードの行」の3段で組み、四隅に
## 左上=コスト / 右下=総量 / 左下=封蝋 を置く(数値の配置はDCGの慣習どおり)。
## **絵の窓の奥にそのカードの色の光だまり**を敷く。絵は全種が同じ砂時計の色違いのため、
## 窓の奥まで同じ色で染めると、暗い手元の面の上でも1枚ずつの色が立つ。
## 寸法はすべて `HAND_SIZE_PX`(118x158)を基準にした比(`CardView._hand_scale()`)で決める。

const CORNER := 9.0
const FRAME_WIDTH := 3.0
## 絵の窓。`CardView._hand_art_box()`(絵を収める正方形)を少し広げた矩形。
const WINDOW_INSET := 5.0
const WINDOW_CORNER := 6.0
## 光だまりの濃さ(中心)と広がり(窓の幅に対する直径の比)。
const GLOW_ALPHA := 0.55
const GLOW_SPREAD := 1.35
## 名前の帯と、その下のキーワードの行。
const NAME_BAND_TOP := 102.0
const NAME_BAND_HEIGHT := 18.0
const NAME_FONT := 13
const KEYWORD_BASELINE := 133.0
const KEYWORD_FONT := 11
## 四隅の丸いバッジ(コスト・総量)と封蝋。
const GEM_RADIUS := 14.0
const GEM_INSET := 16.0
const SEAL_RADIUS := 12.0
const SEAL_EMBLEM_SIDE := 15.0
## 砂術の窓に置く紋章の大きさ。
const SPELL_EMBLEM_SIDE := 58.0

const PAPER_TOP := Color(0.40, 0.33, 0.24, 1.0)
const PAPER_BOTTOM := Color(0.24, 0.19, 0.14, 1.0)
const WINDOW_TOP := Color(0.06, 0.07, 0.12, 1.0)
const WINDOW_BOTTOM := Color(0.10, 0.11, 0.18, 1.0)
const SPELL_WINDOW_TOP := Color(0.08, 0.08, 0.18, 1.0)
const SPELL_WINDOW_BOTTOM := Color(0.14, 0.13, 0.28, 1.0)
const TEXT_SHADOW := Color(0.05, 0.03, 0.02, 0.85)

## 光だまりの放射グラデーション(白)。色は描くときに乗せるため、全カードで1枚を共有する。
static var _glow_cache: GradientTexture2D


static func draw(view: CardView) -> void:
	var ci := view.get_canvas_item()
	var s: float = view._hand_scale()
	var rect := Rect2(Vector2.ZERO, view.size)
	var tint: Color = view._tint()
	var card: CardData = view.card
	var points := UiPaint.rounded_rect_points_uniform(rect, CORNER * s, 6)
	# 紙の札の地。
	UiPaint.fill_gradient_polygon(
		ci, points, rect, [[0.0, PAPER_TOP * tint], [1.0, PAPER_BOTTOM * tint]]
	)
	UiPaint.apply_grain(ci, rect, 0.07)
	_window(view, ci, s, tint)
	_name_band(view, ci, s, tint)
	_frame(view, ci, rect, points, s, tint)
	_labels(view, s, tint)
	_gems(view, ci, s, tint)
	_seal(view, ci, s, tint)
	if not view.badge.is_empty():
		CardViewPaint.badge(view, rect)
	if view._hovering and view.enabled:
		UiPaint.fill_gradient_polygon(
			ci, points, rect, [[0.0, Color(1, 1, 1, 0.07)], [1.0, Color(1, 1, 1, 0.03)]]
		)


## 絵の窓。彫り込んだ暗い面の奥へカードの色の光だまりを敷き、その上に砂時計を立てる。
static func _window(view: CardView, ci: RID, s: float, tint: Color) -> void:
	var card: CardData = view.card
	var box: Rect2 = view._hand_art_box()
	var rect := box.grow(WINDOW_INSET * s)
	rect.position.y = maxf(rect.position.y, FRAME_WIDTH * s + 3.0 * s)
	var radius := WINDOW_CORNER * s
	var points := UiPaint.rounded_rect_points_uniform(rect, radius, 5)
	var top := SPELL_WINDOW_TOP if card.is_spell else WINDOW_TOP
	var bottom := SPELL_WINDOW_BOTTOM if card.is_spell else WINDOW_BOTTOM
	UiPaint.fill_gradient_polygon(ci, points, rect, [[0.0, top * tint], [1.0, bottom * tint]])
	var accent := (
		CardView.SPELL_BORDER if card.is_spell else HourglassArt.accent_color(card.art_key())
	)
	_glow(view, rect, accent * tint)
	if card.is_spell:
		_spell_emblem(view, box, s, tint)
	else:
		var texture: Texture2D = view._icon()
		if texture != null:
			view.draw_texture_rect(texture, view._fit_art(texture, box), false, tint)
	UiPaint.draw_inner_shadow(ci, rect, radius, 5, 3, Color(0, 0, 0, 1), 0.5)
	var closed := points.duplicate()
	closed.append(points[0])
	view.draw_polyline(closed, Color(UiPalette.BRASS_MID, 0.9) * tint, 1.0, true)


## 光だまり。窓の中央やや下(砂時計の胴のあたり)を中心に、放射状に色を落とす。
## 窓の外へはみ出す分は `_window()` の呼び出し後に描く額と紙が覆うが、念のため
## 窓の矩形に収まる大きさで描く。
static func _glow(view: CardView, window: Rect2, color: Color) -> void:
	var diameter := window.size.x * GLOW_SPREAD
	var center := window.get_center() + Vector2(0.0, window.size.y * 0.08)
	var rect := Rect2(center - Vector2.ONE * diameter * 0.5, Vector2.ONE * diameter)
	var clip := rect.intersection(window)
	if clip.size.x <= 0.0 or clip.size.y <= 0.0:
		return
	var src := Rect2(
		(clip.position - rect.position) / diameter * 256.0, clip.size / diameter * 256.0
	)
	view.draw_texture_rect_region(
		_glow_texture(), clip, src, Color(color.r, color.g, color.b, GLOW_ALPHA)
	)


static func _glow_texture() -> GradientTexture2D:
	if _glow_cache != null:
		return _glow_cache
	var gradient := Gradient.new()
	gradient.set_color(0, Color(1, 1, 1, 1.0))
	gradient.set_color(1, Color(1, 1, 1, 0.0))
	gradient.add_point(0.4, Color(1, 1, 1, 0.45))
	var texture := GradientTexture2D.new()
	texture.gradient = gradient
	texture.fill = GradientTexture2D.FILL_RADIAL
	texture.fill_from = Vector2(0.5, 0.5)
	texture.fill_to = Vector2(1.0, 0.5)
	texture.width = 256
	texture.height = 256
	_glow_cache = texture
	return texture


## 砂術は砂時計の絵を持たないため、窓の中央へ紋章を大きく置く(GameDesign.md 9章)。
static func _spell_emblem(view: CardView, box: Rect2, s: float, tint: Color) -> void:
	var card: CardData = view.card
	if card.emblem == null:
		return
	var half := Vector2.ONE * SPELL_EMBLEM_SIDE * 0.5 * s
	var center := box.get_center()
	view.draw_texture_rect(
		card.emblem,
		Rect2(center - half + Vector2(0.0, 2.0 * s), half * 2.0),
		false,
		Color(0.04, 0.03, 0.08, 0.7)
	)
	view.draw_texture_rect(
		card.emblem, Rect2(center - half, half * 2.0), false, CardView.SPELL_BORDER * tint
	)


## 名前を載せる帯。上下に真鍮の細線を通し、額に彫った銘板のように読ませる。
static func _name_band(view: CardView, ci: RID, s: float, tint: Color) -> void:
	var rect := Rect2(
		FRAME_WIDTH * s + 2.0 * s,
		NAME_BAND_TOP * s,
		view.size.x - (FRAME_WIDTH + 2.0) * 2.0 * s,
		NAME_BAND_HEIGHT * s
	)
	var points := UiPaint.rounded_rect_points_uniform(rect, 3.0 * s, 3)
	UiPaint.fill_gradient_polygon(
		ci,
		points,
		rect,
		[[0.0, Color(0.09, 0.07, 0.06, 0.85) * tint], [1.0, Color(0.16, 0.13, 0.10, 0.85) * tint]]
	)
	var line := Color(UiPalette.BRASS_MID, 0.8) * tint
	view.draw_line(rect.position, Vector2(rect.end.x, rect.position.y), line, 1.0)
	view.draw_line(
		Vector2(rect.position.x, rect.end.y), rect.end, Color(UiPalette.BRASS_DARK, 0.9) * tint, 1.0
	)


## 札の額。外側に暗い輪郭、真鍮の面取り、内側に淡い明線。砂術は面取りの色を変える
## (「置くカードではない」と手札の時点で分かるようにする。GameDesign.md 9章)。
## 選択中は水色の太い輪郭で上書きする(守護の真鍮と取り違えないよう別系統の色)。
static func _frame(
	view: CardView, ci: RID, rect: Rect2, points: PackedVector2Array, s: float, tint: Color
) -> void:
	var outer := UiPaint.rounded_rect_points_uniform(rect.grow(1.0), CORNER * s + 1.0, 6)
	_closed(view, outer, UiPalette.OUTLINE_DARK, 1.0)
	var light := UiPalette.BRASS_RIM_LIGHT
	var dark := UiPalette.BRASS_DARK
	if view.card.is_spell:
		light = CardView.SPELL_BORDER
		dark = CardView.SPELL_BORDER.darkened(0.45)
	UiPaint.draw_bevel(ci, points, light * tint, dark * tint, FRAME_WIDTH * s, false)
	var inner := UiPaint.rounded_rect_points_uniform(
		rect.grow(-FRAME_WIDTH * s), maxf(CORNER * s - FRAME_WIDTH * s, 1.0), 6
	)
	_closed(view, inner, Color(light, 0.35) * tint, 1.0)
	if view.selected:
		_closed(view, points, CardView.SELECT_CYAN, CardView.GUARD_BORDER)
	elif view.unselect_amount > 0.01:
		var inset: float = CardView.UNSELECT_INSET * (1.0 - view.unselect_amount)
		var shrink := UiPaint.rounded_rect_points_uniform(rect.grow(-inset), CORNER * s, 6)
		_closed(
			view, shrink, Color(CardView.SELECT_CYAN, view.unselect_amount), CardView.GUARD_BORDER
		)


static func _closed(view: CardView, points: PackedVector2Array, color: Color, width: float) -> void:
	var closed := points.duplicate()
	closed.append(points[0])
	view.draw_polyline(closed, color, width, true)


## 名前は帯の中央、キーワードはその下の行。キーワードの行の両脇は四隅のバッジが占めるため、
## 文字はその内側の幅へ収める(`_centered_text` が収まらない場合だけ縮める)。
static func _labels(view: CardView, s: float, tint: Color) -> void:
	var card: CardData = view.card
	var name_baseline := (NAME_BAND_TOP + NAME_BAND_HEIGHT * 0.5) * s + NAME_FONT * s * 0.36
	view._centered_text(card.display_name, roundi(NAME_FONT * s), name_baseline + 1.0, TEXT_SHADOW)
	view._centered_text(
		card.display_name, roundi(NAME_FONT * s), name_baseline, UiPalette.TEXT_OFFWHITE * tint
	)
	var note: String = view._keyword_text()
	if note.is_empty():
		return
	var limit := view.size.x - (GEM_INSET + GEM_RADIUS + 2.0) * 2.0 * s
	view._centered_text(
		note,
		roundi(KEYWORD_FONT * s),
		KEYWORD_BASELINE * s,
		UiPalette.BRASS_HIGHLIGHT * tint,
		limit
	)


## コスト=左上 / 総量=右下(GameDesign.md 9章)。場の駒のバッジと同じ「暗い地 + 色の輪 + 数字」を、
## 真鍮の縁で額へ嵌め込んだ宝石として描く。**砂術は総量を持たないため右下を出さない**。
static func _gems(view: CardView, ci: RID, s: float, tint: Color) -> void:
	var card: CardData = view.card
	var radius := GEM_RADIUS * s
	var inset := GEM_INSET * s
	_gem(view, ci, Vector2(inset, inset), card.cost, CardView.MANA_BLUE, radius, tint)
	if card.is_spell:
		return
	_gem(
		view,
		ci,
		Vector2(view.size.x - inset, view.size.y - inset),
		card.total_sand,
		CardView.HEALTH_RED,
		radius,
		tint
	)


static func _gem(
	view: CardView, ci: RID, center: Vector2, value: int, color: Color, radius: float, tint: Color
) -> void:
	UiPaint.fill_circle(ci, center + Vector2(0, 1.5), radius + 2.5, Color(0, 0, 0, 0.45), 28)
	UiPaint.draw_ring(ci, center, radius + 2.0, UiPalette.BRASS_LIGHT * tint, 2.5, 28)
	UiPaint.draw_ring(
		ci, center, radius + 1.0, Color(UiPalette.BRASS_HIGHLIGHT, 0.7) * tint, 1.0, 28
	)
	UiPaint.draw_ring(ci, center, radius + 3.5, Color(UiPalette.OUTLINE_DARK, 0.8), 1.0, 28)
	UiPaint.fill_circle(ci, center, radius, Color(0.08, 0.07, 0.06, 1.0), 28)
	UiPaint.draw_ring(ci, center, radius - 1.0, color * tint, 2.5 * radius / GEM_RADIUS, 28)
	var font_size := maxi(CardView.MIN_FONT_SIZE, roundi(18.0 * radius / GEM_RADIUS))
	var text := str(value)
	var width: float = view._font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x
	var at := center + Vector2(-width * 0.5, font_size * 0.36)
	view.draw_string(
		view._font, at + Vector2.ONE, text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, TEXT_SHADOW
	)
	view.draw_string(view._font, at, text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, color * tint)


## 左下の封蝋。紙の札に押した印として、縁を溶けた蝋のように少し不揃いに、面は真鍮で描く。
static func _seal(view: CardView, ci: RID, s: float, tint: Color) -> void:
	var card: CardData = view.card
	if card.emblem == null or card.is_spell:
		return
	var radius := SEAL_RADIUS * s
	var center := Vector2(GEM_INSET * s, view.size.y - GEM_INSET * s)
	var wax := PackedVector2Array()
	for i in 20:
		var angle := TAU * float(i) / 20.0
		var wobble := 1.0 + 0.07 * sin(angle * 5.0 + 1.3)
		wax.append(center + Vector2(cos(angle), sin(angle)) * radius * wobble)
	var box := Rect2(center - Vector2.ONE * radius * 1.1, Vector2.ONE * radius * 2.2)
	UiPaint.fill_gradient_polygon(
		ci, wax, box, [[0.0, Color(0, 0, 0, 0.5)], [1.0, Color(0, 0, 0, 0.5)]]
	)
	var lifted := PackedVector2Array()
	for p in wax:
		lifted.append(p - Vector2(0.0, 1.5))
	UiPaint.fill_gradient_polygon(
		ci, lifted, box, [[0.0, UiPalette.BRASS_LIGHT * tint], [1.0, UiPalette.BRASS_DARK * tint]]
	)
	UiPaint.draw_ring(
		ci,
		center - Vector2(0.0, 1.5),
		radius * 0.78,
		Color(UiPalette.BRASS_DARK, 0.6) * tint,
		1.0,
		20
	)
	var half := Vector2.ONE * SEAL_EMBLEM_SIDE * 0.5 * s
	var at := center - half - Vector2(0.0, 1.5)
	view.draw_texture_rect(
		card.emblem, Rect2(at + Vector2(0.0, 1.0), half * 2.0), false, Color(0.08, 0.05, 0.03, 0.7)
	)
	view.draw_texture_rect(
		card.emblem, Rect2(at, half * 2.0), false, UiPalette.BRASS_HIGHLIGHT * tint
	)
