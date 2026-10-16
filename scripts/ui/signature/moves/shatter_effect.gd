extends SignatureMove
## 砕砂(GameDesign.md 9章):対象の真上に砂の楔が現れて打ち込まれ、刺さった所から対象の表面へ
## ひびが四方へ走りきったところで砂が散る(打撃。盤面が揺れる)。

const APPEAR := 0.2
const DRIVE := 0.12
const CRACK := 0.18
## 楔が浮いている高さと、刺さる位置(対象の中心から上へ)。楔の幅・長さ。
const LIFT := 96.0
const STAB := 30.0
const WEDGE := Vector2(16.0, 34.0)
## ひびの本数・長さと、1本を折る回数。
const CRACKS := 6
const CRACK_LENGTH := 42.0
const BENDS := 3


func impact_at() -> float:
	return APPEAR + DRIVE + CRACK


func draw(item: CanvasItem, t: float) -> void:
	if targets.is_empty():
		return
	var alpha := fade_alpha(t)
	var appear := ease(phase(t, 0.0, APPEAR), 0.5)
	var drive := ease(phase(t, APPEAR, DRIVE), 2.4)
	var stab := targets[0] - Vector2(0.0, STAB)
	var tip := (targets[0] - Vector2(0.0, LIFT)).lerp(stab, drive)
	_wedge(item, tip, alpha * appear)
	var crack := ease(phase(t, APPEAR + DRIVE, CRACK), 0.6)
	if crack <= 0.0:
		return
	for i in range(CRACKS):
		var angle := TAU * float(i) / float(CRACKS) + (SignaturePaint.jitter(i, 11) - 0.5) * 0.6
		var line := PackedVector2Array([stab])
		var reach := CRACK_LENGTH * (0.7 + 0.3 * SignaturePaint.jitter(i, 5)) * crack
		for k in range(1, BENDS + 1):
			var bend := angle + (SignaturePaint.jitter(i * BENDS + k, 13) - 0.5) * 1.0
			line.append(line[k - 1] + Vector2.from_angle(bend) * reach / float(BENDS))
		item.draw_polyline(line, Color(UiPalette.OUTLINE_DARK, alpha * 0.8), 2.6, true)
		item.draw_polyline(line, Color(SignaturePaint.SPARK_HOT, alpha), 1.2, true)


## 下を向いた砂の楔。`tip` は尖った先。
func _wedge(item: CanvasItem, tip: Vector2, alpha: float) -> void:
	if alpha <= 0.0:
		return
	var top := tip - Vector2(0.0, WEDGE.y)
	var shape := PackedVector2Array(
		[tip, top + Vector2(WEDGE.x * 0.5, 0.0), top - Vector2(WEDGE.x * 0.5, 0.0)]
	)
	UiPaint.fill_gradient_polygon(
		item.get_canvas_item(),
		shape,
		Rect2(top - Vector2(WEDGE.x * 0.5, 0.0), WEDGE),
		[[0.0, Color(SignaturePaint.SAND, alpha)], [1.0, Color(SignaturePaint.SAND_DARK, alpha)]]
	)
	var closed := shape.duplicate()
	closed.append(shape[0])
	item.draw_polyline(closed, Color(UiPalette.OUTLINE_DARK, alpha * 0.8), 1.4, true)
