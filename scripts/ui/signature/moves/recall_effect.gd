extends SignatureMove
## 砂へ還す(GameDesign.md 9章):対象の足元に淡い砂の渦が巻き起こり、細りながら駒を巻き上げて
## 包みきったところで、駒が縮んで持ち主の手札へ吸い込まれる(回収)。

const SWIRL := 0.52
## 渦の腕の数、巻き上がる高さ、足元での広がりと包みきったときの細さ。
const ARMS := 3
const HEIGHT := 120.0
const WIDE := Vector2(62.0, 15.0)
const NARROW := 0.35
const TURNS := 1.6
const STEPS := 28
const MIST := Color(0.9, 0.96, 1.0, 1.0)


func impact_at() -> float:
	return SWIRL


func draw(item: CanvasItem, t: float) -> void:
	if targets.is_empty():
		return
	var alpha := fade_alpha(t)
	var swirl := phase(t, 0.0, SWIRL)
	var floor_at := targets[0] + Vector2(0.0, CardView.BOARD_ART_SIDE * 0.5)
	var climb := ease(swirl, 0.6)
	var narrow := lerpf(1.0, NARROW, ease(swirl, 1.6))
	for arm in range(ARMS):
		var points := PackedVector2Array()
		var count := maxi(int(STEPS * climb), 1)
		for i in range(count + 1):
			var s := climb * float(i) / float(count)
			var angle := TAU * (float(arm) / float(ARMS) + TURNS * s) + swirl * TAU
			var radius := WIDE * lerpf(1.0, narrow, s)
			points.append(
				floor_at + Vector2(cos(angle) * radius.x, sin(angle) * radius.y - HEIGHT * s)
			)
		ShapePaint.polyline(
			item.get_canvas_item(), points, Color(SignaturePaint.SAND_DARK, alpha * 0.35), 4.0, true
		)
		ShapePaint.polyline(item.get_canvas_item(), points, Color(MIST, alpha * 0.85), 1.8, true)
