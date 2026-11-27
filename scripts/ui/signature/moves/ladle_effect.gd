extends SignatureMove
## ラドルの設置(GameDesign.md 9章):駒の頭上に竹の柄杓が現れて一度すくい上げ、左の駒から順に
## ひと掬いずつ青緑の水を弧に投げ、届いた駒からしぶきが跳ねて金色の輪が広がる(恵与)。

const APPEAR := 0.1
const SCOOP := 0.16
## 1体ぶんの注ぎの長さ(駒が多いときは全体が `SPAN` に収まるよう縮める)。
const SERVE := 0.16
const SPAN := 0.6
## 柄杓の合(駒の中心から)と柄の向き・長さ、合の大きさ、すくう沈み、投げる弧の高さ、注ぎ先(対象の中心から)。
const CUP := Vector2(0.0, -96.0)
const HANDLE_ANGLE := 2.7
const HANDLE := 40.0
const CUP_SIZE := Vector2(9.0, 8.0)
const DIP := 10.0
const ARC := 46.0
const MOUTH := Vector2(0.0, -36.0)
const TOP := 120.0


func top_extent() -> float:
	return TOP * zoom


func impact_at() -> float:
	return APPEAR + SCOOP + _step() * float(maxi(targets.size(), 1))


func reaches(index: int, t: float) -> bool:
	return t >= APPEAR + SCOOP + _step() * float(index + 1)


func draw(item: CanvasItem, t: float) -> void:
	var alpha := fade_alpha(t) * minf(phase(t, 0.0, APPEAR) * 1.5, 1.0)
	var dip := sin(phase(t, APPEAR, SCOOP) * PI) * DIP
	var cup := from + CUP * zoom + Vector2(0.0, dip) * zoom
	_ladle(item, cup, alpha)
	var step := _step()
	for i in range(targets.size()):
		var start := APPEAR + SCOOP + step * float(i)
		var serve := phase(t, start, step)
		if serve <= 0.0:
			break
		var mouth := targets[i] + MOUTH
		var after := phase(t, start + step, FADE)
		PourPaint.stream(item, cup, mouth, ARC, ease(serve, 0.7), maxf(serve - 0.4, 0.0), alpha)
		PourPaint.splash(item, mouth, after, alpha)
		SignaturePaint.boon_ring(item, targets[i], after, alpha)


## 竹の柄杓。左下へ伸びる柄と、筒の合に満ちた水。
func _ladle(item: CanvasItem, cup: Vector2, alpha: float) -> void:
	if alpha <= 0.0:
		return
	var ci := item.get_canvas_item()
	var grip := cup + Vector2.from_angle(HANDLE_ANGLE) * HANDLE * zoom
	item.draw_line(cup, grip, Color(UiPalette.INK_950, alpha), 6.0 * zoom, true)
	item.draw_line(cup, grip, Color(UiPalette.BAMBOO, alpha), 3.6 * zoom, true)
	var half := CUP_SIZE * zoom
	var box := PackedVector2Array(
		[
			cup + Vector2(-half.x, -half.y),
			cup + Vector2(half.x, -half.y),
			cup + half,
			cup + Vector2(-half.x, half.y)
		]
	)
	ShapePaint.convex_polygon(
		ci, ForesightPaint.grown(box, cup, 2.0), Color(UiPalette.INK_950, alpha)
	)
	ShapePaint.convex_polygon(ci, box, Color(UiPalette.BAMBOO, alpha))
	PourPaint.brim(item, cup - Vector2(0.0, half.y), half.x, 1.0, alpha)


func _step() -> float:
	return minf(SERVE, SPAN / float(maxi(targets.size(), 1)))
