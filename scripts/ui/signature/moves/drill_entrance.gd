extends SignatureMove
## ドリルの登場(GameDesign.md 9章):駒の頭上に螺旋の錐が現れて回りながら真下へ突き下ろされ、台座の
## 手前で石くずが散る(貫通=守りを突き抜けてダメージを通す印)。

const HOVER := 0.14
const PLUNGE := 0.18
const DEBRIS := 0.32
## 錐の出る高さ(台座の上面から上へ)と刺さる位置、錐の長さと根元の半幅、螺旋の筋の数。
const START := 150.0
const END := 6.0
const LENGTH := 34.0
const HALF := 9.0
const BANDS := 4
const SPIN := 14.0
## 石くずの数と飛ぶ速さ・重さ。
const CHIPS := 10
const CHIP_SPEED := 70.0
const GRAVITY := 160.0
const STEEL := Color(0.78, 0.8, 0.86, 1.0)
const STEEL_DARK := Color(0.42, 0.44, 0.5, 1.0)
const STONE := Color(0.58, 0.54, 0.48, 1.0)


func impact_at() -> float:
	return CardUnitFx.LAND_DURATION


func duration() -> float:
	return impact_at() + HOVER + PLUNGE + DEBRIS + FADE * 0.5


func draw(item: CanvasItem, t: float) -> void:
	if t < impact_at():
		return
	var ci := item.get_canvas_item()
	var alpha := fade_alpha(t)
	var hover := phase(t, impact_at(), HOVER)
	var plunge := ease(phase(t, impact_at() + HOVER, PLUNGE), 2.4)
	var tip_y := lerpf(from.y - START, from.y + END, plunge)
	var hit := impact_at() + HOVER + PLUNGE
	if t < hit + DEBRIS * 0.3:
		var a := alpha * minf(hover * 3.0, 1.0) * (1.0 - phase(t, hit, DEBRIS * 0.3))
		_drill(item, Vector2(from.x, tip_y), t * SPIN, a)
	var debris := phase(t, hit, DEBRIS)
	if debris <= 0.0 or debris >= 1.0:
		return
	for i in range(CHIPS):
		var angle := -PI * (0.1 + 0.8 * SignaturePaint.jitter(i, 101))
		var v := (
			Vector2.from_angle(angle) * CHIP_SPEED * (0.5 + 0.5 * SignaturePaint.jitter(i, 102))
		)
		var s := debris * 0.5
		var at := from + Vector2(0.0, END) + v * s + Vector2(0.0, GRAVITY * s * s)
		ShapePaint.circle(ci, at, 2.2, Color(STONE, alpha * (1.0 - debris)))


## 先端 `tip` を下へ向けた錐。`turn` で螺旋の筋が流れて回って見える。
func _drill(item: CanvasItem, tip: Vector2, turn: float, alpha: float) -> void:
	if alpha <= 0.0:
		return
	var ci := item.get_canvas_item()
	var top := tip - Vector2(0.0, LENGTH)
	var cone := PackedVector2Array([top - Vector2(HALF, 0.0), top + Vector2(HALF, 0.0), tip])
	ShapePaint.colored_polygon(ci, cone, Color(STEEL, alpha))
	var closed := cone.duplicate()
	closed.append(cone[0])
	ShapePaint.polyline(ci, closed, Color(UiPalette.OUTLINE_DARK, alpha * 0.8), 1.2, true)
	for k in range(BANDS):
		var s := fposmod(float(k) / float(BANDS) + turn * 0.1, 1.0)
		var y := lerpf(0.0, LENGTH, s)
		var half := HALF * (1.0 - y / LENGTH)
		var left := top + Vector2(-half, y)
		var right := top + Vector2(half, y + LENGTH / float(BANDS) * 0.6)
		item.draw_line(left, right, Color(STEEL_DARK, alpha), 1.4, true)
	item.draw_rect(
		Rect2(top - Vector2(HALF * 0.5, 8.0), Vector2(HALF, 8.0)),
		Color(UiPalette.BRASS_DARK, alpha)
	)
