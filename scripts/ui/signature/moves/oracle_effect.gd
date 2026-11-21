extends SignatureMove
## オラクルの常在(GameDesign.md 9章):砂術を使うたび、駒の上の水晶玉が光り、相手の列へ光が降りて
## 各駒から砂粒が1つずつ昇る(砂粒の昇りは進行役が着弾で出す)。

const GLOW := 0.28
const REACH := 0.3
## 水晶玉の高さ(駒の中心から上へ)と半径、光の筋の太さ。
const LIFT := 74.0
const ORB := 13.0
const RAY_WIDTH := 3.0
const COLOR := Color(0.70, 0.78, 1.0, 1.0)


func impact_at() -> float:
	return GLOW + REACH


func draw(item: CanvasItem, t: float) -> void:
	var alpha := fade_alpha(t)
	var ci := item.get_canvas_item()
	var orb := from - Vector2(0.0, LIFT * zoom)
	var glow := ease(phase(t, 0.0, GLOW), 0.5)
	var r := ORB * zoom
	ShapePaint.circle(ci, orb, r * (1.4 + glow * 0.8), Color(COLOR, alpha * 0.25 * glow))
	ShapePaint.circle(ci, orb, r + 1.0, Color(UiPalette.INK_950, alpha * 0.7))
	ShapePaint.circle(ci, orb, r, Color(COLOR.darkened(0.45), alpha))
	ShapePaint.circle(ci, orb, r * 0.75 * glow, Color(COLOR, alpha))
	ShapePaint.circle(ci, orb - Vector2(r * 0.35, r * 0.35), r * 0.22, Color(1, 1, 1, alpha))
	var reach := phase(t, GLOW, REACH)
	if reach <= 0.0:
		return
	for target in targets:
		var tip := orb.lerp(target, ease(reach, 0.6))
		item.draw_line(orb, tip, Color(COLOR, alpha * 0.3), RAY_WIDTH * zoom * 3.0, true)
		item.draw_line(orb, tip, Color(COLOR, alpha), RAY_WIDTH * zoom, true)
	var landed := phase(t, impact_at(), FADE)
	if landed > 0.0:
		for target in targets:
			SignaturePaint.rising_grains(item, target, landed, alpha)
