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

## 札の大きさ。バトルタブと同じ理由で、余っていた縦の領域を札の背丈へ回す。
## **枠の内側を横いっぱいに使う。**中身が枠より狭いと右側がまるごと空き、
## 枠を敷いた意味が消える(実際に描いて確かめた)。
const MAIN_TILE_SIZE := Vector2(956, 176)
## 2つ並べて内側の幅に収まる大きさ(`Row` の separation は24)。
const SIDE_TILE_SIZE := Vector2(466, 120)
## `.tscn` の縦並びが持つ間隔。枠の高さを合わせるために読む。
const COLUMN_SEPARATION := 28.0

## アカウント帯を避ける上端と、下部タブに接する下端。他のタブと同じ値。
const TOP_BAND := 112.0
const BOTTOM := 560.0
const FRAME_X := 140.0
const FRAME_W := 1000.0
## 枠(`HomeFrame`)の中身の周りに取る余白。
const FRAME_PAD := 22.0
const FRAME_HEAD := 44.0

@onready var deck_edit_button: Button = $Center/VBox/DeckEditButton
@onready var hourglass_list_button: Button = $Center/VBox/Row/HourglassListButton
@onready var shop_button: Button = $Center/VBox/Row/ShopButton


func _ready() -> void:
	# **そのタブでいちばんやってほしいこと1つだけを塗りつぶした真鍮にする**(9章の3段)。
	deck_edit_button = _to_tile(deck_edit_button, "デッキ編集", "sand", 30, MAIN_TILE_SIZE, true)
	hourglass_list_button = _to_tile(hourglass_list_button, "砂時計図鑑", "eye", 22, SIDE_TILE_SIZE)
	shop_button = _to_tile(shop_button, "ショップ", "crown", 22, SIDE_TILE_SIZE)
	deck_edit_button.pressed.connect(func() -> void: deck_edit_pressed.emit())
	hourglass_list_button.pressed.connect(func() -> void: hourglass_list_pressed.emit())
	shop_button.pressed.connect(func() -> void: shop_pressed.emit())
	_add_frame()
	refresh()


## 中身を枠(`HomeFrame`)で囲う。**このタブだけ枠が無いと、他の3タブと並べたときに
## 札が背景の上へ直に浮いて見える**(4タブを切り替えて確かめた)。`.tscn` の
## `Center/VBox` の縦並びはそのまま使い、その後ろへ枠を1枚敷くだけにする。
func _add_frame() -> void:
	var height: float = (
		FRAME_HEAD + MAIN_TILE_SIZE.y + COLUMN_SEPARATION + SIDE_TILE_SIZE.y + FRAME_PAD
	)
	var rect := Rect2(
		Vector2(FRAME_X, TOP_BAND + (BOTTOM - TOP_BAND - height) * 0.5), Vector2(FRAME_W, height)
	)
	# **中身を枠の内側の左端へ揃える。**`.tscn` の `CenterContainer` は子を中央へ置くため、
	# 縦並びの幅を枠の内側いっぱいに広げてから、各札を左寄せにする(こうすると
	# `CenterContainer` が広げた縦並びごと中央へ置き、結果として枠と左端が揃う)。
	var column: Control = $Center/VBox
	column.custom_minimum_size.x = FRAME_W - FRAME_PAD * 2.0
	for child in column.get_children():
		(child as Control).size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	var row: Control = $Center/VBox/Row
	row.alignment = BoxContainer.ALIGNMENT_BEGIN
	var frame := HomeFrame.make(rect, "カード")
	add_child(frame)
	# 枠は札より背面に置く(`Control` は後の子ほど手前に描かれる)。
	move_child(frame, 0)


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
	var collected := AccountService.collected_card_counts()
	(hourglass_list_button as HomeTile).set_subtitle("収集 %d / %d 種" % [collected.x, collected.y])
	(shop_button as HomeTile).set_subtitle(CurrencyRules.label_text(AccountService.currency()))


## `.tscn` に置いてある `Button` を、同じ場所・同じ大きさの `HomeTile` へ置き換える。
## **`.tscn` を書き換えずに済ませるため**の手当てで、並び順(`get_index()`)も引き継ぐ。
func _to_tile(
	button: Button,
	title: String,
	emblem_id: String,
	font_size: int,
	tile_size: Vector2,
	is_primary := false
) -> HomeTile:
	var parent := button.get_parent()
	var tile := HomeTile.make(title, "", emblem_id, tile_size, font_size, is_primary)
	tile.size_flags_horizontal = button.size_flags_horizontal
	tile.size_flags_vertical = button.size_flags_vertical
	parent.add_child(tile)
	parent.move_child(tile, button.get_index())
	parent.remove_child(button)
	button.queue_free()
	return tile
