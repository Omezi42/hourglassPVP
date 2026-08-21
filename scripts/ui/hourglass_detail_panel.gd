class_name HourglassDetailPanel
extends PanelContainer

const PLACEHOLDER_TEXT := "砂時計を選ぶと詳細が表示されます"
const PLACEHOLDER_ALPHA := 0.55

@onready var icon: TextureRect = $Margin/VBox/TopRow/Icon
@onready var name_label: Label = $Margin/VBox/TopRow/InfoVBox/NameLabel
@onready var damage_label: Label = $Margin/VBox/TopRow/InfoVBox/DamageLabel
@onready var effects_label: Label = $Margin/VBox/EffectsScroll/EffectsLabel


func _ready() -> void:
	clear()


func show_data(data: HourglassData) -> void:
	visible = true
	effects_label.modulate.a = 1.0
	effects_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	icon.texture = data.icon_upright
	name_label.text = data.display_name
	damage_label.text = "落下ダメージ: %d" % data.fall_damage
	if data.effects.is_empty() and not data.has_skill():
		effects_label.text = "スキル・追加効果なし"
	else:
		var lines: Array[String] = []
		if data.has_skill():
			lines.append(EffectText.describe_skill(data.skill))
		for effect in data.effects:
			lines.append(EffectText.describe(effect))
		effects_label.text = "\n\n".join(lines)


## 未選択状態の見た目に戻す。枠だけ空で残ると何の領域か分からないため、
## パネル自体は残したまま案内文を出す。
func clear() -> void:
	visible = true
	icon.texture = null
	name_label.text = ""
	damage_label.text = ""
	# 折り返しが効くEffectsLabelを案内文の置き場所として使う
	effects_label.text = PLACEHOLDER_TEXT
	effects_label.modulate.a = PLACEHOLDER_ALPHA
	effects_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
