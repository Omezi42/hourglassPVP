extends SignatureMove
## ケルンの設置(GameDesign.md 9章):駒の足元に平たい石が3つ順に積み上がり、最後の石が
## 載ったところで恵与の金色の輪が広がる(墓地の砂時計を積んで大きくなる)。

const DROP := 0.17
const RING := 0.32
## 石を積む場所(台座の上面の中心から)と、落ちてくる高さ。駒に重ねないよう台座の右の縁へ置く。
const BASE_OFFSET := Vector2(40.0, 4.0)
const FALL := 46.0
## 下から順の石の大きさ(横の半径・高さの半分)と、左右のずれ。
const STONES := [Vector2(15.0, 5.5), Vector2(12.0, 5.0), Vector2(8.5, 4.5)]
const SHIFTS := [0.0, -2.5, 1.5]
const STONE_LIGHT := Color(0.70, 0.66, 0.58, 1.0)
const STONE_DARK := Color(0.38, 0.35, 0.31, 1.0)


func impact_at() -> float:
	return DROP * STONES.size()


func duration() -> float:
	return impact_at() + RING


func draw(item: CanvasItem, t: float) -> void:
	if targets.is_empty():
		return
	var alpha := fade_alpha(t)
	var floor_y := targets[0].y + CardView.BOARD_ART_SIDE * 0.5
	var base := Vector2(targets[0].x, floor_y) + BASE_OFFSET
	var height := 0.0
	for i in range(STONES.size()):
		var drop := phase(t, DROP * float(i), DROP)
		if drop <= 0.0:
			break
		var size: Vector2 = STONES[i]
		var rest := base + Vector2(SHIFTS[i], -height - size.y)
		var at := rest - Vector2(0.0, FALL * (1.0 - ease(drop, 2.2)))
		_stone(item, at, size, alpha * minf(drop * 3.0, 1.0))
		height += size.y * 1.7
	SignaturePaint.boon_ring(item, targets[0], phase(t, impact_at(), RING), alpha)


## 平たい石1つ。上面を明るく、下を暗くして積んだ厚みを見せる。
func _stone(item: CanvasItem, at: Vector2, size: Vector2, alpha: float) -> void:
	var ci := item.get_canvas_item()
	UiPaint.fill_ellipse(ci, at, size + Vector2.ONE, Color(UiPalette.OUTLINE_DARK, alpha * 0.7), 20)
	UiPaint.fill_ellipse(ci, at, size, Color(STONE_DARK, alpha), 20)
	UiPaint.fill_ellipse(
		ci, at - Vector2(0.0, size.y * 0.3), size * Vector2(0.9, 0.6), Color(STONE_LIGHT, alpha), 20
	)
