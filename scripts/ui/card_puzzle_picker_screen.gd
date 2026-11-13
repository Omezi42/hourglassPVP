class_name CardPuzzlePickerScreen
extends Control
## リーサルパズルのステージ選択(GameDesign.md 24章)。
## 共通のレイアウト規約(GameDesign.md 9章)に従い、`ScreenHeader` と横2列のグリッドで組む。

signal back_pressed
signal stage_selected(stage: PuzzleStageData)
## エンドレス(GameDesign.md 24章)の入口が押された。出題は呼び出し側
## (`Main`)が `EndlessPuzzles.next()` で行う——この画面は
## 固定の問題の一覧と入口を並べる責務だけを持つ。
signal endless_selected

const HEADER_SCENE := "res://scenes/screen_header.tscn"
const PANEL_STYLE := "res://resources/theme/content_panel.tres"
const GRID_RECT := Rect2(24, ScreenHeader.CONTENT_TOP, 1232, ScreenHeader.CONTENT_HEIGHT)
const COLUMNS := 2
## 1問ぶんの札。**高さは全問そろえる**——ヒントが2行になる問題だけ背が高いと、
## 2列のグリッドで行ごとに段差が出て、並びが落ち着かない。
## 2行のヒントが収まる高さを最初から取り、1行の問題は下が空くに任せる。
const CARD_SIZE := Vector2(596, 132)
## ヒントの折り返し幅を決めるため、「挑戦」と余白を引いた値を見出しへ渡す。
const ACTION_SIZE := Vector2(132, 52)
const ROW_SEPARATION := 12
const TITLE_FONT := UiPalette.T_LEAD
const HINT_FONT := UiPalette.T_SMALL
## 縦画面(GameDesign.md 9章「縦画面」)。1列にし、札の幅を画面いっぱいに、文字とボタンを目安まで大きくする。
const PORTRAIT_CARD_HEIGHT := 168.0
const PORTRAIT_ACTION_SIZE := Vector2(132, 72)
const PORTRAIT_TITLE_FONT := 28
const PORTRAIT_HINT_FONT := 24
## 縦の札の幅 = スクロール領域の幅 - この値(縦バー8 + 札との間8)。右の余白を左(24)にそろえる。
const SCROLLBAR_GUTTER := 16.0
## 解いた札の右上に描く星の半径。
const CLEAR_MARK_RADIUS := 7.0
const PORTRAIT_CLEAR_MARK_RADIUS := 10.0
## ヘッダーの右に出す、固定の問題の進み具合の文字。
const PROGRESS_FONT := UiPalette.T_LEAD
const PORTRAIT_PROGRESS_FONT := 28
## ヒントを句読点で折る改行。
const HINT_BREAK := "\n"
## 今日の1問を解いたあと、添える文の後ろ半分(ホームの「今日の1問 クリア済み」と同じ言い方)。
const CLEARED_NOTE := "クリア済み"

var _grid: GridContainer
var _header: ScreenHeader
var _scroll: ScrollContainer
var _progress: Label
var _portrait := false


func _ready() -> void:
	_build()


func open() -> void:
	_refresh()


func _build() -> void:
	var backdrop := ScreenBackdrop.new()
	backdrop.room = ScreenBackdrop.Room.HALL
	add_child(backdrop)
	var header: ScreenHeader = load(HEADER_SCENE).instantiate()
	add_child(header)
	_header = header
	header.set_title("リーサルパズル")
	header.back_pressed.connect(func() -> void: back_pressed.emit())
	_progress = Label.new()
	_progress.anchor_left = 1.0
	_progress.anchor_right = 1.0
	_progress.anchor_bottom = 1.0
	_progress.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	_progress.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_progress.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_progress.add_theme_color_override("font_color", UiPalette.IVORY)
	header.add_child(_progress)

	var scroll := ScrollContainer.new()
	scroll.position = GRID_RECT.position
	scroll.size = GRID_RECT.size
	scroll.custom_minimum_size = GRID_RECT.size
	TouchScroll.enable(scroll)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	add_child(scroll)
	_scroll = scroll

	_grid = GridContainer.new()
	_grid.columns = COLUMNS
	_grid.add_theme_constant_override("h_separation", 16)
	_grid.add_theme_constant_override("v_separation", 16)
	scroll.add_child(_grid)


## 縦横が変わったときに `Main` から呼ばれる(Architecture.md 4.7節)。札は大きさが変わるため作り直す。
func apply_orientation(portrait: bool) -> void:
	_portrait = portrait
	if _header == null:
		return
	_header.apply_orientation(portrait)
	var rect := _header.portrait_content_rect() if portrait else GRID_RECT
	_scroll.position = rect.position
	_scroll.custom_minimum_size = rect.size
	_scroll.size = rect.size
	_grid.columns = 1 if portrait else COLUMNS
	_progress.add_theme_font_size_override(
		"font_size", PORTRAIT_PROGRESS_FONT if portrait else PROGRESS_FONT
	)
	_refresh()


func _refresh() -> void:
	# 外してから消す。残したままだと、消える前の札までグリッドの升目と登場演出に数えられる。
	for child in _grid.get_children():
		_grid.remove_child(child)
		child.queue_free()
	var uid := _uid()
	# 今日の1問が先頭、エンドレスがその次(GameDesign.md 24章)。どちらも固定の問題とは別枠。
	var daily := DailyPuzzle.today()
	if daily != null:
		_grid.add_child(_make_daily_card(daily, PuzzleProgress.is_cleared(uid, daily.id)))
	_grid.add_child(_make_endless_card())
	var stages := PuzzleLibrary.all_stages()
	var solved := 0
	for stage in stages:
		var cleared := PuzzleProgress.is_cleared(uid, stage.id)
		solved += 1 if cleared else 0
		_grid.add_child(_make_card(stage, cleared))
	# 今日の1問とエンドレスは数えない(固定の問題の進み具合)。
	_progress.text = "%d / %d" % [solved, stages.size()]
	ListRevealFx.stagger(_grid.get_children())


func _make_daily_card(stage: PuzzleStageData, cleared: bool) -> Control:
	var note := CLEARED_NOTE if cleared else "初回クリアで%d砂金" % PuzzleProgress.CLEAR_REWARD
	return _make_entry_card(
		"今日の1問",
		"%s ・ %s" % [stage.title, note],
		func() -> void: stage_selected.emit(stage),
		cleared
	)


## エンドレスの入口。固定の問題と同じ札の形を使い、狙いを1行添える
## (GameDesign.md 9章「いまの状態を1行添えた札」と同じ考え方)。
func _make_endless_card() -> Control:
	return _make_entry_card(
		"エンドレス", "次々に問題が出る。腕試し専用(報酬なし)", func() -> void: endless_selected.emit(), false
	)


## 1問ぶんの横長カード。**クリア済みは印だけで示す**——解けた問題を暗くして
## 選びにくくすると、解き直して確かめることができなくなる。
func _make_card(stage: PuzzleStageData, cleared: bool) -> Control:
	return _make_entry_card(
		stage.title, stage.hint, func() -> void: stage_selected.emit(stage), cleared
	)


func _make_entry_card(
	title_text: String, hint_text: String, on_pressed: Callable, cleared: bool
) -> Control:
	var card_size := CARD_SIZE
	var action_size := ACTION_SIZE
	if _portrait:
		card_size = Vector2(_scroll.size.x - SCROLLBAR_GUTTER, PORTRAIT_CARD_HEIGHT)
		action_size = PORTRAIT_ACTION_SIZE
	var panel := PuzzleEntryCard.new()
	panel.custom_minimum_size = card_size
	panel.tapped.connect(on_pressed)
	panel.cleared = cleared
	panel.mark_radius = PORTRAIT_CLEAR_MARK_RADIUS if _portrait else CLEAR_MARK_RADIUS
	var style: StyleBox = load(PANEL_STYLE)
	var inner_width := card_size.x
	if style != null:
		panel.add_theme_stylebox_override("panel", style)
		inner_width -= style.get_margin(SIDE_LEFT) + style.get_margin(SIDE_RIGHT)

	var row := HBoxContainer.new()
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_theme_constant_override("separation", ROW_SEPARATION)
	panel.add_child(row)

	# 見出しとヒントは上へ寄せる。中央揃えのままだと、1行の問題と2行の問題で
	# 見出しの高さがそろわない。
	var column := VBoxContainer.new()
	column.mouse_filter = Control.MOUSE_FILTER_IGNORE
	column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	column.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	row.add_child(column)
	var title := Label.new()
	title.text = title_text
	title.clip_text = true
	title.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var title_font := PORTRAIT_TITLE_FONT if _portrait else TITLE_FONT
	title.add_theme_font_size_override("font_size", title_font)
	column.add_child(title)
	var hint := Label.new()
	var hint_font := PORTRAIT_HINT_FONT if _portrait else HINT_FONT
	# 折り返す幅を先に決める。幅0のまま高さを見積もると1文字ずつ折り返した高さになり、
	# グリッドの行が縦に伸びて2行目以降が画面の外へ押し出される。
	var hint_width := inner_width - action_size.x - ROW_SEPARATION
	hint.custom_minimum_size.x = hint_width
	hint.text = _break_hint(hint_text, hint.get_theme_font("font"), hint_font, hint_width)
	hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	hint.add_theme_font_size_override("font_size", hint_font)
	hint.add_theme_color_override("font_color", UiPalette.MUTED)
	column.add_child(hint)

	var button := CodedButton.make("挑戦", action_size)
	if _portrait:
		button.add_theme_font_size_override("font_size", ScreenHeader.PORTRAIT_BUTTON_FONT)
	button.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	panel.bind_button(button)
	row.add_child(button)
	return panel


## 1行に収まらないヒントは、「、」「。」の直後で折る(語の途中で折れないように)。
## 前半・後半の両方が `width` に収まる最後の句読点を選び、見つからなければ自動の折り返しに任せる。
static func _break_hint(text: String, font: Font, font_size: int, width: float) -> String:
	if font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x <= width:
		return text
	for i in range(text.length() - 2, -1, -1):
		if text[i] != "、" and text[i] != "。":
			continue
		var head := text.substr(0, i + 1)
		var tail := text.substr(i + 1)
		var head_width := font.get_string_size(head, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x
		var tail_width := font.get_string_size(tail, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x
		if head_width <= width and tail_width <= width:
			return head + HINT_BREAK + tail
	return text


func _uid() -> String:
	if NetSession.client == null or NetSession.client.auth == null:
		return ""
	return NetSession.client.auth.uid
