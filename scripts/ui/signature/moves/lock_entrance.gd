extends SignatureMove
## ロックの登場(GameDesign.md 9章):駒の正面に南京錠が現れて掛け金がカチリと閉まり、ひと光りしてから
## 消える。

const APPEAR := 0.14
const SNAP := 0.1
const HOLD := 0.3
## 錠の置き場所(駒の中心から下へ)と胴の大きさ、掛け金の半径・太さと、開いているときの浮き。
const DROP := 14.0
const BODY := Vector2(26.0, 20.0)
const SHACKLE := 9.0
const SHACKLE_WIDTH := 4.0
const OPEN_LIFT := 9.0
const FLASH := 30.0


func impact_at() -> float:
	return CardUnitFx.LAND_DURATION


func duration() -> float:
	return impact_at() + APPEAR + SNAP + HOLD


func draw(item: CanvasItem, t: float) -> void:
	if t < impact_at():
		return
	var ci := item.get_canvas_item()
	var alpha := fade_alpha(t) * ease(phase(t, impact_at(), APPEAR), 0.5)
	var core := from - Vector2(0.0, CardView.BOARD_ART_SIDE * 0.5 - DROP)
	var snap := ease(phase(t, impact_at() + APPEAR, SNAP), 2.4)
	var top := core - Vector2(0.0, BODY.y * 0.5)
	var lift := OPEN_LIFT * (1.0 - snap)
	var hinge := top - Vector2(0.0, lift)
	ShapePaint.arc(
		ci,
		hinge,
		SHACKLE,
		PI,
		TAU,
		16,
		Color(UiPalette.OUTLINE_DARK, alpha),
		SHACKLE_WIDTH + 2.0,
		true
	)
	ShapePaint.arc(
		ci, hinge, SHACKLE, PI, TAU, 16, Color(0.78, 0.8, 0.84, alpha), SHACKLE_WIDTH, true
	)
	for side: float in [-1.0, 1.0]:
		var x := hinge.x + side * SHACKLE
		item.draw_line(
			Vector2(x, hinge.y),
			Vector2(x, top.y + 2.0),
			Color(0.78, 0.8, 0.84, alpha),
			SHACKLE_WIDTH,
			true
		)
	var body := Rect2(core - BODY * 0.5, BODY)
	item.draw_rect(body.grow(1.4), Color(UiPalette.OUTLINE_DARK, alpha * 0.8))
	UiPaint.fill_gradient_polygon(
		ci,
		PackedVector2Array(
			[
				body.position,
				Vector2(body.end.x, body.position.y),
				body.end,
				Vector2(body.position.x, body.end.y)
			]
		),
		body,
		[[0.0, Color(UiPalette.BRASS_HIGHLIGHT, alpha)], [1.0, Color(UiPalette.BRASS_DARK, alpha)]]
	)
	ShapePaint.circle(ci, core - Vector2(0.0, 2.0), 3.0, Color(UiPalette.OUTLINE_DARK, alpha))
	item.draw_line(core, core + Vector2(0.0, 6.0), Color(UiPalette.OUTLINE_DARK, alpha), 2.0)
	var flash := phase(t, impact_at() + APPEAR + SNAP, HOLD * 0.6)
	if flash > 0.0 and flash < 1.0:
		ShapePaint.arc(
			ci,
			core,
			FLASH * ease(flash, 0.4),
			0.0,
			TAU,
			32,
			Color(1, 0.96, 0.8, alpha * (1.0 - flash)),
			2.4,
			true
		)
