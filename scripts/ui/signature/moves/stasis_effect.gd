extends SignatureMove
## 時間停止(GameDesign.md 9章):相手の列から一瞬色が抜け(払拭の型のくすんだ色)、
## 各駒から砂粒が上へ昇ってから色が戻る。

const DRAIN := 0.26
const HOLD := 0.48
const WASH := Color(0.70, 0.74, 0.82, 0.55)
const BOX := Vector2(112.0, 128.0)
const CORNER := 22.0


func impact_at() -> float:
	return DRAIN


func duration() -> float:
	return DRAIN + HOLD + FADE


func draw(item: CanvasItem, t: float) -> void:
	var wash := phase(t, 0.0, DRAIN) * fade_alpha(t)
	var rise := phase(t, DRAIN, HOLD)
	for target in targets:
		var box := Rect2(target - BOX * 0.5, BOX)
		item.draw_colored_polygon(
			UiPaint.rounded_rect_points_uniform(box, CORNER, 6), Color(WASH, WASH.a * wash)
		)
		SignaturePaint.rising_grains(item, target, rise, wash)
