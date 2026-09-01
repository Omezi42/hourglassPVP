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
const HEADING_FONT_SIZE := 27
const BODY_RECT := Rect2(BODY_LEFT, 182, BODY_WIDTH, 84)
const BODY_FONT_SIZE := 18
const STAGE_RECT := Rect2(BODY_LEFT, 274, BODY_WIDTH, 350)

const CONTROLS_Y := 636.0
const NAV_BUTTON_SIZE := Vector2(150, 52)
const REPLAY_BUTTON_SIZE := Vector2(200, 52)
const COUNTER_SIZE := Vector2(120, 52)
const COUNTER_FONT_SIZE := 20

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


func _ready() -> void:
	_pages = RulePages.pages()
	_build()
	show_page(0)


## 章の先頭から開き直す。ホーム画面から入るたびに先頭へ戻す(進捗は保存しない)。
func restart() -> void:
	show_page(0)


func show_page(index: int) -> void:
	if _pages.is_empty():
		return
	_index = clampi(index, 0, _pages.size() - 1)
	var page: Dictionary = _pages[_index]
	_heading.text = str(page.get("heading", ""))
	_body.text = str(page.get("body", ""))
	_counter.text = "%d / %d" % [_index + 1, _pages.size()]
	_prev_button.disabled = _index == 0
	_next_button.disabled = _index == _pages.size() - 1
	_stage.show_page(page)
	_replay_button.visible = _stage.has_animation()
	_highlight_chapter(int(page.get("chapter", 0)))


func _build() -> void:
	add_child(ScreenBackdrop.new())

	var header: ScreenHeader = load(HEADER_SCENE).instantiate()
	add_child(header)
	header.set_title("遊び方")
	header.back_pressed.connect(func() -> void: back_pressed.emit())

	_build_toc()

	_heading = _make_label(HEADING_RECT, HEADING_FONT_SIZE, UiPalette.GLOW_AMBER)
	_body = _make_label(BODY_RECT, BODY_FONT_SIZE, UiPalette.TEXT_OFFWHITE)
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

	_stage = RuleStage.new()
	_stage.position = STAGE_RECT.position
	_stage.size = STAGE_RECT.size
	add_child(_stage)

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


func _build_controls() -> void:
	_prev_button = CodedButton.make("前へ", NAV_BUTTON_SIZE)
	_prev_button.position = Vector2(BODY_LEFT, CONTROLS_Y)
	_prev_button.pressed.connect(func() -> void: show_page(_index - 1))
	add_child(_prev_button)

	_counter = _make_label(
		Rect2(BODY_LEFT + NAV_BUTTON_SIZE.x + 12.0, CONTROLS_Y, COUNTER_SIZE.x, COUNTER_SIZE.y),
		COUNTER_FONT_SIZE,
		UiPalette.TEXT_OFFWHITE
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


## いま読んでいる章のボタンだけ文字色を琥珀にする。目次は現在地の表示も兼ねる。
func _highlight_chapter(chapter_index: int) -> void:
	for i in _chapter_buttons.size():
		var color: Color = UiPalette.GLOW_AMBER if i == chapter_index else UiPalette.TEXT_OFFWHITE
		_chapter_buttons[i].add_theme_color_override("font_color", color)


func _make_label(rect: Rect2, font_size: int, color: Color) -> Label:
	var label := Label.new()
	label.position = rect.position
	label.size = rect.size
	label.custom_minimum_size = rect.size
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(label)
	return label
