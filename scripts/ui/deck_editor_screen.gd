class_name DeckEditorScreen
extends Control

signal back_pressed
signal saved

const DECK_SIZE := 5
const DECK_NAME_MAX_LENGTH := 10
const HOURGLASS_CARD_SCENE := preload("res://scenes/hourglass_card.tscn")
## 全砂時計を1行の横スクロールで並べるときのカードサイズ。
## 砂時計は今後も増えるため、行数が変わるグリッドではなく常に1行に保つ。
const CARD_SIZE := Vector2(132, 168)

var _deck_index: int = -1
var _slots: Array[DeckSlot] = []
var _cards: Array[HourglassCard] = []

@onready var deck_name_input: LineEdit = $Body/MainColumn/NameRow/DeckNameInput
@onready var progress_label: Label = $Body/MainColumn/NameRow/ProgressLabel
@onready var slot_grid: GridContainer = $Body/MainColumn/SlotGrid
@onready var card_row: HBoxContainer = $CardScroll/CardRow
@onready var detail_panel: HourglassDetailPanel = $Body/DetailPanel
@onready var status_label: Label = $Body/MainColumn/NameRow/StatusLabel
@onready var screen_header: ScreenHeader = $ScreenHeader
@onready var save_button: Button = $SaveButton


func _ready() -> void:
	# J-12: デッキ名は最大10文字(ネームプレートに収まる文字数の目安)。
	deck_name_input.max_length = DECK_NAME_MAX_LENGTH
	_slots.assign(slot_grid.get_children())
	for i in range(_slots.size()):
		_slots[i].slot_pressed.connect(_on_slot_pressed.bind(_slots[i]))
		_slots[i].card_dropped.connect(_on_card_dropped.bind(i))
	screen_header.set_title("デッキ編集")
	screen_header.back_pressed.connect(func() -> void: back_pressed.emit())
	screen_header.add_action(save_button)
	save_button.pressed.connect(_on_save_pressed)


func open_deck(index: int) -> void:
	var decks: Array[Dictionary] = DeckSave.load_decks()
	if index < 0 or index >= decks.size():
		return
	_deck_index = index
	var deck: Dictionary = decks[index]
	deck_name_input.text = str(deck.get("name", ""))
	status_label.text = ""

	for slot in _slots:
		slot.clear()
	var ids: Array = deck.get("ids", [])
	for i in range(min(ids.size(), _slots.size())):
		var data: HourglassData = MatchSetup.find_by_id(str(ids[i]))
		if data != null:
			_slots[i].show_hourglass(data)

	for child in card_row.get_children():
		child.queue_free()
	_cards.clear()
	for data in MatchSetup.all_hourglasses():
		var card: HourglassCard = HOURGLASS_CARD_SCENE.instantiate()
		card.custom_minimum_size = CARD_SIZE
		card_row.add_child(card)
		card.show_data(data)
		card.set_draggable(true)
		card.card_pressed.connect(_on_card_pressed.bind(card))
		_cards.append(card)
	_refresh_used_visual()


func _on_slot_pressed(slot: DeckSlot) -> void:
	var data: HourglassData = MatchSetup.find_by_id(slot.hourglass_id)
	if data != null:
		detail_panel.show_data(data)


func _on_card_pressed(card: HourglassCard) -> void:
	detail_panel.show_data(card.data)


func _on_card_dropped(hourglass_id: String, slot_index: int) -> void:
	var data: HourglassData = MatchSetup.find_by_id(hourglass_id)
	if data == null:
		return
	for slot in _slots:
		if slot.hourglass_id == hourglass_id:
			slot.clear()
	_slots[slot_index].show_hourglass(data)
	_refresh_used_visual()


func _refresh_used_visual() -> void:
	var used_ids: Dictionary = {}
	for slot in _slots:
		if slot.hourglass_id != "":
			used_ids[slot.hourglass_id] = true
	for card in _cards:
		card.selected = used_ids.has(card.data.id)
	progress_label.text = "%d/%d枚" % [used_ids.size(), DECK_SIZE]


func _on_save_pressed() -> void:
	var ids: Array[String] = []
	for slot in _slots:
		if slot.hourglass_id != "":
			ids.append(slot.hourglass_id)
	if ids.size() != DECK_SIZE:
		status_label.text = "%d/%d 枚配置してください" % [ids.size(), DECK_SIZE]
		return

	var decks: Array[Dictionary] = DeckSave.load_decks()
	if _deck_index < 0 or _deck_index >= decks.size():
		return
	decks[_deck_index] = {"name": deck_name_input.text.strip_edges(), "ids": ids}
	DeckSave.save_decks(decks, DeckSave.load_selected_index())
	status_label.text = "保存しました"
	saved.emit()
