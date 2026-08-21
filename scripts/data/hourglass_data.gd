class_name HourglassData
extends Resource

@export var id: String = ""
@export var display_name: String = ""
@export var fall_damage: int = 0
@export var icon_upright: Texture2D
@export var icon_falling: Texture2D
@export var icon_fallen: Texture2D
## 受動の追加効果(反転時/落下中/落ちきり時・落ちきり中に発動する)。
@export var effects: Array[EffectData] = []
## 手番の行動として発動するスキル(GameDesign.md 4.3)。持たない駒はnull。
@export var skill: SkillData


## この駒がスキルを持つかどうか。
func has_skill() -> bool:
	return skill != null
