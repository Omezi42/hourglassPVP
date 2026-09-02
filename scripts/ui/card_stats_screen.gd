class_name CardStatsScreen
extends Control
## 戦績(GameDesign.md 19章)。左に対局種別ごとの通算、右にカード別の勝率を並べる。
## 共通のレイアウト規約(GameDesign.md 9章)に従い、`ScreenHeader` を使う。

signal back_pressed

const HEADER_SCENE := "res://scenes/screen_header.tscn"
const PANEL_STYLE := "res://resources/theme/content_panel.tres"
const SUMMARY_RECT := Rect2(24, ScreenHeader.CONTENT_TOP, 560, 540)
const CARDS_RECT := Rect2(608, ScreenHeader.CONTENT_TOP, 648, 540)
## カード別は上位だけを出す。全21種を並べると、対局数の少ないカードの
## 見かけ上の高勝率が上に来て読み違えるため、採用数の多い順に絞る。
const CARD_ROWS := 12
const TOGGLE_SIZE := Vector2(168, 48)

## 「自分」と「みんな」を往復する(GameDesign.md 22章)。並び替えの往復と同じ流儀。
var _global := false
## 集計は開いた回に1度だけ読む。空なら未取得。
var _global_stats: Dictionary = {}
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
	_refresh()
	if _global and _global_stats.is_empty():
		_fetch_global()


## 集計を1度だけ読む。**自分の戦績はローカルにあるため、通信できなくても従来どおり読める。**
func _fetch_global() -> void:
	if _fetching or NetSession.client == null:
		_refresh()
		return
	_fetching = true
	var stats: Dictionary = await MatchRecordService.fetch_stats(NetSession.client)
	_fetching = false
	_global_stats = stats
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
	if _global:
		_refresh_global()
		return
	_refresh_own()


## みんなの戦績(GameDesign.md 22章)。オンライン対戦だけを集めた通算であり、
## CPU戦は含まない。
func _refresh_global() -> void:
	if _global_stats.is_empty():
		_summary.add_child(_make_line("集計を読み込んでいます…" if _fetching else "集計を取得できませんでした", 22))
		return
	var counts: Dictionary = _global_stats.get("counts", {})
	var games: int = int(counts.get("games", 0))
	if games == 0:
		_summary.add_child(_make_line("まだオンライン対戦の記録がありません", 22))
		return
	_summary.add_child(_make_line("みんなの戦績(オンライン対戦の通算)", 26))
	_summary.add_child(_make_line("%d戦" % games, 20))
	_summary.add_child(
		_make_line("先手勝率 %.1f%%" % _percent(int(counts.get("first_wins", 0)), games), 20)
	)
	_summary.add_child(
		_make_line("平均 %.1f手" % [float(int(counts.get("turns", 0))) / float(games)], 20)
	)
	_summary.add_child(_make_line("", 12))
	_summary.add_child(_make_line("内訳", 26))
	_summary.add_child(
		_make_line(
			(
				"ランダム %d戦 / ルーム %d戦"
				% [int(counts.get("kind_random", 0)), int(counts.get("kind_room", 0))]
			),
			18
		)
	)
	for reason: Array in [["hp", "HPが0"], ["surrender", "投了"], ["timeout", "時間切れ"]]:
		var value: int = int(counts.get("end_%s" % reason[0], 0))
		if value > 0:
			_summary.add_child(
				_make_line("%s %d戦(%.1f%%)" % [reason[1], value, _percent(value, games)], 18)
			)

	_cards.add_child(_make_line("カード別(そのカードを入れて戦った勝率)", 22))
	for row: Dictionary in _global_card_rows():
		var card := CardLibrary.find_by_id(row["id"])
		var display: String = card.display_name if card != null else row["id"]
		_cards.add_child(_make_line("%s  %d戦 %s" % [display, row["games"], _rate(row)], 19))


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
		_summary.add_child(_make_line("まだ対局の記録がありません", 22))
		return
	_summary.add_child(_make_line("通算", 26))
	_summary.add_child(_make_line(_summary_text("すべて", all), 20))
	for kind in [
		CurrencyRules.MatchKind.RANDOM, CurrencyRules.MatchKind.ROOM, CurrencyRules.MatchKind.CPU
	]:
		var totals := MatchStats.totals(uid, kind)
		if int(totals["games"]) == 0:
			continue
		_summary.add_child(_make_line(_summary_text(_kind_name(kind), totals), 20))

	var decks := MatchStats.decks(uid)
	if not decks.is_empty():
		_summary.add_child(_make_line("", 12))
		_summary.add_child(_make_line("デッキ別", 26))
		for i in mini(decks.size(), 3):
			var row: Dictionary = decks[i]
			_summary.add_child(
				_make_line("%d戦 %s(%s)" % [row["games"], _rate(row), _short_code(row["code"])], 18)
			)

	_cards.add_child(_make_line("カード別(そのカードを入れて戦った勝率)", 22))
	var rows := MatchStats.cards(uid)
	for i in mini(rows.size(), CARD_ROWS):
		var row: Dictionary = rows[i]
		var card := CardLibrary.find_by_id(row["id"])
		var name: String = card.display_name if card != null else row["id"]
		_cards.add_child(_make_line("%s  %d戦 %s" % [name, row["games"], _rate(row)], 19))


func _summary_text(label: String, totals: Dictionary) -> String:
	var games: int = int(totals["games"])
	var wins: int = int(totals["wins"])
	var average := float(totals["turns"]) / float(maxi(games, 1))
	return (
		"%s  %d戦 %d勝 勝率%.1f%%  平均%.1f手"
		% [label, games, wins, 100.0 * float(wins) / float(maxi(games, 1)), average]
	)


func _rate(row: Dictionary) -> String:
	var games: int = int(row["games"])
	return "勝率%.1f%%" % [100.0 * float(int(row["wins"])) / float(maxi(games, 1))]


## デッキの指紋は長いため、見分けが付く長さだけを出す。
func _short_code(code: String) -> String:
	return code.substr(0, 14) + "…" if code.length() > 14 else code


func _kind_name(kind: int) -> String:
	match kind:
		CurrencyRules.MatchKind.RANDOM:
			return "ランダムマッチ"
		CurrencyRules.MatchKind.ROOM:
			return "ルームマッチ"
		CurrencyRules.MatchKind.CPU:
			return "CPU戦"
	return ""


func _make_line(text: String, font_size: int) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", UiPalette.TEXT_OFFWHITE)
	return label


func _build() -> void:
	add_child(ScreenBackdrop.new())
	var header: ScreenHeader = load(HEADER_SCENE).instantiate()
	add_child(header)
	header.set_title("戦績")
	header.back_pressed.connect(func() -> void: back_pressed.emit())
	_toggle = CodedButton.make("みんなの戦績", TOGGLE_SIZE)
	_toggle.pressed.connect(_on_toggle_pressed)
	header.add_action(_toggle)
	_summary = _make_panel(SUMMARY_RECT)
	_cards = _make_panel(CARDS_RECT)


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
