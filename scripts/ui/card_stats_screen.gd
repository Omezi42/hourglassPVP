class_name CardStatsScreen
extends Control
## 戦績(GameDesign.md 19章)。横は左に通算と対局の種類別、右にデッキ別。縦は1本のスクロールに積む。
## 数字の表に、勝率の輪・数字の札・横棒・砂時計の絵(`StatsGraphics`)を添える。
## 共通のレイアウト規約(GameDesign.md 9章)に従い、`ScreenHeader` を使う。

signal back_pressed

## いま保存していない構築(消したデッキ・受け取ったデッキなど)の見出し。
const UNKNOWN_DECK_NAME := "いま保存していない構築"
const HEADER_SCENE := "res://scenes/screen_header.tscn"
const PANEL_STYLE := "res://resources/theme/content_panel.tres"
const SUMMARY_RECT := Rect2(24, ScreenHeader.CONTENT_TOP, 560, 540)
const DECKS_RECT := Rect2(608, ScreenHeader.CONTENT_TOP, 648, 540)
const KINDS := [
	CurrencyRules.MatchKind.RANKED,
	CurrencyRules.MatchKind.RANDOM,
	CurrencyRules.MatchKind.ROOM,
	CurrencyRules.MatchKind.CPU,
]
## 数値の列。**戦績は数字を見比べる画面**であり、行どうしで右揃えにそろえる。
const COL_COUNT := 64.0
const COL_RATE := 80.0
const COL_TURNS := 80.0
const KIND_NAME_WIDTH := 150.0
const ROW_FONT_SIZE := UiPalette.T_LEAD
const SECTION_FONT_SIZE := UiPalette.T_HEAD
const RING_DIAMETER := 150.0
const DECK_ICON_HEIGHT := 40.0
const DECK_BAR_WIDTH := 130.0
## 2段の行では棒を行の残りいっぱいに伸ばす。その最小幅。
const DECK_BAR_MIN_WIDTH := 120.0
const DECK_ICON_GAP := 12
const DECK_STACK_TEXT_GAP := 4
const ROW_GAP := 10
const SECTION_GAP := 10.0
## これより少ない対局数の構築は、横棒と勝率を薄くする(数局の勝率は揺れが大きいため)。
const FEW_GAMES := 5
const FEW_GAMES_ALPHA := 0.4
## 縦画面(GameDesign.md 9章「縦画面」)。文字を目安まで大きくする。
## 数値の列・絵は文字ほどには広げない(見出しの列の幅を残すため)。
const PORTRAIT_TEXT_SCALE := 24.0 / ROW_FONT_SIZE
const PORTRAIT_COLUMN_SCALE := 1.25
const PORTRAIT_PANEL_GAP := 16
## 文字サイズ「大」のとき、25pxの文字が収まるよう列の幅へ重ねる倍率(名前・戦数。勝率・手数は据え置き)。
const LARGE_NAME_SCALE := 1.17
const LARGE_COUNT_SCALE := 1.125

## 記録が無いときに、2つの欄へ重ねて中央へ出す案内。
var _empty: EmptyState

var _summary: VBoxContainer
var _decks: VBoxContainer
var _header: ScreenHeader
var _summary_panel: PanelContainer
var _decks_panel: PanelContainer
## デッキ別は横では欄の中だけをスクロールする(構築は最大20件まで覚えるため)。
var _decks_scroll: ScrollContainer
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
	# 古い行はすぐ外す。`queue_free()` だけだとフレームの終わりまで列に残り、
	# 新しい行がその下へ並んだ位置を登場演出が掴んで、行が欄の下へずれる。
	for column in [_summary, _decks]:
		for child in column.get_children():
			column.remove_child(child)
			child.queue_free()
	_empty.hide_message()
	var uid := _uid()
	var all := MatchStats.totals(uid)
	var empty := int(all["games"]) == 0
	_layout_panels(empty)
	if empty:
		_empty.show_message("まだ対局の記録がありません", "対局を1局終えると、ここへ通算が積まれます")
		return
	_fill_summary(uid, all)
	_fill_decks(uid)
	ListRevealFx.stagger(_summary.get_children())
	ListRevealFx.stagger(_decks.get_children())


## 向きだけの文字の拡大(札の大きさと数字はこれで決まり、文字サイズ「大」では変えない)。
func _orientation_scale() -> float:
	return PORTRAIT_TEXT_SCALE if _portrait else 1.0


func _text_scale() -> float:
	return _orientation_scale() * TextSize.factor()


## 行の文字が大きくなる(文字サイズ「大」)か縦のとき、デッキ別の行を名前と棒の2段に組む。
func _deck_rows_stacked() -> bool:
	return _portrait or TextSize.factor() > 1.0


func _font(base: int) -> int:
	return roundi(base * _text_scale())


func _fill_summary(uid: String, all: Dictionary) -> void:
	var games := int(all["games"])
	var wins := int(all["wins"])
	_summary.add_child(StatsGraphics.label("通算", _font(SECTION_FONT_SIZE)))
	var top := HBoxContainer.new()
	top.alignment = BoxContainer.ALIGNMENT_CENTER
	top.add_theme_constant_override("separation", ROW_GAP + 6)
	_summary.add_child(top)
	var column_scale := PORTRAIT_COLUMN_SCALE if _portrait else 1.0
	top.add_child(StatsGraphics.ring(_rate(wins, games), RING_DIAMETER * column_scale))
	var scale := _orientation_scale()
	top.add_child(StatsGraphics.tile("対局", "%d" % games, "戦", scale))
	top.add_child(StatsGraphics.tile("勝ち", "%d" % wins, "勝", scale))
	top.add_child(StatsGraphics.tile("平均", "%.1f" % _average(all), "手", scale))

	var gap := Control.new()
	gap.custom_minimum_size.y = SECTION_GAP
	_summary.add_child(gap)
	_summary.add_child(StatsGraphics.label("対局の種類別", _font(SECTION_FONT_SIZE)))
	for kind: int in KINDS:
		var totals := MatchStats.totals(uid, kind)
		var kind_games := int(totals["games"])
		if kind_games == 0:
			continue
		var row := _row()
		var name := StatsGraphics.label(_kind_name(kind), _font(ROW_FONT_SIZE))
		name.custom_minimum_size.x = _kind_name_width()
		row.add_child(name)
		row.add_child(StatsGraphics.split_bar(_rate(int(totals["wins"]), kind_games)))
		row.add_child(_cell("%d戦" % kind_games, _count_width()))
		row.add_child(_cell(_percent(int(totals["wins"]), kind_games), COL_RATE))
		row.add_child(_cell("%.1f手" % _average(totals), COL_TURNS))
		_summary.add_child(row)


func _fill_decks(uid: String) -> void:
	_decks.add_child(StatsGraphics.label("デッキ別", _font(SECTION_FONT_SIZE)))
	var stacked := _deck_rows_stacked()
	_decks.add_theme_constant_override("separation", int(UiPalette.S4) if stacked else ROW_GAP)
	var known := _known_decks()
	var column_scale := PORTRAIT_COLUMN_SCALE if _portrait else 1.0
	for entry: Dictionary in merge_unknown_decks(MatchStats.decks(uid), known):
		var games := int(entry["games"])
		var wins := int(entry["wins"])
		var deck: Dictionary = known.get(entry["code"], {})
		var icon := StatsGraphics.deck_icon(deck.get("cards", []), DECK_ICON_HEIGHT * column_scale)
		var name := StatsGraphics.label(
			str(deck.get("name", UNKNOWN_DECK_NAME)), _font(ROW_FONT_SIZE)
		)
		name.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		name.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		name.clip_text = true
		var bar := StatsGraphics.rate_bar(_rate(wins, games), DECK_BAR_WIDTH * column_scale)
		var count := _cell("%d戦" % games, _count_width())
		var rate := _cell(_percent(wins, games), COL_RATE)
		var row := _row()
		if stacked:
			bar.custom_minimum_size.x = DECK_BAR_MIN_WIDTH
			bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			icon.size_flags_vertical = Control.SIZE_SHRINK_CENTER
			row.add_theme_constant_override("separation", DECK_ICON_GAP)
			row.add_child(icon)
			var body := VBoxContainer.new()
			body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			body.add_theme_constant_override("separation", DECK_STACK_TEXT_GAP)
			row.add_child(body)
			body.add_child(name)
			var line := _row()
			line.add_child(bar)
			line.add_child(count)
			line.add_child(rate)
			body.add_child(line)
		else:
			row.add_child(icon)
			row.add_child(name)
			row.add_child(bar)
			row.add_child(count)
			row.add_child(rate)
		if games < FEW_GAMES:
			bar.modulate.a = FEW_GAMES_ALPHA
			rate.modulate.a = FEW_GAMES_ALPHA
		_decks.add_child(row)


## 名前を引けない構築(`known` に無い指紋)を1行へ合算し、対局数の多い順に並べ直す。
## 保存の形(指紋ごとの記録)は変えず、画面側だけでまとめる。
static func merge_unknown_decks(rows: Array, known: Dictionary) -> Array:
	var merged: Array = []
	var unknown := {"code": "", "games": 0, "wins": 0}
	var has_unknown := false
	for entry: Dictionary in rows:
		if known.has(entry["code"]):
			merged.append(entry)
			continue
		has_unknown = true
		unknown["games"] = int(unknown["games"]) + int(entry["games"])
		unknown["wins"] = int(unknown["wins"]) + int(entry["wins"])
	if has_unknown:
		merged.append(unknown)
	merged.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return a["games"] > b["games"])
	return merged


static func _rate(wins: int, games: int) -> float:
	return float(wins) / float(maxi(games, 1))


static func _percent(wins: int, games: int) -> String:
	return "%.1f%%" % [100.0 * _rate(wins, games)]


static func _average(totals: Dictionary) -> float:
	return float(totals["turns"]) / float(maxi(int(totals["games"]), 1))


## 指紋 → `{"name":, "cards":}`。**指紋は構築を見分けるための内部の識別子であり、
## そのまま画面へ出すとプレイヤーには読めない文字列が並ぶ**。いま保存しているデッキと
## プリセットから引き直す。
func _known_decks() -> Dictionary:
	var known := {}
	for preset: Dictionary in CardPresetDecks.PRESETS:
		var cards := CardPresetDecks.deck_of(str(preset["id"]))
		if not cards.is_empty():
			known[CardDeckCode.fingerprint(cards)] = {
				"name": "%s(プリセット)" % preset["name"], "cards": cards
			}
	# 保存したデッキを後から入れる。プリセットをそのまま保存した場合は、
	# プレイヤーが付けた名前のほうを出す。
	for entry: Dictionary in CardDeckSave.list_decks():
		known[CardDeckCode.fingerprint(entry["cards"])] = {
			"name": str(entry["name"]), "cards": entry["cards"]
		}
	return known


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


func _row() -> HBoxContainer:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", ROW_GAP)
	return row


func _is_large() -> bool:
	return TextSize.factor() > 1.0


## 種類名の列。「大」の縦は列の幅(1.25倍)にも重ねる(「ランダムマッチ」が25pxで収まる幅)。
func _kind_name_width() -> float:
	if not _is_large():
		return KIND_NAME_WIDTH * _orientation_scale()
	var column_scale := PORTRAIT_COLUMN_SCALE if _portrait else 1.0
	return KIND_NAME_WIDTH * column_scale * LARGE_NAME_SCALE


func _count_width() -> float:
	return COL_COUNT * (LARGE_COUNT_SCALE if _is_large() else 1.0)


## 「n戦」「n.n%」のように、単位まで含めて1つの右揃えの列へ収める。
func _cell(text: String, width: float) -> Label:
	var column_scale := PORTRAIT_COLUMN_SCALE if _portrait else 1.0
	var cell := StatsGraphics.label(text, _font(ROW_FONT_SIZE))
	cell.custom_minimum_size.x = width * column_scale
	cell.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	return cell


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
	_summary_panel = _make_panel(SUMMARY_RECT)
	_summary = _make_column()
	_summary_panel.add_child(_summary)
	_decks_panel = _make_panel(DECKS_RECT)
	_decks_scroll = ScrollContainer.new()
	_decks_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	TouchScroll.enable(_decks_scroll)
	_decks_panel.add_child(_decks_scroll)
	_decks = _make_column()
	_decks.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_decks_scroll.add_child(_decks)
	_empty = EmptyState.new()
	_empty.visible = false
	add_child(_empty)
	_place_landscape()


## 縦横が変わったときに `Main` から呼ばれる(Architecture.md 4.7節)。
## 縦では2つの欄を1本のスクロールへ移して積む(GameDesign.md 9章「縦画面」)。
func apply_orientation(portrait: bool) -> void:
	_portrait = portrait
	if _header == null:
		return
	_header.apply_orientation(portrait)
	_stack_scroll.visible = portrait
	# 縦は外側の1本だけでスクロールする。デッキ別の欄は中身の高さまで伸ばす。
	_decks_scroll.vertical_scroll_mode = (
		ScrollContainer.SCROLL_MODE_DISABLED if portrait else ScrollContainer.SCROLL_MODE_AUTO
	)
	for panel: PanelContainer in [_summary_panel, _decks_panel]:
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
		_place_landscape()
	# 空の案内は手前に置く(後から足した子ほど手前に描かれる)。
	move_child(_empty, -1)
	_refresh()


func _place_landscape() -> void:
	for pair: Array in [[_summary_panel, SUMMARY_RECT], [_decks_panel, DECKS_RECT]]:
		var rect: Rect2 = pair[1]
		pair[0].position = rect.position
		pair[0].custom_minimum_size = rect.size
		pair[0].size = rect.size
	_empty.position = SUMMARY_RECT.position
	_empty.size = _whole_rect().size


## 2つの欄を合わせた範囲。
static func _whole_rect() -> Rect2:
	return SUMMARY_RECT.merge(DECKS_RECT)


## 記録が無いときは欄を1枚にして、その中央へ案内を出す(2つの欄の境目に案内がまたがらないように)。
## 縦では欄を出さず、案内だけにする。
func _layout_panels(empty: bool) -> void:
	_decks_panel.visible = not empty
	_summary_panel.visible = not (empty and _portrait)
	if _portrait:
		return
	var rect := _whole_rect() if empty else SUMMARY_RECT
	_summary_panel.custom_minimum_size = rect.size
	_summary_panel.size = rect.size


func _make_panel(rect: Rect2) -> PanelContainer:
	var panel := PanelContainer.new()
	panel.position = rect.position
	panel.custom_minimum_size = rect.size
	panel.size = rect.size
	var style: StyleBox = load(PANEL_STYLE)
	if style != null:
		panel.add_theme_stylebox_override("panel", style)
	add_child(panel)
	return panel


func _make_column() -> VBoxContainer:
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", ROW_GAP)
	return column
