extends SignatureMove
## クラウンの設置(GameDesign.md 9章):駒から小さな王冠が浮かび上がって対象の頭上へ山なりに舞い、
## 頭に載ったところで金色の輪が広がる(守護を与える恵与)。

const RISE := 0.16
const FLY := 0.32
const SET := 0.1
const RING := 0.32
## 浮かび上がる場所(駒の中心から上へ)と高さ、飛ぶ弧の高さ、載る位置(対象の中心から上へ)。
const START := 40.0
const LIFT := 22.0
const ARC := 46.0
const HEAD := 62.0
## 王冠の半幅・高さ。
const HALF := 12.0
const HEIGHT := 12.0


func impact_at() -> float:
	return RISE + FLY + SET


func duration() -> float:
	return impact_at() + RING


func draw(item: CanvasItem, t: float) -> void:
	if targets.is_empty():
		return
	var alpha := fade_alpha(t)
	var start := from - Vector2(0.0, START)
	var top := start - Vector2(0.0, LIFT * ease(phase(t, 0.0, RISE), 0.5))
	var head := targets[0] - Vector2(0.0, HEAD)
	var fly := ease(phase(t, RISE, FLY), -1.4)
	var at := top.lerp(head, fly) - Vector2(0.0, ARC * sin(fly * PI))
	var settle := phase(t, RISE + FLY, SET)
	at.y -= 4.0 * sin(settle * PI)
	var a := alpha * minf(phase(t, 0.0, RISE) * 2.0, 1.0)
	_crown(item, at, a)
	SignaturePaint.boon_ring(item, targets[0], phase(t, impact_at(), RING), alpha)


## 3つの尖りを持つ小さな王冠。`at` は帯の中心。
func _crown(item: CanvasItem, at: Vector2, alpha: float) -> void:
	if alpha <= 0.0:
		return
	var ci := item.get_canvas_item()
	var shape := PackedVector2Array(
		[
			at + Vector2(-HALF, 3.0),
			at + Vector2(-HALF, -HEIGHT),
			at + Vector2(-HALF * 0.5, -HEIGHT * 0.45),
			at + Vector2(0.0, -HEIGHT * 1.2),
			at + Vector2(HALF * 0.5, -HEIGHT * 0.45),
			at + Vector2(HALF, -HEIGHT),
			at + Vector2(HALF, 3.0),
		]
	)
	(
		UiPaint
		. fill_gradient_polygon(
			ci,
			shape,
			Rect2(at - Vector2(HALF, HEIGHT * 1.2), Vector2(HALF * 2.0, HEIGHT * 1.2 + 3.0)),
			[
				[0.0, Color(UiPalette.BRASS_HIGHLIGHT, alpha)],
				[1.0, Color(UiPalette.BRASS_DARK, alpha)],
			]
		)
	)
	var closed := shape.duplicate()
	closed.append(shape[0])
	ShapePaint.polyline(ci, closed, Color(UiPalette.OUTLINE_DARK, alpha * 0.8), 1.2, true)
	for x: float in [-HALF, 0.0, HALF]:
		var tip_y := -HEIGHT * (1.2 if x == 0.0 else 1.0)
		ShapePaint.circle(ci, at + Vector2(x, tip_y), 2.2, Color(SignaturePaint.BOON, alpha))
	ShapePaint.circle(ci, at + Vector2(0.0, -1.0), 2.4, Color(0.85, 0.25, 0.3, alpha))
