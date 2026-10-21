extends SignatureMove
## ゲートの登場(GameDesign.md 9章):駒の左右から石の門柱がせり上がって上に横木が渡り、門の形になってから
## 沈む(攻撃できない守護=通さない守りの印)。

const RISE := 0.22
const LINTEL := 0.12
const HOLD := 0.16
const SINK := 0.22
## 門柱の位置(台座の中心から左右へ)と太さ・高さ、横木の張り出しと厚み、横木が落ちてくる高さ。
const SPAN := 54.0
const PILLAR := Vector2(12.0, 100.0)
const OVERHANG := 10.0
const BEAM := 10.0
const BEAM_DROP := 30.0
const STONE := Color(0.66, 0.62, 0.56, 1.0)
const STONE_DARK := Color(0.4, 0.37, 0.33, 1.0)


func impact_at() -> float:
	return CardUnitFx.LAND_DURATION


func duration() -> float:
	return impact_at() + RISE + LINTEL + HOLD + SINK


func draw(item: CanvasItem, t: float) -> void:
	if t < impact_at():
		return
	var rise := back_out(phase(t, impact_at(), RISE))
	var sink := ease(phase(t, impact_at() + RISE + LINTEL + HOLD, SINK), 2.0)
	var height := PILLAR.y * clampf(rise, 0.0, 1.05) * (1.0 - sink)
	var alpha := 1.0 - sink * 0.6
	if height <= 1.0:
		return
	for side: float in [-1.0, 1.0]:
		var x := from.x + side * SPAN
		_block(item, Rect2(x - PILLAR.x * 0.5, from.y - height, PILLAR.x, height), alpha)
	var lintel := ease(phase(t, impact_at() + RISE, LINTEL), 2.0)
	if lintel > 0.0:
		var y := from.y - height - BEAM - BEAM_DROP * (1.0 - lintel)
		var width := SPAN * 2.0 + PILLAR.x + OVERHANG * 2.0
		_block(item, Rect2(from.x - width * 0.5, y, width, BEAM), alpha * minf(lintel * 3.0, 1.0))


## 縁取りと陰を付けた石の角材。
func _block(item: CanvasItem, rect: Rect2, alpha: float) -> void:
	item.draw_rect(rect.grow(1.2), Color(UiPalette.OUTLINE_DARK, alpha * 0.8))
	item.draw_rect(rect, Color(STONE, alpha))
	var shade := Rect2(
		rect.position + Vector2(rect.size.x * 0.65, 0.0), Vector2(rect.size.x * 0.35, rect.size.y)
	)
	item.draw_rect(shade, Color(STONE_DARK, alpha * 0.6))
