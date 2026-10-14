extends SignatureMove
## カノンの反転(GameDesign.md 9章):駒の上にト音記号が描かれ、そこから出た音符の帯が
## 少し遅れて同じ旋律で追いかけるように相手の駒へ届き、届いた瞬間に対象が返る(輪唱)。

const WRITE := 0.28
const FLIGHT := 0.4
## 音符の数と、1つ後ろの音符が追いかける遅れ。
const NOTES := 4
const CANON_GAP := 0.08
const NOTE_SIZE := 5.0
## ト音記号の置き場所(駒の中心から)と大きさ。
const LIFT := 72.0
const CLEF_SCALE := 40.0
## 旋律の上下の揺れ(山の数と高さ)。
const WAVES := 2.0
const SWAY := 14.0
## ト音記号の筆の道(高さを1とした座標。y は下向き)。渦から上の輪を回り、縦線で下へ抜ける。
const CLEF := [
	Vector2(0.06, 0.16),
	Vector2(0.15, 0.22),
	Vector2(0.12, 0.33),
	Vector2(0.0, 0.37),
	Vector2(-0.15, 0.31),
	Vector2(-0.2, 0.15),
	Vector2(-0.1, -0.02),
	Vector2(0.08, -0.15),
	Vector2(0.15, -0.32),
	Vector2(0.08, -0.48),
	Vector2(0.0, -0.5),
	Vector2(-0.06, -0.4),
	Vector2(-0.04, -0.2),
	Vector2(0.0, 0.2),
	Vector2(0.03, 0.55),
	Vector2(-0.02, 0.64),
	Vector2(-0.09, 0.6),
]
const SMOOTH := 4


func impact_at() -> float:
	return WRITE + CANON_GAP * (NOTES - 1) + FLIGHT


func draw(item: CanvasItem, t: float) -> void:
	if targets.is_empty():
		return
	var alpha := fade_alpha(t)
	var clef := from - Vector2(0.0, LIFT)
	_clef(item, clef, phase(t, 0.0, WRITE), alpha)
	for i in range(NOTES):
		var k := phase(t, WRITE + CANON_GAP * i, FLIGHT)
		if k <= 0.0 or k >= 1.0:
			continue
		var at := clef.lerp(targets[0], ease(k, -1.6)) + Vector2(0.0, SWAY * sin(k * TAU * WAVES))
		SignaturePaint.note(item, at, NOTE_SIZE, SignaturePaint.SPIN, alpha)
	SignaturePaint.ripple(
		item, targets[0], 30.0 * phase(t, impact_at(), FADE), alpha, SignaturePaint.SPIN
	)


func _clef(item: CanvasItem, center: Vector2, written: float, alpha: float) -> void:
	if written <= 0.0 or alpha <= 0.0:
		return
	var path := _path(center)
	var count := maxi(2, int(ceil(path.size() * written)))
	var stroke := path.slice(0, count)
	item.draw_polyline(stroke, Color(UiPalette.OUTLINE_DARK, alpha * 0.8), 5.0, true)
	item.draw_polyline(stroke, Color(UiPalette.BRASS_HIGHLIGHT, alpha), 3.2, true)


## 筆の道を Catmull-Rom で滑らかにした点列。
func _path(center: Vector2) -> PackedVector2Array:
	var points := PackedVector2Array()
	var last := CLEF.size() - 1
	for i in range(last):
		var p0: Vector2 = CLEF[maxi(i - 1, 0)]
		var p1: Vector2 = CLEF[i]
		var p2: Vector2 = CLEF[i + 1]
		var p3: Vector2 = CLEF[mini(i + 2, last)]
		for s in range(SMOOTH):
			var u := float(s) / float(SMOOTH)
			points.append(center + p1.cubic_interpolate(p2, p0, p3, u) * CLEF_SCALE)
	points.append(center + CLEF[last] * CLEF_SCALE)
	return points
