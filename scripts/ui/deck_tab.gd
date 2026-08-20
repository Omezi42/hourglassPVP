class_name DeckTab
extends Control

signal deck_edit_pressed
signal hourglass_list_pressed

@onready var deck_edit_button: Button = $Center/VBox/DeckEditButton
@onready var hourglass_list_button: Button = $Center/VBox/Row/HourglassListButton
@onready var shop_button: Button = $Center/VBox/Row/ShopButton
@onready var shop_notice: ConfirmModal = $ShopNotice


func _ready() -> void:
	deck_edit_button.pressed.connect(func() -> void: deck_edit_pressed.emit())
	hourglass_list_button.pressed.connect(func() -> void: hourglass_list_pressed.emit())
	shop_button.pressed.connect(_on_shop_pressed)


func _on_shop_pressed() -> void:
	shop_notice.open_notice("お知らせ", "ショップは近日公開予定です")
