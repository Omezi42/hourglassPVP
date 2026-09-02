class_name CardDetailPanel
extends PanelContainer
## カード1種の詳細(GameDesign.md 9章)。イラスト・名前・コスト・総量・キーワード・効果に
## 加えて、能力が実際にどう働くかの実演(`CardEffectPreview`)を出す。
## 一覧画面と、デッキ編集・将来の対局中の参考表示で共用する。
##
## **デッキ編集では `compact` を立てて使う**。カードの一覧に重ならない場所へ浮かせるため
## 幅を右カラムぶんに絞り、大きなイラストを捨てて実演と効果文を縦に積む。イラストは
## 同じ画面の一覧で既に見えており、ここで繰り返す価値が低い。
##
## **効果欄の語が押せるのは `interactive` のときだけ**で、これを立てるのは砂時計一覧だけ
## (GameDesign.md 17章)。押すと `keyword_pressed` を出し、画面側が `KeywordPopup` を開く。
## ポップ自体をここで持たないのは、パネルが画面の上の小さなノードとして置かれ、
## そこへ全画面の暗幕を持たせられないため。
##
## **デッキ編集と対局画面は `interactive = false` で使う。**どちらもホバーで出して外れたら
## 消えるため、**パネルの中に押しに行く先があると、そこへカーソルを動かした時点で消える**
## (GameDesign.md 9章)。語のボタンを文へ落とし、実演(`CardEffectPreview`)も作らない。

signal keyword_pressed(entry: Dictionary)

const PANEL_STYLE := "res://resources/theme/content_panel.tres"
const PANEL_SIZE := Vector2(380, 460)
const COMPACT_SIZE := Vector2(400, 392)
const ICON_SIZE := Vector2(84, 84)
## カード固有の紋章(GameDesign.md 9章)。名前の左へ置き、カードの面より大きく見せる。
const EMBLEM_SIZE := Vector2(44, 44)
## 語のボタンが下端で切れないよう、縦の詰めた実演にしてある。
## 大きく見たいときは語を押してキーワード辞書のポップで見られる(GameDesign.md 17章)。
const PREVIEW_HEIGHT := 150.0
## 縦積みのときに効果文へ割く幅。
const COMPACT_TEXT_WIDTH := 344.0
## 効果欄の語のボタン。「2回攻撃」の4文字が収まる幅にしてある。
const TERM_BUTTON_SIZE := Vector2(98, 34)
const TERM_FONT_SIZE := 15

## 横並びの詰めた表示にするか。`add_child()` より前に設定する。
var compact := false
## 語のボタンと実演を出すか。**砂時計一覧だけが true**(GameDesign.md 17章)。
## `add_child()` より前に設定する。
var interactive := true

var _icon: TextureRect
var _emblem: TextureRect
var _name: Label
var _stats: Label
var _body: VBoxContainer
var _body_width := 0.0
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
		# 砂術は砂時計の絵を持たない。紋章だけで見せる(GameDesign.md 9章)。
		_icon.texture = null if card.is_spell else card.icon_upright
	_emblem.texture = card.emblem
	_name.text = card.display_name
	# 砂術は総量を持たない(GameDesign.md 6章)。
	if card.is_spell:
		_stats.text = "コスト %d  /  砂術" % card.cost
	else:
		_stats.text = "コスト %d  /  総量 %d" % [card.cost, card.total_sand]
	_fill_body(card)
	if _preview != null:
		_preview.show_card(card)


func clear() -> void:
	if _icon != null:
		_icon.texture = null
	_emblem.texture = null
	_name.text = ""
	_stats.text = ""
	_clear_body()
	_body.add_child(_make_line("カードを選ぶと内容を表示します。"))
	if _preview != null:
		_preview.clear()


## **語として見せるキーワードは語のボタンと説明を並べる**(語だけでは初見に伝わらない)。
## 語にしない能力は、カードの面と同じ短い言い換え(「破壊」など)をボタンに出す。
## 盤面に出ていない語をここだけで見せると、呼び名が食い違うため(GameDesign.md 6章)。
func _fill_body(card: CardData) -> void:
	_clear_body()
	# 砂術は盤面へ出ないため、砂の進み方の説明を出さない(GameDesign.md 6章)。
	# 代わりに、盤面の枠を使わないことをその場で読めるようにする。
	if card.is_spell:
		_body.add_child(_make_line("砂術。盤面へ出ず、使うとすぐ効果が起きる"))
		_body.add_child(_make_line("盤面の枠を使わないため、6枠が埋まっていても使える"))
		if not card.rules_text.is_empty():
			_body.add_child(_make_line(card.rules_text))
		for line in _token_lines(card):
			_body.add_child(_make_line(line))
		return
	_body.add_child(_make_line("場に出たとき  体力 %d / 攻撃力 0" % card.total_sand))
	_body.add_child(_make_line("毎ターン終了時に砂が1粒落ちて 体力-1 / 攻撃力+1"))
	for keyword in card.named_keywords():
		_body.add_child(_make_term_row(KeywordEntries.keyword_entry(keyword)))
	for keyword in card.plain_keywords():
		_body.add_child(_make_term_row(KeywordEntries.keyword_entry(keyword)))
	var triggers := _triggers_of(card)
	for i in triggers.size():
		var text: String = card.rules_text if i == 0 else ""
		_body.add_child(_make_term_row(KeywordEntries.trigger_entry(triggers[i]), text))
	if triggers.is_empty() and not card.rules_text.is_empty():
		_body.add_child(_make_line(card.rules_text))
	if card.keywords.is_empty() and card.rules_text.is_empty():
		_body.add_child(_make_line("効果を持たない基準のカード。"))
	for line in _token_lines(card):
		_body.add_child(_make_line(line))


## 効果で出る砂時計(トークン)の中身を1行で添える(GameDesign.md 6章)。
## トークンはデッキにも一覧にも出ないため、**それを出すカードの側で説明しないと
## 何が場に出るのかを調べる手段が無い**。
static func _token_lines(card: CardData) -> Array[String]:
	var lines: Array[String] = []
	var seen: Array[String] = []
	for effect in card.effects:
		if effect == null or effect.effect_type != CardEnums.EffectType.SUMMON:
			continue
		if seen.has(effect.card_id):
			continue
		seen.append(effect.card_id)
		var token := CardLibrary.find_by_id(effect.card_id)
		if token == null:
			continue
		lines.append(
			(
				"※ %s … 総量 %d の砂時計(%s)。効果で場に出るトークンで、デッキには入れられない。"
				% [token.display_name, token.total_sand, token.describe()]
			)
		)
	return lines


static func _triggers_of(card: CardData) -> Array[int]:
	var found: Array[int] = []
	for effect in card.effects:
		if effect != null and not found.has(effect.trigger):
			found.append(effect.trigger)
	return found


func _clear_body() -> void:
	for child in _body.get_children():
		_body.remove_child(child)
		child.queue_free()


func _make_line(text: String) -> Label:
	var label := Label.new()
	label.text = text
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.custom_minimum_size = Vector2(_body_width, 0)
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	label.add_theme_font_size_override("font_size", 15)
	return label


## 語のボタンと、その説明を横に並べた1行。`override_text` が空でなければ説明の代わりに使う
## (トリガーの行では、カード固有の効果文をそのまま読ませたいため)。
## `interactive` でないときはボタンを持たず、「【語】 説明」の1行の文にする。
func _make_term_row(entry: Dictionary, override_text: String = "") -> Control:
	var body: String = (
		override_text if not override_text.is_empty() else (KeywordEntries.description(entry))
	)
	if not interactive:
		return _make_line("【%s】 %s" % [KeywordEntries.title(entry), _strip_term(body, entry)])

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)

	var button := CodedButton.make(KeywordEntries.title(entry), TERM_BUTTON_SIZE)
	button.add_theme_font_size_override("font_size", TERM_FONT_SIZE)
	button.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	button.pressed.connect(func() -> void: keyword_pressed.emit(entry))
	row.add_child(button)

	var label := _make_line(body)
	label.custom_minimum_size = Vector2(maxf(_body_width - TERM_BUTTON_SIZE.x - 8.0, 80.0), 0)
	row.add_child(label)
	return row


## 効果の文は「余砂:モートを1体出す」のように語を頭に持つ。【】で括って前へ出す以上、
## 文の側の語は取り除く(そのままだと「【余砂】 余砂:…」と2度読ませることになる)。
static func _strip_term(text: String, entry: Dictionary) -> String:
	var title: String = KeywordEntries.title(entry)
	if not text.begins_with(title):
		return text
	var rest := text.substr(title.length())
	while not rest.is_empty() and (rest[0] == ":" or rest[0] == "：" or rest[0] == " "):
		rest = rest.substr(1)
	return text if rest.is_empty() else rest


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

	if interactive:
		_preview = CardEffectPreview.new()
		_preview.custom_minimum_size = Vector2(0, PREVIEW_HEIGHT)
		column.add_child(_preview)

	column.add_child(_make_body_scroll(PANEL_SIZE.x - 80))


## 縦積み:上に名前とコスト、その下に実演、いちばん下に効果文。
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

	if interactive:
		_preview = CardEffectPreview.new()
		_preview.custom_minimum_size = Vector2(COMPACT_TEXT_WIDTH, PREVIEW_HEIGHT)
		_preview.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		column.add_child(_preview)

	column.add_child(_make_body_scroll(COMPACT_TEXT_WIDTH))


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
	_body_width = text_width
	_body = VBoxContainer.new()
	_body.add_theme_constant_override("separation", 10)
	_body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_body.custom_minimum_size = Vector2(text_width, 0)
	scroll.add_child(_body)
	return scroll
