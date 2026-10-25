class_name CardRoomArrange
extends RefCounted
## ルームマッチ画面の部品を縦横の座標へ置く(Architecture.md 4.7節)。向きが変わったときと、部屋の中の役が
## 決まったときに呼ぶ。**置き直すだけで状態は消さない**。`CardMatchArrange` と同じく画面の private メンバを直に触る
## (1000行の上限のための切り出し)。
##
## 縦(GameDesign.md 9章「縦画面」)は、横で左右に並ぶ札(部屋を作る / コードで参加する、自分 / 相手の席)を上下に積み、
## 札・席・コードの板はパネルごと `ZOOM` 倍にする。中の座標は横の値のまま使い、論理幅に収まらないものだけ縦の値を持つ。

const ZOOM := 1.2
const LEFT := 24.0
const GAP := 12.0
## 論理幅(拡大する前)。画面の幅いっぱい(672px)を `ZOOM` で割った値。
const WIDTH := 560.0
const CREATE_HEIGHT := 350.0
const JOIN_HEIGHT := 384.0
const DECK_HEIGHT := 112.0
const MESSAGE_HEIGHT := 40.0
const MESSAGE_FONT_SIZE := 24
const CREATE_BUTTON_Y := 262.0
const ENTRY_TILES_RECT := Rect2(24, 120, 290, 78)
const PAD_POS := Vector2(330, 120)
const DECK_BUTTON_RIGHT := 32.0

const CODE_HEIGHT := 200.0
const CODE_CAPTION_POS := Vector2(32, 20)
const CODE_HINT_POS := Vector2(32, 52)
const ROOM_TILES_RECT := Rect2(32, 92, 331, 92)
const COPY_BUTTON_RECT := Rect2(386, 108, 150, 60)
const SEAT_HEIGHT := 272.0
## 2つの席の間。VSの丸がここへ重なる。
const SEAT_GAP := 24.0
const FOOTER_FONT_SIZE := 24
const FOOTER_LINE := 36.0
const BUTTON_HEIGHT := 72.0
const LEAVE_WIDTH := 300.0
const START_WIDTH := 340.0


static func apply(screen: CardRoomScreen, portrait: bool) -> void:
	if portrait:
		_entrance_portrait(screen)
		_room_portrait(screen)
	else:
		_entrance_landscape(screen)
		_room_landscape(screen)
	place_footer(screen, portrait)
	screen._vs_mark.queue_redraw()


## 部屋の中の下段(持ち時間・状態・退出・開始)。退出の位置は役で変わる(開始が無いときは右端)。
static func place_footer(screen: CardRoomScreen, portrait: bool) -> void:
	var host := screen._role == CardRoomScreen.Role.HOST
	if not portrait:
		screen._time_info.position = CardRoomScreen.TIME_INFO_POS
		screen._status_label.position = CardRoomScreen.STATUS_POS
		screen._status_label.size = Vector2(CardRoomScreen.STATUS_WIDTH, 0)
		_set_font(screen._time_info, CardRoomScreen.STATUS_FONT_SIZE)
		_set_font(screen._status_label, CardRoomScreen.STATUS_FONT_SIZE)
		var leave := CardRoomScreen.LEAVE_RECT if host else CardRoomScreen.LEAVE_ALONE_RECT
		_place(screen._leave_button, leave)
		_place(screen._start_button, CardRoomScreen.START_RECT)
		_set_font(screen._leave_button, 0)
		_set_font(screen._start_button, 0)
		return
	var bottom := ScreenHeader.PORTRAIT_CONTENT_BOTTOM
	var button_top := bottom - BUTTON_HEIGHT
	var right := LEFT + WIDTH * ZOOM
	var foe_bottom := _seat_top(1) + SEAT_HEIGHT * ZOOM
	screen._time_info.position = Vector2(LEFT, foe_bottom + GAP)
	screen._status_label.position = Vector2(LEFT, foe_bottom + GAP + FOOTER_LINE)
	screen._status_label.size = Vector2(WIDTH * ZOOM, 0)
	_set_font(screen._time_info, FOOTER_FONT_SIZE)
	_set_font(screen._status_label, FOOTER_FONT_SIZE)
	var leave_x := LEFT if host else right - LEAVE_WIDTH
	_place(screen._leave_button, Rect2(leave_x, button_top, LEAVE_WIDTH, BUTTON_HEIGHT))
	_place(screen._start_button, Rect2(right - START_WIDTH, button_top, START_WIDTH, BUTTON_HEIGHT))
	_set_font(screen._leave_button, ScreenHeader.PORTRAIT_BUTTON_FONT)
	_set_font(screen._start_button, ScreenHeader.PORTRAIT_BUTTON_FONT)


## VSの丸の中心(2つの席の間)。
static func vs_center() -> Vector2:
	if not ScreenOrientation.is_portrait():
		return CardRoomScreen.VS_CENTER
	var gap_top := _seat_top(0) + SEAT_HEIGHT * ZOOM
	return Vector2(LEFT + WIDTH * ZOOM * 0.5, gap_top + SEAT_GAP * 0.5)


static func _entrance_portrait(screen: CardRoomScreen) -> void:
	var top := ScreenHeader.PORTRAIT_CONTENT_TOP
	_zoom(screen._create_card, Vector2(LEFT, top), Vector2(WIDTH, CREATE_HEIGHT))
	var join_top := top + CREATE_HEIGHT * ZOOM + GAP
	_zoom(screen._join_card, Vector2(LEFT, join_top), Vector2(WIDTH, JOIN_HEIGHT))
	var message_top := join_top + JOIN_HEIGHT * ZOOM
	_place(screen._message_label, Rect2(LEFT, message_top, WIDTH * ZOOM, MESSAGE_HEIGHT))
	_set_font(screen._message_label, MESSAGE_FONT_SIZE)
	_zoom(
		screen._deck_strip, Vector2(LEFT, message_top + MESSAGE_HEIGHT), Vector2(WIDTH, DECK_HEIGHT)
	)
	var create := CardRoomScreen.CREATE_BUTTON_RECT
	screen._create_button.position = Vector2((WIDTH - create.size.x) * 0.5, CREATE_BUTTON_Y)
	_place(screen._join_tiles, ENTRY_TILES_RECT)
	screen._join_pad.position = PAD_POS
	var deck := CardRoomScreen.DECK_BUTTON_RECT
	screen._deck_button.position = Vector2(WIDTH - DECK_BUTTON_RIGHT - deck.size.x, deck.position.y)


static func _entrance_landscape(screen: CardRoomScreen) -> void:
	_unzoom(screen._create_card, CardRoomScreen.CREATE_RECT)
	_unzoom(screen._join_card, CardRoomScreen.JOIN_RECT)
	_place(screen._message_label, CardRoomScreen.MESSAGE_RECT)
	_set_font(screen._message_label, CardRoomScreen.BODY_FONT_SIZE)
	_unzoom(screen._deck_strip, CardRoomScreen.DECK_RECT)
	screen._create_button.position = CardRoomScreen.CREATE_BUTTON_RECT.position
	_place(screen._join_tiles, CardRoomScreen.ENTRY_TILES_RECT)
	screen._join_pad.position = CardRoomScreen.PAD_POS
	screen._deck_button.position = CardRoomScreen.DECK_BUTTON_RECT.position


static func _room_portrait(screen: CardRoomScreen) -> void:
	var top := ScreenHeader.PORTRAIT_CONTENT_TOP
	_zoom(screen._code_plate, Vector2(LEFT, top), Vector2(WIDTH, CODE_HEIGHT))
	screen._code_caption.position = CODE_CAPTION_POS
	screen._code_hint.position = CODE_HINT_POS
	_place(screen._room_tiles, ROOM_TILES_RECT)
	_place(screen._copy_button, COPY_BUTTON_RECT)
	_zoom(screen._my_seat, Vector2(LEFT, _seat_top(0)), Vector2(WIDTH, SEAT_HEIGHT))
	_zoom(screen._foe_seat, Vector2(LEFT, _seat_top(1)), Vector2(WIDTH, SEAT_HEIGHT))


static func _room_landscape(screen: CardRoomScreen) -> void:
	_unzoom(screen._code_plate, CardRoomScreen.CODE_RECT)
	screen._code_caption.position = CardRoomScreen.CODE_CAPTION_POS
	screen._code_hint.position = CardRoomScreen.CODE_HINT_POS
	_place(screen._room_tiles, CardRoomScreen.ROOM_TILES_RECT)
	_place(screen._copy_button, CardRoomScreen.COPY_BUTTON_RECT)
	_unzoom(screen._my_seat, CardRoomScreen.MINE_RECT)
	_unzoom(screen._foe_seat, CardRoomScreen.FOE_RECT)


## `index` は 0 = 自分、1 = 相手。
static func _seat_top(index: int) -> float:
	var first := ScreenHeader.PORTRAIT_CONTENT_TOP + CODE_HEIGHT * ZOOM + GAP
	return first + (SEAT_HEIGHT + SEAT_GAP) * ZOOM * index


static func _zoom(node: Control, at: Vector2, logical_size: Vector2) -> void:
	node.position = at
	node.size = logical_size
	node.scale = Vector2.ONE * ZOOM


static func _unzoom(node: Control, rect: Rect2) -> void:
	node.scale = Vector2.ONE
	_place(node, rect)


static func _place(node: Control, rect: Rect2) -> void:
	node.position = rect.position
	node.size = rect.size


## 0 は上書きを外す(テーマ・作ったときの大きさへ戻す)。
static func _set_font(node: Control, font_size: int) -> void:
	if font_size <= 0:
		node.remove_theme_font_size_override("font_size")
	else:
		node.add_theme_font_size_override("font_size", font_size)
