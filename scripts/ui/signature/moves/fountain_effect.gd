extends SignatureMove
## ファウンテン(GameDesign.md 9章):味方が出るたび、ファウンテンの頭上へ青緑の水が噴き上がって
## 弧を描き、出た駒の頭へ降り注いでしぶきが跳ね、金色の輪が広がる(恵与)。

const RISE := 0.16
const FLIGHT := 0.26
## 噴き出し口(駒の中心から)、噴き上がる高さ、弧の持ち上げ、注ぎ先(対象の中心から)、噴水の冠の粒。
const SPOUT := Vector2(0.0, -48.0)
const JET := 50.0
const ARC := 60.0
const MOUTH := Vector2(0.0, -36.0)
const CROWN := 5
const TOP := 140.0


func top_extent() -> float:
	return TOP * zoom


func impact_at() -> float:
	return RISE + FLIGHT


func draw(item: CanvasItem, t: float) -> void:
	if targets.is_empty():
		return
	var ci := item.get_canvas_item()
	var alpha := fade_alpha(t)
	var spout := from + SPOUT * zoom
	var rise := ease(phase(t, 0.0, RISE), 0.6)
	var peak := spout - Vector2(0.0, JET * zoom * rise)
	var settle := phase(t, impact_at(), FADE)
	if rise > 0.0:
		var jet := PackedVector2Array([spout, peak])
		ShapePaint.polyline(ci, jet, Color(UiPalette.POUR_DEEP, alpha * 0.8), 8.0 * zoom, true)
		ShapePaint.polyline(ci, jet, Color(UiPalette.POUR_WATER, alpha), 5.5 * zoom, true)
		for i in range(CROWN):
			var a := PI + PI * float(i + 1) / float(CROWN + 1)
			var drop := peak + Vector2.from_angle(a) * 9.0 * zoom * rise
			ShapePaint.circle(ci, drop, 2.4 * zoom, Color(UiPalette.POUR_FOAM, alpha * rise))
	var mouth := targets[0] + MOUTH
	var flight := phase(t, RISE, FLIGHT)
	PourPaint.stream(item, peak, mouth, ARC, ease(flight, 0.8), settle, alpha)
	if t >= impact_at():
		PourPaint.splash(item, mouth, settle, alpha)
		SignaturePaint.boon_ring(item, targets[0], settle, alpha)
