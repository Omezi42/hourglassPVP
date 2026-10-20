extends SignatureMove
## シェルの余砂(GameDesign.md 9章):銘板から巻貝の殻がころころ転がり出て空いた台座で止まり、口から
## 砂がこぼれたところでモートが現れる(恵与)。

const ROLL := 0.42
const SPILL := 0.16
const RING := 0.32
## 殻の半径と、転がりながら弾む高さ・回数、渦の巻き数と点の数。
const RADIUS := 10.0
const HOP := 12.0
const HOPS := 2.0
const WHORLS := 2.2
const WHORL_POINTS := 30
## こぼれる砂粒の数と広がり。
const GRAINS := 8
const SPREAD := 16.0
const SHELL_LIGHT := Color(0.98, 0.9, 0.82, 1.0)
const SHELL_DARK := Color(0.78, 0.56, 0.44, 1.0)


func impact_at() -> float:
	return ROLL + SPILL


func duration() -> float:
	return impact_at() + RING


func draw(item: CanvasItem, t: float) -> void:
	if targets.is_empty():
		return
	var ci := item.get_canvas_item()
	var alpha := fade_alpha(t)
	var floor_at := targets[0] + Vector2(0.0, CardView.BOARD_ART_SIDE * 0.5 - RADIUS)
	var roll := phase(t, 0.0, ROLL)
	var s := ease(roll, -1.4)
	var at := from.lerp(floor_at, s) - Vector2(0.0, absf(sin(s * PI * HOPS)) * HOP * (1.0 - s))
	var distance := from.distance_to(floor_at) * s
	var side := signf(floor_at.x - from.x) if absf(floor_at.x - from.x) > 1.0 else 1.0
	_shell(item, at, side * distance / RADIUS, alpha * minf(roll * 6.0, 1.0))
	var spill := phase(t, ROLL, SPILL + RING * 0.5)
	if spill > 0.0 and spill < 1.0:
		var mouth := at + Vector2(side * RADIUS, RADIUS * 0.4)
		for i in range(GRAINS):
			var spread := SPREAD * (0.4 + 0.6 * SignaturePaint.jitter(i, 121)) * ease(spill, 0.5)
			var grain := (
				mouth
				+ Vector2(side * spread, -4.0 * sin(spill * PI) * SignaturePaint.jitter(i, 122))
			)
			ShapePaint.circle(ci, grain, 1.6, Color(SignaturePaint.SAND, alpha * (1.0 - spill)))
	SignaturePaint.boon_ring(
		item, floor_at + Vector2(0.0, RADIUS), phase(t, impact_at(), RING), alpha
	)


## 渦を巻いた巻貝の殻。`turn` は転がった量(ラジアン)。
func _shell(item: CanvasItem, at: Vector2, turn: float, alpha: float) -> void:
	if alpha <= 0.0:
		return
	var ci := item.get_canvas_item()
	ShapePaint.circle(ci, at, RADIUS + 1.2, Color(UiPalette.OUTLINE_DARK, alpha * 0.8))
	ShapePaint.circle(ci, at, RADIUS, Color(SHELL_LIGHT, alpha))
	var whorl := PackedVector2Array()
	for i in range(WHORL_POINTS + 1):
		var s := float(i) / float(WHORL_POINTS)
		whorl.append(at + Vector2.from_angle(turn + s * TAU * WHORLS) * RADIUS * (1.0 - s * 0.85))
	ShapePaint.polyline(ci, whorl, Color(SHELL_DARK, alpha), 1.8, true)
