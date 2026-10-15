extends SignatureMove
## リピートの設置(GameDesign.md 9章):駒から小さなレコード盤が回りながら、このターンに返った
## 駒それぞれの足元へ滑り込み、溝の光がひと回りして馴染む(もう一度返せる印)。

const SLIDE := 0.4
const GROOVE := 0.3
## 盤の大きさと、足元の位置(駒の中心から)。
const RADIUS := 14.0
const FOOT := 46.0
## 滑る間に回る量と、跳ねる弧の高さ。
const TURNS := 2.5
const ARC := 26.0


func impact_at() -> float:
	return SLIDE + GROOVE


func draw(item: CanvasItem, t: float) -> void:
	var alpha := fade_alpha(t)
	var slide := ease(phase(t, 0.0, SLIDE), -1.8)
	var groove := phase(t, SLIDE, GROOVE)
	for target in targets:
		var foot := target + Vector2(0.0, FOOT)
		var at := from.lerp(foot, slide) - Vector2(0.0, ARC * sin(slide * PI))
		_record(item, at, TAU * TURNS * slide, groove, alpha)
		SignaturePaint.boon_ring(item, target, phase(t, impact_at(), FADE), alpha)


## レコード盤。`spin` は回った角度、`groove` は溝を走る光の進み(0→1でひと回り)。
func _record(item: CanvasItem, at: Vector2, spin: float, groove: float, alpha: float) -> void:
	var ci := item.get_canvas_item()
	UiPaint.fill_circle(ci, at, RADIUS + 1.4, Color(UiPalette.OUTLINE_DARK, alpha * 0.8), 28)
	UiPaint.fill_circle(ci, at, RADIUS, Color(0.1, 0.08, 0.07, alpha * 0.95), 28)
	for r in [RADIUS * 0.82, RADIUS * 0.66]:
		item.draw_arc(at, r, 0.0, TAU, 28, Color(1, 1, 1, alpha * 0.12), 1.0, true)
	var shine := Color(1, 1, 1, alpha * 0.3)
	item.draw_arc(at, RADIUS * 0.74, spin, spin + 0.8, 8, shine, 1.6, true)
	UiPaint.fill_circle(ci, at, RADIUS * 0.36, Color(SignaturePaint.BOON, alpha), 16)
	UiPaint.fill_circle(ci, at, RADIUS * 0.08, Color(UiPalette.OUTLINE_DARK, alpha), 8)
	if groove > 0.0 and groove < 1.0:
		var head := spin - PI * 0.5 + TAU * groove
		var glow := Color(SignaturePaint.BOON, alpha * (1.0 - groove * 0.4))
		item.draw_arc(at, RADIUS * 0.74, head - TAU * groove, head, 24, glow, 2.4, true)
