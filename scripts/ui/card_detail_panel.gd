class_name CardDetailPanel
extends PanelContainer
## カード1種の詳細(GameDesign.md 9章)。イラスト・名前・コスト・総量・キーワード・効果。
## 一覧画面と、将来の対局中の参考表示で共用する。

const PANEL_STYLE := "res://resources/theme/content_panel.tres"
const PANEL_SIZE := Vector2(380, 460)
const ICON_SIZE := Vector2(150, 150)

var _icon: TextureRect
var _name: Label
var _stats: Label
var _body: Label


func _ready() -> void:
	custom_minimum_size = PANEL_SIZE
	var style: StyleBox = load(PANEL_STYLE)
	if style != null:
		add_theme_stylebox_override("panel", style)
	_build()
	clear()


func show_card(card: CardData) -> void:
	if card == null:
		clear()
		return
	_icon.texture = card.icon_upright
	_name.text = card.display_name
	_stats.text = "コスト %d  /  総量 %d" % [card.cost, card.total_sand]
	_body.text = _describe(card)


func clear() -> void:
	_icon.texture = null
	_name.text = ""
	_stats.text = ""
	_body.text = "カードを選ぶと内容を表示します。"


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
	column.add_theme_constant_override("separation", 12)
	add_child(column)

	_icon = TextureRect.new()
	_icon.custom_minimum_size = ICON_SIZE
	_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	column.add_child(_icon)

	_name = Label.new()
	_name.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_name.add_theme_font_size_override("font_size", 26)
	column.add_child(_name)

	_stats = Label.new()
	_stats.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_stats.add_theme_color_override("font_color", UiPalette.GLOW_AMBER)
	column.add_child(_stats)

	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	column.add_child(scroll)
	_body = Label.new()
	_body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_body.custom_minimum_size = Vector2(PANEL_SIZE.x - 80, 0)
	scroll.add_child(_body)
