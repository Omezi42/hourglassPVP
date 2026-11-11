class_name CardCpuSettingsPanel
extends Control
## CPU戦の詳細設定のモーダル(GameDesign.md 13章「CPU戦の設定」/ Architecture.md 8.2節)。
## 思考レベルのモーダルの「詳細設定」から重ねて開く。行ごとの「◀ 値 ▶」は端で先頭へ戻る。
## 「決める」で値を保存し、「戻る」は変えた値を捨てる。どちらも `closed` を出す。

signal closed

const SCREEN_SIZE := Vector2(1280, 720)
const PANEL_STYLE := "res://resources/theme/content_panel.tres"
const COLUMN_WIDTH := 430.0
const COLUMN_GAP := 40
const ROW_GAP := 10
const NAME_WIDTH := 150.0
const VALUE_WIDTH := 190.0
const ARROW_SIZE := Vector2(44, 44)
const BUTTON_SIZE := Vector2(200, 60)
const TITLE_FONT_SIZE := UiPalette.T_HEAD
const HEADING_FONT_SIZE := UiPalette.T_LEAD
const ROW_FONT_SIZE := UiPalette.T_LEAD
const NOTE_FONT_SIZE := UiPalette.T_BODY

const FIRST_NAMES := {
	CpuMatchSettings.First.PLAYER: "先手",
	CpuMatchSettings.First.CPU: "後手",
	CpuMatchSettings.First.RANDOM: "ランダム",
}
const SPEED_NAMES := {
	CpuMatchSettings.Speed.SLOW: "ゆっくり",
	CpuMatchSettings.Speed.NORMAL: "普通",
	CpuMatchSettings.Speed.FAST: "速い",
}
const PRACTICE_NOTE := "練習ルールのため、報酬と戦績の対象外"
const DEFAULT_SUMMARY := "標準のルール"
const SUMMARY_SEPARATOR := " ・ "

var _settings: CpuMatchSettings
var _dim: ColorRect
var _center: CenterContainer
var _panel: PanelContainer
var _columns: BoxContainer
var _value_labels: Dictionary = {}
var _deck_summary: Label
var _practice_note: Label


func _ready() -> void:
	visible = false
	mouse_filter = Control.MOUSE_FILTER_STOP
	# `set_anchors_preset()` は生成直後(サイズ0)のノードでは0のまま固定される。
	size = SCREEN_SIZE
	_build()
	PortraitModal.watch(self, _layout)
	EscClose.attach(self, _finish.bind(false))


func open() -> void:
	_settings = CpuMatchSettings.load_saved()
	_refresh()
	_layout()
	visible = true


func close() -> void:
	visible = false


func _layout() -> void:
	var portrait := ScreenOrientation.is_portrait()
	size = PortraitModal.screen_size()
	_dim.size = size
	_columns.vertical = portrait
	PortraitModal.fit(_center)


func _build() -> void:
	_dim = ColorRect.new()
	_dim.color = Color(UiPalette.INK_900, 0.72)
	_dim.size = SCREEN_SIZE
	_dim.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(_dim)

	# 大きさは代入せず画面へ張る(代入は中身の最小幅で広がったまま戻らない。Pitfalls.md)。
	_center = CenterContainer.new()
	_center.anchor_right = 1.0
	_center.anchor_bottom = 1.0
	_center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_center)

	_panel = PanelContainer.new()
	_panel.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var style: StyleBox = load(PANEL_STYLE)
	if style != null:
		_panel.add_theme_stylebox_override("panel", style)
	_center.add_child(_panel)

	var root := VBoxContainer.new()
	root.add_theme_constant_override("separation", 16)
	_panel.add_child(root)
	root.add_child(_label("詳細設定", TITLE_FONT_SIZE, UiPalette.IVORY, true))

	_columns = BoxContainer.new()
	_columns.add_theme_constant_override("separation", COLUMN_GAP)
	root.add_child(_columns)
	var matchup := _add_column("対局の組み合わせ")
	_add_row(matchup, "first", "先手 / 後手")
	_add_row(matchup, "foe_deck", "相手のデッキ")
	_deck_summary = _label("", NOTE_FONT_SIZE, UiPalette.MUTED, false)
	_deck_summary.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_deck_summary.custom_minimum_size = Vector2(COLUMN_WIDTH, 0)
	matchup.add_child(_deck_summary)
	_add_row(matchup, "speed", "指す速さ")
	var practice := _add_column("練習ルール")
	_add_row(practice, "own_hp", "自分のHP")
	_add_row(practice, "foe_hp", "相手のHP")
	_add_row(practice, "mulligan", "マリガン")
	_add_row(practice, "coin", "後手のコイン")
	_add_row(practice, "reveal_hand", "相手の手札")

	_practice_note = _label(PRACTICE_NOTE, NOTE_FONT_SIZE, UiPalette.MUTED, true)
	root.add_child(_practice_note)

	var buttons := HBoxContainer.new()
	buttons.alignment = BoxContainer.ALIGNMENT_CENTER
	buttons.add_theme_constant_override("separation", 24)
	root.add_child(buttons)
	var back := CodedButton.make("戻る", BUTTON_SIZE)
	back.pressed.connect(_finish.bind(false))
	buttons.add_child(back)
	var apply := CodedButton.make_in_group("決める", BUTTON_SIZE, CodedButton.PRIMARY_ACTION_GROUP)
	apply.pressed.connect(_finish.bind(true))
	buttons.add_child(apply)


func _add_column(heading: String) -> VBoxContainer:
	var column := VBoxContainer.new()
	column.custom_minimum_size = Vector2(COLUMN_WIDTH, 0)
	column.add_theme_constant_override("separation", ROW_GAP)
	column.add_child(_label(heading, HEADING_FONT_SIZE, UiPalette.MUTED, false))
	_columns.add_child(column)
	return column


func _add_row(column: VBoxContainer, key: String, title: String) -> void:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	var name_label := _label(title, ROW_FONT_SIZE, UiPalette.IVORY, false)
	name_label.custom_minimum_size = Vector2(NAME_WIDTH, 0)
	name_label.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(name_label)
	var left := CodedButton.make_icon("◀", ARROW_SIZE)
	left.pressed.connect(_step.bind(key, -1))
	row.add_child(left)
	var value := _label("", ROW_FONT_SIZE, UiPalette.IVORY, true)
	value.custom_minimum_size = Vector2(VALUE_WIDTH, 0)
	value.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	value.clip_text = true
	row.add_child(value)
	var right := CodedButton.make_icon("▶", ARROW_SIZE)
	right.pressed.connect(_step.bind(key, 1))
	row.add_child(right)
	column.add_child(row)
	_value_labels[key] = value


func _label(text: String, font_size: int, color: Color, centered: bool) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	if centered:
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	return label


## 選択肢の並びを1つ進める(端で反対の端へ戻る)。
func _step(key: String, offset: int) -> void:
	match key:
		"first":
			_settings.first = _cycle(FIRST_NAMES.keys(), _settings.first, offset)
		"foe_deck":
			var keys := CpuMatchSettings.foe_deck_keys()
			var current := _settings.foe_deck if keys.has(_settings.foe_deck) else keys[0]
			_settings.foe_deck = _cycle(keys, current, offset)
		"speed":
			_settings.speed = _cycle(SPEED_NAMES.keys(), _settings.speed, offset)
		"own_hp":
			_settings.own_hp = _cycle(CpuMatchSettings.HP_CHOICES, _settings.own_hp, offset)
		"foe_hp":
			_settings.foe_hp = _cycle(CpuMatchSettings.HP_CHOICES, _settings.foe_hp, offset)
		"mulligan":
			_settings.mulligan = not _settings.mulligan
		"coin":
			_settings.coin = not _settings.coin
		"reveal_hand":
			_settings.reveal_hand = not _settings.reveal_hand
	_refresh()


func _cycle(values: Array, current: Variant, offset: int) -> Variant:
	var index := maxi(values.find(current), 0)
	return values[posmod(index + offset, values.size())]


func _refresh() -> void:
	_set_value("first", FIRST_NAMES[_settings.first])
	_set_value("foe_deck", _foe_deck_name(_settings))
	_set_value("speed", SPEED_NAMES[_settings.speed])
	_set_value("own_hp", str(_settings.own_hp))
	_set_value("foe_hp", str(_settings.foe_hp))
	_set_value("mulligan", "あり" if _settings.mulligan else "なし")
	_set_value("coin", "あり" if _settings.coin else "なし")
	_set_value("reveal_hand", "見せる" if _settings.reveal_hand else "見せない")
	# 消すと高さが変わってパネルが跳ねるため、空のときも1行ぶんの場所を残す。
	var summary := CardCpuDecks.summary_of(_settings.foe_deck)
	_deck_summary.text = summary if not summary.is_empty() else " "
	_practice_note.modulate.a = 1.0 if _settings.is_practice() else 0.0


func _set_value(key: String, text: String) -> void:
	(_value_labels[key] as Label).text = text


static func _foe_deck_name(settings: CpuMatchSettings) -> String:
	var own_index := settings.own_deck_index()
	if own_index >= 0:
		return "自分の『%s』" % CardDeckSave.list_decks()[own_index]["name"]
	var cpu_name := CardCpuDecks.name_of(settings.foe_deck)
	return cpu_name if not cpu_name.is_empty() else "ランダム"


func _finish(apply: bool) -> void:
	if apply:
		_settings.save()
	close()
	closed.emit()


## 思考レベルのモーダルに出す1行。既定から変えた項目だけを並べ、練習ルールならその旨を続ける
## (設定は覚えておくため、変えたまま忘れて遊ばないように)。
static func summary_of(settings: CpuMatchSettings) -> String:
	var defaults := CpuMatchSettings.new()
	var parts: Array[String] = []
	if settings.first != defaults.first:
		parts.append(FIRST_NAMES[settings.first])
	if settings.own_deck_index() >= 0 or CardCpuDecks.deck_ids().has(settings.foe_deck):
		parts.append("相手 " + _foe_deck_name(settings))
	if settings.speed != defaults.speed:
		parts.append("速さ " + SPEED_NAMES[settings.speed])
	if settings.own_hp != defaults.own_hp:
		parts.append("自分のHP %d" % settings.own_hp)
	if settings.foe_hp != defaults.foe_hp:
		parts.append("相手のHP %d" % settings.foe_hp)
	if not settings.mulligan:
		parts.append("マリガンなし")
	if not settings.coin:
		parts.append("コインなし")
	if settings.reveal_hand:
		parts.append("手札を見せる")
	if parts.is_empty():
		return DEFAULT_SUMMARY
	var line := SUMMARY_SEPARATOR.join(parts)
	if not settings.is_practice():
		return line
	return "%s\n%s" % [line, PRACTICE_NOTE]
