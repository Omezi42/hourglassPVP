class_name RarityPaint
extends RefCounted
## レアリティの見た目(GameDesign.md 9章「レアリティ」)。カードの面の宝石・縁の内線・レジェンドの翼と光、
## 開封で使うカードの裏をここへ集める。手札・在庫・図鑑・開封が同じ描き方を共有する。

## 宝石の大きさ(札の幅に対する比)。菱形の半対角。
const GEM_RATIO := 0.075
const GEM_SETTING := 1.45
const INNER_LINE_INSET := 4.0
const INNER_LINE_WIDTH := 1.4
const WING_SPAN := 2.6
const HALO_ALPHA := 0.34
const HALO_SPREAD := 1.22
## 裏の縁の光(コモン・レア・エピック・レジェンドの順)の広がりと濃さ。
const BACK_GLOW_SPREAD: Array[float] = [0.0, 1.10, 1.18, 1.30]
const BACK_GLOW_ALPHA: Array[float] = [0.0, 0.45, 0.6, 0.85]
const BACK_RAYS := 14
const BACK_DISC_RATIO := 0.2
const BACK_CORNER_RATIO := 0.06
const NAMES: Array[String] = ["コモン", "レア", "エピック", "レジェンド"]


static func color(rarity: CardEnums.Rarity) -> Color:
	match rarity:
		CardEnums.Rarity.RARE:
			return UiPalette.RARITY_RARE
		CardEnums.Rarity.EPIC:
			return UiPalette.RARITY_EPIC
		CardEnums.Rarity.LEGENDARY:
			return UiPalette.RARITY_LEGEND
		_:
			return UiPalette.RARITY_COMMON


static func rarity_name(rarity: CardEnums.Rarity) -> String:
	return NAMES[rarity]


## 弾のカードか(基本セット70枚は宝石を持たない)。
static func marked(card: CardData) -> bool:
	return card != null and not card.set_id.is_empty()


## 真鍮で嵌めた菱形の宝石。`half` は菱形の半対角。
static func gem(
	ci: RID, center: Vector2, half: float, rarity: CardEnums.Rarity, tint := Color.WHITE
) -> void:
	var hue := color(rarity)
	var setting := half * GEM_SETTING
	UiKit.fill(
		ci, diamond(center + Vector2(0, setting * 0.12), setting * 1.08), Color(Color.BLACK, 0.45)
	)
	UiKit.vgrad(
		ci,
		diamond(center, setting),
		[
			[0.0, UiPalette.GOLD_HI * tint],
			[0.5, UiPalette.BRASS * tint],
			[1.0, UiPalette.BRASS_DEEP * tint]
		]
	)
	UiKit.vgrad(
		ci,
		diamond(center, half),
		[
			[0.0, hue.lerp(Color.WHITE, 0.55) * tint],
			[0.5, hue * tint],
			[1.0, hue.darkened(0.45) * tint]
		]
	)
	UiKit.fill(
		ci,
		PackedVector2Array(
			[center + Vector2(0, -half), center + Vector2(half * 0.5, -half * 0.1), center]
		),
		Color(Color.WHITE, 0.35 * tint.a)
	)


static func diamond(center: Vector2, half: float) -> PackedVector2Array:
	return PackedVector2Array(
		[
			center + Vector2(0, -half),
			center + Vector2(half * 0.78, 0),
			center + Vector2(0, half),
			center + Vector2(-half * 0.78, 0)
		]
	)


## 札の外へ敷くレジェンドの光。札の面より先に描く。
static func halo(ci: RID, rect: Rect2, card: CardData, tint := Color.WHITE) -> void:
	if not marked(card) or card.rarity != CardEnums.Rarity.LEGENDARY:
		return
	UiKit.glow(
		ci,
		rect.get_center(),
		rect.size * 0.5 * HALO_SPREAD,
		Color(UiPalette.RARITY_LEGEND, HALO_ALPHA * tint.v * tint.a)
	)


## 縁の内線・レジェンドの金の縁・宝石と翼。札の縁を描いた後に重ねる。
static func card_marks(
	ci: RID, rect: Rect2, corner: float, card: CardData, tint := Color.WHITE
) -> void:
	if not marked(card):
		return
	var hue := color(card.rarity)
	var s := rect.size.x / CardView.HAND_SIZE_PX.x
	if card.rarity == CardEnums.Rarity.LEGENDARY:
		UiKit.stroke_grad(
			ci,
			UiKit.rr(rect, corner),
			[
				[0.0, UiPalette.GOLD_HI * tint],
				[0.5, UiPalette.SAND * tint],
				[1.0, UiPalette.SAND_DEEP * tint]
			],
			HandCardPaint.FRAME_WIDTH * 1.6 * s
		)
	if card.rarity != CardEnums.Rarity.COMMON:
		var inset := INNER_LINE_INSET * s
		UiKit.stroke(
			ci,
			UiKit.rr(rect.grow(-inset), maxf(corner - inset, 0.0)),
			Color(hue * tint, 0.9 * tint.a),
			INNER_LINE_WIDTH * s
		)
	var half := rect.size.x * GEM_RATIO
	var at := Vector2(rect.get_center().x, rect.position.y + half * 0.2)
	if card.rarity == CardEnums.Rarity.LEGENDARY:
		_wings(ci, at, half, tint)
	gem(ci, at, half, card.rarity, tint)


## 宝石の両脇の真鍮の小さな翼(3枚の羽根を扇に重ねる)。
static func _wings(ci: RID, at: Vector2, half: float, tint: Color) -> void:
	for side in [-1.0, 1.0]:
		for i in 3:
			var length := half * (WING_SPAN - i * 0.45)
			var lift := half * (0.55 - i * 0.32)
			var root := at + Vector2(side * half * 0.9, 0)
			var tip := root + Vector2(side * length, -lift)
			var under := root + Vector2(side * length * 0.7, -lift + half * 0.42)
			UiKit.fill(
				ci,
				PackedVector2Array([root + Vector2(0, -half * 0.22), tip, under]),
				(
					(UiPalette.GOLD_HI if i == 0 else UiPalette.GOLD.lerp(UiPalette.BRASS, i * 0.4))
					* tint
				)
			)


## 開封で使うカードの裏。`lit` は縁の光の強さ(0〜1)、`turn` は紋章の砂時計の回転(ラジアン)。
static func card_back(
	ci: RID, rect: Rect2, rarity: CardEnums.Rarity, lit := 1.0, turn := 0.0, tint := Color.WHITE
) -> void:
	var hue := color(rarity)
	var corner := UiKit.radius(rect) * 0.6
	var spread: float = BACK_GLOW_SPREAD[rarity]
	if spread > 0.0 and lit > 0.0:
		if rarity == CardEnums.Rarity.LEGENDARY:
			_rays(ci, rect, hue, lit * tint.a)
		UiKit.glow(
			ci,
			rect.get_center(),
			rect.size * 0.5 * spread,
			Color(hue, float(BACK_GLOW_ALPHA[rarity]) * lit * tint.a)
		)
	var points := UiKit.rr(rect, corner)
	UiKit.vgrad(
		ci,
		points,
		[[0.0, UiPalette.CARD_BACK_TOP * tint], [1.0, UiPalette.CARD_BACK_BOTTOM * tint]]
	)
	var center := rect.get_center()
	var disc := rect.size.x * BACK_DISC_RATIO
	for i in 3:
		ShapePaint.circle(
			ci,
			center,
			disc * (1.7 + i * 0.75),
			Color(UiPalette.GOLD, 0.10 * tint.a),
			false,
			1.0,
			true
		)
	var inner := rect.grow(-rect.size.x * 0.07)
	UiKit.stroke(
		ci, UiKit.rr(inner, corner * 0.6), Color(UiPalette.GOLD * tint, 0.55 * tint.a), 1.2
	)
	var edge := hue if rarity != CardEnums.Rarity.COMMON else UiPalette.BRASS
	UiKit.stroke(ci, points, Color(edge * tint, tint.a), maxf(rect.size.x * 0.018, 1.5))
	var dot := rect.size.x * BACK_CORNER_RATIO * 0.5
	var pad := rect.size.x * 0.13
	for corner_at in [
		inner.position + Vector2(pad, pad) * 0.45,
		Vector2(inner.end.x, inner.position.y) + Vector2(-pad, pad) * 0.45,
		Vector2(inner.position.x, inner.end.y) + Vector2(pad, -pad) * 0.45,
		inner.end - Vector2(pad, pad) * 0.45
	]:
		UiKit.fill(ci, diamond(corner_at, dot), Color(edge * tint, tint.a))
	emblem(ci, center, disc, rarity, turn, tint)


## 裏の中央の紋章: 真鍮の円盤に収めたガラスの小さな砂時計。砂の色がレアリティを示す。
static func emblem(
	ci: RID,
	center: Vector2,
	radius: float,
	rarity: CardEnums.Rarity,
	turn := 0.0,
	tint := Color.WHITE
) -> void:
	var hue := color(rarity)
	var sand := UiPalette.SAND if rarity == CardEnums.Rarity.COMMON else hue
	if rarity != CardEnums.Rarity.COMMON:
		UiKit.glow(ci, center, Vector2.ONE * radius * 1.5, Color(hue, 0.45 * tint.a))
	UiKit.vgrad(
		ci,
		UiKit.ellipse(center, Vector2.ONE * radius),
		[
			[0.0, UiPalette.GOLD_HI * tint],
			[0.5, UiPalette.BRASS * tint],
			[1.0, UiPalette.BRASS_DEEP * tint]
		]
	)
	UiKit.fill(ci, UiKit.ellipse(center, Vector2.ONE * radius * 0.78), UiPalette.INK_900 * tint)
	var h := radius * 0.5
	var w := radius * 0.36
	var xf := Transform2D(turn, center)
	var top := PackedVector2Array([Vector2(-w, -h), Vector2(w, -h), Vector2(0, 0)])
	var bottom := PackedVector2Array([Vector2(0, 0), Vector2(w, h), Vector2(-w, h)])
	UiKit.fill(ci, xf * top, Color(UiPalette.GLASS_TINT * tint, 0.35 * tint.a))
	UiKit.fill(ci, xf * bottom, Color(UiPalette.GLASS_TINT * tint, 0.35 * tint.a))
	var pile := PackedVector2Array(
		[
			Vector2(-w * 0.5, h * 0.5),
			Vector2(w * 0.5, h * 0.5),
			Vector2(w * 0.92, h * 0.92),
			Vector2(-w * 0.92, h * 0.92)
		]
	)
	var rest := PackedVector2Array(
		[Vector2(-w * 0.55, -h * 0.55), Vector2(w * 0.55, -h * 0.55), Vector2(0, -h * 0.05)]
	)
	UiKit.fill(ci, xf * pile, Color(sand.lerp(Color.WHITE, 0.15) * tint, tint.a))
	UiKit.fill(ci, xf * rest, Color(sand * tint, tint.a))
	for y in [-h - 2.0, h + 2.0]:
		var cap := PackedVector2Array(
			[
				Vector2(-w * 1.25, y - 1.6),
				Vector2(w * 1.25, y - 1.6),
				Vector2(w * 1.25, y + 1.6),
				Vector2(-w * 1.25, y + 1.6)
			]
		)
		UiKit.fill(ci, xf * cap, UiPalette.GOLD * tint)


## レジェンドの裏から外へ出る光の筋。
static func _rays(ci: RID, rect: Rect2, hue: Color, alpha: float) -> void:
	var center := rect.get_center()
	var reach := rect.size.length() * 0.78
	var near := rect.size.length() * 0.38
	for i in BACK_RAYS:
		var angle := TAU * i / BACK_RAYS
		var dir := Vector2(cos(angle), sin(angle))
		var side := Vector2(-dir.y, dir.x) * rect.size.x * 0.05
		UiKit.fill(
			ci,
			PackedVector2Array(
				[center + dir * near - side, center + dir * reach, center + dir * near + side]
			),
			Color(hue, 0.35 * alpha)
		)
