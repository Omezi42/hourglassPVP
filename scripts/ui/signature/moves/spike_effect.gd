extends SignatureMove
## スパイクの被弾(GameDesign.md 9章):駒の周りから鋭い棘が3本突き出し、いちばん長い1本が抜けて
## 相手のHPの器へ飛んで刺さる(打撃)。

const THRUST := 0.16
const HOLD := 0.1
const FLIGHT := 0.22
## 棘の根元(駒の中心からの距離)と、長い棘・短い棘の長さと根元の半幅、短い棘の開き(ラジアン)。
const ROOT := 34.0
const LONG := 30.0
const SHORT := 18.0
const WIDTH := 5.0
const SPREAD := 0.9
const STEEL := Color(0.82, 0.84, 0.9, 1.0)
const STEEL_DARK := Color(0.44, 0.46, 0.52, 1.0)


func impact_at() -> float:
	return THRUST + HOLD + FLIGHT


func draw(item: CanvasItem, t: float) -> void:
	if targets.is_empty():
		return
	var alpha := fade_alpha(t)
	var aim := (targets[0] - from).normalized()
	var thrust := back_out(phase(t, 0.0, THRUST))
	for side: float in [-1.0, 1.0]:
		var dir := aim.rotated(side * SPREAD)
		_spike(item, from + dir * ROOT, dir, SHORT * thrust, alpha)
	var flight := phase(t, THRUST + HOLD, FLIGHT)
	if t >= impact_at():
		return
	var root := from + aim * ROOT
	var tip_root := root.lerp(targets[0] - aim * LONG, ease(flight, 1.8))
	_spike(item, tip_root, aim, LONG * thrust, alpha)


## 根元 `root` から `dir` へ伸びる細い三角の棘。
func _spike(item: CanvasItem, root: Vector2, dir: Vector2, length: float, alpha: float) -> void:
	if length <= 1.0 or alpha <= 0.0:
		return
	var across := dir.orthogonal() * WIDTH
	var tip := root + dir * length
	var ci := item.get_canvas_item()
	var outline := PackedVector2Array([root - across * 1.3, tip + dir * 1.5, root + across * 1.3])
	ShapePaint.colored_polygon(ci, outline, Color(UiPalette.OUTLINE_DARK, alpha * 0.8))
	ShapePaint.colored_polygon(
		ci, PackedVector2Array([root - across, tip, root]), Color(STEEL, alpha)
	)
	ShapePaint.colored_polygon(
		ci, PackedVector2Array([root, tip, root + across]), Color(STEEL_DARK, alpha)
	)
