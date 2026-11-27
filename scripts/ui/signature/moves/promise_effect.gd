extends SignatureMove
## プロミス(GameDesign.md 9章)。設置のドロー(静止)では、駒の頭上に証文が開いて羽根ペンが一行書き、朱の封蝋が押されて、
## 証文から光の札が3枚自分の情報帯へ飛ぶ。余砂の代償(打撃)では、砕けた台座に封蝋が現れて二つに割れ、
## 朱の筋が自分の情報帯へ走って打ち当たる。

const UNROLL := 0.14
const SIGN := 0.16
const STAMP := 0.08
const FLY := 0.26
const CARDS := 3
const CARD_LAG := 0.06
const BREAK := 0.2
const STRIKE := 0.2
## 証文の中心(駒の中心から)と半幅・半高、署名の行、封蝋の位置(証文の中心から)と半径、札の大きさ・弧の高さ。
const SCROLL := Vector2(0.0, -96.0)
const SCROLL_HALF := Vector2(30.0, 16.0)
const SEAL_AT := Vector2(18.0, 6.0)
const SEAL_R := 8.0
const CARD := 7.0
const ARC := 40.0
const TOP := 120.0


func top_extent() -> float:
	return TOP * zoom if _drawing() else 0.0


func impact_at() -> float:
	if _drawing():
		return UNROLL + SIGN + STAMP + FLY + CARD_LAG * float(CARDS - 1)
	return BREAK + STRIKE


func draw(item: CanvasItem, t: float) -> void:
	if targets.is_empty():
		return
	if _drawing():
		_draw_signing(item, t)
	else:
		_draw_debt(item, t)


func _draw_signing(item: CanvasItem, t: float) -> void:
	var ci := item.get_canvas_item()
	var alpha := fade_alpha(t)
	var center := from + SCROLL * zoom
	var open := ease(phase(t, 0.0, UNROLL), 0.6)
	var half := Vector2(SCROLL_HALF.x * open, SCROLL_HALF.y) * zoom
	if open > 0.0:
		var sheet := PackedVector2Array(
			[
				center - half,
				center + Vector2(half.x, -half.y),
				center + half,
				center + Vector2(-half.x, half.y)
			]
		)
		ShapePaint.convex_polygon(
			ci, ForesightPaint.grown(sheet, center, 2.0), Color(UiPalette.INK_950, alpha)
		)
		ShapePaint.convex_polygon(ci, sheet, Color(UiPalette.VELLUM, alpha))
		for side: float in [-1.0, 1.0]:
			var rod := center + Vector2(side * half.x, 0.0)
			item.draw_line(
				rod - Vector2(0.0, half.y + 3.0),
				rod + Vector2(0.0, half.y + 3.0),
				Color(UiPalette.WOOD_DARK, alpha),
				4.0 * zoom,
				true
			)
	var signed := phase(t, UNROLL, SIGN)
	var line_from := center + Vector2(-SCROLL_HALF.x * 0.75, -2.0) * zoom
	var line_to := line_from.lerp(center + Vector2(SCROLL_HALF.x * 0.3, -2.0) * zoom, signed)
	if signed > 0.0:
		item.draw_line(line_from, line_to, Color(UiPalette.PAPER_INK, alpha), 1.8, true)
		var nib := line_to + Vector2(0.0, -1.0)
		item.draw_line(
			nib,
			nib + Vector2(16.0, -22.0) * zoom,
			Color(UiPalette.IVORY, alpha * (1.0 - signed * 0.3)),
			4.0 * zoom,
			true
		)
	var stamp := phase(t, UNROLL + SIGN, STAMP)
	if stamp > 0.0:
		var seal := center + SEAL_AT * zoom
		var r := SEAL_R * zoom * lerpf(1.6, 1.0, stamp)
		ShapePaint.circle(ci, seal, r + 1.5, Color(UiPalette.INK_950, alpha))
		ShapePaint.circle(ci, seal, r, Color(UiPalette.SEAL_WAX, alpha))
		ShapePaint.circle(ci, seal, r * 0.5, Color(UiPalette.SEAL_WAX.darkened(0.3), alpha))
	var target := targets[0]
	var start := UNROLL + SIGN + STAMP
	for i in range(CARDS):
		var fly := phase(t, start + CARD_LAG * float(i), FLY)
		if fly <= 0.0 or fly >= 1.0:
			continue
		var at := PourPaint.along(center, target, ARC, ease(fly, 0.8))
		SignaturePaint.card_glint(item, at, CARD, fly * 2.0 + float(i), alpha)
	if t >= impact_at():
		SignaturePaint.pulse_ring(item, target, phase(t, impact_at(), FADE), alpha)


func _draw_debt(item: CanvasItem, t: float) -> void:
	var ci := item.get_canvas_item()
	var alpha := fade_alpha(t)
	var seal := from + Vector2(0.0, -40.0)
	var crack := ease(phase(t, 0.0, BREAK), 0.5)
	for side: float in [-1.0, 1.0]:
		var at := seal + Vector2(side * 6.0 * crack, 4.0 * crack)
		var start := PI * 0.5 if side < 0.0 else -PI * 0.5
		ShapePaint.arc(
			ci,
			at,
			SEAL_R * 0.7,
			start,
			start + PI,
			10,
			Color(UiPalette.SEAL_WAX, alpha),
			SEAL_R * 1.4,
			true
		)
	var strike := phase(t, BREAK, STRIKE)
	var target := targets[0]
	if strike > 0.0 and t < impact_at():
		var head := seal.lerp(target, ease(strike, -1.6))
		var tail := seal.lerp(target, maxf(ease(strike, -1.6) - 0.3, 0.0))
		item.draw_line(tail, head, Color(UiPalette.SEAL_WAX, alpha), 6.0, true)
		item.draw_line(tail, head, Color(SignaturePaint.SPARK_HOT, alpha), 2.0, true)
	if t >= impact_at():
		SignaturePaint.sparks(item, target, phase(t, impact_at(), FADE), alpha)


func _drawing() -> bool:
	return style == CardEnums.EffectVisualStyle.PULSE
