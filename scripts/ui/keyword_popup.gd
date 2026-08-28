class_name KeywordPopup
extends Control
## 砂時計の詳細に出ている語を押したときに重ねる、1語ぶんのポップ
## (GameDesign.md 17章)。`SettingsPanel` / `ConfirmModal` と同じ
## 「暗幕 + コンテンツパネル」のパターンで組む。
##
## **ここから辞書の全一覧へ移る導線は置かない。**対局中にも開くため、
## 画面を離れさせないことを優先する。

const PANEL_STYLE := "res://resources/theme/content_panel.tres"
const PANEL_SIZE := Vector2(600, 520)
const MARGIN := 20
const CLOSE_BUTTON_SIZE := Vector2(160, 52)

var _entry_view: KeywordEntryView


func _ready() -> void:
	# `set_anchors_preset()` は「今の矩形を保つように」offset を計算し直すため、
	# コードで生成した直後(サイズ0)のノードへ使うと0サイズのまま固定される。
	anchor_right = 1.0
	anchor_bottom = 1.0
	visible = false
	_build()


func open(entry: Dictionary) -> void:
	_entry_view.show_entry(entry)
	visible = true


func close() -> void:
	visible = false


func _build() -> void:
	var dim := ColorRect.new()
	dim.anchor_right = 1.0
	dim.anchor_bottom = 1.0
	dim.color = Color(0.02, 0.02, 0.03, 0.7)
	dim.mouse_filter = Control.MOUSE_FILTER_STOP
	dim.gui_input.connect(_on_dim_input)
	add_child(dim)

	var center := CenterContainer.new()
	center.anchor_right = 1.0
	center.anchor_bottom = 1.0
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(center)

	var panel := PanelContainer.new()
	panel.custom_minimum_size = PANEL_SIZE
	var style: StyleBox = load(PANEL_STYLE)
	if style != null:
		panel.add_theme_stylebox_override("panel", style)
	center.add_child(panel)

	var margin := MarginContainer.new()
	for side in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, MARGIN)
	panel.add_child(margin)

	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 12)
	margin.add_child(column)

	_entry_view = KeywordEntryView.new()
	_entry_view.size_flags_vertical = Control.SIZE_EXPAND_FILL
	column.add_child(_entry_view)

	var close_button := CodedButton.make("閉じる", CLOSE_BUTTON_SIZE)
	close_button.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	close_button.pressed.connect(close)
	column.add_child(close_button)


func _on_dim_input(event: InputEvent) -> void:
	var click := event as InputEventMouseButton
	if click != null and click.pressed and click.button_index == MOUSE_BUTTON_LEFT:
		close()
