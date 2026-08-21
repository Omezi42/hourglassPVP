class_name EffectText
extends RefCounted

const TRIGGER_TEXT := {
	GameEnums.Trigger.ON_FLIP: "反転時",
	GameEnums.Trigger.WHILE_FALLING: "落下中",
	GameEnums.Trigger.ON_FALLEN: "落ちきり時",
	GameEnums.Trigger.WHILE_FALLEN: "落ちきり中",
}

const TARGET_TEXT := {
	GameEnums.Target.SELF: "自分自身",
	GameEnums.Target.ADJACENT_LEFT: "左隣",
	GameEnums.Target.ADJACENT_RIGHT: "右隣",
	GameEnums.Target.OPPONENT_PLAYER: "相手プレイヤー",
	GameEnums.Target.OWN_PLAYER: "自分プレイヤー",
	GameEnums.Target.RANDOM_ALLY: "味方ランダム",
	GameEnums.Target.OPPONENT_MIRROR: "正面",
}

const EFFECT_TEXT := {
	GameEnums.EffectType.DAMAGE: "に%dダメージ",
	GameEnums.EffectType.DAMAGE_REDUCTION: "の被ダメージを%d軽減",
	GameEnums.EffectType.LOCK: "をロック",
	GameEnums.EffectType.FORCE_ADVANCE: "を強制進行",
	GameEnums.EffectType.RECOVER: "を上向きに戻す",
	GameEnums.EffectType.COUNTER: "に%dの反撃",
	GameEnums.EffectType.SYNC_STATE: "と状態を同期",
	GameEnums.EffectType.SWAP_BENCH: "を控えと入れ替える",
	GameEnums.EffectType.SWAP_POSITION: "と位置を入れ替える",
	GameEnums.EffectType.HEAL: "のHPを%d回復",
}


static func describe(effect: EffectData) -> String:
	var effect_phrase: String = EFFECT_TEXT[effect.effect_type]
	if effect_phrase.contains("%d"):
		effect_phrase = effect_phrase % effect.value
	return "%s: %s%s" % [TRIGGER_TEXT[effect.trigger], TARGET_TEXT[effect.target], effect_phrase]


static func describe_hourglass(data: HourglassData) -> String:
	var lines: Array[String] = []
	lines.append("%s(落下ダメージ%d)" % [data.display_name, data.fall_damage])
	if data.has_skill():
		lines.append("・" + describe_skill(data.skill))
	for effect in data.effects:
		lines.append("・" + describe(effect))
	return "\n".join(lines)


## スキル(GameDesign.md 4.3)の説明文。駒データが持つ説明文をそのまま使い、無い場合だけ
## 受動効果と同じ語彙(ターゲット×エフェクト)から機械的に組み立てる。
static func describe_skill(skill: SkillData) -> String:
	if not skill.description.is_empty():
		return "スキル『%s』: %s" % [skill.display_name, skill.description]
	var effect_phrase: String = EFFECT_TEXT[skill.effect_type]
	if effect_phrase.contains("%d"):
		effect_phrase = effect_phrase % skill.value
	return "スキル『%s』: %s%s" % [skill.display_name, TARGET_TEXT[skill.target], effect_phrase]
