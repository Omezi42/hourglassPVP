extends SignatureMove
## 砂王の呼び声(GameDesign.md 9章):自分の情報帯の上で真鍮の角笛が鳴って音の輪が広がり、
## 空いた台座へ砂の光の柱が降りて、届いたところでモートが現れる(恵与。1体ごとに1回)。

const HORN := 0.22
const BEAM := 0.24
const RING := 0.3
## 角笛の置き場所(情報帯の中心から)と、吹き口から朝顔までの長さ・反り・太さ。
const LIFT := 40.0
const LENGTH := 46.0
const CURL := 12.0
const BORE := 2.0
const BELL := 9.0
const STEPS := 12
## 音の輪の数と広がり、光の柱が降り始める高さと幅。
const RINGS := 2
const RING_REACH := 34.0
const BEAM_HEIGHT := 150.0
const BEAM_WIDTH := 22.0


func impact_at() -> float:
	return HORN + BEAM


func duration() -> float:
	return impact_at() + RING


func draw(item: CanvasItem, t: float) -> void:
	if targets.is_empty():
		return
	var alpha := fade_alpha(t)
	var appear := ease(phase(t, 0.0, HORN * 0.5), 0.5)
	var center := from - Vector2(0.0, LIFT)
	var bell := _horn(item, center, alpha * appear)
	var blow := phase(t, HORN * 0.4, HORN + BEAM * 0.5)
	for i in range(RINGS):
		var q := blow - float(i) * 0.3
		if q <= 0.0 or q >= 1.0:
			continue
		var color := Color(SignaturePaint.BOON, alpha * (1.0 - q))
		item.draw_arc(bell, RING_REACH * q + BELL, -PI * 0.4, PI * 0.4, 16, color, 2.0, true)
	var floor_at := targets[0] + Vector2(0.0, CardView.BOARD_ART_SIDE * 0.5)
	var beam := ease(phase(t, HORN, BEAM), 1.6)
	if beam > 0.0 and t < impact_at() + RING:
		var top := floor_at - Vector2(0.0, BEAM_HEIGHT)
		var bottom := top.lerp(floor_at, beam)
		var width := BEAM_WIDTH * (1.0 - phase(t, impact_at(), RING))
		var shape := PackedVector2Array(
			[
				top - Vector2(width * 0.3, 0.0),
				top + Vector2(width * 0.3, 0.0),
				bottom + Vector2(width * 0.5, 0.0),
				bottom - Vector2(width * 0.5, 0.0),
			]
		)
		if width > 1.0:
			(
				UiPaint
				. fill_gradient_polygon(
					item.get_canvas_item(),
					shape,
					Rect2(top - Vector2(width * 0.5, 0.0), Vector2(width, bottom.y - top.y + 1.0)),
					[
						[0.0, Color(SignaturePaint.BOON, 0.0)],
						[1.0, Color(SignaturePaint.BOON, alpha * 0.7)],
					]
				)
			)
	SignaturePaint.boon_ring(item, floor_at, phase(t, impact_at(), RING), alpha)


## 右へ朝顔の開いた角笛。朝顔の中心を返す。
func _horn(item: CanvasItem, center: Vector2, alpha: float) -> Vector2:
	var start := center - Vector2(LENGTH * 0.5, 0.0)
	var upper := PackedVector2Array()
	var lower := PackedVector2Array()
	var bell := start
	for i in range(STEPS + 1):
		var s := float(i) / float(STEPS)
		var at := start + Vector2(LENGTH * s, -CURL * sin(s * PI) + CURL * s * 0.6)
		var half := lerpf(BORE, BELL, s * s * s)
		upper.append(at - Vector2(0.0, half))
		lower.append(at + Vector2(0.0, half))
		bell = at
	if alpha <= 0.0:
		return bell
	lower.reverse()
	var shape := upper + lower
	item.draw_colored_polygon(shape, Color(UiPalette.BRASS_HIGHLIGHT, alpha))
	var closed := shape.duplicate()
	closed.append(shape[0])
	item.draw_polyline(closed, Color(UiPalette.OUTLINE_DARK, alpha * 0.8), 1.2, true)
	return bell
