extends SignatureMove
## 砂盗み(GameDesign.md 9章):撃った位置に黒い布の袋が口を開け、袋から暗い紫の帯が相手の駒へ鞭のように伸びて
## 輪に巻きつき、締まると相手の攻めの砂が光の玉になって抜け(払拭)、帯に引かれて袋へ飛び込み、袋の口が絞られて金色の輪が広がる
## (振り上げた腕から力だけが抜けた)。

const OPEN := 0.1
const LASH := 0.2
const CINCH := 0.16
const YANK := 0.26
## 袋の中心(撃った位置から)と半径、帯の弧の高さ・太さ、巻きつく輪の半径、盗った玉の半径。
const SACK := Vector2(0.0, -24.0)
const SACK_R := 22.0
const ARC := 46.0
const BAND := 6.0
const LOOP := Vector2(32.0, 12.0)
const ORB := 10.0


func impact_at() -> float:
	return OPEN + LASH + CINCH


func duration() -> float:
	return impact_at() + YANK + FADE


func draw(item: CanvasItem, t: float) -> void:
	if targets.is_empty():
		return
	var ci := item.get_canvas_item()
	var alpha := fade_alpha(t) * minf(phase(t, 0.0, OPEN) * 1.5, 1.0)
	var sack := from + SACK
	var target := targets[0]
	var lash := ease(phase(t, OPEN, LASH), 0.5)
	var cinch := phase(t, OPEN + LASH, CINCH)
	var yank := ease(phase(t, impact_at(), YANK), 1.8)
	var band_alpha := alpha * (1.0 - yank)
	if lash > 0.0 and band_alpha > 0.0:
		var points := PackedVector2Array()
		var reach := lash * (1.0 - yank)
		for i in range(19):
			points.append(PourPaint.along(sack, target, ARC, reach * float(i) / 18.0))
		ShapePaint.polyline(ci, points, Color(UiPalette.INK_950, band_alpha), BAND + 2.4, true)
		ShapePaint.polyline(ci, points, Color(UiPalette.THIEF_CLOTH, band_alpha), BAND, true)
	if cinch > 0.0 and yank < 1.0:
		var squeeze := 1.0 - 0.5 * ease(cinch, 0.6)
		var ring := PackedVector2Array()
		for i in range(25):
			var a := TAU * float(i) / 24.0
			ring.append(target + Vector2(cos(a) * LOOP.x, sin(a) * LOOP.y) * squeeze)
		ShapePaint.polyline(ci, ring, Color(UiPalette.INK_950, band_alpha), BAND + 2.4, true)
		ShapePaint.polyline(ci, ring, Color(UiPalette.THIEF_CLOTH, band_alpha), BAND, true)
	if t >= impact_at():
		var orb := PourPaint.along(target, sack, ARC, yank)
		if yank < 1.0:
			ShapePaint.circle(ci, orb, ORB + 2.0, Color(UiPalette.INK_950, alpha))
			ShapePaint.circle(ci, orb, ORB, Color(UiPalette.DRAW_FOREIGN, alpha))
			ShapePaint.circle(
				ci, orb + Vector2(-2.0, -2.0), ORB * 0.4, Color(UiPalette.IVORY, alpha)
			)
		SignaturePaint.drain_ring(item, target, phase(t, impact_at(), FADE), alpha)
		SignaturePaint.boon_ring(item, sack, phase(t, impact_at() + YANK, FADE), alpha)
	_sack(item, sack, 1.0 - phase(t, impact_at() + YANK * 0.8, YANK * 0.2), alpha)


## 黒い布の袋。`open` が1なら口が開き、0へ向かって口が絞られる。
func _sack(item: CanvasItem, center: Vector2, open: float, alpha: float) -> void:
	if alpha <= 0.0:
		return
	var ci := item.get_canvas_item()
	var body := PackedVector2Array()
	for i in range(17):
		var a := PI * 0.15 + PI * 1.7 * float(i) / 16.0
		body.append(center + Vector2(sin(a) * SACK_R, -cos(a) * SACK_R * 0.9 + 4.0))
	ShapePaint.convex_polygon(
		ci, ForesightPaint.grown(body, center, 2.0), Color(UiPalette.INK_950, alpha)
	)
	ShapePaint.convex_polygon(ci, body, Color(UiPalette.THIEF_CLOTH, alpha))
	var neck := center + Vector2(0.0, -SACK_R * 0.8)
	var mouth := lerpf(3.0, SACK_R * 0.8, open)
	item.draw_line(
		neck + Vector2(-mouth, -4.0),
		neck + Vector2(mouth, -4.0),
		Color(UiPalette.INK_950, alpha),
		5.0,
		true
	)
	item.draw_line(
		neck + Vector2(-mouth, -4.0),
		neck + Vector2(mouth, -4.0),
		Color(UiPalette.THIEF_CLOTH, alpha),
		3.0,
		true
	)
	item.draw_line(
		neck + Vector2(-5.0, 1.0), neck + Vector2(5.0, 1.0), Color(UiPalette.KINTSUGI, alpha), 2.4
	)
