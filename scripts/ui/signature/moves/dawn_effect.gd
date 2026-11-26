extends SignatureMove
## ドーンの恵与(GameDesign.md 9章):設置で、駒の頭上に金の雄鶏が現れて胸を反らして鳴き、くちばしから音の輪が
## 広がると同時に背の後光が一度に開き、朝焼けの光が自分のHPの器へ降りそそいで金色の輪が広がる(夜明けは一度に来た)。

const CROW := 0.34
const BURST := 0.14
const FALL := 0.2
## 雄鶏の位置(駒の中心から上へ)と胴・頭・尾羽の大きさ、反らす角度、後光の光条の数・長さ、降る光の数と大きさ。
const LIFT := 60.0
const BODY := Vector2(17.0, 11.0)
const HEAD := 7.0
const TAIL := 18.0
const RAISE := 0.35
const RAYS := 14
const RAY := 46.0
const BEAMS := 3
const FLIGHT_RADIUS := 17.0


func impact_at() -> float:
	return CROW + BURST + FALL


func top_extent() -> float:
	return (LIFT + RAY) * zoom


func draw(item: CanvasItem, t: float) -> void:
	if targets.is_empty():
		return
	var ci := item.get_canvas_item()
	var alpha := fade_alpha(t)
	var at := from - Vector2(0.0, LIFT * zoom)
	var burst := phase(t, CROW * 0.6, BURST + FALL)
	if burst > 0.0 and burst < 1.0:
		var reach := RAY * zoom * ease(burst, 0.35)
		var glow := alpha * sin(burst * PI)
		ShapePaint.circle(ci, at, reach * 0.55, Color(UiPalette.DAYBREAK, glow * 0.3))
		for i in range(RAYS):
			var dir := Vector2.from_angle(TAU * float(i) / float(RAYS) + 0.1)
			var span := reach * (1.0 if i % 2 == 0 else 0.7)
			var ray := PackedVector2Array([at + dir * reach * 0.25, at + dir * span])
			ShapePaint.polyline(ci, ray, Color(UiPalette.DAYBREAK, glow), 3.0 * zoom, true)
	var crow := phase(t, 0.0, CROW)
	var bird_alpha := alpha * minf(crow * 5.0, 1.0) * (1.0 - phase(t, CROW + BURST, FADE))
	if bird_alpha > 0.0:
		var lift := RAISE * sin(clampf((crow - 0.3) / 0.7, 0.0, 1.0) * PI)
		_rooster(ci, at, lift, bird_alpha, zoom)
		var crow_call := phase(t, CROW * 0.45, CROW * 0.55)
		if crow_call > 0.0 and crow_call < 1.0:
			var beak := (
				at
				+ (
					(Vector2(BODY.x * 0.8, -BODY.y * 1.3) + Vector2(HEAD * 1.4, 0.0).rotated(-lift))
					* zoom
				)
			)
			SignaturePaint.toll_arcs(
				item,
				beak,
				Vector2.from_angle(-lift - 0.3),
				26.0 * zoom * ease(crow_call, 0.5),
				bird_alpha * (1.0 - crow_call)
			)
	var fall := phase(t, CROW + BURST, FALL)
	for target in targets:
		for i in range(BEAMS):
			var start := at + Vector2((float(i) - 1.0) * 22.0, -10.0) * zoom
			SignaturePaint.toll_flight(
				item,
				start,
				target,
				fall,
				FLIGHT_RADIUS * (1.0 - 0.2 * absf(float(i) - 1.0)),
				alpha,
				UiPalette.DAYBREAK
			)
		SignaturePaint.boon_ring(item, target, phase(t, impact_at(), FADE), alpha)


## 金の雄鶏(右向き)。`lift` だけ首を反らす。
static func _rooster(ci: RID, at: Vector2, lift: float, alpha: float, scale: float) -> void:
	var ink := Color(UiPalette.INK_950, alpha * 0.85)
	var gold := Color(UiPalette.TOLL_BRASS, alpha)
	for i in range(3):
		var a := -PI * 0.62 - 0.32 * float(i)
		var root := at + Vector2(-BODY.x * 0.7, -BODY.y * 0.2) * scale
		var tip := root + Vector2.from_angle(a) * TAIL * scale * (1.0 - 0.12 * float(i))
		var mid := root.lerp(tip, 0.5) + Vector2(-4.0, 0.0) * scale
		var feather := PackedVector2Array([root, mid, tip])
		ShapePaint.polyline(ci, feather, ink, 6.0 * scale, true)
		ShapePaint.polyline(
			ci,
			feather,
			Color(UiPalette.DAYBREAK if i == 1 else UiPalette.FEATHER_RED, alpha),
			3.8 * scale,
			true
		)
	var body := PackedVector2Array()
	for i in range(16):
		var a := TAU * float(i) / 16.0
		body.append(at + Vector2(cos(a) * BODY.x, sin(a) * BODY.y) * scale)
	var rim := PackedVector2Array()
	for p in body:
		rim.append(at + (p - at) * 1.14)
	ShapePaint.convex_polygon(ci, rim, ink)
	ShapePaint.convex_polygon(ci, body, gold)
	var neck := at + Vector2(BODY.x * 0.7, -BODY.y * 0.4) * scale
	var head := neck + Vector2(0.0, -BODY.y * 1.1).rotated(lift * 0.5) * scale
	ShapePaint.polyline(ci, PackedVector2Array([neck, head]), ink, (HEAD * 1.4 + 2.0) * scale, true)
	ShapePaint.polyline(ci, PackedVector2Array([neck, head]), gold, HEAD * 1.4 * scale, true)
	ShapePaint.circle(ci, head, (HEAD + 1.2) * scale, ink)
	ShapePaint.circle(ci, head, HEAD * scale, gold)
	for i in range(3):
		var comb := head + Vector2(-3.0 + 3.0 * float(i), -HEAD - 1.0).rotated(-lift) * scale
		ShapePaint.circle(ci, comb, 2.6 * scale, Color(UiPalette.FEATHER_RED, alpha))
	var beak_dir := Vector2.from_angle(-lift)
	var beak := PackedVector2Array(
		[
			head + beak_dir.rotated(-0.5) * HEAD * 0.8 * scale,
			head + beak_dir * HEAD * 1.9 * scale,
			head + beak_dir.rotated(0.5) * HEAD * 0.8 * scale,
		]
	)
	ShapePaint.convex_polygon(ci, beak, Color(UiPalette.FLAME, alpha))
	ShapePaint.circle(ci, head + Vector2(1.5, -1.0) * scale, 1.2 * scale, ink)
