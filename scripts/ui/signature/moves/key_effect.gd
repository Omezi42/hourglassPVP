extends SignatureMove
## キー(GameDesign.md 9章):対象の上に真鍮の鍵が現れて鍵穴へ差し込まれ、1/4回転したところで
## 対象が返る。続く総量+3では、鍵穴から金色の光があふれて金色の輪が広がる。
## 反転(SPIN)と恵与(DESCEND)の2つの効果で呼ばれ、`style` で描き分ける。

const APPEAR := 0.18
const INSERT := 0.2
const TURN := 0.22
const GLOW := 0.3
const RING := 0.32
## 鍵穴の位置(対象の中心から上へ)と、鍵が差し込まれる前に浮いている高さ。
const LIFT := 66.0
const HOVER := 30.0
## 鍵の寸法(輪の半径・軸の長さ・歯の大きさ)。
const BOW := 8.0
const SHAFT := 22.0
const BIT := Vector2(7.0, 5.0)
const HOLE := 6.0
const GLOW_RADIUS := 22.0


func impact_at() -> float:
	if style == CardEnums.EffectVisualStyle.SPIN:
		return APPEAR + INSERT + TURN
	return GLOW


func duration() -> float:
	if style == CardEnums.EffectVisualStyle.SPIN:
		return impact_at() + FADE
	return impact_at() + RING


func draw(item: CanvasItem, t: float) -> void:
	if targets.is_empty():
		return
	var hole := targets[0] - Vector2(0.0, LIFT)
	if style == CardEnums.EffectVisualStyle.SPIN:
		_unlock(item, hole, t)
	else:
		_overflow(item, hole, t)


func _unlock(item: CanvasItem, hole: Vector2, t: float) -> void:
	var alpha := fade_alpha(t) * ease(phase(t, 0.0, APPEAR), 0.5)
	_keyhole(item, hole, alpha)
	var insert := ease(phase(t, APPEAR, INSERT), -1.6)
	var turn := back_out(phase(t, APPEAR + INSERT, TURN))
	var tip := hole - Vector2(0.0, HOVER * (1.0 - insert))
	_key(item, tip, cos(turn * PI * 0.5), alpha)


func _overflow(item: CanvasItem, hole: Vector2, t: float) -> void:
	var ci := item.get_canvas_item()
	var alpha := fade_alpha(t)
	_keyhole(item, hole, alpha)
	SignaturePaint.boon_ring(item, targets[0], phase(t, impact_at(), RING), alpha)
	var glow := sin(phase(t, 0.0, GLOW + RING) * PI)
	if glow < 0.05:
		return
	UiPaint.fill_circle(ci, hole, GLOW_RADIUS * glow, Color(SignaturePaint.BOON, alpha * 0.35), 24)
	UiPaint.fill_circle(ci, hole, HOLE * glow, Color(SignaturePaint.BOON, alpha), 12)


## 真鍮の座金に開いた鍵穴。
func _keyhole(item: CanvasItem, at: Vector2, alpha: float) -> void:
	var ci := item.get_canvas_item()
	UiPaint.fill_circle(ci, at, HOLE * 2.6, Color(UiPalette.OUTLINE_DARK, alpha * 0.8), 20)
	UiPaint.fill_circle(ci, at, HOLE * 2.3, Color(UiPalette.BRASS_HIGHLIGHT, alpha), 20)
	UiPaint.fill_circle(
		ci, at - Vector2(0.0, HOLE * 0.3), HOLE * 0.6, Color(UiPalette.OUTLINE_DARK, alpha), 10
	)
	var slot := PackedVector2Array(
		[
			at + Vector2(-HOLE * 0.25, 0.0),
			at + Vector2(HOLE * 0.25, 0.0),
			at + Vector2(HOLE * 0.45, HOLE * 1.1),
			at + Vector2(-HOLE * 0.45, HOLE * 1.1)
		]
	)
	item.draw_colored_polygon(slot, Color(UiPalette.OUTLINE_DARK, alpha))


## 上から差し込む鍵。`tip` は軸の先、`width` は回して奥行き方向へ倒れた見かけの幅(1→0)。
func _key(item: CanvasItem, tip: Vector2, width: float, alpha: float) -> void:
	var ci := item.get_canvas_item()
	var bow := tip - Vector2(0.0, SHAFT + BOW)
	var brass := Color(UiPalette.BRASS_HIGHLIGHT, alpha)
	var dark := Color(UiPalette.OUTLINE_DARK, alpha * 0.8)
	item.draw_line(bow, tip, dark, 5.0)
	item.draw_line(bow, tip, brass, 3.0)
	var bit_w := BIT.x * maxf(absf(width), 0.15)
	var bit := Rect2(tip.x, tip.y - BIT.y - 2.0, bit_w, BIT.y)
	item.draw_rect(bit, brass)
	item.draw_rect(bit, dark, false, 1.0)
	var ring := Vector2(BOW * maxf(absf(width), 0.35), BOW)
	UiPaint.fill_ellipse(ci, bow, ring + Vector2.ONE * 1.5, dark, 20)
	UiPaint.fill_ellipse(ci, bow, ring, brass, 20)
	UiPaint.fill_ellipse(ci, bow, ring * 0.45, Color(UiPalette.BRASS_DARK, alpha), 14)
