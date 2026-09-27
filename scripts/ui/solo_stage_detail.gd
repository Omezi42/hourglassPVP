class_name SoloStageDetail
extends PanelContainer
## ソロモードの道で選んだステージの中身(GameDesign.md 27章)。名前・種別・説明・初回クリアの報酬を
## 並べ、「挑戦」で始める。道の駒には番号と名前しか載らないため、読むものはここへ集める。

signal challenge_pressed(stage: SoloStageData)

const PANEL_STYLE := "res://resources/theme/content_panel.tres"
const PADDING := 24
const EYEBROW_FONT_SIZE := 14
const NAME_FONT_SIZE := 26
const BODY_FONT_SIZE := 16
const REWARD_HEAD_FONT_SIZE := 14
const REWARD_TEXT_FONT_SIZE := 17
const STATUS_FONT_SIZE := 17
const RULE_COLOR := Color(1, 0.9, 0.7, 0.18)
const RULE_HEIGHT := 1.0
const REWARD_VISUAL := Vector2(52, 64)
const REWARD_GAP := 14
const BUTTON_SIZE := Vector2(240, 56)
const LOCKED_TEXT := "前のステージをクリアすると挑戦できます"
const CLEARED_TEXT := "クリア済み(解き直しでは報酬は出ません)"

var _stage: SoloStageData
var _eyebrow: Label
var _name: Label
var _body: Label
var _reward_head: Label
var _rewards: VBoxContainer
var _status: Label
var _button: Button


func _ready() -> void:
	var style: StyleBox = load(PANEL_STYLE)
	if style != null:
		add_theme_stylebox_override("panel", style)
	var margin := MarginContainer.new()
	for side in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, PADDING)
	add_child(margin)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 10)
	margin.add_child(box)

	_eyebrow = _label(EYEBROW_FONT_SIZE, UiPalette.BRASS_HIGHLIGHT)
	box.add_child(_eyebrow)
	_name = _label(NAME_FONT_SIZE, UiPalette.TEXT_OFFWHITE)
	box.add_child(_name)
	var rule := ColorRect.new()
	rule.color = RULE_COLOR
	rule.custom_minimum_size.y = RULE_HEIGHT
	box.add_child(rule)
	_body = _label(BODY_FONT_SIZE, UiPalette.TEXT_MUTED)
	box.add_child(_body)

	var spacer := Control.new()
	spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	box.add_child(spacer)

	_reward_head = _label(REWARD_HEAD_FONT_SIZE, UiPalette.BRASS_HIGHLIGHT)
	_reward_head.text = "初回クリアの報酬"
	box.add_child(_reward_head)
	_rewards = VBoxContainer.new()
	_rewards.add_theme_constant_override("separation", 4)
	box.add_child(_rewards)
	_status = _label(STATUS_FONT_SIZE, UiPalette.TEXT_MUTED)
	_status.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(_status)

	_button = CodedButton.make_in_group("挑戦", BUTTON_SIZE, CodedButton.PRIMARY_ACTION_GROUP)
	_button.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_button.pressed.connect(
		func() -> void:
			if _stage != null:
				challenge_pressed.emit(_stage)
	)
	box.add_child(_button)


func show_stage(stage: SoloStageData, cleared: bool, unlocked: bool) -> void:
	_stage = stage
	_eyebrow.text = "ステージ %d ・ %s" % [stage.order, stage.kind_label()]
	_name.text = stage.display_name
	_body.text = stage.description if unlocked else LOCKED_TEXT
	_button.disabled = not unlocked
	for child in _rewards.get_children():
		child.queue_free()
	var show_rewards := not cleared
	_reward_head.visible = show_rewards
	_rewards.visible = show_rewards
	_status.visible = cleared
	_status.text = CLEARED_TEXT
	if show_rewards:
		_fill_rewards(stage)


## 報酬の出し方は結果パネル(`CardChallengeResult`)と同じ絵を使う。
func _fill_rewards(stage: SoloStageData) -> void:
	if stage.reward_gold > 0:
		_rewards.add_child(
			_reward_row(StageRewardTokens.coin(REWARD_VISUAL), "+%d 砂金" % stage.reward_gold)
		)
	if not stage.reward_card_set_id.is_empty():
		var ids := CardSetLibrary.card_ids(stage.reward_card_set_id)
		var card: CardData = null if ids.is_empty() else CardLibrary.find_by_id(ids[0])
		if card != null:
			var art := HourglassArt.texture(card.art_key(), HourglassArt.State.UPRIGHT)
			_rewards.add_child(
				_reward_row(
					StageRewardTokens.art(art, true, REWARD_VISUAL), "カード「%s」" % card.display_name
				)
			)
	if not stage.reward_icon_id.is_empty():
		var icon := UserProfileLibrary.get_icon_texture(stage.reward_icon_id)
		_rewards.add_child(
			_reward_row(
				StageRewardTokens.art(icon, false, REWARD_VISUAL),
				"アイコン「%s」" % UserProfileLibrary.get_icon_name(stage.reward_icon_id)
			)
		)


func _reward_row(visual: Control, text: String) -> Control:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", REWARD_GAP)
	row.add_child(visual)
	var label := _label(REWARD_TEXT_FONT_SIZE, UiPalette.TEXT_OFFWHITE)
	label.text = text
	label.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(label)
	return row


func _label(font_size: int, color: Color) -> Label:
	var label := Label.new()
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	return label
