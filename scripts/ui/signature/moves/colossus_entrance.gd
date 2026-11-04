extends SignatureMove
## コロッサスの登場(GameDesign.md 9章):通常より高くから重く落ちて卓が揺れ、足元から地響きの輪が広がり、
## 砕けた石の欠片が跳ねる(並べた相手を見下ろす巨像の印)。

const QUAKE := 0.5
## 2つ目の輪が遅れて広がり始める割合。
const SECOND_RING_DELAY := 0.2
## 地響きの輪の広がりきる半径と、輪を潰す比。跳ねる欠片の数・高さ・広がり・大きさ。
const REACH := 120.0
const SQUASH := 0.32
const CHIPS := 10
const BOUNCE := 46.0
const SPREAD := 90.0
const CHIP := 3.0
const CHIP_COLOR := Color(0.55, 0.5, 0.44, 1.0)
const RING_POINTS := 40


func impact_at() -> float:
	return CardUnitFx.HEAVY_LAND_DURATION


func duration() -> float:
	return impact_at() + QUAKE + FADE


func heavy_land() -> bool:
	return true


func draw(item: CanvasItem, t: float) -> void:
	if t < impact_at():
		return
	var ci := item.get_canvas_item()
	var alpha := fade_alpha(t)
	var quake := phase(t, impact_at(), QUAKE)
	for i in range(2):
		var spread := clampf(quake - SECOND_RING_DELAY * float(i), 0.0, 1.0)
		if spread <= 0.0:
			continue
		var radius := REACH * ease(spread, 0.5)
		var ring := PackedVector2Array()
		for k in range(RING_POINTS + 1):
			var angle := TAU * float(k) / float(RING_POINTS)
			ring.append(from + Vector2(cos(angle) * radius, sin(angle) * radius * SQUASH))
		var ring_color := Color(SignaturePaint.SAND_DARK, alpha * (1.0 - spread))
		ShapePaint.polyline(ci, ring, ring_color, 3.0, true)
	for i in range(CHIPS):
		var dir := -1.0 if i % 2 == 0 else 1.0
		var x := dir * SPREAD * (0.3 + 0.7 * SignaturePaint.jitter(i, 191)) * quake
		var lift := 0.6 + 0.4 * SignaturePaint.jitter(i, 192)
		var hop := 4.0 * quake * (1.0 - quake) * BOUNCE * lift
		ShapePaint.circle(ci, from + Vector2(x, -hop), CHIP, Color(CHIP_COLOR, alpha))
