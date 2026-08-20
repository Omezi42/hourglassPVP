class_name DeckListScreen
extends Control

signal back_pressed
signal edit_requested(index: int)

const DECK_CARD_SCENE := preload("res://scenes/deck_list_card.tscn")

var _decks: Array[Dictionary] = []
var _selected_index: int = -1
var _delete_pending_index: int = -1
var _reorder_mode: bool = false

@onready var list_container: GridContainer = $ScrollContainer/ListContainer
@onready var screen_header: ScreenHeader = $ScreenHeader
@onready var new_deck_button: Button = $NewDeckButton
@onready var reorder_button: Button = $ReorderButton
@onready var delete_confirm: ConfirmModal = $DeleteConfirm
@onready var empty_label: Label = $EmptyLabel


func _ready() -> void:
	screen_header.set_title("デッキ一覧")
	screen_header.back_pressed.connect(func() -> void: back_pressed.emit())
	screen_header.add_action(reorder_button)
	screen_header.add_action(new_deck_button)
	new_deck_button.pressed.connect(_on_new_deck_pressed)
	reorder_button.pressed.connect(_on_reorder_toggle_pressed)
	delete_confirm.confirmed.connect(_on_delete_confirmed)
	delete_confirm.cancelled.connect(_on_delete_cancelled)
	refresh()


func refresh() -> void:
	_decks = DeckSave.load_decks()
	_selected_index = DeckSave.load_selected_index()
	if _selected_index < 0 or _selected_index >= _decks.size():
		_selected_index = -1
	_reorder_mode = false
	_rebuild_list()


func _rebuild_list() -> void:
	for child in list_container.get_children():
		child.queue_free()
	empty_label.visible = _decks.is_empty()
	new_deck_button.disabled = _reorder_mode
	reorder_button.text = "並び替え完了" if _reorder_mode else "デッキ入れ替え"
	reorder_button.disabled = _decks.size() < 2
	for i in range(_decks.size()):
		var card: DeckListCard = DECK_CARD_SCENE.instantiate()
		card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		list_container.add_child(card)
		SoundBank.wire_buttons(card)
		card.show_deck(_decks[i], i == _selected_index)
		if _reorder_mode:
			card.set_mode(DeckListCard.Mode.REORDER)
			card.set_reorder_bounds(i > 0, i < _decks.size() - 1)
			card.move_up_pressed.connect(_on_move_up.bind(i))
			card.move_down_pressed.connect(_on_move_down.bind(i))
		else:
			card.set_mode(DeckListCard.Mode.MANAGE)
			card.selected_pressed.connect(_on_deck_selected.bind(i))
			card.edit_pressed.connect(_on_edit_pressed.bind(i))
			card.delete_pressed.connect(_on_delete_pressed.bind(i))


func _on_reorder_toggle_pressed() -> void:
	_reorder_mode = not _reorder_mode
	_rebuild_list()


func _on_move_up(index: int) -> void:
	_swap_decks(index, index - 1)


func _on_move_down(index: int) -> void:
	_swap_decks(index, index + 1)


func _swap_decks(index: int, other_index: int) -> void:
	if other_index < 0 or other_index >= _decks.size():
		return
	var tmp: Dictionary = _decks[index]
	_decks[index] = _decks[other_index]
	_decks[other_index] = tmp
	if _selected_index == index:
		_selected_index = other_index
	elif _selected_index == other_index:
		_selected_index = index
	DeckSave.save_decks(_decks, _selected_index)
	_rebuild_list()


func _on_deck_selected(index: int) -> void:
	_selected_index = index
	DeckSave.save_decks(_decks, _selected_index)
	MatchSetup.player_deck = _ids_to_data(_decks[index]["ids"])
	_rebuild_list()


func _on_edit_pressed(index: int) -> void:
	edit_requested.emit(index)


func _on_delete_pressed(index: int) -> void:
	_delete_pending_index = index
	delete_confirm.open_confirm(
		"デッキを削除しますか?",
		"「%s」を削除すると元に戻せません。" % str(_decks[index].get("name", "")),
		"削除する",
		"キャンセル",
		true
	)


func _on_delete_confirmed() -> void:
	if _delete_pending_index < 0 or _delete_pending_index >= _decks.size():
		return
	_decks.remove_at(_delete_pending_index)
	if _selected_index == _delete_pending_index:
		_selected_index = -1
	elif _selected_index > _delete_pending_index:
		_selected_index -= 1
	_delete_pending_index = -1
	DeckSave.save_decks(_decks, _selected_index)
	_rebuild_list()


func _on_delete_cancelled() -> void:
	_delete_pending_index = -1


func _on_new_deck_pressed() -> void:
	_decks.append({"name": "新しいデッキ%d" % (_decks.size() + 1), "ids": []})
	DeckSave.save_decks(_decks, _selected_index)
	edit_requested.emit(_decks.size() - 1)


func _ids_to_data(ids: Array) -> Array[HourglassData]:
	var result: Array[HourglassData] = []
	for id in ids:
		var found: HourglassData = MatchSetup.find_by_id(str(id))
		if found != null:
			result.append(found)
	return result
