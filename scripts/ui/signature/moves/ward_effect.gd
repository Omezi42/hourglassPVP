extends SignatureMove
## ウォードの設置(GameDesign.md 9章):駒から護符の札が1枚ひらりと飛んで対象に貼り付き、紋が光ったところで
## 金色の輪が広がる(恵与)。

const FLY := 0.36
const STICK := 0.1
const GLOW := 0.16
const RING := 0.32
## 札の大きさと、飛ぶ弧の高さ・揺れ、貼り付く位置(対象の中心から上へ)。
const TAG := Vector2(9.0, 14.0)
const ARC := 40.0
const SWAY := 0.6
const SPOT := 10.0
const PAPER := Color(0.97, 0.93, 0.8, 1.0)
const INK := Color(0.8, 0.2, 0.18, 1.0)


func impact_at() -> float:
	return FLY + STICK + GLOW


func duration() -> float:
	return impact_at() + RING


func draw(item: CanvasItem, t: float) -> void:
	if targets.is_empty():
		return
	var alpha := fade_alpha(t)
	var spot := targets[0] - Vector2(0.0, SPOT)
	var fly := phase(t, 0.0, FLY)
	var s := ease(fly, 0.8)
	var at := from.lerp(spot, s) - Vector2(0.0, ARC * sin(s * PI))
	var turn := sin(fly * TAU * 1.5) * SWAY * (1.0 - fly)
	var stick := phase(t, FLY, STICK)
	var squash := 1.0 + 0.2 * sin(stick * PI)
	var glow := sin(phase(t, FLY + STICK, GLOW) * PI)
	_tag(item, at, turn, Vector2(squash, 1.0 / squash), glow, alpha * minf(fly * 6.0, 1.0))
	SignaturePaint.boon_ring(item, targets[0], phase(t, impact_at(), RING), alpha)


## 縦長の護符の札。中央に朱の紋を描き、`glow` で紋の周りを光らせる。
func _tag(
	item: CanvasItem, at: Vector2, turn: float, stretch: Vector2, glow: float, alpha: float
) -> void:
	var ci := item.get_canvas_item()
	var half := TAG * stretch
	var shape := PackedVector2Array()
	for corner: Vector2 in [Vector2(-1, -1), Vector2(1, -1), Vector2(1, 1), Vector2(-1, 1)]:
		shape.append(at + (corner * half).rotated(turn))
	ShapePaint.colored_polygon(ci, shape, Color(PAPER, alpha))
	var closed := shape.duplicate()
	closed.append(shape[0])
	ShapePaint.polyline(ci, closed, Color(UiPalette.OUTLINE_DARK, alpha * 0.7), 1.2, true)
	if glow > 0.0:
		ShapePaint.circle(ci, at, half.x * 1.4, Color(SignaturePaint.BOON, alpha * 0.4 * glow))
	ShapePaint.arc(ci, at, half.x * 0.55, 0.0, TAU, 16, Color(INK, alpha), 1.6, true)
	var up := Vector2.UP.rotated(turn)
	item.draw_line(at - up * half.y * 0.7, at + up * half.y * 0.7, Color(INK, alpha), 1.4, true)
