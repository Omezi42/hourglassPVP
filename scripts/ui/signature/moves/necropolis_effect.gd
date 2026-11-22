extends SignatureMove
## ネクロポリスの設置(GameDesign.md 9章):空いた台座それぞれから墓石がせり上がり、ひびから砂が噴き出して
## 駒が現れる。

const RISE := 0.34
const CRACK := 0.18
## 墓石の幅・高さと、台座の中心からの沈み(せり上がる前は台座の下に隠れている量)。
const STONE := Vector2(40.0, 60.0)
const SINK := 10.0
const STONE_COLOR := Color(0.56, 0.56, 0.62, 1.0)
const GLOW := SignaturePaint.SPECTRAL


func impact_at() -> float:
	return RISE + CRACK


func sound() -> int:
	return SoundBank.Sfx.SIG_NECROPOLIS


func draw(item: CanvasItem, t: float) -> void:
	var alpha := fade_alpha(t)
	var ci := item.get_canvas_item()
	var rise := back_out(phase(t, 0.0, RISE))
	var crack := phase(t, RISE, CRACK)
	for target in targets:
		var size := STONE * zoom
		var bottom := target + Vector2(0.0, SINK * zoom)
		var top := bottom - Vector2(0.0, size.y * rise)
		var rect := Rect2(
			Vector2(top.x - size.x * 0.5, top.y + size.x * 0.5),
			Vector2(size.x, bottom.y - top.y - size.x * 0.5)
		)
		if rect.size.y > 0.0:
			item.draw_rect(rect.grow(1.5), Color(UiPalette.INK_950, alpha * 0.8))
			item.draw_rect(rect, Color(STONE_COLOR, alpha))
		ShapePaint.circle(
			ci,
			top + Vector2(0.0, size.x * 0.5),
			size.x * 0.5 + 1.5,
			Color(UiPalette.INK_950, alpha * 0.8)
		)
		ShapePaint.circle(
			ci, top + Vector2(0.0, size.x * 0.5), size.x * 0.5, Color(STONE_COLOR, alpha)
		)
		if crack > 0.0:
			var path := PackedVector2Array()
			for i in range(5):
				var k := float(i) / 4.0 * crack
				var zig := (5.0 if i % 2 == 0 else -5.0) * zoom
				path.append(top + Vector2(zig, size.y * 0.15 + size.y * 0.75 * k))
			ShapePaint.polyline(ci, path, Color(GLOW, alpha), 2.2, true)
	var landed := phase(t, impact_at(), FADE)
	if landed > 0.0:
		for target in targets:
			SignaturePaint.rising_grains(item, target, landed, alpha)
			ShapePaint.circle(
				ci, target, 30.0 * zoom * landed, Color(GLOW, alpha * 0.4 * (1.0 - landed))
			)
