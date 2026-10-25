class_name CardStatsScreen
extends Control
## 戦績(GameDesign.md 19章)。左に対局種別ごとの通算、右にカード別の勝率を並べる。
## 共通のレイアウト規約(GameDesign.md 9章)に従い、`ScreenHeader` を使う。

signal back_pressed

## いま保存していない構築(消したデッキ・受け取ったデッキなど)の見出し。
const UNKNOWN_DECK_NAME := "いま保存していない構築"
const HEADER_SCENE := "res://scenes/screen_header.tscn"
const PANEL_STYLE := "res://resources/theme/content_panel.tres"
const SUMMARY_RECT := Rect2(24, ScreenHeader.CONTENT_TOP, 560, 540)
const CARDS_RECT := Rect2(608, ScreenHeader.CONTENT_TOP, 648, 540)
## カード別は上位だけを出す。全21種を並べると、対局数の少ないカードの
## 見かけ上の高勝率が上に来て読み違えるため、採用数の多い順に絞る。
const CARD_ROWS := 12
## 数値の列。**戦績は数字を見比べる画面**であり、1本の文へ流し込むと桁の位置が
## 行ごとにずれて読み比べられない。列の幅をここで決め、行はこの表に従って組む。
## 幅は、左の欄(内寸512px)で「ランダムマッチ」(過去の対局の種別)まで省略されずに収まる値にしてある。
const COL_COUNT := 68.0
const COL_WINS := 68.0
const COL_RATE := 94.0
const COL_TURNS := 92.0
const ROW_FONT_SIZE := 18
## 縦画面(GameDesign.md 9章「縦画面」)。2つの欄を上下に積んで1本のスクロールにし、文字を目安まで大きくする。
## 数値の列は文字ほどには広げない(見出しの列の幅を残すため)。
const PORTRAIT_TEXT_SCALE := 24.0 / ROW_FONT_SIZE
const PORTRAIT_COLUMN_SCALE := 1.25
const PORTRAIT_PANEL_GAP := 16

## 記録が無いときに、2つの欄へ重ねて中央へ出す案内。
var _empty: EmptyState

var _summary: VBoxContainer
var _cards: VBoxContainer
var _header: ScreenHeader
var _summary_panel: PanelContainer
var _cards_panel: PanelContainer
## 縦で2つの欄を積む箱。横では使わない。
var _stack_scroll: ScrollContainer
var _stack: VBoxContainer
var _portrait := false


func _ready() -> void:
	_build()


func open() -> void:
	_refresh()


func _uid() -> String:
	if NetSession.client == null or NetSession.client.auth == null:
		return ""
	return NetSession.client.auth.uid


func _refresh() -> void:
	for child in _summary.get_children():
		child.queue_free()
	for child in _cards.get_children():
		child.queue_free()
	_empty.hide_message()
	_refresh_own()


func _refresh_own() -> void:
	var uid := _uid()
	var all := MatchStats.totals(uid)
	if int(all["games"]) == 0:
		_empty.show_message("まだ対局の記録がありません", "対局を1局終えると、ここへ通算が積まれます")
		return
	_summary.add_child(_make_line("通算", 26))
	_summary.add_child(_make_row("すべて", _summary_cells(all)))
	for kind in [
		CurrencyRules.MatchKind.RANKED,
		CurrencyRules.MatchKind.RANDOM,
		CurrencyRules.MatchKind.ROOM,
		CurrencyRules.MatchKind.CPU,
	]:
		var totals := MatchStats.totals(uid, kind)
		if int(totals["games"]) == 0:
			continue
		_summary.add_child(_make_row(_kind_name(kind), _summary_cells(totals)))

	var decks := MatchStats.decks(uid)
	if not decks.is_empty():
		_summary.add_child(_make_line("", 12))
		_summary.add_child(_make_line("デッキ別", 26))
		var names := _deck_names()
		for i in mini(decks.size(), 3):
			var row: Dictionary = decks[i]
			var label: String = names.get(row["code"], UNKNOWN_DECK_NAME)
			_summary.add_child(
				_make_row(label, [_cell("%d戦" % row["games"], COL_COUNT), _rate_cell(row)])
			)

	_cards.add_child(_make_line("カード別(そのカードを入れて戦った勝率)", 22))
	var rows := MatchStats.cards(uid)
	for i in mini(rows.size(), CARD_ROWS):
		var row: Dictionary = rows[i]
		var card := CardLibrary.find_by_id(row["id"])
		var name: String = card.display_name if card != null else row["id"]
		_cards.add_child(_make_row(name, [_cell("%d戦" % row["games"], COL_COUNT), _rate_cell(row)]))
	ListRevealFx.stagger(_summary.get_children())
	ListRevealFx.stagger(_cards.get_children())


func _summary_cells(totals: Dictionary) -> Array:
	var games: int = int(totals["games"])
	var wins: int = int(totals["wins"])
	return [
		_cell("%d戦" % games, COL_COUNT),
		_cell("%d勝" % wins, COL_WINS),
		_cell("%.1f%%" % [100.0 * float(wins) / float(maxi(games, 1))], COL_RATE),
		_cell("%.1f手" % [float(totals["turns"]) / float(maxi(games, 1))], COL_TURNS),
	]


func _rate_cell(row: Dictionary) -> Dictionary:
	var games: int = int(row["games"])
	return _cell("%.1f%%" % [100.0 * float(int(row["wins"])) / float(maxi(games, 1))], COL_RATE)


## 指紋 → デッキ名の対応。**指紋は構築を見分けるための内部の識別子であり、
## そのまま画面へ出すとプレイヤーには読めない文字列が並ぶ**(以前は
## 「HG1-SwB4nEtJLM…」と出ていた)。いま保存しているデッキとプリセットから引き直す。
func _deck_names() -> Dictionary:
	var names := {}
	for preset: Dictionary in CardPresetDecks.PRESETS:
		var cards := CardPresetDecks.deck_of(str(preset["id"]))
		if not cards.is_empty():
			names[CardDeckCode.fingerprint(cards)] = "%s(プリセット)" % preset["name"]
	# 保存したデッキを後から入れる。プリセットをそのまま保存した場合は、
	# プレイヤーが付けた名前のほうを出す。
	for entry: Dictionary in CardDeckSave.list_decks():
		names[CardDeckCode.fingerprint(entry["cards"])] = str(entry["name"])
	return names


func _kind_name(kind: int) -> String:
	match kind:
		CurrencyRules.MatchKind.RANKED:
			return "ランクマッチ"
		CurrencyRules.MatchKind.RANDOM:
			return "ランダムマッチ"
		CurrencyRules.MatchKind.ROOM:
			return "ルームマッチ"
		CurrencyRules.MatchKind.CPU:
			return "CPU戦"
	return ""


## 1行を「見出し(伸びる) + 右揃えの数値の列」として組む。
## `values` は [{"text":, "width":}] の並び。
func _make_row(label: String, values: Array, font_size := ROW_FONT_SIZE) -> HBoxContainer:
	var column_scale := PORTRAIT_COLUMN_SCALE if _portrait else 1.0
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	var name_label := _make_line(label, font_size)
	name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	name_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	row.add_child(name_label)
	for cell: Dictionary in values:
		var value := _make_line(str(cell["text"]), font_size)
		value.custom_minimum_size.x = float(cell["width"]) * column_scale
		value.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		row.add_child(value)
	return row


## 「n戦」「勝率n%」のように、単位まで含めて1つの列へ収める。
static func _cell(text: String, width: float) -> Dictionary:
	return {"text": text, "width": width}


func _make_line(text: String, font_size: int) -> Label:
	var label := Label.new()
	label.text = text
	var text_scale := PORTRAIT_TEXT_SCALE if _portrait else 1.0
	label.add_theme_font_size_override("font_size", roundi(font_size * text_scale))
	label.add_theme_color_override("font_color", UiPalette.TEXT_OFFWHITE)
	return label


func _build() -> void:
	var backdrop := ScreenBackdrop.new()
	backdrop.room = ScreenBackdrop.Room.VAULT
	add_child(backdrop)
	var header: ScreenHeader = load(HEADER_SCENE).instantiate()
	add_child(header)
	_header = header
	header.set_title("戦績")
	header.back_pressed.connect(func() -> void: back_pressed.emit())
	_stack_scroll = ScrollContainer.new()
	_stack_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_stack_scroll.visible = false
	TouchScroll.enable(_stack_scroll)
	add_child(_stack_scroll)
	_stack = VBoxContainer.new()
	_stack.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_stack.add_theme_constant_override("separation", PORTRAIT_PANEL_GAP)
	_stack_scroll.add_child(_stack)
	_summary = _make_panel(SUMMARY_RECT)
	_summary_panel = _summary.get_parent()
	_cards = _make_panel(CARDS_RECT)
	_cards_panel = _cards.get_parent()
	# 記録が無いときは、2つのパネルにまたがる中央へ1つだけ出す。
	# 左の欄の左上へ1行だけ置くと、右の欄が空のまま残って画面が壊れて見える。
	_empty = EmptyState.new()
	_empty.position = SUMMARY_RECT.position
	_empty.size = Vector2(CARDS_RECT.end.x - SUMMARY_RECT.position.x, SUMMARY_RECT.size.y)
	_empty.visible = false
	add_child(_empty)


## 縦横が変わったときに `Main` から呼ばれる(Architecture.md 4.7節)。
## 縦では2つの欄を1本のスクロールへ移して積む(GameDesign.md 9章「縦画面」)。
func apply_orientation(portrait: bool) -> void:
	_portrait = portrait
	if _header == null:
		return
	_header.apply_orientation(portrait)
	_stack_scroll.visible = portrait
	for panel: PanelContainer in [_summary_panel, _cards_panel]:
		panel.get_parent().remove_child(panel)
		if portrait:
			panel.custom_minimum_size = Vector2.ZERO
			_stack.add_child(panel)
		else:
			add_child(panel)
	if portrait:
		var rect := _header.portrait_content_rect()
		_stack_scroll.position = rect.position
		_stack_scroll.size = rect.size
		_empty.position = rect.position
		_empty.size = rect.size
	else:
		for pair: Array in [[_summary_panel, SUMMARY_RECT], [_cards_panel, CARDS_RECT]]:
			var rect: Rect2 = pair[1]
			pair[0].position = rect.position
			pair[0].custom_minimum_size = rect.size
			pair[0].size = rect.size
		_empty.position = SUMMARY_RECT.position
		_empty.size = Vector2(CARDS_RECT.end.x - SUMMARY_RECT.position.x, SUMMARY_RECT.size.y)
	# 空の案内は手前に置く(後から足した子ほど手前に描かれる)。
	move_child(_empty, -1)
	_refresh()


func _make_panel(rect: Rect2) -> VBoxContainer:
	var panel := PanelContainer.new()
	panel.position = rect.position
	panel.custom_minimum_size = rect.size
	panel.size = rect.size
	var style: StyleBox = load(PANEL_STYLE)
	if style != null:
		panel.add_theme_stylebox_override("panel", style)
	add_child(panel)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 10)
	panel.add_child(column)
	return column
