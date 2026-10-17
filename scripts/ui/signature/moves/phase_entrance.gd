extends SignatureMove
## フェイズの登場(GameDesign.md 9章):着地した駒の左右から赤い三日月の刃が2枚走り、
## 頭上で×の字に交差して閃く(総量が5の間、戦闘ダメージが2倍になる印)。

const SLASH := 0.3
const FLASH := 0.26
## 刃が走り出す位置(駒の中心から左右へ)と交差する位置(駒の中心から上へ)。
const SPREAD := 64.0
const CROSS := 58.0
## 三日月の大きさ(外側の弧の半径・太さ)と、交差したときの傾き。
const BLADE := 22.0
const THICK := 7.0
const TILT := PI * 0.25
const ARC_POINTS := 14
const FLASH_RADIUS := 26.0
const BLADE_EDGE := Color(1.0, 0.42, 0.32, 1.0)
const BLADE_CORE := Color(1.0, 0.88, 0.80, 1.0)


func impact_at() -> float:
	return CardUnitFx.LAND_DURATION


func duration() -> float:
	return impact_at() + SLASH + FLASH


func draw(item: CanvasItem, t: float) -> void:
	if t < impact_at():
		return
	var ci := item.get_canvas_item()
	var alpha := fade_alpha(t)
	var core := from - Vector2(0.0, CardView.BOARD_ART_SIDE * 0.5)
	var meet := core - Vector2(0.0, CROSS)
	var run := ease(phase(t, impact_at(), SLASH), -1.8)
	for side: float in [-1.0, 1.0]:
		var start := core + Vector2(side * SPREAD, 0.0)
		var at := start.lerp(meet, run)
		# 左の刃は右上へ、右の刃は左上へ走り、交差で×の字に重なる。
		_crescent(item, at, -PI * 0.5 + side * TILT * run, alpha)
	var flash := phase(t, impact_at() + SLASH, FLASH)
	if flash > 0.02:
		var radius := FLASH_RADIUS * ease(flash, 0.3)
		UiPaint.fill_circle(ci, meet, radius, Color(BLADE_CORE, alpha * (1.0 - flash)), 24)
		ShapePaint.arc(
			item.get_canvas_item(),
			meet,
			radius * 1.4,
			0.0,
			TAU,
			32,
			Color(BLADE_EDGE, alpha * (1.0 - flash)),
			2.0
		)


## 三日月の刃。`facing` は膨らんだ側の向き(ラジアン)。
func _crescent(item: CanvasItem, center: Vector2, facing: float, alpha: float) -> void:
	var shape := PackedVector2Array()
	var half := PI * 0.42
	for i in range(ARC_POINTS + 1):
		var a := facing - half + 2.0 * half * float(i) / float(ARC_POINTS)
		shape.append(center + Vector2.from_angle(a) * BLADE)
	for i in range(ARC_POINTS, -1, -1):
		var a := facing - half + 2.0 * half * float(i) / float(ARC_POINTS)
		var inner := BLADE - THICK * sin(PI * float(i) / float(ARC_POINTS))
		shape.append(
			center + Vector2.from_angle(a) * inner - Vector2.from_angle(facing) * THICK * 0.3
		)
	ShapePaint.colored_polygon(item.get_canvas_item(), shape, Color(BLADE_EDGE, alpha))
	var closed := shape.duplicate()
	closed.append(shape[0])
	ShapePaint.polyline(
		item.get_canvas_item(), closed, Color(UiPalette.OUTLINE_DARK, alpha * 0.7), 1.2, true
	)
	ShapePaint.arc(
		item.get_canvas_item(),
		center,
		BLADE - 1.5,
		facing - half * 0.7,
		facing + half * 0.7,
		10,
		Color(BLADE_CORE, alpha),
		1.6,
		true
	)
