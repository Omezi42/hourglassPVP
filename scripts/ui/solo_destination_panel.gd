class_name SoloDestinationPanel
extends Control
## 遠征(ソロモード)の行き先の詳細(GameDesign.md 27章「画面」)。道の駒を押しても
## 対局を始めず、取り消せない選択の前に相手と特殊ルールを見せる。状態パネルと同じ
## 位置に置き、選択中はこちらを状態パネルの代わりに出す。

signal challenge_pressed
signal back_pressed

const PADDING := 22.0
const HEADING_FONT_SIZE := 20
const FOE_FONT_SIZE := 17
const SUMMARY_FONT_SIZE := 14
const DIFFICULTY_FONT_SIZE := 14
const GATE_NAME_FONT_SIZE := 16
const GATE_DESC_FONT_SIZE := 13
const HP_FONT_SIZE := 22
const BUTTON_SIZE := Vector2(180, 44)
const BACK_BUTTON_SIZE := Vector2(120, 40)
const ICON_COLUMNS := 8
const ICON_GAP := 8.0
const ICON_ROW_GAP := 12.0
const ICON_TOP_GAP := 14.0
## 相手の作戦の絵の数(15種)。自分の山札の写しを使う相手も、この数までを並べる。
const ICON_COUNT := 15

var _panel_canvas: Control
var _heading_label: Label
var _foe_label: Label
var _summary_label: Label
var _difficulty_label: Label
var _icon_grid: Control
var _gate_name_label: Label
var _gate_desc_label: Label
var _gate_note_label: Label
var _hp_label: Label
var _challenge_button: Button
var _back_button: Button
var _dest: Dictionary = {}
var _icon_ids: Array[String] = []


func _ready() -> void:
	_panel_canvas = Control.new()
	_panel_canvas.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_panel_canvas.draw.connect(
		func() -> void:
			SoloUiPaint.paint_panel(
				_panel_canvas.get_canvas_item(), Rect2(Vector2.ZERO, size), false
			)
	)
	add_child(_panel_canvas)

	_heading_label = _make_label(HEADING_FONT_SIZE, UiPalette.BRASS_HIGHLIGHT)
	add_child(_heading_label)
	_foe_label = _make_label(FOE_FONT_SIZE, UiPalette.TEXT_OFFWHITE)
	add_child(_foe_label)
	_summary_label = _make_label(SUMMARY_FONT_SIZE, UiPalette.TEXT_MUTED)
	_summary_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	add_child(_summary_label)
	_difficulty_label = _make_label(DIFFICULTY_FONT_SIZE, UiPalette.TEXT_OFFWHITE)
	add_child(_difficulty_label)
	_icon_grid = Control.new()
	_icon_grid.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_icon_grid)
	_gate_name_label = _make_label(GATE_NAME_FONT_SIZE, UiPalette.BRASS_HIGHLIGHT)
	add_child(_gate_name_label)
	_gate_desc_label = _make_label(GATE_DESC_FONT_SIZE, UiPalette.TEXT_OFFWHITE)
	_gate_desc_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	add_child(_gate_desc_label)
	_gate_note_label = _make_label(GATE_DESC_FONT_SIZE, UiPalette.TEXT_MUTED)
	add_child(_gate_note_label)
	_hp_label = _make_label(HP_FONT_SIZE, UiPalette.TEXT_OFFWHITE)
	add_child(_hp_label)

	_challenge_button = CodedButton.make_in_group(
		"挑む", BUTTON_SIZE, CodedButton.PRIMARY_ACTION_GROUP
	)
	_challenge_button.pressed.connect(func() -> void: challenge_pressed.emit())
	add_child(_challenge_button)
	_back_button = CodedButton.make("戻る", BACK_BUTTON_SIZE)
	_back_button.pressed.connect(func() -> void: back_pressed.emit())
	add_child(_back_button)

	resized.connect(_layout)


## 行き先1つぶんの詳細を出す。`run`は泉の「HP a → b」・工房の見出しに使う。
func show_data(dest: Dictionary, run: SoloRun) -> void:
	_dest = dest
	var floor := run.floor
	var kind: int = int(dest.get("kind", SoloRun.Kind.BATTLE))
	var is_final := floor == SoloRun.FLOOR_COUNT - 1
	var is_expert := floor >= run.expert_from_floor()
	# 最終戦の`gate`には主のidが入る(GameDesign.md 27章「主」)。
	var gate := SoloGateLibrary.find_by_id(str(dest.get("gate", "")))
	var cpu_deck := str(dest.get("cpu_deck", ""))
	var mirror := SoloRun.uses_player_deck(dest)
	_icon_ids = _player_icon_ids(run.deck_ids) if mirror else CardCpuDecks.card_ids_of(cpu_deck)

	if kind == SoloRun.Kind.SPRING:
		_heading_label.text = "%d段目 ・ 泉" % (floor + 1)
		_foe_label.visible = false
		_summary_label.visible = false
		_difficulty_label.visible = false
		_icon_grid.visible = false
		_gate_name_label.visible = false
		_gate_desc_label.visible = false
		_gate_note_label.visible = false
		_hp_label.visible = true
		var healed := mini(run.hp + SoloRun.SPRING_HEAL + run.spring_bonus(), run.max_hp)
		_hp_label.text = "HP %d → %d" % [run.hp, healed]
		_challenge_button.text = "休む"
		_layout()
		return

	if kind == SoloRun.Kind.WORKSHOP:
		_heading_label.text = "%d段目 ・ 工房" % (floor + 1)
		_foe_label.visible = false
		_summary_label.visible = false
		_difficulty_label.visible = false
		_icon_grid.visible = false
		_gate_name_label.visible = false
		_gate_desc_label.visible = false
		_gate_note_label.visible = false
		_hp_label.visible = true
		_hp_label.text = "山札から1枚を抜くか、1枚を複製する"
		_challenge_button.text = "入る"
		_layout()
		return

	var kind_label := "最終戦" if is_final else ("関門" if kind == SoloRun.Kind.GATE else "対局")
	_heading_label.text = "%d段目 ・ %s" % [floor + 1, kind_label]
	_foe_label.visible = true
	_foe_label.text = SoloRun.foe_name_of(dest)
	_summary_label.visible = not mirror
	_summary_label.text = CardCpuDecks.summary_of(cpu_deck)
	_difficulty_label.visible = true
	_difficulty_label.text = "CPUの強さ ・ %s" % ("上級" if is_expert else "中級")
	_icon_grid.visible = true
	_gate_name_label.visible = gate != null
	_gate_desc_label.visible = gate != null
	_gate_note_label.visible = gate != null
	if gate != null:
		_gate_name_label.text = gate.display_name
		_gate_desc_label.text = gate.description
		_gate_note_label.text = "倒せば踏破" if is_final else "勝つと恩恵を1つ"
	_hp_label.visible = false
	_challenge_button.text = "挑む"
	_layout()


## 自分の山札の種類をコスト順に`ICON_COUNT`まで(鏡写し・鏡の主。GameDesign.md 27章「画面」)。
static func _player_icon_ids(deck_ids: Array[String]) -> Array[String]:
	var cards: Array[CardData] = []
	for id in deck_ids:
		var card := CardLibrary.find_by_id(id)
		if card != null and not cards.has(card):
			cards.append(card)
	cards.sort_custom(func(a: CardData, b: CardData) -> bool: return a.cost < b.cost)
	var ids: Array[String] = []
	for card in cards.slice(0, ICON_COUNT):
		ids.append(card.id)
	return ids


func _build_icons(ids: Array[String]) -> void:
	for child in _icon_grid.get_children():
		_icon_grid.remove_child(child)
		child.queue_free()
	var inner_w := _icon_grid.size.x
	if inner_w <= 0.0:
		return
	var icon_w: float = (inner_w - float(ICON_COLUMNS - 1) * ICON_GAP) / float(ICON_COLUMNS)
	var icon_h := icon_w * 1.32
	for i in ids.size():
		var col := i % ICON_COLUMNS
		var row := i / ICON_COLUMNS
		var x := float(col) * (icon_w + ICON_GAP)
		var y := float(row) * (icon_h + ICON_GAP + ICON_ROW_GAP)
		_build_icon(Rect2(x, y, icon_w, icon_h), ids[i])


func _build_icon(rect: Rect2, card_id: String) -> void:
	var card: CardData = CardLibrary.find_by_id(card_id)
	if card == null:
		return
	var texture := HourglassArt.texture(card.art_key(), HourglassArt.State.UPRIGHT)
	var box := Control.new()
	box.position = rect.position
	box.size = rect.size
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.draw.connect(
		func() -> void:
			var ci := box.get_canvas_item()
			var foot := Vector2(rect.size.x * 0.5, rect.size.y)
			UiPaint.fill_ellipse(
				ci, foot, Vector2(rect.size.x * 0.4, rect.size.y * 0.09), Color(0, 0, 0, 0.35), 16
			)
			if texture == null:
				return
			var tex_size := texture.get_size()
			var fit: float = minf(rect.size.x / tex_size.x, rect.size.y / tex_size.y)
			var draw_size := tex_size * fit
			box.draw_texture_rect(
				texture,
				Rect2(
					Vector2((rect.size.x - draw_size.x) * 0.5, rect.size.y - draw_size.y), draw_size
				),
				false
			)
	)
	_icon_grid.add_child(box)


func _layout() -> void:
	if _panel_canvas == null:
		return
	_panel_canvas.size = size
	var top := PADDING
	_heading_label.position = Vector2(PADDING, top)
	_heading_label.size = Vector2(size.x - PADDING * 2.0, 26.0)
	top += 34.0
	var kind: int = int(_dest.get("kind", SoloRun.Kind.BATTLE))
	if kind == SoloRun.Kind.SPRING or kind == SoloRun.Kind.WORKSHOP:
		_hp_label.position = Vector2(PADDING, top + 40.0)
		_hp_label.size = Vector2(size.x - PADDING * 2.0, 32.0)
	else:
		_foe_label.position = Vector2(PADDING, top)
		_foe_label.size = Vector2(size.x - PADDING * 2.0, 24.0)
		top += 28.0
		_summary_label.position = Vector2(PADDING, top)
		_summary_label.size = Vector2(size.x - PADDING * 2.0, 36.0)
		top += 40.0
		_difficulty_label.position = Vector2(PADDING, top)
		_difficulty_label.size = Vector2(size.x - PADDING * 2.0, 22.0)
		top += 22.0 + ICON_TOP_GAP
		var icon_w: float = (
			(size.x - PADDING * 2.0 - float(ICON_COLUMNS - 1) * ICON_GAP) / float(ICON_COLUMNS)
		)
		var icon_h := icon_w * 1.32
		var rows := ceili(float(ICON_COUNT) / float(ICON_COLUMNS))
		var grid_h := icon_h * float(rows) + (ICON_GAP + ICON_ROW_GAP) * float(maxi(rows - 1, 0))
		_icon_grid.position = Vector2(PADDING, top)
		_icon_grid.size = Vector2(size.x - PADDING * 2.0, grid_h)
		_build_icons(_icon_ids)
		top += grid_h + 12.0
		_gate_name_label.position = Vector2(PADDING, top)
		_gate_name_label.size = Vector2(size.x - PADDING * 2.0, 22.0)
		_gate_desc_label.position = Vector2(PADDING, top + 22.0)
		_gate_desc_label.size = Vector2(size.x - PADDING * 2.0, 34.0)
		_gate_note_label.position = Vector2(PADDING, top + 58.0)
		_gate_note_label.size = Vector2(size.x - PADDING * 2.0, 20.0)
	_back_button.position = Vector2(PADDING, size.y - PADDING - BACK_BUTTON_SIZE.y)
	_challenge_button.position = Vector2(
		size.x - PADDING - BUTTON_SIZE.x, size.y - PADDING - BUTTON_SIZE.y
	)


func _make_label(font_size: int, color: Color) -> Label:
	var label := Label.new()
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	return label
