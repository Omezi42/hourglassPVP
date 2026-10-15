extends SignatureMove
## 砂葬(GameDesign.md 9章):対象の真上から砂が降り積もって墓標の形の砂山になり、覆いきった
## ところで砕ける(打撃)。続くドロー(PULSE)では、自分の情報帯から砂粒が2筋立ち昇る。

const POUR := 0.5
## 砂が降り始める高さ(駒の中心から)と、砂山の幅・高さ。
const SKY := 110.0
const MOUND := Vector2(64.0, 104.0)
const GRAINS := 40
const DRAW_RISE := 0.42
## ドローの2筋の間隔と昇る高さ。
const DRAW_SPREAD := 34.0
const DRAW_REACH := 64.0
const DRAW_GRAINS := 12


func impact_at() -> float:
	return DRAW_RISE if _drawing() else POUR


func draw(item: CanvasItem, t: float) -> void:
	if targets.is_empty():
		return
	if _drawing():
		_draw_streams(item, t)
		return
	var alpha := fade_alpha(t)
	var pour := phase(t, 0.0, POUR)
	var target := targets[0]
	var floor_y := target.y + CardView.BOARD_ART_SIDE * 0.5
	for i in range(GRAINS):
		var start := SignaturePaint.jitter(i, 31) * 0.8
		var q := clampf((pour - start) / 0.25, 0.0, 1.0)
		if q <= 0.0 or q >= 1.0:
			continue
		var x := target.x + (SignaturePaint.jitter(i, 32) - 0.5) * MOUND.x
		var y := lerpf(target.y - SKY, floor_y - MOUND.y * pour, q * q)
		item.draw_line(
			Vector2(x, y - 5.0), Vector2(x, y), Color(SignaturePaint.SAND, alpha * 0.85), 1.4
		)
	_mound(item, Vector2(target.x, floor_y), ease(pour, 0.7), alpha)


## 墓標の形の砂山。`grow` は積もった量(0→1)で、下から高さが伸びる。
func _mound(item: CanvasItem, foot: Vector2, grow: float, alpha: float) -> void:
	if grow <= 0.0:
		return
	var h := MOUND.y * grow
	var w := MOUND.x * 0.5 * (0.7 + 0.3 * grow)
	# 上は半円の肩、左右は裾へ広がる斜面。低いうちは肩を潰して山の形に保つ。
	var r := minf(w, h)
	var top := foot + Vector2(0.0, -h + r)
	var shape := PackedVector2Array([foot + Vector2(-w * 1.2, 0.0)])
	for i in range(13):
		var a := PI * float(i) / 12.0
		shape.append(top + Vector2(-cos(a) * w, -sin(a) * r))
	shape.append(foot + Vector2(w * 1.2, 0.0))
	var rect := Rect2(foot - Vector2(w * 1.2, h), Vector2(w * 2.4, h))
	(
		UiPaint
		. fill_gradient_polygon(
			item.get_canvas_item(),
			shape,
			rect,
			[
				[0.0, Color(SignaturePaint.SAND, alpha * 0.92)],
				[1.0, Color(SignaturePaint.SAND_DARK, alpha * 0.92)],
			]
		)
	)


func _draw_streams(item: CanvasItem, t: float) -> void:
	var alpha := fade_alpha(t)
	var rise := phase(t, 0.0, DRAW_RISE + FADE)
	for side: float in [-1.0, 1.0]:
		var base := from + Vector2(side * DRAW_SPREAD * 0.5, 0.0)
		for i in range(DRAW_GRAINS):
			var q := rise - float(i) / float(DRAW_GRAINS) * 0.5
			if q <= 0.0 or q >= 1.0:
				continue
			var at := base + Vector2(sin(q * TAU + side) * 4.0, -DRAW_REACH * q)
			item.draw_circle(at, 1.8, Color(SignaturePaint.SAND, alpha * (1.0 - q)))


func _drawing() -> bool:
	return style == CardEnums.EffectVisualStyle.PULSE
