extends SignatureMove
## ソードの設置(GameDesign.md 9章):駒の上に剣が現れて切っ先を相手のHPの器へ向け、まっすぐ突き
## 進んで刺さる(打撃)。

const APPEAR := 0.12
const AIM := 0.18
const THRUST := 0.22
## 剣の置き場所(駒の中心から上へ、鍔の位置)と、刃の長さ・半幅、柄の長さ、鍔の半幅。
const LIFT := 60.0
const BLADE := 40.0
const BLADE_HALF := 3.6
const GRIP := 12.0
const GUARD := 9.0
const STEEL := Color(0.86, 0.88, 0.94, 1.0)
const STEEL_DARK := Color(0.5, 0.52, 0.58, 1.0)


func impact_at() -> float:
	return APPEAR + AIM + THRUST


func draw(item: CanvasItem, t: float) -> void:
	if targets.is_empty() or t >= impact_at():
		return
	var alpha := fade_alpha(t) * ease(phase(t, 0.0, APPEAR), 0.5)
	var hilt := from - Vector2(0.0, LIFT)
	var aim := (targets[0] - hilt).normalized()
	var dir := Vector2.UP.slerp(aim, back_out(phase(t, APPEAR, AIM)))
	var thrust := ease(phase(t, APPEAR + AIM, THRUST), 2.4)
	hilt = hilt.lerp(targets[0] - aim * BLADE, thrust)
	_sword(item, hilt, dir, alpha)


## 鍔 `hilt` から `dir` へ刃が伸びる剣。
func _sword(item: CanvasItem, hilt: Vector2, dir: Vector2, alpha: float) -> void:
	var ci := item.get_canvas_item()
	var across := dir.orthogonal()
	var tip := hilt + dir * BLADE
	var blade := PackedVector2Array(
		[
			hilt - across * BLADE_HALF,
			tip - dir * BLADE_HALF * 2.0 - across * BLADE_HALF,
			tip,
			tip - dir * BLADE_HALF * 2.0 + across * BLADE_HALF,
			hilt + across * BLADE_HALF,
		]
	)
	var outline := PackedVector2Array()
	for p in blade:
		outline.append(p + (p - hilt.lerp(tip, 0.5)).normalized() * 1.2)
	ShapePaint.colored_polygon(ci, outline, Color(UiPalette.OUTLINE_DARK, alpha * 0.8))
	ShapePaint.colored_polygon(ci, blade, Color(STEEL, alpha))
	item.draw_line(hilt, tip - dir * 4.0, Color(STEEL_DARK, alpha), 1.0, true)
	item.draw_line(
		hilt - across * GUARD,
		hilt + across * GUARD,
		Color(UiPalette.OUTLINE_DARK, alpha),
		4.6,
		true
	)
	item.draw_line(
		hilt - across * GUARD,
		hilt + across * GUARD,
		Color(UiPalette.BRASS_HIGHLIGHT, alpha),
		3.0,
		true
	)
	var pommel := hilt - dir * GRIP
	item.draw_line(hilt, pommel, Color(UiPalette.WOOD_TOP.lightened(0.2), alpha), 3.4, true)
	ShapePaint.circle(ci, pommel, 3.0, Color(UiPalette.BRASS_HIGHLIGHT, alpha))
