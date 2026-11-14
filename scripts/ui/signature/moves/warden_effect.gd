extends SignatureMove
## ウォーデンの恵与(GameDesign.md 9章):砂術に応えて、駒の頭上に砦の狭間が3つ灯り、足元から光の粒が
## 1つ駒の正面を昇って狭間のあいだに収まったところで金色の輪が広がる(砂が1粒上へ戻る)。

const LIGHT := 0.12
const RISE := 0.28
## 狭間の置き場所(駒の中心から上へ)、凸1つの大きさと間隔、粒の大きさ。
const LIFT := 66.0
const MERLON := Vector2(9.0, 8.0)
const PITCH := 17.0
const BASE_WIDTH := 44.0
const GRAIN := 2.6
## 粒が昇り始める足元(駒の中心から下へ)と、収まる隙間(左から数えた番号)。
const FOOT := 50.0
const GAP_INDEX := 1
const STONE := Color(0.86, 0.84, 0.78, 1.0)


func impact_at() -> float:
	return LIGHT + RISE


func draw(item: CanvasItem, t: float) -> void:
	if targets.is_empty():
		return
	var ci := item.get_canvas_item()
	var alpha := fade_alpha(t)
	var top := from - Vector2(0.0, LIFT)
	var lit := ease(phase(t, 0.0, LIGHT), 0.5)
	for i in range(3):
		var x := (float(i) - 1.0) * PITCH
		var rect := Rect2(
			top + Vector2(x - MERLON.x * 0.5, -MERLON.y * lit), Vector2(MERLON.x, MERLON.y * lit)
		)
		item.draw_rect(rect.grow(1.2), Color(UiPalette.INK_950, alpha * lit * 0.8))
		item.draw_rect(rect, Color(STONE, alpha * lit))
	var wall := Rect2(top + Vector2(-BASE_WIDTH * 0.5, 0.0), Vector2(BASE_WIDTH, 3.0))
	item.draw_rect(wall, Color(STONE.darkened(0.25), alpha * lit))
	var gap_x := (float(GAP_INDEX) - 0.5) * PITCH
	var rise := phase(t, LIGHT, RISE)
	if rise > 0.0 and rise < 1.0:
		var s := ease(rise, 1.4)
		var start := from + Vector2(0.0, FOOT)
		var end := top + Vector2(gap_x, -MERLON.y * 0.5)
		var at := start.lerp(end, s)
		ShapePaint.circle(ci, at, GRAIN * 2.4, Color(SignaturePaint.RECITE, alpha * 0.25))
		ShapePaint.circle(ci, at, GRAIN, Color(SignaturePaint.RECITE, alpha))
	elif rise >= 1.0:
		var rest := top + Vector2(gap_x, -MERLON.y * 0.5)
		ShapePaint.circle(ci, rest, GRAIN, Color(SignaturePaint.RECITE, alpha))
	SignaturePaint.boon_ring(item, targets[0], phase(t, impact_at(), FADE), alpha)
