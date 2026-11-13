class_name RuleScreen
extends Control
## ルール(遊び方)の紙芝居(GameDesign.md 16章)。
##
## 左に章の目次、右に「見出し・本文・実際にレンダリングされた盤面・ページ送り」を置く。
## 順に読ませる導線(次へ)と、あとから1点だけ調べに戻る導線(目次)の両方を持たせ、
## チュートリアルではなくリファレンスとしても使えるようにしている。

signal back_pressed

const HEADER_SCENE := "res://scenes/screen_header.tscn"
const PANEL_STYLE := "res://resources/theme/content_panel.tres"

const TOC_RECT := Rect2(24, ScreenHeader.CONTENT_TOP, 224, ScreenHeader.CONTENT_HEIGHT)
const TOC_BUTTON_HEIGHT := 60.0
const TOC_GAP := 12.0

const BODY_LEFT := 272.0
const BODY_WIDTH := 1280.0 - BODY_LEFT - ScreenHeader.OUTER_MARGIN

const HEADING_RECT := Rect2(BODY_LEFT, ScreenHeader.CONTENT_TOP, BODY_WIDTH, 40)
const HEADING_FONT_SIZE := UiPalette.T_HEAD
const BODY_RECT := Rect2(BODY_LEFT, 182, BODY_WIDTH, 84)
const BODY_FONT_SIZE := UiPalette.T_BODY
const STAGE_RECT := Rect2(BODY_LEFT, 274, BODY_WIDTH, 350)
## 盤面の中身を枠線から離す(縦で手札の端の札が金線に重なるため)。
const STAGE_SIDE_INSET := 12.0

const CONTROLS_Y := 636.0
const NAV_BUTTON_SIZE := Vector2(150, 52)
const REPLAY_BUTTON_SIZE := Vector2(200, 52)
const COUNTER_SIZE := Vector2(120, 52)
const COUNTER_FONT_SIZE := UiPalette.T_LEAD

## 縦画面(GameDesign.md 9章「縦画面」)。上から「章のボタン(2列)/ 見出し / 本文 / 盤面 / ページ送り」と積む。
const PORTRAIT_TOC_COLUMNS := 2
const PORTRAIT_TOC_BUTTON_HEIGHT := 72.0
const PORTRAIT_GAP := 12.0
const PORTRAIT_HEADING_HEIGHT := 48.0
const PORTRAIT_HEADING_FONT := UiPalette.T_TITLE
const PORTRAIT_BODY_HEIGHT := 190.0
const PORTRAIT_BODY_FONT := 24
const PORTRAIT_BUTTON_FONT := 24
const PORTRAIT_CONTROL_HEIGHT := 72.0
const PORTRAIT_NAV_WIDTH := 170.0
const PORTRAIT_REPLAY_WIDTH := 220.0
const PORTRAIT_COUNTER_FONT := 26

## ページが替わるときの入り(GameDesign.md 9章「操作への反応」)。進む向きへ横から入る。
const PAGE_SHIFT := 16.0
const BASE_X_META := &"base_x"

var _pages: Array = []
var _index := 0
var _chapter_buttons: Array[Button] = []
var _heading: Label
var _body: Label
var _counter: Label
var _stage: RuleStage
var _prev_button: Button
var _next_button: Button
var _replay_button: Button
var _header: ScreenHeader
var _stage_panel: PanelContainer
var _chapter_mark: Label
var _mark_chapter := -1
var _shown_index := -1
var _page_tween: Tween
var _mark_tween: Tween


func _ready() -> void:
	_pages = RulePages.pages()
	_build()
	show_page(0)


## 章の先頭から開き直す。ホーム画面から入るたびに先頭へ戻す(進捗は保存しない)。
func restart() -> void:
	show_page(0, false)


## `animate` が偽、または前と同じ番号なら動かさず最終値を置く(縦横の組み替え・初回表示)。
func show_page(index: int, animate := true) -> void:
	if _pages.is_empty():
		return
	_index = clampi(index, 0, _pages.size() - 1)
	var move := animate and _shown_index >= 0 and _shown_index != _index
	var direction := 1.0 if _index > _shown_index else -1.0
	_shown_index = _index
	var page: Dictionary = _pages[_index]
	_heading.text = str(page.get("heading", ""))
	_body.text = str(page.get("body", ""))
	_counter.text = "%d / %d" % [_index + 1, _pages.size()]
	_prev_button.disabled = _index == 0
	_next_button.disabled = _index == _pages.size() - 1
	_stage.show_page(page)
	_replay_button.visible = _stage.has_animation()
	_highlight_chapter(int(page.get("chapter", 0)), move)
	_reset_page_motion()
	if move:
		_play_page_in(direction)


func _build() -> void:
	var backdrop := ScreenBackdrop.new()
	backdrop.room = ScreenBackdrop.Room.LIBRARY
	add_child(backdrop)

	var header: ScreenHeader = load(HEADER_SCENE).instantiate()
	add_child(header)
	_header = header
	header.set_title("遊び方")
	header.back_pressed.connect(func() -> void: back_pressed.emit())

	_build_toc()

	_heading = _make_label(HEADING_RECT, HEADING_FONT_SIZE, UiPalette.GOLD)
	_body = _make_label(BODY_RECT, BODY_FONT_SIZE, UiPalette.IVORY)
	_body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_body.vertical_alignment = VERTICAL_ALIGNMENT_TOP

	# 盤面は他の画面と同じコンテンツパネルの上へ載せる。下地に直接置くと、
	# 説明文と同じ面に浮いていて「実演の枠」として読めない。
	var stage_panel := PanelContainer.new()
	stage_panel.position = STAGE_RECT.position
	stage_panel.size = STAGE_RECT.size
	stage_panel.custom_minimum_size = STAGE_RECT.size
	stage_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var style: StyleBox = load(PANEL_STYLE)
	if style != null:
		stage_panel.add_theme_stylebox_override("panel", style)
	add_child(stage_panel)
	_stage_panel = stage_panel

	_stage = RuleStage.new()
	add_child(_stage)
	_place_stage(STAGE_RECT)

	_build_controls()


func _build_toc() -> void:
	for i in RulePages.CHAPTERS.size():
		var chapter: Dictionary = RulePages.CHAPTERS[i]
		var button := CodedButton.make(
			str(chapter["title"]), Vector2(TOC_RECT.size.x, TOC_BUTTON_HEIGHT)
		)
		button.position = Vector2(
			TOC_RECT.position.x, TOC_RECT.position.y + (TOC_BUTTON_HEIGHT + TOC_GAP) * float(i)
		)
		button.pressed.connect(func() -> void: show_page(RulePages.first_page_of(i)))
		add_child(button)
		_chapter_buttons.append(button)
	_chapter_mark = Label.new()
	_chapter_mark.text = KeywordDictScreen.SELECTED_MARK
	_chapter_mark.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_chapter_mark.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_chapter_mark.add_theme_color_override("font_color", UiPalette.SAND_HI)
	_chapter_mark.visible = false
	add_child(_chapter_mark)


func _build_controls() -> void:
	_prev_button = CodedButton.make("前へ", NAV_BUTTON_SIZE)
	_prev_button.position = Vector2(BODY_LEFT, CONTROLS_Y)
	_prev_button.pressed.connect(func() -> void: show_page(_index - 1))
	add_child(_prev_button)

	_counter = _make_label(
		Rect2(BODY_LEFT + NAV_BUTTON_SIZE.x + 12.0, CONTROLS_Y, COUNTER_SIZE.x, COUNTER_SIZE.y),
		COUNTER_FONT_SIZE,
		UiPalette.IVORY
	)
	_counter.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_counter.vertical_alignment = VERTICAL_ALIGNMENT_CENTER

	_replay_button = CodedButton.make("もう一度見る", REPLAY_BUTTON_SIZE)
	_replay_button.position = Vector2(
		BODY_LEFT + (BODY_WIDTH - REPLAY_BUTTON_SIZE.x) * 0.5, CONTROLS_Y
	)
	_replay_button.pressed.connect(func() -> void: _stage.play())
	add_child(_replay_button)

	_next_button = CodedButton.make("次へ", NAV_BUTTON_SIZE)
	_next_button.position = Vector2(BODY_LEFT + BODY_WIDTH - NAV_BUTTON_SIZE.x, CONTROLS_Y)
	_next_button.pressed.connect(func() -> void: show_page(_index + 1))
	add_child(_next_button)


## 縦横が変わったときに `Main` から呼ばれる(Architecture.md 4.7節)。読んでいるページは保つ。
func apply_orientation(portrait: bool) -> void:
	if _header == null:
		return
	_header.apply_orientation(portrait)
	if portrait:
		_layout_portrait()
	else:
		_layout_landscape()
	# 盤面は枠の大きさに合わせて組み直す(`RuleStage._fit()`)。
	show_page(_index, false)


func _layout_landscape() -> void:
	for i in _chapter_buttons.size():
		var at := Vector2(
			TOC_RECT.position.x, TOC_RECT.position.y + (TOC_BUTTON_HEIGHT + TOC_GAP) * float(i)
		)
		_place(_chapter_buttons[i], Rect2(at, Vector2(TOC_RECT.size.x, TOC_BUTTON_HEIGHT)), 0)
	_place_label(_heading, HEADING_RECT, HEADING_FONT_SIZE)
	_place_label(_body, BODY_RECT, BODY_FONT_SIZE)
	_place_stage(STAGE_RECT)
	_place(_prev_button, Rect2(Vector2(BODY_LEFT, CONTROLS_Y), NAV_BUTTON_SIZE), 0)
	_place_label(
		_counter,
		Rect2(BODY_LEFT + NAV_BUTTON_SIZE.x + 12.0, CONTROLS_Y, COUNTER_SIZE.x, COUNTER_SIZE.y),
		COUNTER_FONT_SIZE
	)
	_place(
		_replay_button,
		Rect2(
			Vector2(BODY_LEFT + (BODY_WIDTH - REPLAY_BUTTON_SIZE.x) * 0.5, CONTROLS_Y),
			REPLAY_BUTTON_SIZE
		),
		0
	)
	_place(
		_next_button,
		Rect2(Vector2(BODY_LEFT + BODY_WIDTH - NAV_BUTTON_SIZE.x, CONTROLS_Y), NAV_BUTTON_SIZE),
		0
	)


func _layout_portrait() -> void:
	var content := _header.portrait_content_rect()
	var left := content.position.x
	var width := content.size.x
	var column_w := (width - PORTRAIT_GAP) / PORTRAIT_TOC_COLUMNS
	for i in _chapter_buttons.size():
		var at := Vector2(
			left + (column_w + PORTRAIT_GAP) * (i % PORTRAIT_TOC_COLUMNS),
			content.position.y + (PORTRAIT_TOC_BUTTON_HEIGHT + PORTRAIT_GAP) * floorf(i / 2.0)
		)
		_place(
			_chapter_buttons[i],
			Rect2(at, Vector2(column_w, PORTRAIT_TOC_BUTTON_HEIGHT)),
			PORTRAIT_BUTTON_FONT
		)
	var rows := ceili(float(_chapter_buttons.size()) / PORTRAIT_TOC_COLUMNS)
	var y := content.position.y + rows * (PORTRAIT_TOC_BUTTON_HEIGHT + PORTRAIT_GAP) + PORTRAIT_GAP
	_place_label(_heading, Rect2(left, y, width, PORTRAIT_HEADING_HEIGHT), PORTRAIT_HEADING_FONT)
	y += PORTRAIT_HEADING_HEIGHT + PORTRAIT_GAP
	_place_label(_body, Rect2(left, y, width, PORTRAIT_BODY_HEIGHT), PORTRAIT_BODY_FONT)
	y += PORTRAIT_BODY_HEIGHT + PORTRAIT_GAP
	var controls_y := content.end.y - PORTRAIT_CONTROL_HEIGHT
	_place_stage(Rect2(left, y, width, controls_y - PORTRAIT_GAP - y))
	var nav := Vector2(PORTRAIT_NAV_WIDTH, PORTRAIT_CONTROL_HEIGHT)
	_place(_prev_button, Rect2(Vector2(left, controls_y), nav), PORTRAIT_BUTTON_FONT)
	_place(
		_next_button, Rect2(Vector2(content.end.x - nav.x, controls_y), nav), PORTRAIT_BUTTON_FONT
	)
	# 「もう一度見る」は前へ・次への間、ページ数はその上の盤面の右下に重ねずにボタンの間へ置く。
	var middle := Rect2(
		left + nav.x + PORTRAIT_GAP, controls_y, width - (nav.x + PORTRAIT_GAP) * 2.0, nav.y
	)
	_place(
		_replay_button,
		Rect2(
			Vector2(middle.position.x, controls_y),
			Vector2(PORTRAIT_REPLAY_WIDTH, PORTRAIT_CONTROL_HEIGHT)
		),
		PORTRAIT_BUTTON_FONT
	)
	_place_label(
		_counter,
		Rect2(
			middle.position.x + PORTRAIT_REPLAY_WIDTH,
			controls_y,
			middle.size.x - PORTRAIT_REPLAY_WIDTH,
			nav.y
		),
		PORTRAIT_COUNTER_FONT
	)


func _place_stage(rect: Rect2) -> void:
	_stage_panel.position = rect.position
	_stage_panel.custom_minimum_size = rect.size
	_stage_panel.size = rect.size
	_stage.position = rect.position + Vector2(STAGE_SIDE_INSET, 0.0)
	_stage.size = rect.size - Vector2(STAGE_SIDE_INSET * 2.0, 0.0)


## ボタンを置き直す。`font` が0なら文字の大きさは作ったとき(テーマ)のまま。
func _place(button: Control, rect: Rect2, font: int) -> void:
	button.custom_minimum_size = rect.size
	button.size = rect.size
	button.position = rect.position
	if font > 0:
		button.add_theme_font_size_override("font_size", font)
	else:
		button.remove_theme_font_size_override("font_size")


func _place_label(label: Label, rect: Rect2, font: int) -> void:
	label.custom_minimum_size = rect.size
	label.size = rect.size
	label.position = rect.position
	label.set_meta(BASE_X_META, rect.position.x)
	label.add_theme_font_size_override("font_size", font)


## いま読んでいる章のボタンだけ文字色を琥珀にし、砂色の印をそのボタンへ置く。目次は現在地の表示も兼ねる。
## 章が替わったときだけ印を次のボタンへ滑らせる(同じ章のページ送りでは動かさない)。
func _highlight_chapter(chapter_index: int, animate: bool) -> void:
	for i in _chapter_buttons.size():
		var color: Color = UiPalette.SAND_HI if i == chapter_index else UiPalette.IVORY
		_chapter_buttons[i].add_theme_color_override("font_color", color)
	var button := _chapter_buttons[chapter_index]
	var portrait := ScreenOrientation.is_portrait()
	var font := KeywordDictScreen.PORTRAIT_MARK_FONT if portrait else KeywordDictScreen.MARK_FONT
	var left := KeywordDictScreen.PORTRAIT_MARK_LEFT if portrait else KeywordDictScreen.MARK_LEFT
	var target := button.position + Vector2(left, 0.0)
	var moving := animate and _chapter_mark.visible and chapter_index != _mark_chapter
	if not animate and _mark_tween != null and _mark_tween.is_valid():
		_mark_tween.kill()
	_chapter_mark.add_theme_font_size_override("font_size", font)
	_chapter_mark.size = Vector2(font * 2.0, button.size.y)
	_chapter_mark.visible = true
	_mark_chapter = chapter_index
	if moving:
		if _mark_tween != null and _mark_tween.is_valid():
			_mark_tween.kill()
		_mark_tween = create_tween().set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
		_mark_tween.tween_property(_chapter_mark, "position", target, UiPalette.DUR_HOVER)
	elif _mark_tween == null or not _mark_tween.is_valid():
		_chapter_mark.position = target


## 連打で途中の入りを殺すときは、位置と透明度を最終値へ戻してから次を始める。
func _reset_page_motion() -> void:
	if _page_tween != null and _page_tween.is_valid():
		_page_tween.kill()
	for label: Label in [_heading, _body]:
		label.modulate.a = 1.0
		label.position.x = float(label.get_meta(BASE_X_META, label.position.x))
	_stage.modulate.a = 1.0


## 中身は即時に差し替え済み。新しい中身が進む向きの横から入る。盤面は枠を動かさず透明度だけ。
func _play_page_in(direction: float) -> void:
	_page_tween = create_tween().set_parallel(true)
	_page_tween.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
	for label: Label in [_heading, _body]:
		var base_x := float(label.get_meta(BASE_X_META, label.position.x))
		label.modulate.a = 0.0
		label.position.x = base_x + PAGE_SHIFT * direction
		_page_tween.tween_property(label, "modulate:a", 1.0, UiPalette.DUR_HOVER)
		_page_tween.tween_property(label, "position:x", base_x, UiPalette.DUR_HOVER)
	_stage.modulate.a = 0.0
	_page_tween.tween_property(_stage, "modulate:a", 1.0, UiPalette.DUR_HOVER)


func _make_label(rect: Rect2, font_size: int, color: Color) -> Label:
	var label := Label.new()
	label.position = rect.position
	label.size = rect.size
	label.custom_minimum_size = rect.size
	label.set_meta(BASE_X_META, rect.position.x)
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(label)
	return label
