class_name SoloBoonOverlay
extends Control
## 遠征(ソロモード)の恩恵のオーバーレイ(GameDesign.md 27章「画面」)。関門に勝った
## 直後に出す。恩恵の札を3枚横に並べ、押すと得る(見送りは無い)。下に持っている恩恵の
## 名前を並べる。

signal boon_chosen(boon_id: String)

const TITLE_FONT_SIZE := 30
const SUBTITLE_FONT_SIZE := 16
const DIM_COLOR := Color(0, 0, 0, 0.74)
const TITLE_TOP := 70.0
const SUBTITLE_TOP := 118.0
const CARDS_TOP := 150.0
const CARD_SIZE := Vector2(300, 330)
const CARD_GAP := 36.0
const MEDAL_RADIUS := 46.0
const MEDAL_TOP_OFFSET := 36.0
## メダルの内側の円に対する絵の大きさ。
const MEDAL_ICON_RATIO := 1.1
const NAME_FONT_SIZE := 24
const DESC_FONT_SIZE := 15
const OWNED_FONT_SIZE := 14
const OWNED_TOP_MARGIN := 40.0

var _dim: ColorRect
var _title: Label
var _subtitle: Label
var _cards_box: Control
var _owned_label: Label
var _offer: Array[String] = []


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	_dim = ColorRect.new()
	_dim.color = DIM_COLOR
	_dim.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(_dim)
	_title = _label(TITLE_FONT_SIZE, UiPalette.TEXT_OFFWHITE, true)
	add_child(_title)
	_subtitle = _label(SUBTITLE_FONT_SIZE, UiPalette.TEXT_MUTED)
	add_child(_subtitle)
	_cards_box = Control.new()
	_cards_box.mouse_filter = Control.MOUSE_FILTER_PASS
	add_child(_cards_box)
	_owned_label = _label(OWNED_FONT_SIZE, UiPalette.TEXT_MUTED)
	add_child(_owned_label)

	resized.connect(_layout)
	_layout()


## 恩恵の候補を出す。`gate_name`は小見出しの「関門『名前』を越えた」に使う。
func show_data(offer: Array[String], owned: Array[String], gate_name: String = "") -> void:
	_offer = offer
	_title.text = "恩恵を1つ選ぶ"
	_subtitle.text = (
		"関門『%s』を越えた ・ 遠征のあいだずっと効く" % gate_name if not gate_name.is_empty() else "遠征のあいだずっと効く"
	)
	var names: Array[String] = []
	for id in owned:
		var boon := SoloBoonLibrary.find_by_id(id)
		if boon != null:
			names.append(boon.display_name)
	_owned_label.text = "持っている恩恵: %s" % ("、".join(names) if not names.is_empty() else "なし")
	_rebuild_cards()
	_layout()


func _rebuild_cards() -> void:
	for child in _cards_box.get_children():
		_cards_box.remove_child(child)
		child.queue_free()
	var total_w := CARD_SIZE.x * float(_offer.size()) + CARD_GAP * float(maxi(_offer.size() - 1, 0))
	var left := (_cards_box.size.x - total_w) * 0.5
	for i in _offer.size():
		var boon := SoloBoonLibrary.find_by_id(_offer[i])
		if boon == null:
			continue
		_build_card(
			Rect2(left + float(i) * (CARD_SIZE.x + CARD_GAP), 0.0, CARD_SIZE.x, CARD_SIZE.y), boon
		)


func _build_card(rect: Rect2, boon: SoloBoonData) -> void:
	var canvas := Control.new()
	canvas.position = rect.position
	canvas.size = rect.size
	canvas.mouse_filter = Control.MOUSE_FILTER_IGNORE
	canvas.draw.connect(
		func() -> void:
			SoloUiPaint.paint_panel(canvas.get_canvas_item(), Rect2(Vector2.ZERO, rect.size), false)
	)
	_cards_box.add_child(canvas)

	var medal := Control.new()
	medal.position = rect.position + Vector2(rect.size.x * 0.5 - MEDAL_RADIUS, MEDAL_TOP_OFFSET)
	medal.size = Vector2(MEDAL_RADIUS, MEDAL_RADIUS) * 2.0
	medal.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var icon := boon.icon()
	medal.draw.connect(
		func() -> void:
			var center := Vector2(MEDAL_RADIUS, MEDAL_RADIUS)
			var inner := MEDAL_RADIUS - 6.0
			medal.draw_circle(center, MEDAL_RADIUS, UiPalette.BRASS_MID)
			medal.draw_circle(center, inner, UiPalette.NAVY_PANEL_TOP)
			medal.draw_arc(center, inner, 0, TAU, 48, UiPalette.GLOW_AMBER, 2.0)
			if icon != null:
				var side := inner * MEDAL_ICON_RATIO
				var icon_rect := Rect2(center - Vector2.ONE * side * 0.5, Vector2.ONE * side)
				medal.draw_texture_rect(icon, icon_rect, false, UiPalette.GLOW_AMBER)
	)
	_cards_box.add_child(medal)

	var name_label := _label(NAME_FONT_SIZE, UiPalette.TEXT_OFFWHITE)
	name_label.position = rect.position + Vector2(0, MEDAL_TOP_OFFSET + MEDAL_RADIUS * 2.0 + 12.0)
	name_label.size = Vector2(rect.size.x, 30.0)
	name_label.text = boon.display_name
	_cards_box.add_child(name_label)

	var desc_label := _label(DESC_FONT_SIZE, UiPalette.TEXT_MUTED)
	desc_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	desc_label.position = (
		rect.position + Vector2(28.0, MEDAL_TOP_OFFSET + MEDAL_RADIUS * 2.0 + 46.0)
	)
	desc_label.size = Vector2(rect.size.x - 56.0, 80.0)
	desc_label.text = boon.description
	_cards_box.add_child(desc_label)

	var button := SoloUiPaint.transparent_button()
	button.position = rect.position
	button.size = rect.size
	button.pressed.connect(func() -> void: boon_chosen.emit(boon.id))
	_cards_box.add_child(button)


func _layout() -> void:
	if _dim == null:
		return
	_dim.size = size
	_title.position = Vector2(0, TITLE_TOP)
	_title.size = Vector2(size.x, 44.0)
	_subtitle.position = Vector2(0, SUBTITLE_TOP)
	_subtitle.size = Vector2(size.x, 26.0)
	_cards_box.position = Vector2(0, CARDS_TOP)
	_cards_box.size = Vector2(size.x, CARD_SIZE.y)
	_rebuild_cards()
	_owned_label.position = Vector2(0, CARDS_TOP + CARD_SIZE.y + OWNED_TOP_MARGIN)
	_owned_label.size = Vector2(size.x, 24.0)


func _label(font_size: int, color: Color, display := false) -> Label:
	var label := Label.new()
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	if display:
		label.add_theme_font_override("font", UiFonts.display_font(label.get_theme_default_font()))
	return label
