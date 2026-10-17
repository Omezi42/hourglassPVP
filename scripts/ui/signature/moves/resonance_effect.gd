extends SignatureMove
## レゾナンスの反転(GameDesign.md 9章):駒の上に音叉が現れて震え、共鳴の波紋が対象へ伝わる。
## 対象が同じ周期で小さく震えてから返る。

const APPEAR := 0.16
const TRAVEL := 0.42
const SHIVER := 0.2
## 音叉の置き場所(駒の中心から)と形。
const LIFT := 66.0
const PRONG := Vector2(5.0, 22.0)
const STEM := 14.0
## 震えの速さ(1秒あたりの往復)と振れ幅。
const HZ := 18.0
const AMPLITUDE := 1.8
## 共鳴の波紋(対象へ向かう弧)の数と開き。
const WAVES := 3
const WAVE_GAP := 0.16
const WAVE_SPREAD := 0.5
## 対象の左右で震える弧。
const SHIVER_RADIUS := 34.0


func impact_at() -> float:
	return APPEAR + TRAVEL + SHIVER


func draw(item: CanvasItem, t: float) -> void:
	if targets.is_empty():
		return
	var intro := ease(phase(t, 0.0, APPEAR), 0.5)
	var alpha := intro * fade_alpha(t)
	var wobble := sin(t * TAU * HZ) * AMPLITUDE * (1.0 - phase(t, impact_at(), FADE))
	var fork := from - Vector2(0.0, LIFT)
	_fork(item, fork, wobble, alpha)
	_waves(item, fork, targets[0], phase(t, APPEAR, TRAVEL), alpha)
	var shiver := phase(t, APPEAR + TRAVEL, SHIVER + FADE)
	if shiver > 0.0 and shiver < 1.0:
		var color := Color(SignaturePaint.SPIN, alpha * (1.0 - shiver))
		for side in [-1.0, 1.0]:
			var center := targets[0] + Vector2(side * wobble * 2.0, 0.0)
			var mid := 0.0 if side > 0.0 else PI
			ShapePaint.arc(
				item.get_canvas_item(),
				center,
				SHIVER_RADIUS,
				mid - 0.5,
				mid + 0.5,
				12,
				color,
				2.0,
				true
			)


func _fork(item: CanvasItem, base: Vector2, wobble: float, alpha: float) -> void:
	var ci := item.get_canvas_item()
	var outline := Color(UiPalette.OUTLINE_DARK, alpha * 0.8)
	var brass := Color(UiPalette.BRASS_HIGHLIGHT, alpha)
	for side in [-1.0, 1.0]:
		var x: float = side * (PRONG.x + wobble)
		var foot := base + Vector2(x, 0.0)
		var tip := base + Vector2(x, -PRONG.y)
		item.draw_line(foot, tip, outline, 4.6, true)
		item.draw_line(foot, tip, brass, 3.0, true)
	ShapePaint.arc(item.get_canvas_item(), base, PRONG.x, 0.0, PI, 10, outline, 4.6, true)
	ShapePaint.arc(item.get_canvas_item(), base, PRONG.x, 0.0, PI, 10, brass, 3.0, true)
	var stem := base + Vector2(0.0, PRONG.x)
	item.draw_line(stem, stem + Vector2(0.0, STEM), outline, 4.6, true)
	item.draw_line(stem, stem + Vector2(0.0, STEM), brass, 3.0, true)
	UiPaint.fill_circle(ci, stem + Vector2(0.0, STEM), 3.0, brass, 10)


func _waves(item: CanvasItem, start: Vector2, end: Vector2, travel: float, alpha: float) -> void:
	if travel <= 0.0 or travel >= 1.0:
		return
	var toward := (end - start).angle()
	var reach := start.distance_to(end)
	for i in range(WAVES):
		var k := travel - WAVE_GAP * i
		if k <= 0.0:
			continue
		var color := Color(SignaturePaint.SPIN, alpha * (1.0 - k * 0.5))
		var arc_from := toward - WAVE_SPREAD
		var arc_to := toward + WAVE_SPREAD
		ShapePaint.arc(
			item.get_canvas_item(), start, reach * k, arc_from, arc_to, 16, color, 2.4, true
		)
