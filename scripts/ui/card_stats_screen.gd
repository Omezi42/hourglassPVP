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

var _summary: VBoxContainer
var _cards: VBoxContainer


func _ready() -> void:
	_build()


func open() -> void:
	_refresh()


func _uid() -> String:
	if NetSession.client == null or NetSession.client.auth == null:
		return ""
	return NetSession.client.auth.uid


func _refresh() -> void:
	var uid := _uid()
	for child in _summary.get_children():
		child.queue_free()
	for child in _cards.get_children():
		child.queue_free()

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


## デッキコードは長いため、見分けが付く長さだけを出す。
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
