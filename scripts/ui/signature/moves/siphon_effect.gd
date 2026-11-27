extends SignatureMove
## サイフォンの設置(GameDesign.md 9章)。払拭では、駒から銅の吸い管が高い弧を描いて相手の駒へ伸び、他人の色の滴が
## 列になって管を登ってくるが、半分は途中で管からこぼれ落ち、相手の駒に縮む渦が残る。
## 続く恵与では、管が味方の駒へ下りて残った滴を注ぎ、金色の輪が広がる(高いほうから低いほうへ)。

const REACH := 0.2
const FLOW := 0.38
const POUR := 0.3
const BEADS := 4
## 吸い管の弧の高さ(払拭は高く、恵与は低く)と、管の出口(駒の中心から)。
const ARC_HIGH := 80.0
const ARC_LOW := 30.0
const MOUTH := Vector2(0.0, -30.0)
const TOP := 90.0


func top_extent() -> float:
	return TOP * zoom


func impact_at() -> float:
	if _giving():
		return REACH + POUR
	return REACH + FLOW


func draw(item: CanvasItem, t: float) -> void:
	if targets.is_empty():
		return
	var alpha := fade_alpha(t)
	var target := targets[0]
	var mouth := from + MOUTH * zoom
	var reach := ease(phase(t, 0.0, REACH), 0.6)
	var tube_alpha := alpha * (1.0 - phase(t, impact_at(), FADE))
	if _giving():
		var top := target + Vector2(0.0, -26.0)
		DrawSandPaint.tube(item, mouth, top, ARC_LOW, reach, tube_alpha)
		DrawSandPaint.beads(item, top, mouth, ARC_LOW, phase(t, REACH, POUR), alpha, 2)
		SignaturePaint.boon_ring(item, target, phase(t, impact_at(), FADE), alpha)
		return
	var flow := phase(t, REACH, FLOW)
	DrawSandPaint.tube(item, mouth, target, ARC_HIGH, reach, tube_alpha)
	DrawSandPaint.beads(
		item, mouth, target, ARC_HIGH, flow, alpha, BEADS, UiPalette.DRAW_FOREIGN, 0.5
	)
	DrawSandPaint.gulp(item, target, flow, alpha)
	SignaturePaint.drain_ring(item, target, phase(t, impact_at(), FADE), alpha)


func _giving() -> bool:
	return style == CardEnums.EffectVisualStyle.DESCEND
