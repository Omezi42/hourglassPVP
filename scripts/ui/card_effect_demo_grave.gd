class_name CardEffectDemoGrave
extends RefCounted
## 墓地を読む効果と、自分の駒を払う効果の実演の台本(遺砂の刻。GameDesign.md 6章)。
##
## `CardEffectPreview` が1000行の上限に近いため切り出した(`CardEffectDemoKeyword` と
## 同じ流儀)。台本は「時刻 → 盤面の状態」を返す純粋な関数で、部品は `CardEffectStage` が持つ。

## 数える効果の実演で、墓地に積もっている砂時計の数。
const GRAVE_COUNT := 3
const BASE_TOTAL := 3


## 扱わない台本は空の Dictionary を返す。`self_card` は対象が砕けたそのカード自身か。
static func stage(demo: int, t: float, self_card: bool) -> Dictionary:
	match demo:
		CardEffectPreview.Demo.FX_ADD_TOTAL_PER_GRAVE:
			return _stage_per_grave(t)
		CardEffectPreview.Demo.FX_RECOVER_FROM_GRAVE:
			return _stage_recover(t, self_card)
		CardEffectPreview.Demo.FX_REVIVE_FROM_GRAVE:
			return _stage_revive(t)
		CardEffectPreview.Demo.FX_SACRIFICE:
			return _stage_sacrifice(t)
	return {}


static func _stage_per_grave(t: float) -> Dictionary:
	var stage := CardEffectStage.empty_stage()
	var own := CardEffectStage.piece(BASE_TOTAL, 0, BASE_TOTAL)
	own["fade"] = CardEffectStage.seg(t, 0.0, 0.15)
	stage["trigger_note"] = "墓地の砂時計1体につき総量が1増える(いまは%d体)" % GRAVE_COUNT
	if t >= 0.5:
		own["h"] = BASE_TOTAL + GRAVE_COUNT
		own["total"] = BASE_TOTAL + GRAVE_COUNT
		stage["pops"] = [
			CardEffectStage.pop(
				"own",
				0,
				"+%d" % GRAVE_COUNT,
				UiPalette.GLOW_AMBER,
				CardEffectStage.seg(t, 0.5, 0.9)
			)
		]
	stage["own"] = [own]
	return stage


static func _stage_recover(t: float, self_card: bool) -> Dictionary:
	var stage := CardEffectStage.empty_stage()
	if self_card:
		stage["trigger_note"] = "このカードが手札に戻る"
	else:
		var own := CardEffectStage.piece(4, 0, 4)
		own["fade"] = CardEffectStage.seg(t, 0.0, 0.15)
		stage["own"] = [own]
		stage["trigger_note"] = "墓地の砂時計を1体選んで手札に戻す"
	stage["draw_card"] = CardEffectStage.seg(t, 0.35, 0.85)
	return stage


static func _stage_revive(t: float) -> Dictionary:
	var stage := CardEffectStage.empty_stage()
	stage["trigger_note"] = "墓地の砂時計を1体選んで場に出す"
	if t >= 0.35:
		var revived := CardEffectStage.piece(6, 0, 6)
		revived["fade"] = CardEffectStage.seg(t, 0.35, 0.7)
		stage["own"] = [revived]
	return stage


static func _stage_sacrifice(t: float) -> Dictionary:
	var stage := CardEffectStage.empty_stage()
	var paid := CardEffectStage.piece(1, 3, 4)
	paid["fade"] = CardEffectStage.seg(t, 0.0, 0.15)
	paid["shatter"] = CardEffectStage.seg(t, 0.3, 0.6)
	stage["own"] = [paid]
	stage["trigger_note"] = "自分の砂時計1体を壊す"
	return stage
