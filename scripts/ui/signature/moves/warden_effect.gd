extends SignatureMove
## ウォーデンの恵与(GameDesign.md 9章):砂術に応えて、駒の頭上に砦の狭間が3つ灯り、足元から光の粒が
## 1つ駒の正面を昇って狭間のあいだに収まったところで金色の輪が広がる(砂が1粒上へ戻る)。

const LIGHT := 0.12
const RISE := 0.28
## 狭間の置き場所(駒の中心から上へ)、凸1つの大きさと間隔、粒の大きさ。長さはすべて駒の拡大を掛ける。
## 狭間は駒の頭(絵の枠の上端)へ載せ、卓の中央の線から離す。
const LIFT := CardView.BOARD_ART_SIDE * 0.5 - 4.0
const MERLON := Vector2(20.0, 17.0)
const PITCH := 30.0
const BASE_WIDTH := 2.0 * PITCH + MERLON.x
const GRAIN := 4.0
## 粒が昇り始める足元(駒の中心から下へ)と、収まる隙間(左から数えた番号)。
const FOOT := 50.0
const GAP_INDEX := 1
const STONE := Color(0.86, 0.84, 0.78, 1.0)


func impact_at() -> float:
	return LIGHT + RISE


func top_extent() -> float:
	return (LIFT + MERLON.y) * zoom


func draw(item: CanvasItem, t: float) -> void:
	if targets.is_empty():
		return
	var ci := item.get_canvas_item()
	var alpha := fade_alpha(t)
	var top := from - Vector2(0.0, LIFT * zoom)
	var merlon := MERLON * zoom
	var lit := ease(phase(t, 0.0, LIGHT), 0.5)
	for i in range(3):
		var x := (float(i) - 1.0) * PITCH * zoom
		var rect := Rect2(
			top + Vector2(x - merlon.x * 0.5, -merlon.y * lit), Vector2(merlon.x, merlon.y * lit)
		)
		item.draw_rect(rect.grow(1.2), Color(UiPalette.INK_950, alpha * lit * 0.8))
		item.draw_rect(rect, Color(STONE, alpha * lit))
	var wall := Rect2(
		top + Vector2(-BASE_WIDTH * 0.5 * zoom, 0.0), Vector2(BASE_WIDTH * zoom, 3.0 * zoom)
	)
	item.draw_rect(wall, Color(STONE.darkened(0.25), alpha * lit))
	var gap_x := (float(GAP_INDEX) - 0.5) * PITCH * zoom
	var rise := phase(t, LIGHT, RISE)
	if rise > 0.0 and rise < 1.0:
		var s := ease(rise, 1.4)
		var start := from + Vector2(0.0, FOOT * zoom)
		var end := top + Vector2(gap_x, -merlon.y * 0.5)
		var at := start.lerp(end, s)
		ShapePaint.circle(ci, at, GRAIN * 2.4 * zoom, Color(SignaturePaint.RECITE, alpha * 0.25))
		ShapePaint.circle(ci, at, GRAIN * zoom, Color(SignaturePaint.RECITE, alpha))
	elif rise >= 1.0:
		var rest := top + Vector2(gap_x, -merlon.y * 0.5)
		ShapePaint.circle(ci, rest, GRAIN * zoom, Color(SignaturePaint.RECITE, alpha))
	SignaturePaint.boon_ring(item, targets[0], phase(t, impact_at(), FADE), alpha)
