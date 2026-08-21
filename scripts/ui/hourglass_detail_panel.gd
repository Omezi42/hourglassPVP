class_name HourglassDetailPanel
extends PanelContainer

const PLACEHOLDER_TEXT := "砂時計を選ぶと詳細が表示されます"
const PLACEHOLDER_ALPHA := 0.55
const VANILLA_TEXT := "スキル・受動効果なし"

@onready var icon: TextureRect = $Margin/VBox/TopRow/Icon
@onready var name_label: Label = $Margin/VBox/TopRow/InfoVBox/NameLabel
@onready var damage_label: Label = $Margin/VBox/TopRow/InfoVBox/DamageLabel
@onready var skill_header: HBoxContainer = $Margin/VBox/EffectsScroll/EffectsBox/SkillHeader
@onready var skill_emblem: PieceMarks = skill_header.get_node("SkillEmblem")
@onready var skill_title: Label = skill_header.get_node("SkillTitle")
@onready var skill_body: Label = $Margin/VBox/EffectsScroll/EffectsBox/SkillBody
@onready var passive_title: Label = $Margin/VBox/EffectsScroll/EffectsBox/PassiveTitle
@onready var passive_body: Label = $Margin/VBox/EffectsScroll/EffectsBox/PassiveBody
@onready var note_label: Label = $Margin/VBox/EffectsScroll/EffectsBox/NoteLabel


func _ready() -> void:
	clear()


## スキルと受動効果は能動/受動という性質の違いがあるため、1つの文章の塊にせず
## 見出しで分けて出す(GameDesign.md 9章)。スキルの見出しには、盤面・行動ボタンに出るものと
## 同じ紋章を添えて結びつける。
func show_data(data: HourglassData) -> void:
	visible = true
	icon.texture = data.icon_upright
	name_label.text = data.display_name
	damage_label.text = "落下ダメージ: %d" % data.fall_damage

	var has_skill := data.has_skill()
	skill_header.visible = has_skill
	skill_body.visible = has_skill
	if has_skill:
		skill_emblem.show_for(data)
		skill_title.text = "スキル『%s』" % data.skill.display_name
		skill_body.text = EffectText.skill_body(data.skill)

	var passive_lines: Array[String] = []
	for effect in data.effects:
		passive_lines.append(EffectText.describe(effect))
	passive_title.visible = not passive_lines.is_empty()
	passive_body.visible = not passive_lines.is_empty()
	passive_body.text = "\n".join(passive_lines)

	note_label.visible = not has_skill and passive_lines.is_empty()
	note_label.text = VANILLA_TEXT
	note_label.modulate.a = 1.0


## 未選択状態の見た目に戻す。枠だけ空で残ると何の領域か分からないため、
## パネル自体は残したまま案内文を出す。
func clear() -> void:
	visible = true
	icon.texture = null
	name_label.text = ""
	damage_label.text = ""
	skill_header.visible = false
	skill_body.visible = false
	passive_title.visible = false
	passive_body.visible = false
	note_label.visible = true
	note_label.text = PLACEHOLDER_TEXT
	note_label.modulate.a = PLACEHOLDER_ALPHA
