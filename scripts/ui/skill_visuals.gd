class_name SkillVisuals
extends RefCounted
## スキル(GameDesign.md 4.3)の見た目を1箇所に集約する。どのスキルにどの紋章・どの色を
## 割り当てるかをUI各所へ配らず、ここから引く。駒データ(SkillData)は効果だけを持ち、
## 見た目を持たないため、effect_typeから機械的に導出する。

## スキルの効果種別ごとの紋章。反転(HOURGLASS)とは必ず別の形にして、
## ボタンを見ただけで「反転ではない何か」だと分かるようにする。
const EMBLEMS := {
	GameEnums.EffectType.SWAP_BENCH: UiPaint.Emblem.BENCH,
	GameEnums.EffectType.SWAP_POSITION: UiPaint.Emblem.SWAP_ARROWS,
	GameEnums.EffectType.FORCE_ADVANCE: UiPaint.Emblem.ADVANCE,
	GameEnums.EffectType.RECOVER: UiPaint.Emblem.AWAKEN,
	GameEnums.EffectType.SYNC_STATE: UiPaint.Emblem.SWAP_ARROWS,
	GameEnums.EffectType.DAMAGE: UiPaint.Emblem.STRIKE,
	GameEnums.EffectType.HEAL: UiPaint.Emblem.HEAL,
}


static func emblem_for(skill: SkillData) -> UiPaint.Emblem:
	if skill == null:
		return UiPaint.Emblem.NONE
	return EMBLEMS.get(skill.effect_type, UiPaint.Emblem.NONE)


## スキルの発動が「自分の駒だけで完結するか」「盤面の別のマスへ届くか」。
## 届くスキルは、発動元から対象へ光の筋を伸ばす演出を付ける(GameDesign.md 9章)。
static func reaches_other_slot(skill: SkillData) -> bool:
	if skill == null:
		return false
	return (
		skill.effect_type == GameEnums.EffectType.SWAP_POSITION
		or skill.effect_type == GameEnums.EffectType.RECOVER
		or skill.effect_type == GameEnums.EffectType.SYNC_STATE
	)
