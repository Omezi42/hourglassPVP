extends SignatureMove
## オベリスクの落砂(GameDesign.md 9章):駒の上に石の尖塔が立ち、先端から光線が相手の駒それぞれへ左から
## 順に放たれる(打撃。光線が届いた駒から順に砂が散る)。

const RISE := 0.22
const LAG := 0.08
const FLIGHT := 0.14
const LINGER := 0.12
## 尖塔の置き場所(駒の中心から上へ、根元)と高さ・根元の半幅・頂の半幅。
const LIFT := 40.0
const HEIGHT := 56.0
const BASE_HALF := 9.0
const TOP_HALF := 5.0
const CAP := 9.0
const STONE := Color(0.7, 0.66, 0.6, 1.0)
const STONE_DARK := Color(0.42, 0.39, 0.35, 1.0)
const BEAM := Color(1.0, 0.94, 0.72, 1.0)


func impact_at() -> float:
	return _arrival(targets.size() - 1)


func reaches(index: int, t: float) -> bool:
	return t >= _arrival(_rank(index))


func _arrival(rank: int) -> float:
	return RISE + LAG * float(maxi(rank, 0)) + FLIGHT


## 左から数えて何番目の対象か。
func _rank(index: int) -> int:
	var rank := 0
	for other: Vector2 in targets:
		if other.x < targets[index].x:
			rank += 1
	return rank


func draw(item: CanvasItem, t: float) -> void:
	if targets.is_empty():
		return
	var ci := item.get_canvas_item()
	var alpha := fade_alpha(t)
	var rise := ease(phase(t, 0.0, RISE), 0.6)
	var base := from - Vector2(0.0, LIFT)
	var top := base - Vector2(0.0, HEIGHT * rise)
	var a := alpha * minf(rise * 2.0, 1.0)
	var body := PackedVector2Array(
		[
			base + Vector2(-BASE_HALF, 0.0),
			base + Vector2(BASE_HALF, 0.0),
			top + Vector2(TOP_HALF, 0.0),
			top - Vector2(0.0, CAP * rise),
			top + Vector2(-TOP_HALF, 0.0),
		]
	)
	ShapePaint.colored_polygon(ci, body, Color(STONE, a))
	var shade := PackedVector2Array(
		[
			base,
			base + Vector2(BASE_HALF, 0.0),
			top + Vector2(TOP_HALF, 0.0),
			top - Vector2(0.0, CAP * rise)
		]
	)
	ShapePaint.colored_polygon(ci, shade, Color(STONE_DARK, a * 0.6))
	var closed := body.duplicate()
	closed.append(body[0])
	ShapePaint.polyline(ci, closed, Color(UiPalette.OUTLINE_DARK, a * 0.8), 1.2, true)
	var tip := top - Vector2(0.0, CAP)
	for i in range(targets.size()):
		var start := RISE + LAG * float(_rank(i))
		var q := phase(t, start, FLIGHT)
		var fade := 1.0 - phase(t, start + FLIGHT, LINGER)
		if q <= 0.0 or fade <= 0.0:
			continue
		var head := tip.lerp(targets[i], ease(q, 1.4))
		item.draw_line(tip, head, Color(BEAM, alpha * 0.35 * fade), 6.0, true)
		item.draw_line(tip, head, Color(BEAM, alpha * fade), 2.0, true)
	if t >= RISE:
		ShapePaint.circle(ci, tip, 4.0, Color(BEAM, alpha * (1.0 - phase(t, impact_at(), FADE))))
