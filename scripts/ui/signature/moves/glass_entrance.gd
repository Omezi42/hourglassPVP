extends SignatureMove
## グラスの登場(GameDesign.md 9章):駒の表面を光の筋が斜めに一度走り抜け、肩できらりと星が
## 瞬く(硝子=1度だけダメージを防ぐ膜の印)。

const SWEEP := 0.3
const TWINKLE := 0.3
## 光の筋の長さ・太さと、走り抜ける幅(駒の中心から斜めに前後)。
const STREAK := 46.0
const WIDTH := 7.0
const TRAVEL := 52.0
## 星の位置(駒の中心から)と大きさ。
const STAR_AT := Vector2(22.0, -40.0)
const STAR := 11.0
const SHINE := Color(0.9, 0.97, 1.0, 1.0)


func impact_at() -> float:
	return CardUnitFx.LAND_DURATION


func duration() -> float:
	return impact_at() + SWEEP + TWINKLE * 0.6 + FADE


func draw(item: CanvasItem, t: float) -> void:
	if t < impact_at():
		return
	var ci := item.get_canvas_item()
	var alpha := fade_alpha(t)
	var core := from - Vector2(0.0, CardView.BOARD_ART_SIDE * 0.5)
	var sweep := phase(t, impact_at(), SWEEP)
	if sweep > 0.0 and sweep < 1.0:
		var along := Vector2(1.0, 1.0).normalized()
		var across := Vector2(1.0, -1.0).normalized()
		var mid := core + along * lerpf(-TRAVEL, TRAVEL, ease(sweep, -1.4))
		var a := alpha * sin(sweep * PI)
		var half := across * STREAK * 0.5
		item.draw_line(mid - half, mid + half, Color(SHINE, a * 0.35), WIDTH * 2.0, true)
		item.draw_line(mid - half, mid + half, Color(SHINE, a * 0.9), WIDTH * 0.5, true)
	var twinkle := phase(t, impact_at() + SWEEP * 0.7, TWINKLE)
	if twinkle <= 0.0 or twinkle >= 1.0:
		return
	var size := STAR * sin(twinkle * PI)
	var at := core + STAR_AT
	var color := Color(SHINE, alpha)
	item.draw_line(at - Vector2(size, 0.0), at + Vector2(size, 0.0), color, 1.6, true)
	item.draw_line(at - Vector2(0.0, size), at + Vector2(0.0, size), color, 1.6, true)
	var diag := Vector2(size, size) * 0.4
	item.draw_line(at - diag, at + diag, Color(SHINE, alpha * 0.6), 1.0, true)
	item.draw_line(
		at - Vector2(diag.x, -diag.y),
		at + Vector2(diag.x, -diag.y),
		Color(SHINE, alpha * 0.6),
		1.0,
		true
	)
	if size > 2.0:
		ShapePaint.circle(ci, at, size * 0.2, Color(1, 1, 1, alpha))
