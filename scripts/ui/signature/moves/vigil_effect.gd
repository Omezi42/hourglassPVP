extends SignatureMove
## ヴィジル(GameDesign.md 9章):味方が壊れるたび、駒の上に見張りの灯がともり、炎が細い
## 火の矢になって相手のHPの器へ飛ぶ(打撃。当たると盤面が揺れる)。

const KINDLE := 0.26
const FLIGHT := 0.34
## 灯の置き場所(駒の中心から)と、燭台・炎の大きさ。
const LIFT := 74.0
const HOLDER := Vector2(10.0, 4.0)
const FLAME := Vector2(6.0, 15.0)
## 火の矢の尾の長さ(進みの割合)と、尾を作る点の数。
const TAIL := 0.22
const TAIL_POINTS := 8
const FLAME_CORE := Color(1.0, 0.95, 0.75, 1.0)
const FLAME_EDGE := Color(1.0, 0.5, 0.16, 1.0)


func impact_at() -> float:
	return KINDLE + FLIGHT


func draw(item: CanvasItem, t: float) -> void:
	if targets.is_empty():
		return
	var ci := item.get_canvas_item()
	var alpha := fade_alpha(t)
	var lamp := from - Vector2(0.0, LIFT)
	var appear := ease(phase(t, 0.0, KINDLE * 0.5), 0.5)
	UiPaint.fill_ellipse(
		ci, lamp + Vector2(0.0, 3.0), HOLDER, Color(UiPalette.BRASS_DARK, alpha * appear), 16
	)
	UiPaint.fill_ellipse(
		ci, lamp, HOLDER * 0.8, Color(UiPalette.BRASS_HIGHLIGHT, alpha * appear), 16
	)
	var kindle := phase(t, KINDLE * 0.3, KINDLE * 0.7)
	var flight := phase(t, KINDLE, FLIGHT)
	if flight <= 0.0:
		var flicker := 1.0 + 0.12 * sin(t * 60.0)
		_flame(item, lamp, FLAME * ease(kindle, 0.5) * flicker, alpha)
		return
	# 灯は飛び立った後も小さく残り、どの駒が撃ったかを示す。
	_flame(item, lamp, FLAME * 0.35 * (1.0 - flight), alpha)
	if t >= impact_at():
		return
	var head := ease(flight, 1.6)
	var start := lamp - Vector2(0.0, FLAME.y)
	for i in range(TAIL_POINTS, 0, -1):
		var q := maxf(head - TAIL * float(i) / float(TAIL_POINTS), 0.0)
		var size := 3.2 * (1.0 - float(i) / float(TAIL_POINTS + 1))
		UiPaint.fill_circle(ci, start.lerp(targets[0], q), size, Color(FLAME_EDGE, alpha * 0.7), 8)
	var at := start.lerp(targets[0], head)
	var dir := (targets[0] - start).normalized()
	_dart(item, at, dir, alpha)


## 上へ伸びるしずく形の炎(下が丸く、上が尖る)。`size` は横の半径と高さ。
func _flame(item: CanvasItem, base: Vector2, size: Vector2, alpha: float) -> void:
	if size.x <= 1.0 or size.y <= 1.0:
		return
	var ci := item.get_canvas_item()
	var outer := PackedVector2Array()
	var inner := PackedVector2Array()
	for i in range(13):
		var a := PI * float(i) / 12.0
		outer.append(base + Vector2(cos(a) * size.x, sin(a) * size.x * 0.6))
		inner.append(base + Vector2(cos(a) * size.x * 0.5, sin(a) * size.x * 0.3))
	outer.append(base - Vector2(0.0, size.y))
	inner.append(base - Vector2(0.0, size.y * 0.55))
	UiPaint.fill_gradient_polygon(
		ci,
		outer,
		Rect2(base - Vector2(size.x, size.y), size * Vector2(2.0, 1.0)),
		[[0.0, Color(FLAME_EDGE, alpha * 0.5)], [1.0, Color(FLAME_EDGE, alpha)]]
	)
	item.draw_colored_polygon(inner, Color(FLAME_CORE, alpha))


## 火の矢の先端。進む向きへ尖った細い菱形。
func _dart(item: CanvasItem, at: Vector2, dir: Vector2, alpha: float) -> void:
	var across := dir.orthogonal() * 3.6
	var shape := PackedVector2Array([at + dir * 12.0, at + across, at - dir * 8.0, at - across])
	item.draw_colored_polygon(shape, Color(FLAME_EDGE, alpha))
	UiPaint.fill_circle(item.get_canvas_item(), at, 2.4, Color(FLAME_CORE, alpha), 8)
