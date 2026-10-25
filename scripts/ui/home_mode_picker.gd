class_name HomeModePicker
extends Control
## ホームの札を押したあとに出す「どれで遊ぶか」のモーダル(GameDesign.md 9章)。
## 「バトル」= ランクマッチ / ルームマッチ / CPU戦、「ソロモード」= 遠征 / リーサルパズル。
## **ホームにはボタンを並べず、押してから選ばせる**ための部品で、2つとも同じ組み立てにする。
##
## 暗幕の上に見出しと同じ大きさの札(`HomeTile`)を横に並べ、最初の札の下に補助の
## ボタンを1つ(「ランキングを見る」)、中央下に「とじる」。暗幕を押しても閉じる。
## 札を押したら閉じてから札の `pressed` に任せる(選んだ先の画面へそのまま移るため)。

signal closed

const DIM_COLOR := Color(0, 0, 0, 0.62)
const TITLE_SIZE := 32
const TITLE_TOP := 112.0
const TITLE_HEIGHT := 52.0
const TILE_SIZE := Vector2(340, 380)
const TILE_TOP := 184.0
const GAP := 20.0
const BUTTON_HEIGHT := 56.0
const BUTTON_GAP := 18.0
const CLOSE_WIDTH := 200.0

## 縦では札を画面の幅いっぱいにして上から積む(9章「縦画面」)。
const PORTRAIT_TITLE_SIZE := 40
const PORTRAIT_TITLE_TOP := 150.0
const PORTRAIT_TILE_TOP := 230.0
const PORTRAIT_TILE_WIDTH := 672.0
const PORTRAIT_TILE_HEIGHT := 250.0
const PORTRAIT_GAP := 16.0
const PORTRAIT_BUTTON_HEIGHT := 76.0
const PORTRAIT_FONT := 28
const LANDSCAPE_TITLE_META := "landscape_title"

var _dim: ColorRect
var _title: Label
var _tiles: Array[HomeTile] = []
var _extra: Button
var _close: Button
var _portrait := false


static func make(title_text: String) -> HomeModePicker:
	var picker := HomeModePicker.new()
	picker._build(title_text)
	return picker


func _build(title_text: String) -> void:
	visible = false
	anchor_right = 1.0
	anchor_bottom = 1.0
	mouse_filter = Control.MOUSE_FILTER_STOP
	_dim = ColorRect.new()
	_dim.color = DIM_COLOR
	_dim.anchor_right = 1.0
	_dim.anchor_bottom = 1.0
	_dim.gui_input.connect(_on_dim_input)
	add_child(_dim)
	_title = Label.new()
	_title.text = title_text
	_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_title.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_title.add_theme_color_override("font_color", UiPalette.TEXT_OFFWHITE)
	_title.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_title)
	_close = CodedButton.make("とじる", Vector2(CLOSE_WIDTH, BUTTON_HEIGHT))
	_close.pressed.connect(close)
	add_child(_close)


## 選べる札を1つ足す。札を押すとモーダルを閉じてから札の `pressed` が届く。
func add_tile(tile: HomeTile) -> void:
	# 縦から横へ戻したときに元の大きさへ戻せるよう、横の文字の大きさを控える。
	tile.set_meta(LANDSCAPE_TITLE_META, tile.title_size)
	tile.pressed.connect(close)
	_tiles.append(tile)
	add_child(tile)
	move_child(_close, get_child_count() - 1)
	_layout()


## 最初の札の下に置く補助のボタン(ランクマッチの「ランキングを見る」)。
func set_extra_button(button: Button) -> void:
	_extra = button
	button.pressed.connect(close)
	add_child(button)
	_layout()


func open() -> void:
	_layout()
	visible = true
	move_to_front()


func close() -> void:
	if not visible:
		return
	visible = false
	closed.emit()


func apply_orientation(portrait: bool) -> void:
	_portrait = portrait
	_layout()


func _on_dim_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed:
		close()


func _layout() -> void:
	if _title == null:
		return
	var screen := Vector2(ScreenOrientation.base_size())
	if _portrait:
		_layout_portrait(screen)
		return
	_title.add_theme_font_size_override("font_size", TITLE_SIZE)
	_title.position = Vector2(0.0, TITLE_TOP)
	_title.size = Vector2(screen.x, TITLE_HEIGHT)
	var count := maxi(_tiles.size(), 1)
	var total := TILE_SIZE.x * float(count) + GAP * float(count - 1)
	var left := (screen.x - total) * 0.5
	for i in _tiles.size():
		_place(
			_tiles[i],
			Rect2(left + (TILE_SIZE.x + GAP) * float(i), TILE_TOP, TILE_SIZE.x, TILE_SIZE.y)
		)
	var below := TILE_TOP + TILE_SIZE.y + BUTTON_GAP
	if _extra != null:
		_place(_extra, Rect2(left, below, TILE_SIZE.x, BUTTON_HEIGHT))
		below += BUTTON_HEIGHT + BUTTON_GAP
	_place(_close, Rect2((screen.x - CLOSE_WIDTH) * 0.5, below, CLOSE_WIDTH, BUTTON_HEIGHT))


func _layout_portrait(screen: Vector2) -> void:
	_title.add_theme_font_size_override("font_size", PORTRAIT_TITLE_SIZE)
	_title.position = Vector2(0.0, PORTRAIT_TITLE_TOP)
	_title.size = Vector2(screen.x, TITLE_HEIGHT)
	var left := (screen.x - PORTRAIT_TILE_WIDTH) * 0.5
	var top := PORTRAIT_TILE_TOP
	for i in _tiles.size():
		_place(_tiles[i], Rect2(left, top, PORTRAIT_TILE_WIDTH, PORTRAIT_TILE_HEIGHT))
		top += PORTRAIT_TILE_HEIGHT + PORTRAIT_GAP
		if i == 0 and _extra != null:
			_place(_extra, Rect2(left, top, PORTRAIT_TILE_WIDTH, PORTRAIT_BUTTON_HEIGHT))
			top += PORTRAIT_BUTTON_HEIGHT + PORTRAIT_GAP
	_place(_close, Rect2((screen.x - CLOSE_WIDTH) * 0.5, top, CLOSE_WIDTH, PORTRAIT_BUTTON_HEIGHT))


func _place(control: Control, rect: Rect2) -> void:
	control.custom_minimum_size = rect.size
	control.position = rect.position
	control.size = rect.size
	if control is HomeTile:
		var landscape_title := int(control.get_meta(LANDSCAPE_TITLE_META))
		HomeTile.set_portrait_text(control, _portrait, PORTRAIT_FONT, landscape_title)
