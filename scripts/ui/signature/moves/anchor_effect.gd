extends SignatureMove
## アンカーの落砂(GameDesign.md 9章):駒の足元へ錨が鎖とともに沈み込み、食い込んだところから金色の波紋が
## 味方の駒それぞれへ届いて金色の輪が広がる(恵与。波紋が届いた駒から順に)。

const SINK := 0.26
const RIPPLE := 0.34
const RING := 0.32
## 錨が降り始める高さ(足元から上へ)と大きさ、波紋の縦の潰れ。
const DROP := 120.0
const SHANK := 26.0
const ARMS := 13.0
const RING_TOP := 5.0
const SQUASH := 0.3
const IRON := Color(0.36, 0.38, 0.44, 1.0)


func impact_at() -> float:
	return SINK + RIPPLE


func duration() -> float:
	return impact_at() + RING


func reaches(index: int, t: float) -> bool:
	return _radius(t) >= absf(targets[index].x - from.x)


func _radius(t: float) -> float:
	var reach := 0.0
	for target: Vector2 in targets:
		reach = maxf(reach, absf(target.x - from.x))
	return (reach + 1.0) * ease(phase(t, SINK, RIPPLE), 0.7)


func draw(item: CanvasItem, t: float) -> void:
	if targets.is_empty():
		return
	var ci := item.get_canvas_item()
	var alpha := fade_alpha(t)
	var foot := from + Vector2(0.0, CardView.BOARD_ART_SIDE * 0.5)
	var sink := ease(phase(t, 0.0, SINK), 2.2)
	var crown := foot - Vector2(0.0, SHANK + DROP * (1.0 - sink))
	var a := alpha * minf(phase(t, 0.0, SINK) * 4.0, 1.0)
	item.draw_line(
		crown - Vector2(0.0, DROP), crown, Color(IRON.lightened(0.2), a * 0.8), 1.6, true
	)
	_anchor(item, crown, a)
	var radius := _radius(t)
	var spread := phase(t, SINK, RIPPLE)
	if spread > 0.0 and spread < 1.0:
		for k in range(2):
			var r := radius - float(k) * 18.0
			if r > 2.0:
				UiPaint.draw_ellipse_ring(
					ci,
					foot,
					Vector2(r, r * SQUASH),
					Color(SignaturePaint.BOON, alpha * (1.0 - spread) * (1.0 - float(k) * 0.4)),
					2.0,
					40
				)
	for i in range(targets.size()):
		var arrive := SINK + RIPPLE * _reach_share(i)
		SignaturePaint.boon_ring(item, targets[i], phase(t, arrive, RING), alpha)


## 対象 `index` へ波紋が届く時刻の、波紋の時間に対する割合。
func _reach_share(index: int) -> float:
	var reach := 0.0
	for target: Vector2 in targets:
		reach = maxf(reach, absf(target.x - from.x))
	var d := absf(targets[index].x - from.x) / (reach + 1.0)
	return pow(d, 1.0 / 0.7) if d > 0.0 else 0.0


## 輪 `top` から下へ伸びる錨。
func _anchor(item: CanvasItem, top: Vector2, alpha: float) -> void:
	var ci := item.get_canvas_item()
	var bottom := top + Vector2(0.0, SHANK)
	ShapePaint.arc(
		ci, top - Vector2(0.0, RING_TOP), RING_TOP, 0.0, TAU, 14, Color(IRON, alpha), 2.4, true
	)
	item.draw_line(top, bottom, Color(IRON, alpha), 3.6, true)
	item.draw_line(top + Vector2(-8.0, 6.0), top + Vector2(8.0, 6.0), Color(IRON, alpha), 3.0, true)
	ShapePaint.arc(
		ci,
		bottom - Vector2(0.0, ARMS),
		ARMS,
		PI * 0.15,
		PI * 0.85,
		14,
		Color(IRON, alpha),
		3.4,
		true
	)
	for side: float in [-1.0, 1.0]:
		var tip := bottom - Vector2(0.0, ARMS) + Vector2.from_angle(PI * (0.5 - side * 0.35)) * ARMS
		var barb := PackedVector2Array(
			[
				tip + Vector2(side * 4.0, -1.0),
				tip + Vector2(-side * 2.0, -6.0),
				tip + Vector2(-side * 1.0, 2.0)
			]
		)
		ShapePaint.colored_polygon(ci, barb, Color(IRON, alpha))
