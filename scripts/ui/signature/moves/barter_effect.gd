extends SignatureMove
## バーターの設置(GameDesign.md 9章)。反転では、駒の頭上に二つの巾着が並び、金貨が回りながら相手の駒へ弧を描いて飛び、
## 入れ違いに他人の色の滴が巾着へ戻る(交換)。続く恵与では、紫の結晶をのぞかせた藍の巾着が味方の駒へ投げ渡され、
## 届いた駒から金色の輪が広がる(「交換だ。損はさせない」)。

const APPEAR := 0.1
const TOSS := 0.34
## 二つの巾着の中心(駒の中心から)と半径、投げる弧の高さ、金貨の半径と回る速さ、投げ渡す巾着の半径。
const POUCHES := Vector2(0.0, -92.0)
const POUCH_GAP := 22.0
const POUCH_R := 15.0
const ARC := 60.0
const COIN_R := 11.0
const COIN_TURNS := 3.0
const TOP := 120.0


func top_extent() -> float:
	return TOP * zoom


func impact_at() -> float:
	return APPEAR + TOSS


func draw(item: CanvasItem, t: float) -> void:
	if targets.is_empty():
		return
	var ci := item.get_canvas_item()
	var alpha := fade_alpha(t) * minf(phase(t, 0.0, APPEAR) * 1.5, 1.0)
	var target := targets[0]
	var center := from + POUCHES * zoom
	var left := center + Vector2(-POUCH_GAP, 0.0) * zoom
	var right := center + Vector2(POUCH_GAP, 4.0) * zoom
	var toss := phase(t, APPEAR, TOSS)
	var landed := phase(t, impact_at(), FADE)
	if _giving():
		_pouch(item, right, POUCH_R * zoom, UiPalette.OAK, alpha)
		if toss < 1.0:
			var at := PourPaint.along(left, target, ARC, ease(toss, -1.6))
			_pouch(item, at, POUCH_R * zoom, UiPalette.NIGHT_VEIL, alpha)
		SignaturePaint.boon_ring(item, target, landed, alpha)
		return
	_pouch(item, left, POUCH_R * zoom, UiPalette.NIGHT_VEIL, alpha)
	_pouch(item, right, POUCH_R * zoom, UiPalette.OAK, alpha)
	DrawSandPaint.beads(item, left, target, -ARC * 0.5, toss, alpha, 2)
	if toss > 0.0 and toss < 1.0:
		var at := PourPaint.along(right, target, ARC, ease(toss, -1.4))
		var face := absf(cos(toss * PI * COIN_TURNS))
		var coin := PackedVector2Array()
		for i in range(17):
			var a := TAU * float(i) / 16.0
			coin.append(at + Vector2(cos(a) * COIN_R * maxf(face, 0.15), sin(a) * COIN_R))
		ShapePaint.convex_polygon(
			ci, ForesightPaint.grown(coin, at, 2.0), Color(UiPalette.INK_950, alpha)
		)
		ShapePaint.convex_polygon(ci, coin, Color(UiPalette.COIN_GOLD, alpha))
	SignaturePaint.pulse_ring(item, target, landed, alpha)


## 口を紐で絞った巾着。丸い胴と襞の口、紐の結び目。
func _pouch(item: CanvasItem, at: Vector2, radius: float, cloth: Color, alpha: float) -> void:
	if alpha <= 0.0 or radius <= 0.0:
		return
	var ci := item.get_canvas_item()
	ShapePaint.circle(ci, at, radius + 2.0, Color(UiPalette.INK_950, alpha))
	ShapePaint.circle(ci, at, radius, Color(cloth, alpha))
	var neck := at + Vector2(0.0, -radius * 1.05)
	ShapePaint.circle(
		ci, neck + Vector2(0.0, -3.0), radius * 0.5 + 2.0, Color(UiPalette.INK_950, alpha)
	)
	ShapePaint.circle(ci, neck + Vector2(0.0, -3.0), radius * 0.5, Color(cloth, alpha))
	item.draw_line(
		neck + Vector2(-radius * 0.45, 0.0),
		neck + Vector2(radius * 0.45, 0.0),
		Color(UiPalette.KINTSUGI, alpha),
		2.4
	)
	if cloth == UiPalette.NIGHT_VEIL:
		for k in range(3):
			var gem := neck + Vector2(-4.0 + 4.0 * float(k), -8.0 - 2.0 * float(k == 1))
			ShapePaint.circle(ci, gem, 2.6, Color(UiPalette.AMETHYST, alpha))


func _giving() -> bool:
	return style == CardEnums.EffectVisualStyle.DESCEND
