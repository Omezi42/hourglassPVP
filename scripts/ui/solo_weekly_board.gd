class_name SoloWeeklyBoard
extends Control
## 今週の順位表(GameDesign.md 27章「週替わりの遠征」)。ランクマッチの順位表(28章)と同じ組み立てで、
## 上位20人を並べ、自分の行を琥珀で強調して最下段にも固定する。入っていなければ「圏外」。
## 列は 順位・アイコン・表示名・勝った数・残りHP(`RankBoardRow` の週替わりの行)。

const PANEL_STYLE := "res://resources/theme/content_panel.tres"
const PAD := Vector2(24, 20)
const TITLE := "今週の順位"
const TITLE_SIZE := UiPalette.T_LEAD
const TITLE_HEIGHT := 32.0
const NOTE_SIZE := UiPalette.T_SMALL
const NOTE_HEIGHT := 28.0
const LIST_TOP_GAP := 12.0
const ROW_GAP := 4.0
const PINNED_RULE_GAP := 8.0
const NAMELESS := "(名無し)"
const SIGN_IN_NOTE := "サインインすると順位に載ります"
const LOAD_FAILED := "順位表を取得できませんでした"
const LOAD_FAILED_HINT := "通信状況を確認してください"
const LOADING := "順位表を読み込んでいます"
const NO_RECORD := "まだ今週の記録がありません"
## 縦画面(GameDesign.md 9章「縦画面」)。行は1行のまま拡大し、見出しと注記も大きくする。
const PORTRAIT_ROW_ZOOM := 1.25
const PORTRAIT_TITLE_SIZE := 30
const PORTRAIT_TITLE_HEIGHT := 44.0
const PORTRAIT_NOTE_SIZE := 24
const PORTRAIT_NOTE_HEIGHT := 36.0

var _back: Panel
var _title: Label
var _note: Label
var _scroll: ScrollContainer
var _rows: VBoxContainer
var _pinned: RankBoardRow
var _pinned_rule: ColorRect
var _empty: EmptyState
var _portrait := false
## 開いた回の識別。読み込み中に開き直されたら、古い読み込みの結果は捨てる。
var _generation := 0
var _own: Dictionary = {}
var _pinned_shown := false


func _ready() -> void:
	_build()


func _build() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_back = Panel.new()
	_back.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_back.add_theme_stylebox_override("panel", load(PANEL_STYLE))
	add_child(_back)
	_title = _make_label(TITLE, TITLE_SIZE, UiPalette.IVORY)
	add_child(_title)
	_note = _make_label(SIGN_IN_NOTE, NOTE_SIZE, UiPalette.MUTED)
	_note.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	add_child(_note)
	_pinned = RankBoardRow.new()
	_pinned.weekly = true
	_pinned.mine = true
	_pinned.visible = false
	add_child(_pinned)
	_pinned_rule = ColorRect.new()
	_pinned_rule.color = Color(UiPalette.SAND, 0.45)
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
	_layout()


func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED and _back != null:
		_layout()


func set_portrait(portrait: bool) -> void:
	_portrait = portrait
	if _back != null:
		_layout()


## 順位表を開く。`own` は自分の `{"wins", "hp"}`(まだ挑んでいなければ空。空なら最下段の自分の行を出さない)。
func open(week: String, own: Dictionary) -> void:
	_generation += 1
	var generation := _generation
	_own = own
	for child in _rows.get_children():
		_rows.remove_child(child)
		child.queue_free()
	_set_pinned(false)
	_note.visible = StageReward.current_uid().is_empty()
	_layout()
	_empty.show_message(LOADING, "", true)
	_empty.visible = true
	var rows: Variant = await WeeklyBoard.load_top(week)
	if generation != _generation:
		return
	if not (rows is Array):
		_empty.show_message(LOAD_FAILED, LOAD_FAILED_HINT)
		return
	if (rows as Array).is_empty():
		_empty.show_message(NO_RECORD, "")
		_show_own_row(0)
		return
	_empty.hide_message()
	var my_uid := StageReward.current_uid()
	for i in (rows as Array).size():
		var row := _row_from(rows[i])
		row.rank = i + 1
		row.zebra = i % 2 == 0
		row.mine = not my_uid.is_empty() and str(rows[i]["uid"]) == my_uid
		row.set_portrait(_portrait, PORTRAIT_ROW_ZOOM)
		_rows.add_child(row)
	_show_own_row(WeeklyBoard.rank_in(rows, my_uid))
	ListRevealFx.stagger(_rows.get_children())


func _row_from(data: Dictionary) -> RankBoardRow:
	var row := RankBoardRow.new()
	row.weekly = true
	var name := str(data.get("name", ""))
	row.display_name = name if not name.is_empty() else NAMELESS
	row.icon_id = str(data.get("icon", UserProfileLibrary.DEFAULT_ICON_ID))
	row.title_id = ""
	row.wins = int(data.get("wins", 0))
	row.hp_left = int(data.get("hp", 0))
	return row


## 最下段に自分の行を固定する。上位に入っていなければ順位は「圏外」。
func _show_own_row(rank: int) -> void:
	if _own.is_empty():
		return
	_pinned.rank = rank
	_pinned.display_name = AccountService.display_name_or_default()
	_pinned.icon_id = AccountService.icon_id()
	_pinned.title_id = ""
	_pinned.wins = int(_own.get("wins", 0))
	_pinned.hp_left = int(_own.get("hp", 0))
	_set_pinned(true)
	_pinned.queue_redraw()


func _set_pinned(shown: bool) -> void:
	_pinned_shown = shown
	_pinned.visible = shown
	_pinned_rule.visible = shown
	_layout()


func _layout() -> void:
	var inner := Rect2(PAD, size - PAD * 2.0)
	_place(_back, Rect2(Vector2.ZERO, size))
	var title_height := PORTRAIT_TITLE_HEIGHT if _portrait else TITLE_HEIGHT
	_title.add_theme_font_size_override(
		"font_size", PORTRAIT_TITLE_SIZE if _portrait else TITLE_SIZE
	)
	_place(_title, Rect2(inner.position, Vector2(inner.size.x, title_height)))
	var note_height := PORTRAIT_NOTE_HEIGHT if _portrait else NOTE_HEIGHT
	_note.add_theme_font_size_override("font_size", PORTRAIT_NOTE_SIZE if _portrait else NOTE_SIZE)
	_place(_note, Rect2(inner.position.x, inner.end.y - note_height, inner.size.x, note_height))
	var bottom := inner.end.y - (note_height if _note.visible else 0.0)
	for row in [_pinned] + _rows.get_children():
		(row as RankBoardRow).set_portrait(_portrait, PORTRAIT_ROW_ZOOM)
	var pinned_top := bottom
	if _pinned_shown:
		pinned_top = bottom - _pinned.row_height()
		_place(_pinned, Rect2(inner.position.x, pinned_top, inner.size.x, _pinned.row_height()))
		_place(
			_pinned_rule, Rect2(inner.position.x, pinned_top - PINNED_RULE_GAP, inner.size.x, 1.0)
		)
		pinned_top -= PINNED_RULE_GAP * 2.0
	var list_top := inner.position.y + title_height + LIST_TOP_GAP
	var list_rect := Rect2(inner.position.x, list_top, inner.size.x, pinned_top - list_top)
	_place(_scroll, list_rect)
	_place(_empty, list_rect)


func _place(node: Control, rect: Rect2) -> void:
	node.position = rect.position
	node.size = rect.size


func _make_label(text: String, font_size: int, color: Color) -> Label:
	var label := Label.new()
	label.text = text
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	return label
