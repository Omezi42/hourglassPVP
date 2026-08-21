class_name SkillData
extends Resource
## 手番の行動として発動するスキル1件分のデータ(GameDesign.md 4.3・7章)。
## 受動効果(EffectData)とは別に、HourglassData.skill として1駒につき最大1つ持つ。
## トリガーは常に「起動時」の1種類しかないため持たず、代わりにUIのボタンへ出す名前を持つ。

@export var display_name: String = ""
@export var description: String = ""
@export var effect_type: GameEnums.EffectType = GameEnums.EffectType.SWAP_BENCH
@export var target: GameEnums.Target = GameEnums.Target.SELF
@export var value: int = 0


## 交代スキルのように、発動時に対象を選ぶ必要があるかどうか(GameDesign.md 7章)。
## 対象を選ばせるのは交代だけとし、他は自動で決められる形に限る。
func needs_bench_target() -> bool:
	return effect_type == GameEnums.EffectType.SWAP_BENCH
