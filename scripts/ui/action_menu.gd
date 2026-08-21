class_name ActionMenu
extends HBoxContainer

signal flip_pressed
signal skill_pressed

enum SelectionType { NONE, OWN_BOARD, OPPONENT_BOARD, BENCH }

## スキルボタンのスタイルは、駒ごとのスキルに合わせて紋章だけを差し替える(GameDesign.md 9章)。
## 状態ごとの元スタイルを控えておき、紋章違いを作って使い回す。
const BUTTON_STATES := ["normal", "hover", "pressed", "disabled"]

var _base_skill_styles: Dictionary = {}
var _skill_style_cache: Dictionary = {}
var _applied_emblem: int = -1

@onready var flip_button: Button = $FlipButton
@onready var skill_button: Button = $SkillButton


func _ready() -> void:
	flip_button.pressed.connect(func() -> void: flip_pressed.emit())
	skill_button.pressed.connect(func() -> void: skill_pressed.emit())
	for state_name in BUTTON_STATES:
		_base_skill_styles[state_name] = skill_button.get_theme_stylebox(state_name)


func _apply_skill_emblem(emblem: int) -> void:
	if emblem == _applied_emblem:
		return
	_applied_emblem = emblem
	for state_name in BUTTON_STATES:
		var key := "%d_%s" % [emblem, state_name]
		if not _skill_style_cache.has(key):
			var base: StyleBox = _base_skill_styles[state_name]
			if base == null:
				continue
			var style: StyleBox = base.duplicate()
			style.emblem = emblem
			_skill_style_cache[key] = style
		skill_button.add_theme_stylebox_override(state_name, _skill_style_cache[key])


## 選択中の駒に対して選べる行動を出す(GameDesign.md 4.2)。基本行動は「反転」だけで、
## その駒がスキルを持つ場合にのみスキルのボタンが並ぶ。
## flip_disabledは、選択中の駒がロック中で反転できない場合にtrueを渡す
## (GameState.flip()はロック中は何もしないため、押しても意味のない反転ボタンを出さない)。
## skillは自分の場の駒を選んだときだけ渡す(相手の駒のスキルは使えない)。
func show_for_selection(
	selection_type: SelectionType, flip_disabled: bool = false, skill: SkillData = null
) -> void:
	visible = selection_type != SelectionType.NONE
	var is_board_selection := (
		selection_type == SelectionType.OWN_BOARD or selection_type == SelectionType.OPPONENT_BOARD
	)
	flip_button.visible = is_board_selection and not flip_disabled
	var has_skill := selection_type == SelectionType.OWN_BOARD and skill != null
	skill_button.visible = has_skill
	if has_skill:
		skill_button.text = skill.display_name
		_apply_skill_emblem(SkillVisuals.emblem_for(skill))
