class_name ReplayListCard
extends Control

signal card_pressed(match_id: String)

var match_id: String = ""

var _press_tracker := PressTracker.new()
var _hovering := false
var _rest_position := Vector2.ZERO

## ホバー/押下のTween先。コンテナ(ListContainer)の直接の子である自分自身の
## position/scaleを外部から動かすと再レイアウト時に崩れるため、見た目専用の
## VisualRootへ逃がす。
@onready var visual_root: Control = $VisualRoot
@onready var background_panel: Panel = $VisualRoot/BackgroundPanel
@onready var result_badge: Label = $VisualRoot/Margin/VBox/HeaderRow/ResultBadge
@onready var info_label: Label = $VisualRoot/Margin/VBox/HeaderRow/InfoLabel
@onready var own_deck_row: HBoxContainer = $VisualRoot/Margin/VBox/Rows/OwnGroup/OwnDeckRow
@onready
var opponent_deck_row: HBoxContainer = $VisualRoot/Margin/VBox/Rows/OpponentGroup/OpponentDeckRow


func _ready() -> void:
	mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	_rest_position = visual_root.position
	resized.connect(_on_resized)
	mouse_entered.connect(_on_mouse_entered)
	mouse_exited.connect(_on_mouse_exited)


func _gui_input(event: InputEvent) -> void:
	match _press_tracker.feed(event, size):
		PressTracker.Result.PRESSED:
			ClickArea.animate_press(visual_root, true)
		PressTracker.Result.CONFIRMED:
			ClickArea.animate_press(visual_root, false)
			card_pressed.emit(match_id)
		PressTracker.Result.CANCELED:
			ClickArea.animate_press(visual_root, false)


func _on_resized() -> void:
	visual_root.pivot_offset = visual_root.size / 2.0
	if not _hovering:
		_rest_position = visual_root.position


func _on_mouse_entered() -> void:
	_hovering = true
	ClickArea.animate_hover(visual_root, true, _rest_position)


func _on_mouse_exited() -> void:
	_hovering = false
	ClickArea.animate_hover(visual_root, false, _rest_position)


## CPU戦(source == "cpu")は自分が常に先手(側A)のローカル対局のため、player_a/player_bの
## uid比較は行わず常にis_a=trueとして扱う(GameDesign.md 13章)。
func show_replay(doc: Dictionary, my_uid: String) -> void:
	match_id = str(doc["id"])
	var fields: Dictionary = doc["fields"]
	var is_cpu: bool = str(fields.get("source", "")) == "cpu"
	var is_a: bool = true if is_cpu else str(fields.get("player_a", "")) == my_uid
	var side_text := "先手" if is_a else "後手"
	var winner := str(fields.get("winner", ""))
	var won: bool = (winner == "a" and is_a) or (winner == "b" and not is_a)
	var type_text := "CPU戦" if is_cpu else "オンライン"
	var dt := Time.get_datetime_dict_from_unix_time(int(fields.get("finished_at", 0)))
	var date_text := (
		"%04d/%02d/%02d %02d:%02d" % [dt["year"], dt["month"], dt["day"], dt["hour"], dt["minute"]]
	)
	info_label.text = "%s　%s　[%s]" % [date_text, side_text, type_text]
	_apply_result(won)

	_fill_row(own_deck_row, fields.get("deck_a" if is_a else "deck_b", []))
	_fill_row(opponent_deck_row, fields.get("deck_b" if is_a else "deck_a", []))


## 勝敗が`info_label`の文中に埋もれて一目で分からなかったため、専用のバッジ(ResultBadge)と
## カード枠の色の両方で示す。色はUiPaletteの既存色(HPバーの残量表現と同じ、
## 安全=琥珀/危険=赤の意味付け)をそのまま流用し、新しい色は増やさない。
func _apply_result(won: bool) -> void:
	var accent := UiPalette.GLOW_AMBER if won else UiPalette.WARNING_RED

	result_badge.text = "勝利" if won else "敗北"
	var badge_style := (result_badge.get_theme_stylebox("normal") as StyleBoxFlat).duplicate()
	badge_style.border_color = accent
	badge_style.bg_color = Color(accent, 0.28)
	result_badge.add_theme_stylebox_override("normal", badge_style)

	var card_style := (background_panel.get_theme_stylebox("panel") as StyleBoxFlat).duplicate()
	card_style.border_color = accent
	background_panel.add_theme_stylebox_override("panel", card_style)


func _fill_row(row: HBoxContainer, ids: Array) -> void:
	for child in row.get_children():
		child.queue_free()
	for id in ids:
		var data: HourglassData = MatchSetup.find_by_id(str(id))
		if data == null:
			continue
		var icon := TextureRect.new()
		icon.texture = data.icon_upright
		icon.custom_minimum_size = Vector2(40, 40)
		icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		row.add_child(icon)
