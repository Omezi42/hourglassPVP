class_name PackCardSlot
extends Control
## 開封の札1枚(GameDesign.md 21章「開封」)。めくる前はカードの裏(縁の光でレアリティ)を描き、
## めくった後は `CardView` の表と、その下の札(「はじめて」「所持 n / 上限」「砂粒 +n」)を出す。
## 動き(配る・めくる・浮く)は `PackOpeningOverlay` が `position` / `scale` / 各値を動かす。

signal pressed(slot: PackCardSlot)

const CARD_SIZE := Vector2(177, 237)
const CAPTION_GAP := 28.0
const CAPTION_HEIGHT := 30.0
const CAPTION_WIDTH := 104.0
const CAPTION_FONT := UiPalette.T_SMALL
const NOTE_GAP := 22.0
const FADED_ALPHA := 0.32
const HOVER_LIFT := 6.0

var card: CardData
var rarity: CardEnums.Rarity = CardEnums.Rarity.COMMON
## めくり終えたか。
var revealed := false
## 裏の縁の光(0〜1)。配った直後に灯る。
var lit := 0.0:
	set(value):
		lit = value
		queue_redraw()
## 裏の紋章の砂時計の回転(めくる直前に返る)。
var turn := 0.0:
	set(value):
		turn = value
		queue_redraw()
## めくった後の下の札。空なら出さない。
var caption := ""
## 上限を超えたぶん(砂粒へ崩れた)。札を薄く残して「上限を超えたぶん」を添える。
var overflow := false
## 下の札を出すか(崩れる演出の途中は出さない)。
var show_caption := false:
	set(value):
		show_caption = value
		queue_redraw()

var _view: CardView
var _font: Font
var _hovering := false


func _init(p_card: CardData) -> void:
	card = p_card
	rarity = p_card.rarity
	size = CARD_SIZE + Vector2(0, CAPTION_GAP + CAPTION_HEIGHT + NOTE_GAP)
	pivot_offset = CARD_SIZE * 0.5


func _ready() -> void:
	_font = get_theme_default_font()
	mouse_filter = Control.MOUSE_FILTER_STOP
	mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	_view = CardView.new()
	_view.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_view)
	_view.show_card(card, true)
	_view.custom_minimum_size = CARD_SIZE
	_view.size = CARD_SIZE
	_view.visible = false
	mouse_entered.connect(func() -> void: _set_hover(true))
	mouse_exited.connect(func() -> void: _set_hover(false))


func _gui_input(event: InputEvent) -> void:
	var button := event as InputEventMouseButton
	if button != null and button.pressed and button.button_index == MOUSE_BUTTON_LEFT:
		accept_event()
		pressed.emit(self)


## 裏から表へ差し替える(`scale.x` が0を通る瞬間に呼ぶ)。
func show_face() -> void:
	revealed = true
	_view.visible = true
	mouse_default_cursor_shape = Control.CURSOR_ARROW
	queue_redraw()


## 上限を超えたぶんとして薄く残す。
func fade_face() -> void:
	_view.modulate.a = FADED_ALPHA


## 札の中心(親の座標)。演出の起点に使う。
func card_center() -> Vector2:
	return position + CARD_SIZE * 0.5


func _set_hover(on: bool) -> void:
	_hovering = on and not revealed
	queue_redraw()


func _draw() -> void:
	var ci := get_canvas_item()
	if not revealed:
		var rect := Rect2(Vector2(0, -HOVER_LIFT if _hovering else 0.0), CARD_SIZE)
		RarityPaint.card_back(ci, rect, rarity, lit, turn)
		return
	if not show_caption or caption.is_empty() or _font == null:
		return
	var tag := Rect2(
		Vector2((CARD_SIZE.x - CAPTION_WIDTH) * 0.5, CARD_SIZE.y + CAPTION_GAP),
		Vector2(CAPTION_WIDTH, CAPTION_HEIGHT)
	)
	if overflow or caption == PackOpeningOverlay.FIRST_TEXT:
		UiKit.tag(ci, _font, tag, caption, CAPTION_FONT)
	else:
		UiKit.text_in(ci, _font, caption, tag, CAPTION_FONT, UiPalette.IVORY)
	if overflow:
		UiKit.text_in(
			ci,
			_font,
			PackOpeningOverlay.OVERFLOW_NOTE,
			Rect2(tag.position.x - CAPTION_WIDTH, tag.end.y, CAPTION_WIDTH * 3.0, NOTE_GAP),
			UiPalette.T_MICRO,
			UiPalette.MUTED
		)
