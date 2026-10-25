class_name CardRankScreen
extends Control
## ランク画面(GameDesign.md 28章「ランク画面」)。左 = 自分の段位と月末報酬(`RankOwnPanel`)、
## 右 = 今シーズンのランキング。入口は対局の種類を選ぶモーダルの「ランキングを見る」。
##
## **ブロンズ〜プラチナまで全員を1本のランキングへ並べる。**並び順は
## `RankRules.progress_score()`が合成する単一のスコアで、帯・階級・★・レートの
## どこにいても一意に比較できる。

signal back_pressed

const HEADER_SCENE := "res://scenes/screen_header.tscn"
const PANEL_STYLE := "res://resources/theme/content_panel.tres"
const LEFT_RECT := Rect2(24, ScreenHeader.CONTENT_TOP, 440, ScreenHeader.CONTENT_HEIGHT)
const RIGHT_RECT := Rect2(480, ScreenHeader.CONTENT_TOP, 776, ScreenHeader.CONTENT_HEIGHT)
## 右パネルの内側の余白(`content_panel.tres` の content_margin と同じ)。
const RIGHT_PAD := Vector2(24, 20)
const TITLE_SIZE := 20
const NOTE_SIZE := 15
const TITLE_HEIGHT := 32.0
const LIST_TOP := 62.0
const ROW_GAP := 4.0
## 最下段に固定する自分の行と、その上の仕切り。
const PINNED_RULE_GAP := 8.0
## ランキングへ並べる上限(GameDesign.md 6章のクエリ方針と同じく、件数を絞って
## 複合インデックスのクエリを軽く保つ)。
const LEADERBOARD_LIMIT := 30
const NAMELESS := "(名無し)"
## 縦画面(GameDesign.md 9章「縦画面」)。自分の段位とランキングを切り替えて1つずつ出す
## (並べると、どちらも文字が読める大きさにならないため)。段位は中身ごと幅いっぱいへ拡大し、
## ランキングの行は2段に積んで拡大する。
const PORTRAIT_TABS := ["自分の段位", "ランキング"]
const PORTRAIT_ROW_ZOOM := 1.4
const PORTRAIT_TITLE_SIZE := 30
const PORTRAIT_NOTE_SIZE := 24
const PORTRAIT_TITLE_HEIGHT := 44.0
const PORTRAIT_NOTE_HEIGHT := 36.0
const PORTRAIT_LIST_GAP := 16.0

var _own: RankOwnPanel
var _season_label: Label
var _scroll: ScrollContainer
var _rows: VBoxContainer
var _pinned: RankBoardRow
var _pinned_rule: ColorRect
var _empty: EmptyState
var _fetching := false
var _ceremony: CardSeasonCeremonyPanel
var _header: ScreenHeader
var _own_back: Panel
var _board_back: Panel
var _title: Label
var _tabs: Array[Button] = []
var _show_board := false
## 中身として出すか(縦で隠している間も保つ)。
var _pinned_shown := false
var _empty_shown := false
var _portrait := false


func _ready() -> void:
	_build()


func open() -> void:
	if NetSession.client != null and NetSession.auth != null:
		var season_result := await RankProgress.ensure_current_season(
			NetSession.client, NetSession.auth.uid
		)
		if bool(season_result.get("transitioned", false)):
			_ceremony.open(season_result)
	_own.show_standing(RankProgress.standing(), RankProgress.days_left_in_season())
	_season_label.text = "%s ・ 上位%d人" % [_season_title(), LEADERBOARD_LIMIT]
	_fetch_leaderboard()


func _build() -> void:
	var backdrop := ScreenBackdrop.new()
	backdrop.room = ScreenBackdrop.Room.VAULT
	add_child(backdrop)
	_header = load(HEADER_SCENE).instantiate()
	add_child(_header)
	_header.set_title("ランク")
	_header.back_pressed.connect(func() -> void: back_pressed.emit())
	var tab_width := (
		(
			(ScreenOrientation.PORTRAIT_SIZE.x - ScreenHeader.OUTER_MARGIN * 2.0)
			- ScreenHeader.PORTRAIT_ACTION_GAP
		)
		/ float(PORTRAIT_TABS.size())
	)
	_tabs = PortraitTabs.make(
		_header, PORTRAIT_TABS, tab_width, func(i: int) -> void: _select_tab(i == 1)
	)

	_own_back = _add_panel()
	_own = RankOwnPanel.new()
	add_child(_own)

	_board_back = _add_panel()
	_title = _make_label("今シーズンのランキング", TITLE_SIZE, UiPalette.TEXT_OFFWHITE)
	add_child(_title)
	_season_label = _make_label("", NOTE_SIZE, UiPalette.TEXT_MUTED)
	add_child(_season_label)

	_pinned = RankBoardRow.new()
	_pinned.mine = true
	_pinned.visible = false
	add_child(_pinned)
	_pinned_rule = ColorRect.new()
	_pinned_rule.color = Color(UiPalette.GLOW_AMBER, 0.45)
	_pinned_rule.visible = false
	add_child(_pinned_rule)

	_scroll = ScrollContainer.new()
	_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	TouchScroll.enable(_scroll)
	add_child(_scroll)
	_rows = VBoxContainer.new()
	_rows.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_rows.add_theme_constant_override("separation", int(ROW_GAP))
	_scroll.add_child(_rows)

	_empty = EmptyState.new()
	_empty.visible = false
	add_child(_empty)

	# 表彰式は最後の子にする(後から足した子ほど手前に描かれる)。
	_ceremony = CardSeasonCeremonyPanel.new()
	add_child(_ceremony)
	_layout()


## 縦横が変わったときに `Main` から呼ばれる(Architecture.md 4.7節)。並んでいる行は保つ。
func apply_orientation(portrait: bool) -> void:
	_portrait = portrait
	if _header == null:
		return
	PortraitTabs.mark(_tabs, int(_show_board), portrait)
	_header.apply_orientation(portrait)
	_layout()
	_select_tab(_show_board)


## 縦で自分の段位とランキングを切り替える。横では両方を出す。
func _select_tab(board: bool) -> void:
	_show_board = board
	PortraitTabs.mark(_tabs, int(board), _portrait)
	for node: CanvasItem in [_own_back, _own]:
		node.visible = not board or not _portrait
	for node: CanvasItem in [_board_back, _title, _season_label, _scroll]:
		node.visible = board or not _portrait
	_pinned.visible = _pinned_shown and (board or not _portrait)
	_pinned_rule.visible = _pinned.visible
	_empty.visible = _empty_shown and (board or not _portrait)


func _layout() -> void:
	var content := _header.portrait_content_rect()
	var own_rect := LEFT_RECT
	var board_rect := RIGHT_RECT
	_own.zoom = 1.0
	if _portrait:
		_own.zoom = content.size.x / LEFT_RECT.size.x
		own_rect = Rect2(
			content.position, Vector2(content.size.x, RankOwnPanel.content_height() * _own.zoom)
		)
		board_rect = content
	_place(_own_back, own_rect)
	_place(_own, own_rect)
	_place(_board_back, board_rect)

	var inner := Rect2(board_rect.position + RIGHT_PAD, board_rect.size - RIGHT_PAD * 2.0)
	var title_height := PORTRAIT_TITLE_HEIGHT if _portrait else TITLE_HEIGHT
	_title.add_theme_font_size_override(
		"font_size", PORTRAIT_TITLE_SIZE if _portrait else TITLE_SIZE
	)
	_place(_title, Rect2(inner.position, Vector2(inner.size.x, title_height)))
	# 縦は見出しの下の行へ回す(見出しと同じ行に収まらないため)。
	_season_label.add_theme_font_size_override(
		"font_size", PORTRAIT_NOTE_SIZE if _portrait else NOTE_SIZE
	)
	_season_label.horizontal_alignment = (
		HORIZONTAL_ALIGNMENT_LEFT if _portrait else HORIZONTAL_ALIGNMENT_RIGHT
	)
	var note_top := inner.position.y + (title_height if _portrait else 0.0)
	var note_height := PORTRAIT_NOTE_HEIGHT if _portrait else TITLE_HEIGHT
	_place(_season_label, Rect2(inner.position.x, note_top, inner.size.x, note_height))

	for row in [_pinned] + _rows.get_children():
		(row as RankBoardRow).set_portrait(_portrait, PORTRAIT_ROW_ZOOM)
	var pinned_top := inner.end.y - _pinned.row_height()
	_place(_pinned, Rect2(inner.position.x, pinned_top, inner.size.x, _pinned.row_height()))
	_place(_pinned_rule, Rect2(inner.position.x, pinned_top - PINNED_RULE_GAP, inner.size.x, 1.0))
	var list_top := (
		note_top + note_height + PORTRAIT_LIST_GAP
		if _portrait
		else board_rect.position.y + LIST_TOP
	)
	var list_rect := Rect2(
		inner.position.x, list_top, inner.size.x, pinned_top - PINNED_RULE_GAP * 2.0 - list_top
	)
	_place(_scroll, list_rect)
	_place(_empty, list_rect)


func _place(node: Control, rect: Rect2) -> void:
	node.position = rect.position
	node.size = rect.size


## 集計は開いた回に1度だけ読む。
func _fetch_leaderboard() -> void:
	if _fetching:
		return
	for child in _rows.get_children():
		child.queue_free()
	_show_pinned(0)
	if NetSession.client == null:
		_empty.show_message("ランキングを取得できませんでした", "通信状況を確認してください")
		_set_empty_shown(true)
		return
	_fetching = true
	_empty.show_message("ランキングを読み込んでいます", "", true)
	_set_empty_shown(true)
	var docs: Array = await NetSession.client.query_ranked_leaderboard(
		AccountService.COLLECTION, RankProgress.current_season_key(), LEADERBOARD_LIMIT
	)
	_fetching = false
	if docs.is_empty():
		_empty.show_message("まだ今シーズンの対局記録がありません", "")
		return
	_set_empty_shown(false)
	var my_uid := NetSession.auth.uid if NetSession.auth != null else ""
	var my_rank := 0
	for i in docs.size():
		var doc: Dictionary = docs[i]
		var row := _row_from_fields(doc.get("fields", {}))
		row.rank = i + 1
		row.zebra = i % 2 == 0
		row.mine = my_uid != "" and str(doc.get("id", "")) == my_uid
		if row.mine:
			my_rank = row.rank
		row.set_portrait(_portrait, PORTRAIT_ROW_ZOOM)
		_rows.add_child(row)
	_show_pinned(my_rank)
	ListRevealFx.stagger(_rows.get_children())


func _set_empty_shown(shown: bool) -> void:
	_empty_shown = shown
	_select_tab(_show_board)


func _row_from_fields(fields: Dictionary) -> RankBoardRow:
	var row := RankBoardRow.new()
	var name := str(fields.get("display_name", ""))
	row.display_name = name if not name.is_empty() else NAMELESS
	row.icon_id = str(fields.get("icon_id", UserProfileLibrary.DEFAULT_ICON_ID))
	row.title_id = str(fields.get("title_id", UserProfileLibrary.DEFAULT_TITLE_ID))
	row.tier = str(fields.get("rank_tier", RankRules.INITIAL_TIER))
	row.stars = int(fields.get("rank_stars", 0))
	row.rating = int(fields.get("rank_rating", RankRules.PLATINUM_START_RATING))
	return row


## 自分の行を最下段に固定する。上位の一覧に入っていなければ順位は「圏外」。
func _show_pinned(rank: int) -> void:
	var standing := RankProgress.standing()
	_pinned.rank = rank
	_pinned.display_name = AccountService.display_name_or_default()
	_pinned.icon_id = AccountService.icon_id()
	_pinned.title_id = AccountService.title_id()
	_pinned.tier = standing["tier"]
	_pinned.stars = standing["stars"]
	_pinned.rating = standing["rating"]
	_pinned_shown = true
	_select_tab(_show_board)
	_pinned.queue_redraw()


## 「2026年9月」。シーズンキー("2026-09")から組み立てる。
static func _season_title() -> String:
	var parts := RankProgress.current_season_key().split("-")
	return "%d年%d月" % [int(parts[0]), int(parts[1])]


func _add_panel() -> Panel:
	var panel := Panel.new()
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_theme_stylebox_override("panel", load(PANEL_STYLE))
	add_child(panel)
	return panel


func _make_label(text: String, font_size: int, color: Color) -> Label:
	var label := Label.new()
	label.text = text
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	return label
