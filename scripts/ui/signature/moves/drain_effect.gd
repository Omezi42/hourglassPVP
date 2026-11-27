extends SignatureMove
## ドレイン(GameDesign.md 9章)。払拭では、撃った位置から針のように細い銅の管が相手の駒へ音もなく伸び、他人の色の滴が
## たった一粒だけ管を登って戻り、相手の駒に小さな渦が残る。続く恵与では、その一粒が味方の駒の頭へ落ちて金色の輪が広がる
## (一滴ずつなら気づかれない)。

const REACH := 0.18
const SIP := 0.28
const FALL := 0.26
## 管の細さ、弧の高さ、恵与で滴が落ち始める高さ(対象の中心から)。
const THIN := 0.55
const ARC := 24.0
const DROP_FROM := Vector2(0.0, -80.0)
const TOP := 90.0


func top_extent() -> float:
	return TOP if _giving() else 0.0


func impact_at() -> float:
	if _giving():
		return FALL
	return REACH + SIP


func draw(item: CanvasItem, t: float) -> void:
	if targets.is_empty():
		return
	var alpha := fade_alpha(t)
	var target := targets[0]
	if _giving():
		var fall := phase(t, 0.0, FALL)
		if fall < 1.0:
			var start := target + DROP_FROM
			SignaturePaint.water_drop(
				item,
				start.lerp(target + Vector2(0.0, -16.0), fall * fall),
				4.4,
				Vector2.DOWN,
				alpha
			)
		SignaturePaint.boon_ring(item, target, phase(t, impact_at(), FADE), alpha)
		return
	var sip := phase(t, REACH, SIP)
	DrawSandPaint.tube(
		item,
		from,
		target,
		ARC,
		ease(phase(t, 0.0, REACH), 0.6),
		alpha * (1.0 - phase(t, impact_at(), FADE)),
		THIN
	)
	DrawSandPaint.beads(item, from, target, ARC, sip, alpha, 1)
	DrawSandPaint.gulp(item, target, sip * 0.8, alpha * 0.7)
	SignaturePaint.drain_ring(item, target, phase(t, impact_at(), FADE), alpha)


func _giving() -> bool:
	return style == CardEnums.EffectVisualStyle.DESCEND
