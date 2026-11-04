extends SignatureMove
## ハウンド(GameDesign.md 9章):相手が引いた瞬間、駒から体力のいちばん少ない駒へ足跡が駆け、
## 上下の牙が噛み合って火花が散る(打撃)。

const RUN := 0.26
const BITE := 0.12
## 駆ける足跡の数と大きさ・左右のずれ。牙の本数・顎の幅・牙の長さ、開いた顎の隙間。
const PRINTS := 4
const PRINT := 3.0
const STRIDE := 5.0
const FANGS := 4
const JAW_WIDTH := 34.0
const FANG := 9.0
const GAP := 22.0
const FANG_COLOR := Color(1.0, 0.97, 0.9, 1.0)


func impact_at() -> float:
	return RUN + BITE


func draw(item: CanvasItem, t: float) -> void:
	if targets.is_empty():
		return
	var ci := item.get_canvas_item()
	var alpha := fade_alpha(t)
	var target: Vector2 = targets[0]
	var run := phase(t, 0.0, RUN)
	var across := (target - from).normalized().orthogonal()
	for i in range(PRINTS):
		var s := (float(i) + 1.0) / float(PRINTS + 1)
		if s > run:
			break
		var side := STRIDE if i % 2 == 0 else -STRIDE
		var at := from.lerp(target, s) + across * side
		ShapePaint.circle(ci, at, PRINT, Color(UiPalette.OUTLINE_DARK, alpha))
	if t < RUN:
		return
	var open := GAP * (1.0 - ease(phase(t, RUN, BITE), 0.5))
	_jaw(ci, target - Vector2(0.0, open + 2.0), 1.0, alpha)
	_jaw(ci, target + Vector2(0.0, open + 2.0), -1.0, alpha)
	if t >= impact_at():
		SignaturePaint.sparks(item, target, phase(t, impact_at(), FADE), alpha)


## 牙の列。`facing` が 1.0 なら下向き(上顎)、-1.0 なら上向き(下顎)。
func _jaw(ci: RID, base: Vector2, facing: float, alpha: float) -> void:
	var step := JAW_WIDTH / float(FANGS)
	for i in range(FANGS):
		var left := base + Vector2(-JAW_WIDTH * 0.5 + step * float(i), 0.0)
		var tip := left + Vector2(step * 0.5, FANG * facing)
		var tooth := PackedVector2Array([left, left + Vector2(step, 0.0), tip])
		ShapePaint.colored_polygon(ci, tooth, Color(FANG_COLOR, alpha))
		var outline := tooth.duplicate()
		outline.append(left)
		ShapePaint.polyline(ci, outline, Color(UiPalette.OUTLINE_DARK, alpha), 1.2, true)
