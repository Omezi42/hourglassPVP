extends SignatureMove
## メイルストロムの設置(GameDesign.md 9章):駒の頭上に光る青緑の大渦が巻き起こり、渦の縁から銅の吸い管が相手の駒それぞれへ
## 伸びて、近い駒から順に他人の色の滴を吸い上げ、渦へ呑まれた滴が目へ沈む。吸われた駒には縮む渦が残る(払拭)。

const FORM := 0.2
const REACH := 0.2
const DRINK := 0.24
## 相手の駒ごとの遅れ(駒が多いときは全体が `SPAN` に収まるよう縮める)。
const LAG := 0.08
const SPAN := 0.24
## 渦の中心(駒の中心から)と半径(手前へ倒した楕円)、腕の数、吸い管の弧の高さ。
const SWIRL := Vector2(0.0, -96.0)
const SWIRL_R := Vector2(60.0, 22.0)
const ARMS := 3
const ARC := 34.0
const TOP := 130.0


func top_extent() -> float:
	return TOP * zoom


func impact_at() -> float:
	return FORM + REACH + DRINK + _lag() * float(maxi(targets.size() - 1, 0))


func reaches(index: int, t: float) -> bool:
	return t >= FORM + REACH + DRINK + _lag() * float(_order().find(index))


func sound() -> int:
	return SoundBank.Sfx.SIG_MAELSTROM


func draw(item: CanvasItem, t: float) -> void:
	var alpha := fade_alpha(t)
	var center := from + SWIRL * zoom
	var form := ease(phase(t, 0.0, FORM), 0.5)
	_swirl(item, center, form, t, alpha)
	var order := _order()
	for rank in range(order.size()):
		var i: int = order[rank]
		var start := FORM + _lag() * float(rank)
		var target := targets[i]
		var rim := center + (target - center).normalized() * SWIRL_R.x * 0.7 * zoom
		var drink := phase(t, start + REACH, DRINK)
		DrawSandPaint.tube(
			item,
			rim,
			target,
			ARC,
			ease(phase(t, start, REACH), 0.6),
			alpha * (1.0 - phase(t, impact_at(), FADE))
		)
		DrawSandPaint.beads(item, rim, target, ARC, drink, alpha, 2)
		DrawSandPaint.gulp(item, target, drink, alpha)
		SignaturePaint.drain_ring(item, target, phase(t, start + REACH + DRINK, FADE), alpha)


## 光る青緑の大渦。暗い目へ巻き込む腕と、縁の白い飛沫の輪。`form` で広がり、`t` で回る。
func _swirl(item: CanvasItem, center: Vector2, form: float, t: float, alpha: float) -> void:
	if alpha <= 0.0 or form <= 0.0:
		return
	var ci := item.get_canvas_item()
	var r := SWIRL_R * zoom * form
	var disc := PackedVector2Array()
	for i in range(25):
		var a := TAU * float(i) / 24.0
		disc.append(center + Vector2(cos(a) * r.x, sin(a) * r.y))
	ShapePaint.convex_polygon(
		ci, ForesightPaint.grown(disc, center, 2.0), Color(UiPalette.INK_950, alpha)
	)
	ShapePaint.convex_polygon(ci, disc, Color(UiPalette.MAELSTROM, alpha * 0.85))
	for k in range(ARMS):
		var arm := PackedVector2Array()
		for i in range(13):
			var u := float(i) / 12.0
			var a := TAU * float(k) / float(ARMS) + u * 3.6 - t * 9.0
			arm.append(center + Vector2(cos(a) * r.x, sin(a) * r.y) * (1.0 - u * 0.85))
		ShapePaint.polyline(ci, arm, Color(UiPalette.ABYSS, alpha * 0.7), 3.0, true)
	var eye := PackedVector2Array()
	for i in range(13):
		var a := TAU * float(i) / 12.0
		eye.append(center + Vector2(cos(a) * r.x * 0.18, sin(a) * r.y * 0.18))
	ShapePaint.convex_polygon(ci, eye, Color(UiPalette.ABYSS, alpha))
	disc.append(disc[0])
	ShapePaint.polyline(ci, disc, Color(UiPalette.POUR_FOAM, alpha), 2.0, true)


## 近い駒から順に吸う並び(出どころからの距離の近い順)。
func _order() -> Array[int]:
	var order: Array[int] = []
	for i in range(targets.size()):
		order.append(i)
	order.sort_custom(
		func(a: int, b: int) -> bool:
			return from.distance_to(targets[a]) < from.distance_to(targets[b])
	)
	return order


func _lag() -> float:
	return minf(LAG, SPAN / float(maxi(targets.size() - 1, 1)))
