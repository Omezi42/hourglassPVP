class_name DeckTab
extends Control
## ホーム画面の「デッキ」タブ(GameDesign.md 9章)。
##
## **入口は `HomeTile` として出し、押す前に分かるべきことを1行添える。**
## 以前は「デッキ編集」「砂時計一覧」「ショップ」という文字だけの板が並んでおり、
## いま何枚のデッキを持っているのかも、砂金がいくらあるのかも、押すまで分からなかった。

signal deck_edit_pressed
signal hourglass_list_pressed
signal shop_pressed

@onready var deck_edit_button: Button = $Center/VBox/DeckEditButton
@onready var hourglass_list_button: Button = $Center/VBox/Row/HourglassListButton
@onready var shop_button: Button = $Center/VBox/Row/ShopButton


func _ready() -> void:
	deck_edit_button = _to_tile(deck_edit_button, "デッキ編集", "sand", 30)
	hourglass_list_button = _to_tile(hourglass_list_button, "砂時計図鑑", "eye", 22)
	shop_button = _to_tile(shop_button, "ショップ", "crown", 22)
	deck_edit_button.pressed.connect(func() -> void: deck_edit_pressed.emit())
	hourglass_list_button.pressed.connect(func() -> void: hourglass_list_pressed.emit())
	shop_button.pressed.connect(func() -> void: shop_pressed.emit())
	refresh()


## タブを開くたびに副題を読み直す(デッキも砂金も画面の外で変わる)。
func refresh() -> void:
	var decks := CardDeckSave.list_decks()
	var selected := CardDeckSave.selected_deck()
	var tile := deck_edit_button as HomeTile
	if decks.is_empty():
		tile.set_subtitle("プリセット「基本」で対戦できます")
	else:
		var index: int = clampi(CardDeckSave.selected_index(), 0, decks.size() - 1)
		tile.set_subtitle(
			"%s ・ %d 枚 ・ 全%dデッキ" % [String(decks[index]["name"]), selected.size(), decks.size()]
		)
	(hourglass_list_button as HomeTile).set_subtitle(
		"収集 %d / %d 種" % [_card_count(), _card_count()]
	)
	(shop_button as HomeTile).set_subtitle(
		"%s %d" % [CurrencyRules.CURRENCY_NAME, AccountService.currency()]
	)


static func _card_count() -> int:
	return CardLibrary.all_cards().size()


## `.tscn` に置いてある `Button` を、同じ場所・同じ大きさの `HomeTile` へ置き換える。
## **`.tscn` を書き換えずに済ませるため**の手当てで、並び順(`get_index()`)も引き継ぐ。
func _to_tile(button: Button, title: String, emblem_id: String, font_size: int) -> HomeTile:
	var parent := button.get_parent()
	var tile := HomeTile.make(title, "", emblem_id, button.custom_minimum_size, font_size)
	tile.size_flags_horizontal = button.size_flags_horizontal
	tile.size_flags_vertical = button.size_flags_vertical
	parent.add_child(tile)
	parent.move_child(tile, button.get_index())
	parent.remove_child(button)
	button.queue_free()
	return tile
