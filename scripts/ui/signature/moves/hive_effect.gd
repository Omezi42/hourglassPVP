extends SignatureMove
## ハイヴの被弾(GameDesign.md 9章):駒の上に蜂の巣の六角の巣穴が3つ並んで灯り、砂の蜂が1匹
## 飛び出して揺れながら空いた台座へ向かい、届いたところでモートが現れる(恵与)。

const APPEAR := 0.16
const GLOW := 0.14
const FLY := 0.4
const RING := 0.32
## 巣穴の六角の半径と置き場所(駒の中心から上へ)、3つの並び。
const CELL := 8.0
const LIFT := 22.0
const CELL_OFFSETS: Array[Vector2] = [Vector2(-1.0, 0.0), Vector2(1.0, 0.0), Vector2(0.0, -1.0)]
## 蜂の胴の大きさ、羽ばたく速さ、飛ぶ道の揺れの幅と回数。
const BODY := Vector2(5.0, 3.6)
const WING := Vector2(3.6, 2.2)
const FLAP := 60.0
const WOBBLE := 9.0
const WAVES := 2.5
const COMB := Color(0.86, 0.64, 0.24, 1.0)
const COMB_DARK := Color(0.5, 0.34, 0.12, 1.0)
const STRIPE := Color(0.3, 0.2, 0.08, 1.0)
const WING_COLOR := Color(1.0, 1.0, 1.0, 0.75)


func impact_at() -> float:
	return APPEAR + GLOW + FLY


func duration() -> float:
	return impact_at() + RING


func draw(item: CanvasItem, t: float) -> void:
	if targets.is_empty():
		return
	var alpha := fade_alpha(t)
	var comb_at := from - Vector2(0.0, LIFT)
	var a := alpha * ease(phase(t, 0.0, APPEAR), 0.5)
	var glow := phase(t, APPEAR, GLOW)
	_comb(item, comb_at, a, glow)
	var floor_at := targets[0] + Vector2(0.0, CardView.BOARD_ART_SIDE * 0.5 - BODY.y)
	var fly := phase(t, APPEAR + GLOW, FLY)
	if fly > 0.0 and fly < 1.0:
		var s := ease(fly, -1.6)
		var path := floor_at - comb_at
		var side := path.orthogonal().normalized() if path.length() > 1.0 else Vector2.RIGHT
		var at := comb_at.lerp(floor_at, s) + side * sin(s * PI * WAVES) * WOBBLE * (1.0 - s)
		_bee(item, at, t, signf(path.x) if absf(path.x) > 1.0 else 1.0, alpha)
	SignaturePaint.boon_ring(
		item, floor_at + Vector2(0.0, BODY.y), phase(t, impact_at(), RING), alpha
	)


## 六角の巣穴を3つ。`glow` に応じて中が蜜の色に灯る。
func _comb(item: CanvasItem, center: Vector2, alpha: float, glow: float) -> void:
	if alpha <= 0.0:
		return
	var ci := item.get_canvas_item()
	var step := Vector2(CELL * sqrt(3.0) * 0.5, CELL * 1.5)
	for offset: Vector2 in CELL_OFFSETS:
		var at := center + Vector2(offset.x * step.x, offset.y * step.y)
		var outer := _hexagon(at, CELL)
		ShapePaint.colored_polygon(ci, outer, Color(COMB_DARK, alpha))
		ShapePaint.colored_polygon(ci, _hexagon(at, CELL - 1.6), Color(COMB, alpha))
		if glow > 0.0:
			var lit := Color(SignaturePaint.BOON, alpha * sin(minf(glow, 1.0) * PI * 0.5))
			ShapePaint.colored_polygon(ci, _hexagon(at, (CELL - 1.6) * 0.6), lit)


## 頂点が上下を向いた六角形。
func _hexagon(center: Vector2, radius: float) -> PackedVector2Array:
	var points := PackedVector2Array()
	for i in range(6):
		points.append(center + Vector2.from_angle(PI / 6.0 + TAU * float(i) / 6.0) * radius)
	return points


## 縞のある砂の蜂。`facing` は進む向き(1=右)。羽は時間で羽ばたく。
func _bee(item: CanvasItem, at: Vector2, t: float, facing: float, alpha: float) -> void:
	var ci := item.get_canvas_item()
	var flap := 0.5 + 0.5 * sin(t * FLAP)
	var wing := Vector2(WING.x, WING.y * (0.4 + 0.6 * flap))
	UiPaint.fill_ellipse(
		ci, at + Vector2(-facing * 1.0, -BODY.y - wing.y * 0.5), wing, Color(WING_COLOR, alpha), 12
	)
	UiPaint.fill_ellipse(ci, at, BODY + Vector2.ONE, Color(UiPalette.OUTLINE_DARK, alpha), 14)
	UiPaint.fill_ellipse(ci, at, BODY, Color(SignaturePaint.SAND, alpha), 14)
	for x: float in [-1.6, 1.0]:
		var stripe := at + Vector2(x * facing, 0.0)
		item.draw_line(
			stripe - Vector2(0.0, BODY.y * 0.85),
			stripe + Vector2(0.0, BODY.y * 0.85),
			Color(STRIPE, alpha),
			1.2
		)
