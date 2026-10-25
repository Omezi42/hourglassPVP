class_name DeckTab
extends Control
## ホームの右の列「デッキ編集」「砂時計図鑑」「ショップ」(GameDesign.md 9章)。左と中央は `BattleTab`。
##
## **入口は `HomeTile` として出し、押す前に分かるべきことを1行添える。**
## いま何枚のデッキを持っているのか、砂金がいくらあるのかを押す前に読めるようにする。
## 3つは同格の凹んだパネル(ホームで真鍮にするのは「バトル」だけ)。

signal deck_edit_pressed
signal hourglass_list_pressed
signal shop_pressed

const TILE_FONT := 28
## 縦画面では3つを横1列に並べる(幅が3分の1になるため、副題は2行まで折る)。
const PORTRAIT_TILE_FONT := 26

var _tiles: Array[HomeTile] = []
var _portrait := false

@onready var deck_edit_button: Button = $Center/VBox/DeckEditButton
@onready var hourglass_list_button: Button = $Center/VBox/Row/HourglassListButton
@onready var shop_button: Button = $Center/VBox/Row/ShopButton


func _ready() -> void:
	deck_edit_button = _to_tile(deck_edit_button, "デッキ編集", "sand")
	hourglass_list_button = _to_tile(hourglass_list_button, "砂時計図鑑", "eye")
	shop_button = _to_tile(shop_button, "ショップ", "crown")
	deck_edit_button.pressed.connect(func() -> void: deck_edit_pressed.emit())
	hourglass_list_button.pressed.connect(func() -> void: hourglass_list_pressed.emit())
	shop_button.pressed.connect(func() -> void: shop_pressed.emit())
	# `.tscn` の縦並び(`Center/VBox`)は、列の位置を `HomeLayout` で決める構成では使わない。
	$Center.queue_free()
	_layout()
	refresh()


## 縦横が変わったときに `HomeScreen` から呼ばれる(Architecture.md 4.7節)。
func apply_orientation(portrait: bool) -> void:
	_portrait = portrait
	if not _tiles.is_empty():
		_layout()


func _layout() -> void:
	for i in _tiles.size():
		var rect := (
			HomeLayout.portrait_collect_rect(i, _tiles.size())
			if _portrait
			else HomeLayout.collect_rect(i, _tiles.size())
		)
		var tile := _tiles[i]
		tile.custom_minimum_size = rect.size
		tile.position = rect.position
		tile.size = rect.size
		HomeTile.set_portrait_text(tile, _portrait, PORTRAIT_TILE_FONT, TILE_FONT)
		# 縦の3分の1の幅では、紋章のぶんを空けると見出しが入らない。紋章は文字の下の透かしにする。
		tile.emblem_reserve = 0.0


## タブを開くたびに副題を読み直す(デッキも砂金も画面の外で変わる)。
## 前回と文字列が変わっていたら、その行だけ短く光らせる
## (GameDesign.md 9章「押さなくても何かが変わったと分かるように」)。
func refresh() -> void:
	var decks := CardDeckSave.list_decks()
	var selected := CardDeckSave.selected_deck()
	var tile := deck_edit_button as HomeTile
	if decks.is_empty():
		_apply_subtitle(tile, "プリセット「基本」で対戦できます")
	else:
		var index: int = clampi(CardDeckSave.selected_index(), 0, decks.size() - 1)
		_apply_subtitle(
			tile,
			"%s ・ %d 枚 ・ 全%dデッキ" % [String(decks[index]["name"]), selected.size(), decks.size()]
		)
	var collected := AccountService.collected_card_counts()
	_apply_subtitle(hourglass_list_button as HomeTile, "収集 %d / %d 種" % [collected.x, collected.y])
	_apply_subtitle(shop_button as HomeTile, CurrencyRules.label_text(AccountService.currency()))


func _apply_subtitle(tile: HomeTile, text_line: String) -> void:
	var changed := not tile.subtitle.is_empty() and tile.subtitle != text_line
	tile.set_subtitle(text_line)
	if changed:
		tile.flash_subtitle()


## `.tscn` に置いてある `Button` を `HomeTile` へ置き換え、この列の直下へ移す。
## **`.tscn` を書き換えずに済ませるため**の手当て。
func _to_tile(button: Button, title: String, emblem_id: String) -> HomeTile:
	var tile := HomeTile.make(title, "", emblem_id, Vector2.ZERO, TILE_FONT)
	add_child(tile)
	_tiles.append(tile)
	button.get_parent().remove_child(button)
	button.queue_free()
	return tile
