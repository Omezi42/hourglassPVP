class_name CardRankScreen
extends Control
## ランク画面(GameDesign.md 28章「ランク画面」)。左 = 自分の段位と月末報酬(`RankOwnPanel`)、
## 右 = 今シーズンのランキング。入口はホームの「きろく」タブ。
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

var _own: RankOwnPanel
var _season_label: Label
var _scroll: ScrollContainer
var _rows: VBoxContainer
var _pinned: RankBoardRow
var _pinned_rule: ColorRect
var _empty: EmptyState
var _fetching := false
var _ceremony: CardSeasonCeremonyPanel


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
	var header: ScreenHeader = load(HEADER_SCENE).instantiate()
	add_child(header)
	header.set_title("ランク")
	header.back_pressed.connect(func() -> void: back_pressed.emit())

	_add_panel(LEFT_RECT)
	_own = RankOwnPanel.new()
	_own.position = LEFT_RECT.position
	_own.size = LEFT_RECT.size
	add_child(_own)

	_add_panel(RIGHT_RECT)
	var inner := Rect2(RIGHT_RECT.position + RIGHT_PAD, RIGHT_RECT.size - RIGHT_PAD * 2.0)
	var title := _make_label("今シーズンのランキング", TITLE_SIZE, UiPalette.TEXT_OFFWHITE)
	title.position = inner.position
	title.size = Vector2(inner.size.x, TITLE_HEIGHT)
	add_child(title)
	_season_label = _make_label("", NOTE_SIZE, UiPalette.TEXT_MUTED)
	_season_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_season_label.position = inner.position
	_season_label.size = Vector2(inner.size.x, TITLE_HEIGHT)
	add_child(_season_label)

	var pinned_top := inner.end.y - RankBoardRow.HEIGHT
	_pinned = RankBoardRow.new()
	_pinned.mine = true
	_pinned.position = Vector2(inner.position.x, pinned_top)
	_pinned.size = Vector2(inner.size.x, RankBoardRow.HEIGHT)
	_pinned.visible = false
	add_child(_pinned)
	_pinned_rule = ColorRect.new()
	_pinned_rule.color = Color(UiPalette.GLOW_AMBER, 0.45)
	_pinned_rule.position = Vector2(inner.position.x, pinned_top - PINNED_RULE_GAP)
	_pinned_rule.size = Vector2(inner.size.x, 1.0)
	_pinned_rule.visible = false
	add_child(_pinned_rule)

	var list_rect := Rect2(
		inner.position.x,
		RIGHT_RECT.position.y + LIST_TOP,
		inner.size.x,
		pinned_top - PINNED_RULE_GAP * 2.0 - (RIGHT_RECT.position.y + LIST_TOP)
	)
	_scroll = ScrollContainer.new()
	_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_scroll.position = list_rect.position
	_scroll.size = list_rect.size
	TouchScroll.enable(_scroll)
	add_child(_scroll)
	_rows = VBoxContainer.new()
	_rows.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_rows.add_theme_constant_override("separation", int(ROW_GAP))
	_scroll.add_child(_rows)

	_empty = EmptyState.new()
	_empty.position = list_rect.position
	_empty.size = list_rect.size
	_empty.visible = false
	add_child(_empty)

	# 表彰式は最後の子にする(後から足した子ほど手前に描かれる)。
	_ceremony = CardSeasonCeremonyPanel.new()
	add_child(_ceremony)


## 集計は開いた回に1度だけ読む。
func _fetch_leaderboard() -> void:
	if _fetching:
		return
	for child in _rows.get_children():
		child.queue_free()
	_show_pinned(0)
	if NetSession.client == null:
		_empty.show_message("ランキングを取得できませんでした", "通信状況を確認してください")
		_empty.visible = true
		return
	_fetching = true
	_empty.show_message("ランキングを読み込んでいます", "", true)
	_empty.visible = true
	var docs: Array = await NetSession.client.query_ranked_leaderboard(
		AccountService.COLLECTION, RankProgress.current_season_key(), LEADERBOARD_LIMIT
	)
	_fetching = false
	if docs.is_empty():
		_empty.show_message("まだ今シーズンの対局記録がありません", "")
		return
	_empty.visible = false
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
		_rows.add_child(row)
	_show_pinned(my_rank)
	ListRevealFx.stagger(_rows.get_children())


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
	_pinned.visible = true
	_pinned_rule.visible = true
	_pinned.queue_redraw()


## 「2026年9月」。シーズンキー("2026-09")から組み立てる。
static func _season_title() -> String:
	var parts := RankProgress.current_season_key().split("-")
	return "%d年%d月" % [int(parts[0]), int(parts[1])]


func _add_panel(rect: Rect2) -> void:
	var panel := Panel.new()
	panel.position = rect.position
	panel.size = rect.size
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_theme_stylebox_override("panel", load(PANEL_STYLE))
	add_child(panel)


func _make_label(text: String, font_size: int, color: Color) -> Label:
	var label := Label.new()
	label.text = text
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	return label
