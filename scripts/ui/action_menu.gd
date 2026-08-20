class_name ActionMenu
extends HBoxContainer

signal flip_pressed
signal move_pressed
signal swap_pressed

enum SelectionType { NONE, OWN_BOARD, OPPONENT_BOARD, BENCH }

@onready var flip_button: Button = $FlipButton
@onready var move_button: Button = $MoveButton
@onready var swap_button: Button = $SwapButton


func _ready() -> void:
	flip_button.pressed.connect(func() -> void: flip_pressed.emit())
	move_button.pressed.connect(func() -> void: move_pressed.emit())
	swap_button.pressed.connect(func() -> void: swap_pressed.emit())


## flip_disabledは、選択中の駒がロック中で反転できない場合にtrueを渡す
## (GameState.flip()はロック中は何もしないため、押しても意味のない反転ボタンを出さない)。
func show_for_selection(selection_type: SelectionType, flip_disabled: bool = false) -> void:
	visible = selection_type != SelectionType.NONE
	var is_board_selection := (
		selection_type == SelectionType.OWN_BOARD or selection_type == SelectionType.OPPONENT_BOARD
	)
	flip_button.visible = is_board_selection and not flip_disabled
	move_button.visible = selection_type == SelectionType.OWN_BOARD
	swap_button.visible = selection_type == SelectionType.BENCH
