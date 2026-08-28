class_name CardDetailPanel
extends PanelContainer
## カード1種の詳細(GameDesign.md 9章)。イラスト・名前・コスト・総量・キーワード・効果に
## 加えて、能力が実際にどう働くかの実演(`CardEffectPreview`)を出す。
## 一覧画面と、デッキ編集・将来の対局中の参考表示で共用する。
##
## **デッキ編集では `compact` を立てて使う**。右カラムの上半分しか使えないため、
## 大きなイラストを捨てて実演と効果文を横に並べる。イラストは同じ画面の下部にある
## カード一覧で既に見えており、ここで繰り返す価値が低い。

const PANEL_STYLE := "res://resources/theme/content_panel.tres"
const PANEL_SIZE := Vector2(380, 460)
const COMPACT_SIZE := Vector2(588, 262)
const ICON_SIZE := Vector2(104, 104)
## カード固有の紋章(GameDesign.md 9章)。名前の左へ置き、カードの面より大きく見せる。
const EMBLEM_SIZE := Vector2(44, 44)
const PREVIEW_HEIGHT := 214.0
## 横並びのときに効果文へ割く幅。
const COMPACT_TEXT_WIDTH := 236.0

## 横並びの詰めた表示にするか。`add_child()` より前に設定する。
var compact := false

var _icon: TextureRect
var _emblem: TextureRect
var _name: Label
var _stats: Label
var _body: Label
var _preview: CardEffectPreview


func _ready() -> void:
	custom_minimum_size = COMPACT_SIZE if compact else PANEL_SIZE
	var style: StyleBox = load(PANEL_STYLE)
	if style != null:
		add_theme_stylebox_override("panel", style)
	if compact:
		_build_compact()
	else:
		_build()
	clear()


func show_card(card: CardData) -> void:
	if card == null:
		clear()
		return
	if _icon != null:
		_icon.texture = card.icon_upright
	_emblem.texture = card.emblem
	_name.text = card.display_name
	_stats.text = "コスト %d  /  総量 %d" % [card.cost, card.total_sand]
	_body.text = _describe(card)
	_preview.show_card(card)


func clear() -> void:
	if _icon != null:
		_icon.texture = null
	_emblem.texture = null
	_name.text = ""
	_stats.text = ""
	_body.text = "カードを選ぶと内容を表示します。"
	_preview.clear()


## **語として見せるキーワードは【語】と説明の両方**を出す(語だけでは初見に伝わらない)。
## 語にしない能力は、語を出さずに効果の文だけを書く。
func _describe(card: CardData) -> String:
	var lines: PackedStringArray = []
	lines.append("場に出たとき  体力 %d / 攻撃力 0" % card.total_sand)
	lines.append("毎ターン終了時に砂が1粒落ちて 体力-1 / 攻撃力+1")
	for keyword in card.named_keywords():
		lines.append("")
		lines.append(
			"【%s】%s" % [CardEnums.keyword_name(keyword), CardEnums.keyword_description(keyword)]
		)
	# 語にしない能力は、語を出さずに効果の文だけを書く(GameDesign.md 6章)。
	for keyword in card.plain_keywords():
		lines.append("")
		lines.append(CardEnums.keyword_description(keyword))
	if not card.rules_text.is_empty():
		lines.append("")
		lines.append(card.rules_text)
	if card.keywords.is_empty() and card.rules_text.is_empty():
		lines.append("")
		lines.append("効果を持たない基準のカード。")
	return "\n".join(lines)


func _build() -> void:
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 10)
	add_child(column)

	_icon = TextureRect.new()
	_icon.custom_minimum_size = ICON_SIZE
	_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	column.add_child(_icon)

	column.add_child(_make_title_row(true))
	_stats = _make_stats()
	_stats.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	column.add_child(_stats)

	_preview = CardEffectPreview.new()
	_preview.custom_minimum_size = Vector2(0, PREVIEW_HEIGHT)
	column.add_child(_preview)

	column.add_child(_make_body_scroll(PANEL_SIZE.x - 80))


## 横並び:上に名前とコスト、下に「実演 | 効果文」。
func _build_compact() -> void:
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 8)
	add_child(column)

	var header := HBoxContainer.new()
	header.add_theme_constant_override("separation", 12)
	column.add_child(header)
	header.add_child(_make_title_row(false))
	_stats = _make_stats()
	_stats.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_stats.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	header.add_child(_stats)

	var row := HBoxContainer.new()
	row.size_flags_vertical = Control.SIZE_EXPAND_FILL
	row.add_theme_constant_override("separation", 12)
	column.add_child(row)

	_preview = CardEffectPreview.new()
	_preview.custom_minimum_size = Vector2(260, 0)
	_preview.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_preview.size_flags_vertical = Control.SIZE_EXPAND_FILL
	row.add_child(_preview)

	var scroll := _make_body_scroll(COMPACT_TEXT_WIDTH - 12.0)
	scroll.custom_minimum_size = Vector2(COMPACT_TEXT_WIDTH, 0)
	row.add_child(scroll)


func _make_title_row(centered: bool) -> HBoxContainer:
	var title_row := HBoxContainer.new()
	if centered:
		title_row.alignment = BoxContainer.ALIGNMENT_CENTER
	title_row.add_theme_constant_override("separation", 10)

	_emblem = TextureRect.new()
	_emblem.custom_minimum_size = EMBLEM_SIZE
	_emblem.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_emblem.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_emblem.modulate = UiPalette.BRASS_HIGHLIGHT
	title_row.add_child(_emblem)

	_name = Label.new()
	_name.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_name.add_theme_font_size_override("font_size", 26)
	title_row.add_child(_name)
	return title_row


func _make_stats() -> Label:
	var stats := Label.new()
	stats.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	stats.add_theme_color_override("font_color", UiPalette.GLOW_AMBER)
	return stats


func _make_body_scroll(text_width: float) -> ScrollContainer:
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_body = Label.new()
	_body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_body.custom_minimum_size = Vector2(text_width, 0)
	_body.add_theme_font_size_override("font_size", 15)
	scroll.add_child(_body)
	return scroll
