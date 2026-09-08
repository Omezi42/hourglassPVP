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
const TOGGLE_SIZE := Vector2(168, 48)
## 数値の列。**戦績は数字を見比べる画面**であり、1本の文へ流し込むと桁の位置が
## 行ごとにずれて読み比べられない。列の幅をここで決め、行はこの表に従って組む。
## 幅は、左の欄(内寸512px)で「ランダムマッチ」まで省略されずに収まる値にしてある。
const COL_COUNT := 68.0
const COL_WINS := 68.0
const COL_RATE := 94.0
const COL_TURNS := 92.0
const ROW_FONT_SIZE := 18

## 「自分」と「みんな」を往復する(GameDesign.md 22章)。並び替えの往復と同じ流儀。
var _global := false
## 記録が無いとき・読み込み中に、2つの欄へ重ねて中央へ出す案内。
var _empty: EmptyState
## 集計は開いた回に1度だけ読む。
var _global_stats: Dictionary = {}
## 一度でも読もうとしたか。読めなかった(通信失敗)と、まだ読んでいないを区別するため。
var _global_fetched := false
## 直近の取得が通信そのものに失敗したか。「まだ誰も対局していない」(0件)とは別の状態。
var _global_failed := false
var _fetching := false

var _summary: VBoxContainer
var _cards: VBoxContainer
var _toggle: Button


func _ready() -> void:
	_build()


func open() -> void:
	_refresh()


func _on_toggle_pressed() -> void:
	_global = not _global
	_toggle.text = "自分の戦績" if _global else "みんなの戦績"
	if _global and not _global_fetched and not _fetching:
		_fetch_global()
	else:
		_refresh()


## 集計を1度だけ読む。**自分の戦績はローカルにあるため、通信できなくても従来どおり読める。**
## `MatchRecordService.fetch_stats()` の `ok` で「まだ誰も対局していない」(0件)と
## 「通信そのものに失敗した」を区別する(GameDesign.md 22章「読めなかったときは
## その旨を1行で示す」)。
func _fetch_global() -> void:
	if _fetching:
		return
	if NetSession.client == null:
		_global_fetched = true
		_global_failed = true
		_refresh()
		return
	_fetching = true
	_refresh()
	var result: Dictionary = await MatchRecordService.fetch_stats(NetSession.client)
	_fetching = false
	_global_fetched = true
	_global_failed = not bool(result.get("ok", false))
	_global_stats = {} if _global_failed else result.get("fields", {})
	if _global:
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
	if _global:
		_refresh_global()
		return
	_refresh_own()


## みんなの戦績(GameDesign.md 22章)。オンライン対戦だけを集めた通算であり、
## CPU戦は含まない。**枠(見出し)は状態に関わらず常に描き、数値だけが状態で変わる**
## (読み込み中・通信失敗・0件・通常の4状態を同じ体裁で表す)。
func _refresh_global() -> void:
	_summary.add_child(_make_line("みんなの戦績(オンライン対戦の通算)", 26))
	_cards.add_child(_make_line("カード別(そのカードを入れて戦った勝率)", 22))
	if _fetching or not _global_fetched:
		_empty.show_message("集計を読み込んでいます", "", true)
		return
	if _global_failed:
		_empty.show_message("集計を取得できませんでした", "通信状況を確認してください")
		return
	var counts: Dictionary = _global_stats.get("counts", {})
	var games: int = int(counts.get("games", 0))
	if games == 0:
		_empty.show_message("まだみんなの記録がありません", "オンライン対戦が行われると、ここへ積まれます")
		return
	# 1つの値しか持たない行は、**すべて同じ列へ収める**。行ごとに違う幅の列へ置くと
	# 数字の右端がそろわず、縦に読み比べられない。
	_summary.add_child(_make_line("通算", 26))
	_summary.add_child(_make_row("対局数", [_cell("%d戦" % games, COL_RATE)]))
	_summary.add_child(
		_make_row(
			"先手勝率", [_cell("%.1f%%" % _percent(int(counts.get("first_wins", 0)), games), COL_RATE)]
		)
	)
	_summary.add_child(
		_make_row(
			"平均手数", [_cell("%.1f手" % [float(int(counts.get("turns", 0))) / float(games)], COL_RATE)]
		)
	)
	_summary.add_child(_make_line("", 12))
	_summary.add_child(_make_line("内訳", 26))
	for kind: Array in [["kind_random", "ランダムマッチ"], ["kind_room", "ルームマッチ"]]:
		_summary.add_child(
			_make_row(str(kind[1]), [_cell("%d戦" % int(counts.get(kind[0], 0)), COL_COUNT)])
		)
	for reason: Array in [["hp", "HPが0"], ["surrender", "投了"], ["timeout", "時間切れ"]]:
		var value: int = int(counts.get("end_%s" % reason[0], 0))
		if value > 0:
			_summary.add_child(
				_make_row(
					str(reason[1]),
					[
						_cell("%d戦" % value, COL_COUNT),
						_cell("%.1f%%" % _percent(value, games), COL_RATE)
					]
				)
			)

	for row: Dictionary in _global_card_rows():
		var card := CardLibrary.find_by_id(row["id"])
		var display: String = card.display_name if card != null else row["id"]
		_cards.add_child(
			_make_row(display, [_cell("%d戦" % row["games"], COL_COUNT), _rate_cell(row)])
		)


## 集計のカード別を、採用数の多い順に並べて返す。
func _global_card_rows() -> Array:
	var source: Dictionary = _global_stats.get("cards", {})
	var rows: Array = []
	for id: String in source:
		var entry: Dictionary = source[id]
		rows.append({"id": id, "games": int(entry.get("g", 0)), "wins": int(entry.get("w", 0))})
	rows.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return a["games"] > b["games"])
	return rows.slice(0, CARD_ROWS)


func _percent(value: int, total: int) -> float:
	return 100.0 * float(value) / float(maxi(total, 1))


func _refresh_own() -> void:
	var uid := _uid()
	var all := MatchStats.totals(uid)
	if int(all["games"]) == 0:
		_empty.show_message("まだ対局の記録がありません", "対局を1局終えると、ここへ通算が積まれます")
		return
	_summary.add_child(_make_line("通算", 26))
	_summary.add_child(_make_row("すべて", _summary_cells(all)))
	for kind in [
		CurrencyRules.MatchKind.RANDOM, CurrencyRules.MatchKind.ROOM, CurrencyRules.MatchKind.CPU
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
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	var name_label := _make_line(label, font_size)
	name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	name_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	row.add_child(name_label)
	for cell: Dictionary in values:
		var value := _make_line(str(cell["text"]), font_size)
		value.custom_minimum_size.x = float(cell["width"])
		value.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		row.add_child(value)
	return row


## 「n戦」「勝率n%」のように、単位まで含めて1つの列へ収める。
static func _cell(text: String, width: float) -> Dictionary:
	return {"text": text, "width": width}


func _make_line(text: String, font_size: int) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", UiPalette.TEXT_OFFWHITE)
	return label


func _build() -> void:
	var backdrop := ScreenBackdrop.new()
	backdrop.room = ScreenBackdrop.Room.VAULT
	add_child(backdrop)
	var header: ScreenHeader = load(HEADER_SCENE).instantiate()
	add_child(header)
	header.set_title("戦績")
	header.back_pressed.connect(func() -> void: back_pressed.emit())
	_toggle = CodedButton.make("みんなの戦績", TOGGLE_SIZE)
	_toggle.pressed.connect(_on_toggle_pressed)
	header.add_action(_toggle)
	_summary = _make_panel(SUMMARY_RECT)
	_cards = _make_panel(CARDS_RECT)
	# 記録が無い/読み込み中は、2つのパネルにまたがる中央へ1つだけ出す。
	# 左の欄の左上へ1行だけ置くと、右の欄が空のまま残って画面が壊れて見える。
	_empty = EmptyState.new()
	_empty.position = SUMMARY_RECT.position
	_empty.size = Vector2(CARDS_RECT.end.x - SUMMARY_RECT.position.x, SUMMARY_RECT.size.y)
	_empty.visible = false
	add_child(_empty)


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
