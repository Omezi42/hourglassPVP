extends SignatureMove
## ウィックの恵与(GameDesign.md 9章):余砂で、銘板の上に燃え尽きた蝋燭の芯が現れて燠が一度赤く灯り、
## 細い煙が味方の駒それぞれへ低い山なりに漂って、届いた駒から金色の輪が広がる(砂が1粒上へ戻る)。

const APPEAR := 0.12
const KINDLE := 0.18
const DRIFT := 0.42
const RING := 0.32
## 蝋燭の残り(銘板から上へ)の大きさ、芯の長さ、燠の大きさ。
const LIFT := 24.0
const STUB := Vector2(13.0, 9.0)
const WICK := 9.0
const COAL := 3.6
## 煙の山なりの高さ、揺れの幅と回数、太さ、尾の長さ(進みの割合)。
const ARC := 34.0
const SWAY := 7.0
const WAVES := 2.0
const SMOKE_WIDTH := 3.2
const TAIL := 0.45
const TRAIL_STEPS := 10


func impact_at() -> float:
	return APPEAR + KINDLE + DRIFT


func duration() -> float:
	return impact_at() + RING


func draw(item: CanvasItem, t: float) -> void:
	var ci := item.get_canvas_item()
	var alpha := fade_alpha(t)
	var appear := ease(phase(t, 0.0, APPEAR), 0.5)
	var stub := from - Vector2(0.0, LIFT)
	_stub(item, stub, alpha * appear)
	var tip := stub - Vector2(0.0, STUB.y + WICK)
	var kindle := phase(t, APPEAR, KINDLE)
	var glow := sin(kindle * PI) if kindle < 1.0 else 0.35
	var coal_alpha := alpha * appear
	ShapePaint.circle(ci, tip, COAL * (2.0 + glow * 2.5), Color(UiPalette.EMBER, coal_alpha * 0.3))
	ShapePaint.circle(
		ci, tip, COAL, Color(UiPalette.EMBER.lerp(SignaturePaint.SPARK_HOT, glow), coal_alpha)
	)
	SignaturePaint.ember_motes(item, tip, phase(t, APPEAR, KINDLE + DRIFT * 0.5), alpha, 14.0, 30.0)
	var drift := phase(t, APPEAR + KINDLE, DRIFT)
	if drift > 0.0 and t < impact_at() + FADE:
		var smoke_alpha := alpha * (1.0 - phase(t, impact_at(), FADE))
		for i in range(targets.size()):
			_smoke(item, tip, targets[i], drift, float(i), smoke_alpha)
	for target in targets:
		SignaturePaint.boon_ring(item, target, phase(t, impact_at(), RING), alpha)


## 燃え尽きて短くなった蝋燭。`at` は底の中心。
func _stub(item: CanvasItem, at: Vector2, alpha: float) -> void:
	if alpha <= 0.0:
		return
	var body := Rect2(at - Vector2(STUB.x, STUB.y), Vector2(STUB.x * 2.0, STUB.y))
	item.draw_rect(body.grow(1.4), Color(UiPalette.INK_950, alpha * 0.8))
	item.draw_rect(body, Color(UiPalette.WAX, alpha))
	var drip := Rect2(at + Vector2(-STUB.x + 3.0, -STUB.y), Vector2(4.0, STUB.y * 0.7))
	item.draw_rect(drip, Color(UiPalette.WAX.lightened(0.4), alpha))
	var wick_top := at - Vector2(0.0, STUB.y + WICK)
	item.draw_line(at - Vector2(0.0, STUB.y), wick_top, Color(UiPalette.INK_950, alpha), 2.2, true)


## 芯の先から対象へ漂う煙の筋。先頭ほど濃く、尾は薄れる。
func _smoke(
	item: CanvasItem, tip: Vector2, target: Vector2, drift: float, lane: float, alpha: float
) -> void:
	var head := ease(drift, 0.8)
	var points := PackedVector2Array()
	var colors := PackedColorArray()
	for k in range(TRAIL_STEPS + 1):
		var s := maxf(head - TAIL * float(TRAIL_STEPS - k) / float(TRAIL_STEPS), 0.0)
		var at := tip.lerp(target, s)
		at.y -= ARC * sin(s * PI)
		at.x += sin((s * WAVES + lane * 0.37) * TAU) * SWAY * sin(s * PI)
		points.append(at)
		colors.append(Color(UiPalette.SMOKE, alpha * float(k) / float(TRAIL_STEPS) * 0.85))
	ShapePaint.polyline_colors(item.get_canvas_item(), points, colors, SMOKE_WIDTH, true)
	if drift < 1.0:
		ShapePaint.circle(
			item.get_canvas_item(), points[TRAIL_STEPS], COAL * 0.7, Color(UiPalette.EMBER, alpha)
		)
