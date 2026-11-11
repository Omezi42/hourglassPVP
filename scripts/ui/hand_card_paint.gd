class_name HandCardPaint
extends RefCounted
## 手札の札の描画(GameDesign.md 9章「手札は紙の札」)。`CardView.Mode.HAND` の `_draw()` から
## `draw(view)` を呼ぶ。`CardViewPaint` と同じく第1引数に `CardView` を取る static だけの層で、
## 状態(選択・ホバー・有効/無効)は `CardView` が持つ。
##
## 札は上から「絵の窓 / 名前の帯 / キーワードの行」の3段で組み、四隅に
## 左上=コスト / 右上=紋章の印 / 左下=攻撃力 / 右下=体力 を置く(数値の配置はDCGの慣習どおり。場の駒と同じ並び)。
## **絵の窓の奥にそのカードの色の光だまり**を敷く。絵は全種が同じ砂時計の色違いのため、
## 窓の奥まで同じ色で染めると、暗い手元の面の上でも1枚ずつの色が立つ。
## 寸法はすべて `HAND_SIZE_PX`(118x158)を基準にした比(`CardView._hand_scale()`)で決める。

const CORNER := 9.0
## 盤面に応じてコストが下がっているときのコストの石の色(GameDesign.md 9章)。
const COST_DOWN_GREEN := UiPalette.GOOD
const COST_DOWN_DEEP := Color(0.12, 0.38, 0.18)
const FRAME_WIDTH := 2.0
const SELECT_WIDTH := 3.0
const SELECT_GROW := 2.0
## 絵の窓。`CardView._hand_art_box()`(絵を収める正方形)を少し広げた矩形。
const WINDOW_INSET := 5.0
const WINDOW_CORNER := 5.5
const WINDOW_TOP_DARKEN := 0.78
const WINDOW_BOTTOM_DARKEN := 0.55
const WINDOW_EDGE := Color(0, 0, 0, 0.5)
## 光だまりの濃さ(中心)と広がり(窓の幅に対する直径の比)。
const GLOW_ALPHA := 0.55
const GLOW_SPREAD := 1.35
## 名前の帯(紙)と、その下のキーワードの行。
const NAME_BAND_TOP := 101.0
const NAME_BAND_HEIGHT := 20.0
const NAME_BAND_SIDE := 3.0
const NAME_FONT := 13
const KEYWORD_BASELINE := 134.0
const KEYWORD_FONT := 11
const SPELL_KEYWORD := Color(0.72, 0.86, 1.0)
## 四隅の数値の宝石(コスト・攻撃力・体力)と紋章の印。
const GEM_RADIUS := 13.5
const GEM_INSET := 15.0
const SEAL_RADIUS := 10.5
## 砂術の窓に置く紋章の大きさと色。
const SPELL_EMBLEM_SIDE := 58.0
const SPELL_EMBLEM := Color(0.82, 0.90, 1.0)
const SPELL_EDGE_LIGHT := Color(0.75, 0.88, 1.0)
const HOVER_FILM := Color(1, 1, 1, 0.06)

## 光だまりの放射グラデーション(白)。色は描くときに乗せるため、全カードで1枚を共有する。
static var _glow_cache: GradientTexture2D


static func draw(view: CardView) -> void:
	var ci := view.get_canvas_item()
	var s: float = view._hand_scale()
	var rect := Rect2(Vector2.ZERO, view.size)
	var tint: Color = view._tint()
	var points := UiKit.rr(rect, CORNER * s)
	# 札の地は夜の藍。紙は名前の帯だけ(暗い卓の上で名前がいちばん読めるように。GameDesign.md 9章)。
	UiKit.vgrad(ci, points, [[0.0, UiPalette.INK_600 * tint], [1.0, UiPalette.INK_900 * tint]])
	_window(view, ci, s, tint)
	_name_band(view, ci, s, tint)
	_frame(view, ci, rect, points, s, tint)
	_labels(view, s, tint)
	_gems(view, ci, s, tint)
	_seal(view, ci, s, tint)
	if not view.badge.is_empty():
		CardViewPaint.badge(view, rect)
	if view._hovering and view.enabled:
		UiKit.fill(ci, points, HOVER_FILM)


## 絵の窓。カードの砂の色で染めた暗い面の奥へ光だまりを敷き、その上に砂時計を立てる。
static func _window(view: CardView, ci: RID, s: float, tint: Color) -> void:
	var card: CardData = view.card
	var box: Rect2 = view._hand_art_box()
	var rect := box.grow(WINDOW_INSET * s)
	rect.position.y = maxf(rect.position.y, (FRAME_WIDTH + 3.0) * s)
	var points := UiKit.rr(rect, WINDOW_CORNER * s)
	var accent := (
		UiPalette.COST if card.is_spell else CardSkins.accent_color(card, view.skin_viewer)
	)
	UiKit.vgrad(
		ci,
		points,
		[
			[0.0, accent.darkened(WINDOW_TOP_DARKEN) * tint],
			[1.0, accent.darkened(WINDOW_BOTTOM_DARKEN) * tint]
		]
	)
	_glow(view, rect, accent * tint)
	if card.is_spell:
		_spell_emblem(view, box, s, tint)
	else:
		var texture: Texture2D = view._icon()
		if texture != null:
			view.draw_texture_rect(texture, view._fit_art(texture, box), false, tint)
	UiKit.stroke(ci, points, WINDOW_EDGE, UiKit.LINE_MIN)


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
		UiPaint.EMBLEM_SHADOW
	)
	view.draw_texture_rect(
		card.emblem, Rect2(center - half, half * 2.0), false, SPELL_EMBLEM * tint
	)


## 名前を載せる紙の帯。
static func _name_band(view: CardView, ci: RID, s: float, tint: Color) -> void:
	var rect := Rect2(
		NAME_BAND_SIDE * s,
		NAME_BAND_TOP * s,
		view.size.x - NAME_BAND_SIDE * 2.0 * s,
		NAME_BAND_HEIGHT * TextSize.factor() * s
	)
	UiKit.vgrad(
		ci,
		UiKit.rr(rect, NAME_BAND_SIDE * s),
		[[0.0, UiPalette.PAPER * tint], [1.0, UiPalette.PAPER_DEEP * tint]],
		true
	)


## 札の縁。真鍮の細い縁(砂術は青。「置くカードではない」と手札の時点で分かるように)。
## 選択中は水色の太い輪郭を外へ足す(守護の真鍮と取り違えないよう別系統の色)。
static func _frame(
	view: CardView, ci: RID, rect: Rect2, points: PackedVector2Array, s: float, tint: Color
) -> void:
	var stops := [
		[0.0, UiPalette.GOLD_HI * tint],
		[0.5, UiPalette.BRASS * tint],
		[1.0, UiPalette.BRASS_DEEP * tint]
	]
	if view.card.is_spell:
		stops = [
			[0.0, SPELL_EDGE_LIGHT * tint],
			[0.5, UiPalette.COST * tint],
			[1.0, UiPalette.COST_DEEP * tint]
		]
	UiKit.stroke(ci, points, Color(0, 0, 0, UiKit.GLASS_OUTER_ALPHA), (FRAME_WIDTH + 2.0) * s)
	UiKit.stroke_grad(ci, points, stops, FRAME_WIDTH * s)
	if view.selected:
		UiKit.stroke(
			ci,
			UiKit.rr(rect.grow(SELECT_GROW), CORNER * s + SELECT_GROW),
			CardView.SELECT_CYAN,
			SELECT_WIDTH * s
		)
	elif view.unselect_amount > 0.01:
		var inset: float = CardView.UNSELECT_INSET * (1.0 - view.unselect_amount)
		UiKit.stroke(
			ci,
			UiKit.rr(rect.grow(-inset), CORNER * s),
			Color(CardView.SELECT_CYAN, view.unselect_amount),
			SELECT_WIDTH * s
		)


## 名前は紙の帯の中央、キーワードはその下の行。キーワードの行の両脇は四隅の宝石が占めるため、
## 文字はその内側の幅へ収める(`_centered_text` が収まらない場合だけ縮める)。
## 文字の大きさ「大」(GameDesign.md 9章)では名前の帯ごと高くし、キーワードの行はそのぶん下げる。
static func _labels(view: CardView, s: float, tint: Color) -> void:
	var card: CardData = view.card
	var f := TextSize.factor()
	var band_height := NAME_BAND_HEIGHT * f
	var name_font := roundi(NAME_FONT * f * s)
	var name_baseline := (NAME_BAND_TOP + band_height * 0.5) * s + name_font * 0.36
	view._centered_text(card.display_name, name_font, name_baseline, UiPalette.PAPER_INK)
	var note: String = CardViewPaint.keyword_text(view)
	if note.is_empty():
		return
	var limit := view.size.x - (GEM_INSET + GEM_RADIUS + 2.0) * 2.0 * s
	var keyword_drop := (band_height - NAME_BAND_HEIGHT) + KEYWORD_FONT * (f - 1.0)
	view._centered_text(
		note,
		roundi(KEYWORD_FONT * f * s),
		(KEYWORD_BASELINE + keyword_drop) * s,
		(SPELL_KEYWORD if card.is_spell else UiPalette.SAND_HI) * tint,
		limit
	)


## コスト=左上 / 攻撃力=左下 / 体力=右下(GameDesign.md 9章)。数値は場に出た時点のもの。
## 真鍮の縁で嵌めた宝石として描く。下がったコストは緑の石にする。
## **砂術は攻撃力・体力を持たないため下の2つを出さない**。
static func _gems(view: CardView, ci: RID, s: float, tint: Color) -> void:
	var card: CardData = view.card
	var radius := GEM_RADIUS * s
	var inset := GEM_INSET * s
	var cost := card.cost if view.play_cost < 0 else view.play_cost
	var cost_at := Vector2(inset, inset)
	if cost < card.cost:
		_gem(view, ci, cost_at, cost, COST_DOWN_GREEN, COST_DOWN_DEEP, radius, tint)
	else:
		_gem(view, ci, cost_at, cost, UiPalette.COST, UiPalette.COST_DEEP, radius, tint)
	if card.is_spell:
		return
	var bottom := view.size.y - inset
	_gem(
		view,
		ci,
		Vector2(inset, bottom),
		card.initial_attack,
		UiPalette.ATTACK,
		UiPalette.ATTACK_DEEP,
		radius,
		tint
	)
	_gem(
		view,
		ci,
		Vector2(view.size.x - inset, bottom),
		card.initial_health(),
		UiPalette.HEALTH,
		UiPalette.HEALTH_DEEP,
		radius,
		tint
	)


static func _gem(
	view: CardView,
	ci: RID,
	center: Vector2,
	value: int,
	light: Color,
	deep: Color,
	radius: float,
	tint: Color
) -> void:
	UiKit.gem(ci, center, radius, light, deep, tint)
	UiKit.gem_text(ci, view._font, center, radius, str(value), Color.WHITE * tint)


## 右上の紋章の印(左下は攻撃力が使う)。
static func _seal(view: CardView, ci: RID, s: float, tint: Color) -> void:
	var card: CardData = view.card
	if card.emblem == null or card.is_spell:
		return
	var center := Vector2(view.size.x - GEM_INSET * s, GEM_INSET * s)
	UiKit.seal(ci, center, SEAL_RADIUS * s, card.emblem, UiPalette.GOLD * tint)
