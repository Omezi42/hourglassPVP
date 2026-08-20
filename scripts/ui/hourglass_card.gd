class_name HourglassCard
extends Control

signal card_pressed

const SELECTED_BORDER := Color(1.0, 0.82, 0.36, 1.0)
const SELECTED_BG := Color(0.2, 0.16, 0.1, 0.92)
const SELECTED_BORDER_WIDTH := 3
const SHELF_SHADOW_SELECTED_COLOR := Color(1.0, 0.82, 0.36, 0.55)
## 通常モードでアイコンの下に空ける高さ(名前ラベル34px+余白)。
## Iconは下端アンカー基準のため、カードの表示サイズを変えるとアイコンもそれに追随する。
const ICON_BOTTOM_GAP := 36.0

var data: HourglassData
var selected: bool = false:
	set(value):
		selected = value
		_refresh_selection()
var _draggable: bool = false
var _shelf_mode: bool = false

var _normal_style: StyleBoxFlat
var _selected_style: StyleBoxFlat
var _shelf_shadow_normal_style: StyleBoxFlat
var _shelf_shadow_selected_style: StyleBoxFlat

var _press_tracker := PressTracker.new()
var _hovering := false
var _rest_position := Vector2.ZERO

## ホバー/押下のTween先。コンテナ(CardRow等)の直接の子である自分自身の
## position/scaleを外部から動かすと再レイアウト時に崩れるため、見た目専用の
## VisualRootへ逃がす(HourglassSlot.shake_rejected()と同じ回避パターン)。
@onready var visual_root: Control = $VisualRoot
@onready var frame: Panel = $VisualRoot/Frame
@onready var shelf_shadow: Panel = $VisualRoot/ShelfShadow
@onready var icon: TextureRect = $VisualRoot/Icon
@onready var name_label: Label = $VisualRoot/NameLabel
@onready var damage_badge: Label = $VisualRoot/DamageBadge


func _ready() -> void:
	_normal_style = frame.get_theme_stylebox("panel")
	_selected_style = _normal_style.duplicate()
	_selected_style.bg_color = SELECTED_BG
	_selected_style.border_color = SELECTED_BORDER
	_selected_style.border_width_left = SELECTED_BORDER_WIDTH
	_selected_style.border_width_top = SELECTED_BORDER_WIDTH
	_selected_style.border_width_right = SELECTED_BORDER_WIDTH
	_selected_style.border_width_bottom = SELECTED_BORDER_WIDTH
	_shelf_shadow_normal_style = shelf_shadow.get_theme_stylebox("panel")
	_shelf_shadow_selected_style = _shelf_shadow_normal_style.duplicate()
	_shelf_shadow_selected_style.bg_color = SHELF_SHADOW_SELECTED_COLOR
	_refresh_selection()
	mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	_rest_position = visual_root.position
	resized.connect(_on_resized)
	mouse_entered.connect(_on_mouse_entered)
	mouse_exited.connect(_on_mouse_exited)


func _gui_input(event: InputEvent) -> void:
	match _press_tracker.feed(event, size):
		PressTracker.Result.PRESSED:
			ClickArea.animate_press(visual_root, true)
		PressTracker.Result.CONFIRMED:
			ClickArea.animate_press(visual_root, false)
			card_pressed.emit()
		PressTracker.Result.CANCELED:
			ClickArea.animate_press(visual_root, false)


func _get_drag_data(_at_position: Vector2) -> Variant:
	if data == null:
		return null
	# ドラッグが始まったら、押しっぱなしのまま宙に浮く見た目にならないよう押下状態を解除する
	if _press_tracker.cancel():
		ClickArea.animate_press(visual_root, false)
	_hovering = false
	ClickArea.animate_hover(visual_root, false, _rest_position)
	# J-14: expand_modeを指定しないとTextureRectの既定(EXPAND_KEEP_SIZE)により
	# custom_minimum_sizeを無視してテクスチャの原寸で描画されてしまい、
	# 下部のカード一覧より大幅に大きいプレビューになっていた。IGNORE_SIZEで
	# 実際のアイコン表示サイズ(icon.size)に固定する。
	var preview: TextureRect = TextureRect.new()
	preview.texture = icon.texture
	preview.custom_minimum_size = icon.size
	preview.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	preview.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	set_drag_preview(preview)
	return {"hourglass_id": data.id}


func _on_resized() -> void:
	visual_root.pivot_offset = visual_root.size / 2.0
	if not _hovering:
		_rest_position = visual_root.position


func _on_mouse_entered() -> void:
	_hovering = true
	ClickArea.animate_hover(visual_root, true, _rest_position)


func _on_mouse_exited() -> void:
	_hovering = false
	ClickArea.animate_hover(visual_root, false, _rest_position)


func show_data(hourglass_data: HourglassData) -> void:
	data = hourglass_data
	icon.texture = hourglass_data.icon_upright
	name_label.text = hourglass_data.display_name
	damage_badge.text = str(hourglass_data.fall_damage)


func _refresh_selection() -> void:
	if _normal_style == null:
		return
	frame.add_theme_stylebox_override("panel", _selected_style if selected else _normal_style)
	shelf_shadow.add_theme_stylebox_override(
		"panel", _shelf_shadow_selected_style if selected else _shelf_shadow_normal_style
	)


## ドラッグでデッキ枠へ配置できる画面(DeckEditorScreenのCardRow)でのみtrueにする。
## ドラッグ不可の画面(砂時計一覧・デッキ選択の手札)では通常のクリック用カーソルのままにする。
func set_draggable(draggable: bool) -> void:
	_draggable = draggable
	mouse_default_cursor_shape = Control.CURSOR_DRAG if draggable else Control.CURSOR_POINTING_HAND


## 棚UI用のモード。丸角背景と名前ラベルを消し、アイコンの下に台座の影だけを残す。
## 名前は呼び出し側(棚の金属プレート)で表示する想定のため、ここでは扱わない。
func set_shelf_mode(enabled: bool) -> void:
	_shelf_mode = enabled
	frame.visible = not enabled
	name_label.visible = not enabled
	shelf_shadow.visible = enabled
	# 名前ラベルを消す棚モードでは、その分アイコンをカード下端まで広げる。
	icon.offset_bottom = 0.0 if enabled else -ICON_BOTTOM_GAP
