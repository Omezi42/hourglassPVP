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
const MAIN_FONT := 30
const SIDE_FONT := 22

## アカウント帯を避ける上端と、下部タブに接する下端。他のタブと同じ値。
const TOP_BAND := 112.0
const BOTTOM := 560.0
const FRAME_X := 140.0
const FRAME_W := 1000.0
## 枠(`HomeFrame`)の中身の周りに取る余白。
const FRAME_PAD := 22.0
const FRAME_HEAD := 44.0

## 縦画面(GameDesign.md 9章「縦画面」)。札はどれも枠の幅いっぱいにし、横の2枚は縦に積む。
const PORTRAIT_MAIN_TILE_SIZE := Vector2(628, 200)
const PORTRAIT_SIDE_TILE_SIZE := Vector2(628, 120)
const PORTRAIT_MAIN_FONT := 40
const PORTRAIT_SIDE_FONT := 32
const PORTRAIT_FRAME_HEAD := 52.0

var _frame: HomeFrame
var _portrait := false

@onready var deck_edit_button: Button = $Center/VBox/DeckEditButton
@onready var hourglass_list_button: Button = $Center/VBox/Row/HourglassListButton
@onready var shop_button: Button = $Center/VBox/Row/ShopButton


func _ready() -> void:
	# **そのタブでいちばんやってほしいこと1つだけを塗りつぶした真鍮にする**(9章の3段)。
	deck_edit_button = _to_tile(deck_edit_button, "デッキ編集", "sand", MAIN_FONT, MAIN_TILE_SIZE, true)
	hourglass_list_button = _to_tile(
		hourglass_list_button, "砂時計図鑑", "eye", SIDE_FONT, SIDE_TILE_SIZE
	)
	shop_button = _to_tile(shop_button, "ショップ", "crown", SIDE_FONT, SIDE_TILE_SIZE)
	deck_edit_button.pressed.connect(func() -> void: deck_edit_pressed.emit())
	hourglass_list_button.pressed.connect(func() -> void: hourglass_list_pressed.emit())
	shop_button.pressed.connect(func() -> void: shop_pressed.emit())
	_add_frame()
	refresh()


## 中身を枠(`HomeFrame`)で囲う。**このタブだけ枠が無いと、他の3タブと並べたときに
## 札が背景の上へ直に浮いて見える**(4タブを切り替えて確かめた)。`.tscn` の
## `Center/VBox` の縦並びはそのまま使い、その後ろへ枠を1枚敷くだけにする。
func _add_frame() -> void:
	# **中身を枠の内側の左端へ揃える。**`.tscn` の `CenterContainer` は子を中央へ置くため、
	# 縦並びの幅を枠の内側いっぱいに広げてから、各札を左寄せにする(こうすると
	# `CenterContainer` が広げた縦並びごと中央へ置き、結果として枠と左端が揃う)。
	var column: Control = $Center/VBox
	for child in column.get_children():
		(child as Control).size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	var row: BoxContainer = $Center/VBox/Row
	row.alignment = BoxContainer.ALIGNMENT_BEGIN
	_frame = HomeFrame.make(Rect2(), "カード")
	add_child(_frame)
	# 枠は札より背面に置く(`Control` は後の子ほど手前に描かれる)。
	move_child(_frame, 0)
	_layout()


## 縦横が変わったときに `HomeScreen` から呼ばれる(Architecture.md 4.7節)。
func apply_orientation(portrait: bool) -> void:
	_portrait = portrait
	if _frame != null:
		_layout()


## 縦では図鑑とショップを横並び(`Row`)から出し、デッキ編集の下へ縦に積む。横では `Row` へ戻す。
func _move_side_tiles() -> void:
	var row: Control = $Center/VBox/Row
	var column: Control = $Center/VBox
	var target: Control = column if _portrait else row
	for tile in [hourglass_list_button, shop_button]:
		if tile.get_parent() != target:
			tile.reparent(target, false)
	row.visible = not _portrait


func _layout() -> void:
	var main_size := PORTRAIT_MAIN_TILE_SIZE if _portrait else MAIN_TILE_SIZE
	var side_size := PORTRAIT_SIDE_TILE_SIZE if _portrait else SIDE_TILE_SIZE
	_move_side_tiles()
	for tile: HomeTile in [deck_edit_button, hourglass_list_button, shop_button]:
		var is_main: bool = tile == deck_edit_button
		tile.custom_minimum_size = main_size if is_main else side_size
		tile.size = tile.custom_minimum_size
		HomeTile.set_portrait_text(
			tile,
			_portrait,
			PORTRAIT_MAIN_FONT if is_main else PORTRAIT_SIDE_FONT,
			MAIN_FONT if is_main else SIDE_FONT
		)
	_frame.set_portrait(_portrait)
	var center: Control = $Center
	var rect: Rect2
	if _portrait:
		var stack: float = main_size.y + (COLUMN_SEPARATION + side_size.y) * 2.0
		var height: float = PORTRAIT_FRAME_HEAD + stack + FRAME_PAD
		rect = Rect2(
			Vector2(HomeFrame.PORTRAIT_X, HomeFrame.portrait_stack_top(height)),
			Vector2(HomeFrame.PORTRAIT_W, height)
		)
		# 列を枠の見出しの下へ合わせる(`CenterContainer` の領域を列の高さちょうどにする)。
		center.anchor_bottom = 0.0
		center.offset_top = rect.position.y + PORTRAIT_FRAME_HEAD
		center.offset_bottom = center.offset_top + stack
	else:
		var height: float = FRAME_HEAD + main_size.y + COLUMN_SEPARATION + side_size.y + FRAME_PAD
		rect = Rect2(
			Vector2(FRAME_X, TOP_BAND + (BOTTOM - TOP_BAND - height) * 0.5),
			Vector2(FRAME_W, height)
		)
		center.anchor_bottom = 1.0
		center.offset_top = TOP_BAND
		center.offset_bottom = 0.0
	($Center/VBox as Control).custom_minimum_size.x = rect.size.x - FRAME_PAD * 2.0
	HomeFrame.place(_frame, rect)


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
