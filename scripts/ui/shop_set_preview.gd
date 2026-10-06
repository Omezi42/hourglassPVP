class_name ShopSetPreview
extends Control
## カードセット1件の中身を見るモーダル(GameDesign.md 21章、Architecture.md 10.8.1)。
##
## デッキ編集・砂時計一覧は未所有のカードをロック/シルエットで隠すため、**それ以外の
## どこかで買う前に確認できる**という前提が成立しない。ここが唯一の確認場所であり、
## 所有しているかどうかに関わらず中身をそのまま見せる。`CardPileViewer` と同じ
## 「暗幕 + `content_panel.tres` の中央パネル + 閉じる」の型を使う。

const SCREEN_SIZE := Vector2(1280, 720)
const PANEL_STYLE := "res://resources/theme/content_panel.tres"
## パネルの内側に収める1枚ぶんの幅。5枚が横一列にちょうど収まる帯にはならないため、
## 横スクロールで残りを読む(墓地ビューアが縦の行数で同じことをしているのと同じ考え方)。
const SCROLL_SIZE := Vector2(1140, 470)
const ROW_GAP := 16.0
## 段階公開でまだ出していない札(GameDesign.md 21章)。公開済みの札と同じ大きさで並べる。
const HIDDEN_FRAME_WIDTH := 1.5
const HIDDEN_MARK_SIZE := 96
const HIDDEN_NAME_SIZE := 18
const HIDDEN_NAME_GAP := 48.0

var _title: Label
var _row: HBoxContainer
var _scroll: ScrollContainer


func _ready() -> void:
	visible = false
	mouse_filter = Control.MOUSE_FILTER_STOP
	# `set_anchors_preset()` は使わない(Architecture.md 4章)。コードで生成した直後の
	# サイズ0のノードへ使うと0のまま固定され、暗幕が盤面を覆わずクリックも止められない。
	size = SCREEN_SIZE
	_build()


## そのセットの全カードを、購入の有無に関わらずそのまま見せる。未公開の枠は「?」の札で示す。
func open_set(set_id: String) -> void:
	_title.text = (
		"%s — 内容(%s)" % [CardSetLibrary.display_name(set_id), CardSetLibrary.count_text(set_id)]
	)
	for child in _row.get_children():
		child.queue_free()
	for card_id in CardSetLibrary.card_ids(set_id):
		var card := CardLibrary.find_by_id(card_id)
		if card == null:
			continue
		var panel := CardDetailPanel.new()
		panel.interactive = false
		_row.add_child(panel)
		panel.show_card(card)
	for i in CardSetLibrary.hidden_count(set_id):
		_row.add_child(_hidden_slot())
	visible = true


func _hidden_slot() -> Control:
	var slot := Control.new()
	slot.custom_minimum_size = CardDetailPanel.PANEL_SIZE
	slot.draw.connect(
		func() -> void:
			var font := slot.get_theme_default_font()
			var rect := Rect2(Vector2.ZERO, slot.size)
			slot.draw_rect(rect, UiPalette.BOARD_TABLE_FILL)
			slot.draw_rect(rect, UiPalette.BRASS_DARK, false, HIDDEN_FRAME_WIDTH)
			var mid := rect.get_center().y
			slot.draw_string(
				font,
				Vector2(0.0, mid + HIDDEN_MARK_SIZE * 0.36),
				"?",
				HORIZONTAL_ALIGNMENT_CENTER,
				rect.size.x,
				HIDDEN_MARK_SIZE,
				ShopItemArt.HIDDEN_MARK_COLOR
			)
			slot.draw_string(
				font,
				Vector2(0.0, mid + HIDDEN_MARK_SIZE * 0.36 + HIDDEN_NAME_GAP),
				ShopItemArt.HIDDEN_NAME,
				HORIZONTAL_ALIGNMENT_CENTER,
				rect.size.x,
				HIDDEN_NAME_SIZE,
				UiPalette.TEXT_MUTED
			)
	)
	return slot


func _build() -> void:
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.65)
	dim.size = SCREEN_SIZE
	dim.mouse_filter = Control.MOUSE_FILTER_STOP
	dim.gui_input.connect(_on_dim_input)
	add_child(dim)

	# 中身の幅で伸び縮みさせつつ画面の中央に置くため、CenterContainer へ入れる。
	var center := CenterContainer.new()
	center.size = SCREEN_SIZE
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(center)

	var panel := PanelContainer.new()
	panel.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	panel.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var style: StyleBox = load(PANEL_STYLE)
	if style != null:
		panel.add_theme_stylebox_override("panel", style)
	center.add_child(panel)

	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 14)
	panel.add_child(column)
	_title = Label.new()
	_title.add_theme_font_size_override("font_size", 22)
	_title.add_theme_color_override("font_color", UiPalette.TEXT_OFFWHITE)
	column.add_child(_title)

	_scroll = ScrollContainer.new()
	_scroll.custom_minimum_size = SCROLL_SIZE
	_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	TouchScroll.enable(_scroll)
	column.add_child(_scroll)
	_row = HBoxContainer.new()
	_row.add_theme_constant_override("separation", int(ROW_GAP))
	_scroll.add_child(_row)

	# VBoxContainer は子を横いっぱいに広げるため、明示的に中央へ縮める。
	var close := CodedButton.make("閉じる", Vector2(160, 48))
	close.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	close.pressed.connect(func() -> void: visible = false)
	column.add_child(close)


func _on_dim_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and (event as InputEventMouseButton).pressed:
		visible = false
