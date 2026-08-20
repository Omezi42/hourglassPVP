class_name BattleDeckPickerScreen
extends Control

## ランダムマッチ/ルーム作成/CPU戦の開始前に挟む、使用デッキ選択画面。
## デッキタブでの「使用中」指定は初期選択値として引き継ぐが、選択自体は
## 対局のたびにここで選び直せる一時的なものであり、保存はしない。

signal back_pressed
signal deck_confirmed

const DECK_CARD_SCENE := preload("res://scenes/deck_list_card.tscn")

var _decks: Array[Dictionary] = []
var _selected_index: int = -1

@onready var list_container: GridContainer = $ScrollContainer/ListContainer
@onready var empty_label: Label = $EmptyLabel
@onready var screen_header: ScreenHeader = $ScreenHeader
@onready var confirm_button: Button = $ConfirmButton


func _ready() -> void:
	screen_header.set_title("使用するデッキを選択")
	screen_header.back_pressed.connect(func() -> void: back_pressed.emit())
	screen_header.add_action(confirm_button)
	confirm_button.pressed.connect(_on_confirm_pressed)


## 画面を開く直前にMainから呼ぶ。保存済みデッキを読み込み直し、
## 現在の使用中デッキ(MatchSetup.player_deck)を初期選択にする。
func open() -> void:
	_decks = DeckSave.load_decks()
	_selected_index = _initial_selected_index()
	_rebuild_list()


func _initial_selected_index() -> int:
	var current_ids: Array[String] = []
	for hourglass_data in MatchSetup.player_deck:
		current_ids.append(hourglass_data.id)
	if not current_ids.is_empty():
		for i in range(_decks.size()):
			if _decks[i]["ids"] == current_ids:
				return i
	var saved_index := DeckSave.load_selected_index()
	if saved_index >= 0 and saved_index < _decks.size():
		return saved_index
	return -1


func _rebuild_list() -> void:
	for child in list_container.get_children():
		child.queue_free()

	empty_label.visible = _decks.is_empty()
	list_container.visible = not _decks.is_empty()

	for i in range(_decks.size()):
		var card: DeckListCard = DECK_CARD_SCENE.instantiate()
		card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		list_container.add_child(card)
		card.set_mode(DeckListCard.Mode.PICKER)
		card.show_deck(_decks[i], i == _selected_index)
		card.selected_pressed.connect(_on_deck_pressed.bind(i))

	_refresh_confirm_button()


func _on_deck_pressed(index: int) -> void:
	_selected_index = index
	_rebuild_list()


func _refresh_confirm_button() -> void:
	confirm_button.disabled = _selected_index < 0 or _selected_index >= _decks.size()


func _on_confirm_pressed() -> void:
	if _selected_index < 0 or _selected_index >= _decks.size():
		return
	MatchSetup.player_deck = _ids_to_data(_decks[_selected_index]["ids"])
	deck_confirmed.emit()


func _ids_to_data(ids: Array) -> Array[HourglassData]:
	var result: Array[HourglassData] = []
	for id in ids:
		var found: HourglassData = MatchSetup.find_by_id(str(id))
		if found != null:
			result.append(found)
	return result
