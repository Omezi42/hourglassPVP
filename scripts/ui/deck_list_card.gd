class_name DeckListCard
extends Control

signal selected_pressed
signal edit_pressed
signal delete_pressed
signal move_up_pressed
signal move_down_pressed

## デッキ一覧のカード表示モード。
## MANAGE: 編集/削除ボタンを表示(通常のデッキ一覧)
## REORDER: 上へ/下へボタンを表示(並び替えモード、DeckListScreen.set_reorder_mode()経由)
## PICKER: ボタン非表示、タップして選択するのみ(BattleDeckPickerScreen)
enum Mode { MANAGE, REORDER, PICKER }

const SELECTED_BORDER := Color(0.85, 0.62, 0.22, 1.0)
const ICON_SIZE := Vector2(80, 80)

var _mode: Mode = Mode.MANAGE
var _press_tracker := PressTracker.new()
var _hovering := false
var _rest_position := Vector2.ZERO

## カード内は VBox[ TopRow[NamePlate, ButtonRow/ReorderRow], IconRow ] の縦2段構成。
## 一覧を横2列で並べる制約(1列あたり約600px)に収めるための構成で、以前の
## 「左に名札+ボタンの縦積み / 右にアイコン5個」は幅796pxを要求し2列に収まらなかった。
##
## ホバー/押下のTween先。コンテナ(ListContainer)の直接の子である自分自身の
## position/scaleを外部から動かすと再レイアウト時に崩れるため、見た目専用の
## VisualRootへ逃がす。背景パネルもVisualRoot配下のBackgroundPanelが描画する。
@onready var visual_root: Control = $VisualRoot
@onready var background_panel: Panel = $VisualRoot/BackgroundPanel
@onready var name_label: Label = $VisualRoot/Margin/VBox/TopRow/NamePlate/NameLabel
@onready var icon_row: HBoxContainer = $VisualRoot/Margin/VBox/IconRow
@onready var button_row: HBoxContainer = $VisualRoot/Margin/VBox/TopRow/ButtonRow
@onready var edit_button: Button = $VisualRoot/Margin/VBox/TopRow/ButtonRow/EditButton
@onready var delete_button: Button = $VisualRoot/Margin/VBox/TopRow/ButtonRow/DeleteButton
@onready var reorder_row: HBoxContainer = $VisualRoot/Margin/VBox/TopRow/ReorderRow
@onready var move_up_button: Button = $VisualRoot/Margin/VBox/TopRow/ReorderRow/MoveUpButton
@onready var move_down_button: Button = $VisualRoot/Margin/VBox/TopRow/ReorderRow/MoveDownButton


func _ready() -> void:
	edit_button.pressed.connect(func() -> void: edit_pressed.emit())
	delete_button.pressed.connect(func() -> void: delete_pressed.emit())
	move_up_button.pressed.connect(func() -> void: move_up_pressed.emit())
	move_down_button.pressed.connect(func() -> void: move_down_pressed.emit())
	mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	_rest_position = visual_root.position
	resized.connect(_on_resized)
	mouse_entered.connect(_on_mouse_entered)
	mouse_exited.connect(_on_mouse_exited)
	_apply_mode()


func _gui_input(event: InputEvent) -> void:
	match _press_tracker.feed(event, size):
		PressTracker.Result.PRESSED:
			ClickArea.animate_press(visual_root, true)
		PressTracker.Result.CONFIRMED:
			ClickArea.animate_press(visual_root, false)
			selected_pressed.emit()
		PressTracker.Result.CANCELED:
			ClickArea.animate_press(visual_root, false)


func _on_resized() -> void:
	visual_root.pivot_offset = visual_root.size / 2.0
	if not _hovering:
		_rest_position = visual_root.position


# M-5: カード自体のホバー反応(拡大・浮き上がり)は廃止。カード内の各ボタンのホバーは
# ButtonのStyleBox差し替えでそのまま機能するため、ここでは_hoveringの追跡のみ残す。
func _on_mouse_entered() -> void:
	_hovering = true


func _on_mouse_exited() -> void:
	_hovering = false


## 表示モードを切り替える(J-9: 入れ替えは並び替えモードへ、J-13: 選択専用モードを追加)。
func set_mode(mode: Mode) -> void:
	_mode = mode
	if is_node_ready():
		_apply_mode()


func _apply_mode() -> void:
	button_row.visible = _mode == Mode.MANAGE
	reorder_row.visible = _mode == Mode.REORDER


## 並び替えモード時、上へ/下へボタンの有効/無効を先頭・末尾で切り替える。
func set_reorder_bounds(can_move_up: bool, can_move_down: bool) -> void:
	move_up_button.disabled = not can_move_up
	move_down_button.disabled = not can_move_down


func show_deck(deck: Dictionary, is_selected: bool) -> void:
	name_label.text = str(deck.get("name", ""))

	for child in icon_row.get_children():
		child.queue_free()
	for id in deck.get("ids", []):
		var data: HourglassData = MatchSetup.find_by_id(str(id))
		if data == null:
			continue
		var icon := TextureRect.new()
		icon.texture = data.icon_upright
		icon.custom_minimum_size = ICON_SIZE
		icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		icon_row.add_child(icon)

	# J-10: 「使用中」バッジ表示は廃止。選択状態は枠線の色だけでうっすら示す。
	var style := (background_panel.get_theme_stylebox("panel") as StyleBoxFlat).duplicate()
	if is_selected:
		style.border_color = SELECTED_BORDER
	background_panel.add_theme_stylebox_override("panel", style)
