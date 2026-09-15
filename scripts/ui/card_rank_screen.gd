class_name CardRankScreen
extends Control
## ランクマッチの自分の段位と、現在シーズンのランキング一覧(GameDesign.md 28章)。
## `CardStatsScreen`と同じ「共通ヘッダー + `content_panel.tres`のパネル」の組み方を使う。
##
## **ブロンズ〜ゴールドはランキングへ出さない**(28章)。星取り制の段位は
## レートのような一意の順序を持たないため、上位者一覧に混ぜても意味を持つ順序にならない。

signal back_pressed

const HEADER_SCENE := "res://scenes/screen_header.tscn"
const PANEL_STYLE := "res://resources/theme/content_panel.tres"
const OWN_RECT := Rect2(24, ScreenHeader.CONTENT_TOP, 1232, 130)
const LIST_RECT := Rect2(
	24, ScreenHeader.CONTENT_TOP + 150, 1232, ScreenHeader.CONTENT_HEIGHT - 150
)
## ランキングへ並べる上限(GameDesign.md 6章のクエリ方針と同じく、件数を絞って
## 複合インデックスのクエリを軽く保つ)。
const LEADERBOARD_LIMIT := 30
const ROW_FONT_SIZE := 18
const COL_RATING := 100.0

var _own: VBoxContainer
var _list: VBoxContainer
var _empty: EmptyState
var _fetching := false


func _ready() -> void:
	_build()


func open() -> void:
	if NetSession.client != null and NetSession.auth != null:
		await RankProgress.ensure_current_season(NetSession.client, NetSession.auth.uid)
	_refresh_own()
	_fetch_leaderboard()


func _build() -> void:
	var backdrop := ScreenBackdrop.new()
	backdrop.room = ScreenBackdrop.Room.VAULT
	add_child(backdrop)
	var header: ScreenHeader = load(HEADER_SCENE).instantiate()
	add_child(header)
	header.set_title("ランク")
	header.back_pressed.connect(func() -> void: back_pressed.emit())

	_own = _make_panel(OWN_RECT)
	_list = _make_panel(LIST_RECT)

	_empty = EmptyState.new()
	_empty.position = LIST_RECT.position
	_empty.size = LIST_RECT.size
	_empty.visible = false
	add_child(_empty)


func _refresh_own() -> void:
	for child in _own.get_children():
		child.queue_free()
	_own.add_child(_make_line("いまの段位", 22))
	var tier := AccountService.rank_tier()
	var line := RankRules.display_name(tier)
	if tier != RankRules.PLATINUM_KEY:
		line += "(★%d/%d)" % [AccountService.rank_stars(), RankRules.star_requirement(tier)]
	else:
		line += "(レート %d)" % AccountService.rank_rating()
	_own.add_child(_make_line(line, 30))
	var peak := AccountService.rank_peak_tier()
	if RankRules.compare_tier(peak, tier) > 0:
		_own.add_child(_make_line("このシーズンの最高到達: %s" % RankRules.display_name(peak), 16))


## 集計は開いた回に1度だけ読む。
func _fetch_leaderboard() -> void:
	if _fetching:
		return
	for child in _list.get_children():
		child.queue_free()
	if NetSession.client == null:
		_empty.show_message("ランキングを取得できませんでした", "通信状況を確認してください")
		_empty.visible = true
		return
	_fetching = true
	_empty.show_message("ランキングを読み込んでいます", "", true)
	_empty.visible = true
	var season := RankProgress.current_season_key()
	var docs: Array = await NetSession.client.query_ranked_leaderboard(
		AccountService.COLLECTION, season, LEADERBOARD_LIMIT
	)
	_fetching = false
	if docs.is_empty():
		_empty.show_message("まだプラチナに到達したプレイヤーがいません", "")
		_empty.visible = true
		return
	_empty.visible = false
	_list.add_child(_make_line("プラチナ帯 ランキング", 22))
	var rank := 1
	for doc: Dictionary in docs:
		var fields: Dictionary = doc.get("fields", {})
		var name := str(fields.get("display_name", ""))
		if name.is_empty():
			name = "(名無し)"
		var rating := int(fields.get("rank_rating", RankRules.PLATINUM_START_RATING))
		_list.add_child(_make_row("%d位 %s" % [rank, name], [_cell("%d" % rating, COL_RATING)]))
		rank += 1
	ListRevealFx.stagger(_list.get_children())


func _make_row(label: String, values: Array) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	var name_label := _make_line(label, ROW_FONT_SIZE)
	name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	name_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	row.add_child(name_label)
	for cell: Dictionary in values:
		var value := _make_line(str(cell["text"]), ROW_FONT_SIZE)
		value.custom_minimum_size.x = float(cell["width"])
		value.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		row.add_child(value)
	return row


static func _cell(text: String, width: float) -> Dictionary:
	return {"text": text, "width": width}


func _make_line(text: String, font_size: int) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", UiPalette.TEXT_OFFWHITE)
	return label


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
