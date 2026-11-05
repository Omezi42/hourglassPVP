class_name HomeProps
extends RefCounted
## ホームの札に添える小物の絵(GameDesign.md 9章)。新しい画像を使わず、真鍮・濃紺・革・木の面をコードで描く。
## **絵は `DESIGN_SIZE` の中の座標で描き、`draw()` が置き場所の大きさへ縮尺を掛ける。**
## 各関数の座標の数値は絵の形そのもの(線を引く位置)であり、調整用の値ではない。

enum Kind { CARDS, BOOK, CHEST, GIFT }

const DESIGN_SIZE := Vector2(120, 92)
const BRASS := [
	[0.0, Color(0.99, 0.88, 0.56)],
	[0.45, Color(0.86, 0.66, 0.30)],
	[1.0, Color(0.52, 0.35, 0.12)],
]
const BRASS_DARK := [[0.0, Color(0.80, 0.60, 0.27)], [1.0, Color(0.42, 0.27, 0.09)]]
const NAVY := [[0.0, Color(0.20, 0.26, 0.46)], [1.0, Color(0.07, 0.09, 0.19)]]
const LEATHER := [
	[0.0, Color(0.17, 0.22, 0.42)],
	[0.55, Color(0.11, 0.14, 0.29)],
	[1.0, Color(0.06, 0.07, 0.15)],
]
const WOOD := [[0.0, Color(0.62, 0.38, 0.19)], [1.0, Color(0.33, 0.18, 0.08)]]
const WOOD_LID := [[0.0, Color(0.72, 0.46, 0.24)], [1.0, Color(0.42, 0.24, 0.11)]]
const PAGE := [[0.0, Color(0.97, 0.93, 0.80)], [1.0, Color(0.80, 0.73, 0.57)]]
const RIBBON := [[0.0, Color(0.85, 0.20, 0.18)], [1.0, Color(0.55, 0.10, 0.10)]]
const INK := Color(0.07, 0.05, 0.03, 0.9)
const GRAIN := Color(0.25, 0.13, 0.05, 0.6)
const PAGE_LINE := Color(0.62, 0.54, 0.40, 0.7)
const EMBOSS := Color(0.98, 0.84, 0.50)
const RIVET := Color(0.40, 0.26, 0.08)
const COIN_RIM := Color(0.55, 0.36, 0.08)
const COIN := Color(0.99, 0.84, 0.40)
const GOLD_LIGHT := Color(1.0, 0.95, 0.75)
const GLOW := Color(1.0, 0.85, 0.5, 0.05)
const GLOW_RINGS := 6
const SHADOW := Color(0, 0, 0, 0.35)
const SHADOW_OFFSET := Vector2(3, 4)

## ホバーの動き(GameDesign.md 9章)。`hover` は浮きの進み(開いたまま保つ形)、`play` は入った瞬間に1度だけ流す進み。
## カード: 扇の開き足し / 揃え直すときに寄せる量 / 揃え直した後のぱちっとした揺れ(回数と角度)/ 前のカードの浮き。
const CARD_SPREAD := 0.18
const CARD_GATHER := 0.65
const CARD_SNAPS := 3.0
const CARD_SNAP_ANGLE := 0.07
const CARD_RISE := 5.0
## 本: 表紙の右端が手前へ起きる量と、下の紙の光。
const BOOK_OPEN := Vector2(14, 5)
const BOOK_PAGE_GLOW := 20.0
const BOOK_GLOW_STRENGTH := 4.0
## 宝箱: 蓋の浮き・蓋を奥へ倒して見せる縮み・光の広がりと筋。
const CHEST_LIFT := 9.0
const CHEST_TILT := 0.3
const CHEST_GLOW_GROWTH := 0.2
const CHEST_GLOW_STRENGTH := 1.2
const CHEST_RAYS := 5
const CHEST_RAY_SPREAD := 1.1
const CHEST_RAY_LENGTH := 42.0
const CHEST_RAY_WIDTH := 0.07
const CHEST_RAY_ALPHA := 0.5
## 贈り物の箱: 跳ねる高さと、蓋だけが余計に浮く量。
const GIFT_HOP := 7.0
const GIFT_LID_POP := 4.0


## `rect` の中央へ、縦横比を保ったまま収まる大きさで描く。`hover` / `play` はホバーの動き(0〜1)。
static func draw(kind: Kind, ci: CanvasItem, rect: Rect2, hover := 0.0, play := 0.0) -> void:
	var scale := minf(rect.size.x / DESIGN_SIZE.x, rect.size.y / DESIGN_SIZE.y)
	var origin := rect.get_center() - DESIGN_SIZE * scale * 0.5
	if kind == Kind.GIFT:
		origin.y -= sin(PI * play) * GIFT_HOP * scale
	ci.draw_set_transform(origin, 0.0, Vector2(scale, scale))
	match kind:
		Kind.CARDS:
			_cards(ci, hover, play)
		Kind.BOOK:
			_book(ci, hover)
		Kind.CHEST:
			_chest(ci, hover)
		Kind.GIFT:
			_gift(ci, play)
	ci.draw_set_transform_matrix(Transform2D.IDENTITY)


## 後光(淡い円を重ねる)。砂時計の絵の後ろにも使う。`strength` で濃さを掛ける。
static func glow(ci: CanvasItem, center: Vector2, radius: float, strength := 1.0) -> void:
	for k in GLOW_RINGS:
		var shrink := 1.0 - float(k) / float(GLOW_RINGS + 1)
		ShapePaint.circle(
			ci.get_canvas_item(), center, radius * shrink, Color(GLOW, GLOW.a * strength)
		)


## デッキ編集: 扇に開いた3枚のカード。ホバーで一度寄せて揃え直し(しゃかっ)、少し広く開いて止まる(ぱちっ)。
static func _cards(ci: CanvasItem, hover: float, play: float) -> void:
	var c := DESIGN_SIZE * 0.5 + Vector2(0, 6)
	var spread := (1.0 + CARD_SPREAD * hover) * (1.0 - CARD_GATHER * sin(PI * play))
	var snap := sin(PI * CARD_SNAPS * play) * (1.0 - play) * CARD_SNAP_ANGLE
	var rise := sin(PI * play) * CARD_RISE
	_card(ci, c + Vector2(-26 * spread, 4), Vector2(48, 68), -0.38 * spread - snap)
	_card(ci, c + Vector2(26 * spread, 4), Vector2(48, 68), 0.38 * spread + snap)
	_card(ci, c - Vector2(0, rise), Vector2(52, 74), snap * 0.5)


static func _card(ci: CanvasItem, center: Vector2, card_size: Vector2, angle: float) -> void:
	var outer := _rot(
		UiPaint.rounded_rect_points_uniform(Rect2(-card_size * 0.5, card_size), 6, 6), center, angle
	)
	var inner_size := card_size - Vector2(8, 8)
	var inner := _rot(
		UiPaint.rounded_rect_points_uniform(Rect2(-inner_size * 0.5, inner_size), 4, 6),
		center,
		angle
	)
	_shadow(ci, outer)
	_fill(ci, outer, BRASS)
	_fill(ci, inner, NAVY)
	var d := card_size.x * 0.18
	var diamond := _rot(
		PackedVector2Array(
			[Vector2(0, -d * 1.4), Vector2(d, 0), Vector2(0, d * 1.4), Vector2(-d, 0)]
		),
		center,
		angle
	)
	_fill(ci, diamond, BRASS)
	_outline(ci, outer, 1.5)


## 砂時計図鑑: 斜め前から見た革装の本。紙の束の厚み・背の飾り・型押しの二重の枠・角金具・紋章・しおり紐。
## ホバーで表紙の右端が手前へ起き、下の紙が光る。
static func _book(ci: CanvasItem, hover: float) -> void:
	var skew := Vector2(10, -6)
	var tl := Vector2(20, 14)
	var tr0 := tl + Vector2(70, 0) + skew
	var bl := tl + Vector2(0, 70)
	var br0 := bl + Vector2(70, 0) + skew
	var tr := tr0 + Vector2(-BOOK_OPEN.x, -BOOK_OPEN.y) * hover
	var br := br0 + Vector2(-BOOK_OPEN.x, BOOK_OPEN.y) * hover
	var thick := Vector2(6, 9)
	var block := PackedVector2Array([tr0, tr0 + thick, br0 + thick, bl + thick, bl])
	_shadow(ci, block)
	_fill(ci, block, PAGE)
	for k in 5:
		var t := 0.18 + 0.16 * float(k)
		ci.draw_line(
			tr0.lerp(br0, t) + thick * 0.15, tr0.lerp(br0, t) + thick * 0.95, PAGE_LINE, 1.0
		)
		ci.draw_line(bl.lerp(br0, t) + thick * 0.15, bl.lerp(br0, t) + thick * 0.95, PAGE_LINE, 1.0)
	if hover > 0.0:
		_fill(ci, PackedVector2Array([tl, tr0, br0, bl]), PAGE)
		glow(
			ci,
			tr0.lerp(br0, 0.5) - Vector2(BOOK_OPEN.x, 0),
			BOOK_PAGE_GLOW,
			hover * BOOK_GLOW_STRENGTH
		)
	var cover := PackedVector2Array([tl, tr, br, bl])
	_fill(ci, cover, LEATHER)
	var spine := PackedVector2Array(
		[tl + Vector2(-5, 2), tl + Vector2(8, 0), bl + Vector2(8, 0), bl + Vector2(-5, -2)]
	)
	_fill(ci, spine, BRASS_DARK)
	for k in 3:
		var y := 0.25 + 0.25 * float(k)
		ci.draw_line(
			tl.lerp(bl, y) + Vector2(-4, 0),
			tl.lerp(bl, y) + Vector2(8, 0),
			Color(GOLD_LIGHT, 0.8),
			1.5
		)
	ShapePaint.polyline(
		ci.get_canvas_item(),
		RankMedal.closed(_inset_quad(cover, 9.0)),
		Color(EMBOSS, 0.75),
		1.5,
		true
	)
	ShapePaint.polyline(
		ci.get_canvas_item(),
		RankMedal.closed(_inset_quad(cover, 13.0)),
		Color(EMBOSS, 0.4),
		1.5,
		true
	)
	for corner in [[tl, tr, bl], [tr, tl, br], [br, bl, tr], [bl, br, tl]]:
		var c: Vector2 = corner[0]
		var a: Vector2 = c + ((corner[1] as Vector2) - c).normalized() * 14.0
		var b: Vector2 = c + ((corner[2] as Vector2) - c).normalized() * 14.0
		_fill(ci, PackedVector2Array([c, a, b]), BRASS)
	var mid := (tl + br) * 0.5
	ShapePaint.circle(ci.get_canvas_item(), mid, 17, BRASS_DARK[1][1])
	_fill(ci, UiPaint.circle_points(mid, 15.5, 24), BRASS)
	UiPaint.draw_emblem(ci.get_canvas_item(), UiPaint.Emblem.HOURGLASS, mid, 20)
	var tie := bl.lerp(br, 0.62)
	var ribbon := PackedVector2Array(
		[
			tie,
			tie + Vector2(6, 0),
			tie + Vector2(7, 16),
			tie + Vector2(3, 12),
			tie + Vector2(-1, 17)
		]
	)
	_fill(ci, ribbon, RIBBON)
	ci.draw_line(tl + Vector2(2, 1), tr + Vector2(-2, 1), Color(1, 1, 1, 0.25), 1.5)
	_outline(ci, cover, 1.6)
	_outline(ci, block, 1.2)


## ショップ: 蓋が少し開いた宝箱。隙間から砂金が光り、板目の蓋と胴に真鍮の帯・鋲・角金具・鍵穴の座金。
## ホバーで蓋がもう少し開き(浮いて奥へ倒れる)、隙間から光の筋が漏れる。
static func _chest(ci: CanvasItem, hover: float) -> void:
	var rid := ci.get_canvas_item()
	var body := Rect2(Vector2(14, 46), Vector2(92, 42))
	var lid_h := 30.0
	var lid_base := body.position.y - 6.0
	var half_w := body.size.x * 0.5
	var cx := body.get_center().x
	var lift := CHEST_LIFT * hover
	var squash := 1.0 - CHEST_TILT * hover
	var lid := PackedVector2Array()
	for k in 21:
		var t := PI + PI * float(k) / 20.0
		var y := _lid_y(lid_base + sin(t) * lid_h, lid_base, lift, squash)
		lid.append(Vector2(cx + cos(t) * half_w, y))
	var body_pts := UiPaint.rounded_rect_points_uniform(body, 3, 4)
	_shadow(ci, body_pts)
	var gap := Rect2(body.position.x + 4, lid_base - 2 - lift, body.size.x - 8, 10 + lift)
	glow(
		ci,
		gap.get_center() + Vector2(0, -4),
		46 * (1.0 + CHEST_GLOW_GROWTH * hover),
		1.0 + CHEST_GLOW_STRENGTH * hover
	)
	ShapePaint.colored_polygon(
		rid, UiPaint.rounded_rect_points_uniform(gap, 3, 3), Color(0.20, 0.10, 0.03)
	)
	for p in [Vector2(-26, 1), Vector2(-10, -1), Vector2(6, 0), Vector2(22, 1), Vector2(-2, 3)]:
		var at: Vector2 = gap.get_center() + p
		ShapePaint.circle(rid, at, 6.5, COIN_RIM)
		ShapePaint.circle(rid, at, 5.2, COIN)
	_fill(ci, lid, WOOD_LID)
	for k in 2:
		var y := lid_base - lid_h * (0.35 + 0.33 * float(k))
		var half := _arc_half_width(lid_base - y, lid_h) * half_w
		var moved := _lid_y(y, lid_base, lift, squash)
		ci.draw_line(Vector2(cx - half + 2, moved), Vector2(cx + half - 2, moved), GRAIN, 1.2)
	ShapePaint.polyline(rid, lid.slice(4, 14), Color(1, 0.85, 0.6, 0.35), 1.5, true)
	if hover > 0.0:
		_rays(ci, gap.get_center(), hover)
	_fill(ci, body_pts, WOOD)
	for k in 2:
		var y := body.position.y + body.size.y * (0.36 + 0.3 * float(k))
		ci.draw_line(Vector2(body.position.x + 2, y), Vector2(body.end.x - 2, y), GRAIN, 1.2)
	var lip := Rect2(body.position.x - 3, lid_base - 3 - lift, body.size.x + 6, 7)
	_fill(ci, UiPaint.rounded_rect_points_uniform(lip, 3, 3), BRASS)
	var rim := Rect2(body.position + Vector2(-3, -2), Vector2(body.size.x + 6, 6))
	_fill(ci, UiPaint.rounded_rect_points_uniform(rim, 3, 3), BRASS)
	for x in [body.position.x + 16, body.end.x - 24]:
		var band := Rect2(x, body.position.y + 4, 8, body.size.y - 4)
		_fill(ci, UiPaint.rounded_rect_points_uniform(band, 2, 2), BRASS)
		for y in [body.position.y + 14, body.end.y - 8]:
			ShapePaint.circle(rid, Vector2(x + 4, y), 1.8, RIVET)
		var arc_top: float = lid_base - lid_h * _arc_half_width(x + 4 - cx, half_w)
		_fill(
			ci,
			PackedVector2Array(
				[
					Vector2(x, _lid_y(lid_base - 3, lid_base, lift, squash)),
					Vector2(x, _lid_y(arc_top + 3, lid_base, lift, squash)),
					Vector2(x + 8, _lid_y(arc_top + 3, lid_base, lift, squash)),
					Vector2(x + 8, _lid_y(lid_base - 3, lid_base, lift, squash))
				]
			),
			BRASS
		)
	for corner in [Vector2(body.position.x, body.end.y), body.end]:
		var s := -1.0 if corner.x < cx else 1.0
		var bracket := PackedVector2Array(
			[
				corner + Vector2(-2 * s, 2),
				corner + Vector2(-14 * s, 2),
				corner + Vector2(-14 * s, -4),
				corner + Vector2(-4 * s, -4),
				corner + Vector2(-4 * s, -14),
				corner + Vector2(-2 * s, -14)
			]
		)
		_fill(ci, bracket, BRASS)
	var plate_c := Vector2(cx, body.position.y + 12)
	var plate := PackedVector2Array(
		[
			plate_c + Vector2(-9, -8),
			plate_c + Vector2(9, -8),
			plate_c + Vector2(9, 4),
			plate_c + Vector2(0, 13),
			plate_c + Vector2(-9, 4)
		]
	)
	_fill(ci, plate, BRASS)
	_outline(ci, plate, 1.0)
	ShapePaint.circle(rid, plate_c + Vector2(0, -1), 2.8, INK)
	ShapePaint.colored_polygon(
		rid,
		PackedVector2Array(
			[
				plate_c + Vector2(-1.8, 0),
				plate_c + Vector2(1.8, 0),
				plate_c + Vector2(2.4, 7),
				plate_c + Vector2(-2.4, 7)
			]
		),
		INK
	)
	for spark in [Vector2(-34, -40), Vector2(30, -44), Vector2(4, -50)]:
		_sparkle(ci, body.get_center() + spark, 5)
	_outline(ci, body_pts, 1.5)
	_outline(ci, lid, 1.5)


## ミッション: リボンを掛けた濃紺の贈り物の箱。
## ホバーで小さく跳ね、蓋だけが少し余計に浮く。
static func _gift(ci: CanvasItem, play: float) -> void:
	var box := Rect2(Vector2(29, 36), Vector2(62, 52))
	var lid := Rect2(
		box.position + Vector2(-5, -12 - sin(PI * play) * GIFT_LID_POP),
		Vector2(box.size.x + 10, 16)
	)
	var box_pts := UiPaint.rounded_rect_points_uniform(box, 4, 4)
	_shadow(ci, box_pts)
	_fill(ci, box_pts, NAVY)
	_fill(ci, UiPaint.rounded_rect_points_uniform(lid, 4, 4), NAVY)
	var cx := box.get_center().x
	var ribbon := Rect2(cx - 6, lid.position.y, 12, box.end.y - lid.position.y)
	_fill(ci, UiPaint.rounded_rect_points_uniform(ribbon, 2, 2), BRASS)
	var hband := Rect2(box.position.x, box.get_center().y - 4, box.size.x, 8)
	_fill(ci, UiPaint.rounded_rect_points_uniform(hband, 2, 2), BRASS)
	for s in [-1.0, 1.0]:
		var loop := PackedVector2Array()
		for k in 20:
			var t := TAU * float(k) / 20.0
			loop.append(Vector2(cx + s * 13 + cos(t) * 12, lid.position.y - 7 + sin(t) * 8))
		_fill(ci, loop, BRASS)
		_outline(ci, loop, 1.2)
	ShapePaint.circle(ci.get_canvas_item(), Vector2(cx, lid.position.y - 6), 5, BRASS[1][1])
	_outline(ci, box_pts, 1.5)


## 蓋の上の点(高さ `y`)を、`lift` だけ浮かせて奥へ倒した(`squash` だけ背を縮めた)位置へ移す。
static func _lid_y(y: float, lid_base: float, lift: float, squash: float) -> float:
	return lid_base - lift - (lid_base - y) * squash


## 宝箱の隙間から上へ漏れる光の筋。蓋の手前へ半透明で重ねる。
static func _rays(ci: CanvasItem, from: Vector2, hover: float) -> void:
	var color := Color(GOLD_LIGHT, CHEST_RAY_ALPHA * hover)
	var clear := Color(color, 0.0)
	for k in CHEST_RAYS:
		var spread := lerpf(-CHEST_RAY_SPREAD, CHEST_RAY_SPREAD, float(k) / float(CHEST_RAYS - 1))
		var angle := spread * 0.5
		var reach := Vector2.UP.rotated(angle) * CHEST_RAY_LENGTH * hover
		var side := Vector2.RIGHT.rotated(angle) * CHEST_RAY_LENGTH * CHEST_RAY_WIDTH
		ShapePaint.polygon(
			ci.get_canvas_item(),
			PackedVector2Array([from, from + reach + side, from + reach - side]),
			PackedColorArray([color, clear, clear])
		)


## 半円の弧の、中心からの距離 `offset` における高さの比(0〜1)。
static func _arc_half_width(offset: float, radius: float) -> float:
	return sqrt(maxf(1.0 - pow(offset / radius, 2.0), 0.0))


static func _fill(ci: CanvasItem, pts: PackedVector2Array, stops: Array) -> void:
	UiPaint.fill_gradient_polygon(ci.get_canvas_item(), pts, _bounds(pts), stops)


static func _outline(ci: CanvasItem, pts: PackedVector2Array, width: float) -> void:
	ShapePaint.polyline(ci.get_canvas_item(), RankMedal.closed(pts), INK, width, true)


static func _shadow(ci: CanvasItem, pts: PackedVector2Array) -> void:
	var moved := PackedVector2Array()
	for p in pts:
		moved.append(p + SHADOW_OFFSET)
	ShapePaint.colored_polygon(ci.get_canvas_item(), moved, SHADOW)


static func _sparkle(ci: CanvasItem, at: Vector2, r: float) -> void:
	var star := PackedVector2Array()
	for k in 8:
		var reach := r if k % 2 == 0 else r * 0.35
		star.append(at + Vector2.UP.rotated(TAU * float(k) / 8.0) * reach)
	ShapePaint.colored_polygon(ci.get_canvas_item(), star, GOLD_LIGHT)


static func _inset_quad(q: PackedVector2Array, inset: float) -> PackedVector2Array:
	var c := (q[0] + q[1] + q[2] + q[3]) * 0.25
	var out := PackedVector2Array()
	for p in q:
		out.append(p + (c - p).normalized() * inset * sqrt(2.0))
	return out


static func _rot(pts: PackedVector2Array, center: Vector2, angle: float) -> PackedVector2Array:
	var out := PackedVector2Array()
	for p in pts:
		out.append(center + p.rotated(angle))
	return out


static func _bounds(pts: PackedVector2Array) -> Rect2:
	var r := Rect2(pts[0], Vector2.ZERO)
	for p in pts:
		r = r.expand(p)
	return r
