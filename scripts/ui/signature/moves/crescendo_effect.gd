extends SignatureMove
## クレッシェンド(GameDesign.md 9章):情報帯から相手のHPの器へ、拡声器の音の弧が段々大きく
## なりながら続けて飛び、最後のいちばん大きな弧で当たる。

const WAVES := 4
const GAP := 0.12
const FLIGHT := 0.36
## 最初と最後の弧の半径・太さ。
const SMALL := 8.0
const LARGE := 30.0
const SPREAD := 0.7
## 打撃の型(素の紋章のまま)に寄せた明るい色。
const COLOR := Color(1.0, 0.95, 0.82, 1.0)


func impact_at() -> float:
	return GAP * (WAVES - 1) + FLIGHT


func draw(item: CanvasItem, t: float) -> void:
	if targets.is_empty():
		return
	var alpha := fade_alpha(t)
	var toward := (targets[0] - from).angle()
	for i in range(WAVES):
		var k := phase(t, GAP * i, FLIGHT)
		if k <= 0.0 or k >= 1.0:
			continue
		var grow := float(i) / float(WAVES - 1)
		var radius := lerpf(SMALL, LARGE, grow)
		var at := from.lerp(targets[0], ease(k, 1.6)) - Vector2.from_angle(toward) * radius
		var color := Color(COLOR, alpha * (0.5 + 0.5 * grow))
		var width := lerpf(2.0, 4.0, grow)
		ShapePaint.arc(
			item.get_canvas_item(),
			at,
			radius,
			toward - SPREAD,
			toward + SPREAD,
			16,
			color,
			width,
			true
		)
