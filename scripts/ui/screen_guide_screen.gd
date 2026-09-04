class_name ScreenGuideScreen
extends Control
## 「画面の見かた」(GameDesign.md 20章)。左に項目の一覧、中央に実際の描画で組んだ盤面、
## その下に説明を置く。項目を選ぶと盤面の該当箇所が脈打って光る。
##
## ルール画面(16章)がルールを順に読ませ、キーワード辞書(17章)が語を引かせるのに対し、
## ここは**画面に出ているものの意味を引く**場所として分けている。
##
## **盤面はクリックを受け付けない**(20章)。対局と同じ見た目である以上、押せそうに
## 見えるものが押せないことを避けるため、ホバーの反応も出さない。

signal back_pressed

const HEADER_SCENE := "res://scenes/screen_header.tscn"
const PANEL_STYLE := "res://resources/theme/content_panel.tres"

const LIST_RECT := Rect2(24, ScreenHeader.CONTENT_TOP, 244, 512)
const LIST_BUTTON_HEIGHT := 48.0
const LIST_GAP := 8.0
const LIST_FONT_SIZE := 19
## いま見ている項目のボタンに掛ける色。
const SELECTED_TINT := Color(1.3, 1.12, 0.82)

const BODY_LEFT := 288.0
const BODY_WIDTH := 1280.0 - BODY_LEFT - ScreenHeader.OUTER_MARGIN
const STAGE_RECT := Rect2(BODY_LEFT, ScreenHeader.CONTENT_TOP, BODY_WIDTH, 412)
const BODY_RECT := Rect2(BODY_LEFT, 564, BODY_WIDTH, 132)
const BODY_PADDING := 18.0
const BODY_FONT_SIZE := 18
const TITLE_FONT_SIZE := 22

## 光らせる枠。脈打たせるのは、静止した枠だと盤面の罫線と見分けがつかないため。
const HIGHLIGHT_COLOR := Color(0.55, 0.9, 1.0)
const HIGHLIGHT_PERIOD := 1.1
const HIGHLIGHT_GROW := 6.0
const HIGHLIGHT_WIDTH := 2.5
## 外へ広がる輪の本数。1本だと盤面の罫線や台座の輪と紛れる。
const HIGHLIGHT_RINGS := [0, 1, 2]

var _index := 0
var _buttons: Array[Button] = []
var _stage: ScreenGuideStage
var _overlay: Control
var _title: Label
var _body: Label
var _elapsed := 0.0


func _ready() -> void:
	_build()
	select(0)


## ホーム画面から入るたびに先頭へ戻す(進捗は保存しない。GameDesign.md 20章)。
func restart() -> void:
	select(0)


func select(index: int) -> void:
	if index < 0 or index >= ScreenGuideEntries.ENTRIES.size():
		return
	_index = index
	var entry: Dictionary = ScreenGuideEntries.ENTRIES[index]
	_title.text = str(entry["title"])
	_body.text = str(entry["body"])
	# **選んでいる項目は暗くせず明るくする。**`disabled` にすると「押せない項目」に
	# 見えてしまい、いま見ているところだと読めない。
	for i in _buttons.size():
		_buttons[i].modulate = SELECTED_TINT if i == index else Color(1, 1, 1)
	_overlay.queue_redraw()


func _process(delta: float) -> void:
	_elapsed += delta
	_overlay.queue_redraw()


func _build() -> void:
	var backdrop := ScreenBackdrop.new()
	backdrop.room = ScreenBackdrop.Room.LIBRARY
	add_child(backdrop)
	var header: ScreenHeader = load(HEADER_SCENE).instantiate()
	add_child(header)
	header.set_title("画面の見かた")
	header.back_pressed.connect(func() -> void: back_pressed.emit())

	_stage = ScreenGuideStage.new()
	_stage.position = STAGE_RECT.position
	_stage.size = STAGE_RECT.size
	add_child(_stage)
	_stage.build()

	# 光る枠は盤面より手前へ出す(`Control._draw()` は自分の子より背面に描かれるため、
	# ステージ側で描くと駒に隠れる。Architecture.md 11章)。
	_overlay = Control.new()
	_overlay.position = STAGE_RECT.position
	_overlay.size = STAGE_RECT.size
	_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_overlay.draw.connect(_draw_overlay)
	add_child(_overlay)

	_build_list()
	_build_body()


func _build_list() -> void:
	for i in ScreenGuideEntries.ENTRIES.size():
		var entry: Dictionary = ScreenGuideEntries.ENTRIES[i]
		var button := CodedButton.make(
			str(entry["title"]), Vector2(LIST_RECT.size.x, LIST_BUTTON_HEIGHT)
		)
		button.position = Vector2(
			LIST_RECT.position.x, LIST_RECT.position.y + (LIST_BUTTON_HEIGHT + LIST_GAP) * i
		)
		button.add_theme_font_size_override("font_size", LIST_FONT_SIZE)
		button.pressed.connect(select.bind(i))
		add_child(button)
		_buttons.append(button)


func _build_body() -> void:
	var panel := Panel.new()
	panel.position = BODY_RECT.position
	panel.size = BODY_RECT.size
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var style: StyleBox = load(PANEL_STYLE)
	if style != null:
		panel.add_theme_stylebox_override("panel", style)
	add_child(panel)

	_title = Label.new()
	_title.position = BODY_RECT.position + Vector2(BODY_PADDING, BODY_PADDING * 0.6)
	_title.size = Vector2(BODY_RECT.size.x - BODY_PADDING * 2.0, 30)
	_title.add_theme_font_size_override("font_size", TITLE_FONT_SIZE)
	_title.add_theme_color_override("font_color", UiPalette.GLOW_AMBER)
	_title.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_title)

	_body = Label.new()
	# 折り返しは `size` より先に立てる(`RulesTab._add_caption()` と同じ理由)。
	_body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_body.position = BODY_RECT.position + Vector2(BODY_PADDING, BODY_PADDING * 0.6 + 32)
	_body.size = Vector2(
		BODY_RECT.size.x - BODY_PADDING * 2.0, BODY_RECT.size.y - BODY_PADDING - 34
	)
	_body.add_theme_font_size_override("font_size", BODY_FONT_SIZE)
	_body.add_theme_color_override("font_color", UiPalette.TEXT_OFFWHITE)
	_body.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_body)


## 選んだ項目の場所を脈打つ枠で囲む。**外へ広がる輪を3重に重ねる**。1本の細い枠だと
## 盤面の罫線や台座の輪と紛れて、どこを指しているのか読み取れなかった。
##
## **周りを暗幕で落とす案は採らない。**光らせる場所は「上下2本の情報帯」のように
## 離れて複数あることがあり、その外側だけを塗るには盤面を格子状に走査することになる
## (毎フレーム数千の矩形を描くことになり、見た目の得に対して割に合わない)。
func _draw_overlay() -> void:
	var entry: Dictionary = ScreenGuideEntries.ENTRIES[_index]
	var rects: Array = _stage.region(str(entry["region"]))
	var pulse: float = 0.5 + 0.5 * sin(_elapsed * TAU / HIGHLIGHT_PERIOD)
	for rect: Rect2 in rects:
		_overlay.draw_rect(rect, Color(HIGHLIGHT_COLOR, 0.10 + 0.07 * pulse))
		for ring in HIGHLIGHT_RINGS:
			var spread: float = 2.0 + HIGHLIGHT_GROW * (float(ring) + pulse)
			var alpha: float = 0.9 / (float(ring) + 1.0)
			_overlay.draw_rect(
				rect.grow(spread), Color(HIGHLIGHT_COLOR, alpha), false, HIGHLIGHT_WIDTH
			)
