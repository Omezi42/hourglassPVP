class_name HourglassListScreen
extends Control

signal back_pressed

const HOURGLASS_CARD_SCENE := preload("res://scenes/hourglass_card.tscn")
const NAMEPLATE_STYLE := preload("res://resources/theme/coded_nameplate.tres")

const ROW_SIZE := 5
const ROW_HEIGHT := 270.0
const PLANK_HEIGHT := 64.0
const PLANK_TOP := 132.0
const ITEM_SEPARATION := 8
## 棚1枚に5個を並べたとき、棚板の幅(画面幅 - 詳細パネル分)を超えない間隔。
const ITEM_ROW_SEPARATION := 24
const CARD_SIZE := Vector2(152, 152)
const NAMEPLATE_SIZE := Vector2(128, 38)
const NAMEPLATE_FONT_SIZE := 16
const NAMEPLATE_TEXT_COLOR := Color(0.96, 0.94, 0.89, 1)

var _populated := false
var _cards: Array[HourglassCard] = []

@onready var shelf_list: VBoxContainer = $ScrollContainer/ShelfList
@onready var detail_panel: HourglassDetailPanel = $DetailPanel
@onready var screen_header: ScreenHeader = $ScreenHeader


func _ready() -> void:
	screen_header.set_title("砂時計一覧")
	screen_header.back_pressed.connect(func() -> void: back_pressed.emit())
	_populate()


func _populate() -> void:
	if _populated:
		return
	_populated = true
	var all_data := MatchSetup.all_hourglasses()
	var index := 0
	while index < all_data.size():
		var row_data := all_data.slice(index, index + ROW_SIZE)
		_build_shelf_row(shelf_list, row_data)
		index += ROW_SIZE
	if not _cards.is_empty():
		_select_card(_cards[0])


## HourglassCardは@onreadyで子ノードを参照するため、show_data()/set_shelf_mode()を呼ぶ前に
## シーンツリーへ入って_ready()が発火している必要がある。そのため各コンテナは生成直後に
## (既にツリーへ入っている)親へadd_childしてから中身を組み立てる、という順序で進める。
func _build_shelf_row(parent: Node, row_data: Array) -> void:
	var row := Control.new()
	row.name = "ShelfRow"
	row.custom_minimum_size = Vector2(0, ROW_HEIGHT)
	row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	parent.add_child(row)

	## 棚板は画面幅いっぱいに敷く可変幅の土台のため、画像(TextureRect)ではなく
	## Control._draw()で都度サイズに合わせて再描画するShelfPlankを使う(フェーズ12 Q-4)。
	var plank := ShelfPlank.new()
	plank.name = "Plank"
	plank.mouse_filter = Control.MOUSE_FILTER_IGNORE
	plank.anchor_right = 1.0
	plank.offset_top = PLANK_TOP
	plank.offset_bottom = PLANK_TOP + PLANK_HEIGHT
	row.add_child(plank)

	var items := HBoxContainer.new()
	items.name = "Items"
	items.anchor_right = 1.0
	items.anchor_bottom = 1.0
	items.alignment = BoxContainer.ALIGNMENT_CENTER
	items.add_theme_constant_override("separation", ITEM_ROW_SEPARATION)
	row.add_child(items)

	for data in row_data:
		_build_shelf_item(items, data)


func _build_shelf_item(parent: Node, data: HourglassData) -> void:
	var item := VBoxContainer.new()
	item.name = "Item"
	item.alignment = BoxContainer.ALIGNMENT_BEGIN
	item.add_theme_constant_override("separation", ITEM_SEPARATION)
	parent.add_child(item)

	var card: HourglassCard = HOURGLASS_CARD_SCENE.instantiate()
	item.add_child(card)
	card.custom_minimum_size = CARD_SIZE
	card.show_data(data)
	card.set_shelf_mode(true)
	card.card_pressed.connect(_on_card_pressed.bind(card))
	_cards.append(card)

	item.add_child(_build_nameplate(data.display_name))


func _build_nameplate(display_name: String) -> Control:
	var holder := Control.new()
	holder.name = "Nameplate"
	holder.custom_minimum_size = NAMEPLATE_SIZE
	holder.mouse_filter = Control.MOUSE_FILTER_IGNORE

	## 画像(shelf_nameplate.png)の代わりに、コード描画のCodedNameplateStyleを敷いた
	## Panelを使う(フェーズ12 Q-4)。サイズに応じて形が再計算されるため歪みは生じない。
	var plate := Panel.new()
	plate.add_theme_stylebox_override("panel", NAMEPLATE_STYLE)
	plate.mouse_filter = Control.MOUSE_FILTER_IGNORE
	plate.anchor_right = 1.0
	plate.anchor_bottom = 1.0
	holder.add_child(plate)

	var label := Label.new()
	label.text = display_name
	label.anchor_right = 1.0
	label.anchor_bottom = 1.0
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", NAMEPLATE_FONT_SIZE)
	label.add_theme_color_override("font_color", NAMEPLATE_TEXT_COLOR)
	holder.add_child(label)

	return holder


func _on_card_pressed(card: HourglassCard) -> void:
	_select_card(card)


## 選択中の駒は棚の上でも分かるようにハイライトし、詳細パネルへ内容を出す。
## 画面を開いた直後は先頭の駒を選んだ状態にして、詳細パネルが空のまま置かれないようにする。
func _select_card(card: HourglassCard) -> void:
	for other in _cards:
		other.selected = other == card
	detail_panel.show_data(card.data)
