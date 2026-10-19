extends SignatureMove
## ハローの設置(GameDesign.md 9章):対象の頭上へ光の輪が降りてきて、対象を透明な膜が下から包み、
## 包みきったところで金色の輪が広がる(硝子を与える恵与)。

const DESCEND := 0.24
const WRAP := 0.28
const RING := 0.32
## 光の輪が降り始める高さと止まる高さ(対象の中心から上へ)、輪の大きさ。
const START := 120.0
const REST := 66.0
const HALO := Vector2(18.0, 5.0)
## 膜の大きさ(対象の中心からの半幅・半高さ)。
const SHELL := Vector2(40.0, 60.0)
const LIGHT := Color(1.0, 0.97, 0.82, 1.0)
const FILM := Color(0.85, 0.94, 1.0, 1.0)


func impact_at() -> float:
	return DESCEND + WRAP


func duration() -> float:
	return impact_at() + RING


func draw(item: CanvasItem, t: float) -> void:
	if targets.is_empty():
		return
	var ci := item.get_canvas_item()
	var alpha := fade_alpha(t)
	var descend := ease(phase(t, 0.0, DESCEND), -1.6)
	var halo := targets[0] - Vector2(0.0, lerpf(START, REST, descend))
	var a := alpha * minf(phase(t, 0.0, DESCEND) * 3.0, 1.0)
	UiPaint.draw_ellipse_ring(ci, halo, HALO, Color(LIGHT, a * 0.35), 6.0, 28)
	UiPaint.draw_ellipse_ring(ci, halo, HALO, Color(LIGHT, a), 2.4, 28)
	var wrap := ease(phase(t, DESCEND, WRAP), 0.7)
	if wrap > 0.0:
		var bottom := targets[0].y + SHELL.y
		var height := SHELL.y * 2.0 * wrap
		var center := Vector2(targets[0].x, bottom - height * 0.5)
		var radius := Vector2(SHELL.x, height * 0.5)
		if radius.y > 2.0:
			UiPaint.fill_ellipse(ci, center, radius, Color(FILM, alpha * 0.18), 36)
			UiPaint.draw_ellipse_ring(ci, center, radius, Color(FILM, alpha * 0.8), 1.6, 36)
			var shine_a := center + Vector2(-SHELL.x * 0.55, radius.y * 0.2)
			var shine_b := center + Vector2(-SHELL.x * 0.35, -radius.y * 0.5)
			item.draw_line(shine_a, shine_b, Color(1, 1, 1, alpha * 0.5), 2.0, true)
	SignaturePaint.boon_ring(item, targets[0], phase(t, impact_at(), RING), alpha)
