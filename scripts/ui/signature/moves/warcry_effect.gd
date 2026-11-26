extends SignatureMove
## 鬨の声の恵与(GameDesign.md 9章):撃った位置に赤い軍旗が立ってはためき、旗から声の輪が広がって、
## 味方の駒それぞれの足元から炎が一度燃え立ち、金色の輪が広がる(砂が1粒ずつ落ちる)。

const RAISE := 0.22
const SHOUT := 0.24
const BLAZE := 0.32
## 旗竿の高さと太さ、旗の大きさ・はためく波の数と幅、声の輪の広がり。
const POLE := 60.0
const POLE_WIDTH := 3.0
const FLAG := Vector2(34.0, 20.0)
const WAVES := 2.0
const FLUTTER := 4.0
const FLAG_STEPS := 8
const SHOUT_REACH := 90.0
## 駒の足元に立つ炎の高さと幅。
const FLAME := 34.0
const FLAME_WIDTH := 20.0


func impact_at() -> float:
	return RAISE + SHOUT


func duration() -> float:
	return impact_at() + BLAZE


func draw(item: CanvasItem, t: float) -> void:
	var ci := item.get_canvas_item()
	var alpha := fade_alpha(t)
	var raise := back_out(phase(t, 0.0, RAISE))
	var flag_alpha := alpha * minf(phase(t, 0.0, RAISE) * 3.0, 1.0)
	var foot := from + Vector2(0.0, POLE * 0.5)
	var top := foot - Vector2(0.0, POLE * raise)
	ShapePaint.polyline(
		ci,
		PackedVector2Array([foot, top]),
		Color(UiPalette.INK_950, flag_alpha * 0.85),
		POLE_WIDTH + 2.4,
		true
	)
	ShapePaint.polyline(
		ci, PackedVector2Array([foot, top]), Color(UiPalette.GOLD, flag_alpha), POLE_WIDTH, true
	)
	var upper := PackedVector2Array()
	var lower := PackedVector2Array()
	for i in range(FLAG_STEPS + 1):
		var s := float(i) / float(FLAG_STEPS)
		var wave := sin((s * WAVES - t * 3.0) * TAU) * FLUTTER * s
		upper.append(top + Vector2(FLAG.x * s, wave))
		lower.append(top + Vector2(FLAG.x * s, FLAG.y * (1.0 - 0.3 * s) + wave))
	lower.reverse()
	var cloth := upper + lower
	var outline := cloth.duplicate()
	outline.append(cloth[0])
	ShapePaint.colored_polygon(ci, cloth, Color(UiPalette.SIGNAL_RED, flag_alpha))
	ShapePaint.polyline(ci, outline, Color(UiPalette.INK_950, flag_alpha * 0.7), 1.6, true)
	var shout := phase(t, RAISE, SHOUT + BLAZE)
	if shout > 0.0 and shout < 1.0:
		SignaturePaint.ripple(
			item,
			top + Vector2(FLAG.x * 0.5, FLAG.y * 0.5),
			SHOUT_REACH * ease(shout, 0.5),
			alpha * (1.0 - shout),
			UiPalette.FLAME
		)
	var blaze := phase(t, impact_at(), BLAZE)
	if blaze <= 0.0 or blaze >= 1.0:
		return
	for i in range(targets.size()):
		var h := FLAME * sin(minf(blaze * 1.6, 1.0) * PI * 0.5)
		SignaturePaint.flame_tongue(
			item, targets[i] + Vector2(0.0, 26.0), h, FLAME_WIDTH, -5.0, alpha * (1.0 - blaze)
		)
		SignaturePaint.boon_ring(item, targets[i], blaze, alpha)
