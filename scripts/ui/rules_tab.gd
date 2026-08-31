class_name RulesTab
extends Control
## ホーム画面の「ルール」タブ(GameDesign.md 9章)。
##
## **「遊んで覚える」と「読んで覚える」の2つの枠に分ける**(9章)。前者は誘導対局
## (18章)、後者は「遊び方」(16章)・「画面の見かた」(20章)・「キーワード辞書」(17章)。
## **入口を縦に4つ並べる形は採らない。**タブの高さは下部タブとアカウント帯に挟まれた
## 448pxしかなく4行では収まらず、加えて手を動かして覚える道と読んで覚える道は
## 性質が違うため、同じ列に並べるより枠を分けたほうが選びやすい。
##
## 章の目次や語の一覧はそれぞれの画面側にあり、ここへ並べると同じ一覧が2箇所に出て
## どちらが本体か分からなくなるため、入口だけを置く。
## `DeckTab` / `BattleTab` と違い `.tscn` を持たず、`HomeScreen` がコードで生成する。

signal tutorial_requested
signal rules_requested
signal screen_guide_requested
signal keyword_dict_requested

## アカウント帯(ホーム画面のヘッダー)を避ける上端。`DeckTab` と同じ値。
const TOP_BAND := 112.0
const FRAME_RECT := Rect2(140, TOP_BAND + 4.0, 1000, 0)
const PLAY_FRAME_HEIGHT := 138.0
const READ_FRAME_HEIGHT := 216.0
const FRAME_GAP := 18.0
const FRAME_PADDING := 18.0

const CAPTION_FONT_SIZE := 17
const HEADING_FONT_SIZE := 21

## 誘導対局(GameDesign.md 18章)。**まだ遊んでいない間はいちばん大きく出す**。
## 読み物より先に、実際に手を指して覚えられることを示すため。終えたら他と同じ大きさへ下げる。
const PLAY_BUTTON_SIZE := Vector2(340, 92)
const PLAY_BUTTON_SIZE_DONE := Vector2(300, 76)
const PLAY_FONT_SIZE := 26
const PLAY_FONT_SIZE_DONE := 22

const READ_BUTTON_SIZE := Vector2(292, 72)
const READ_FONT_SIZE := 21
const READ_GAP := 20.0

## **説明文は句読点・語の切れ目で改行する**。折り返しに任せると「実際の盤/面」
## 「案内役/のすなえる」のように語の途中で切れるため、改行の位置を文側で決める。
## `autowrap_mode` は残してあるので、想定より狭くなっても文字が枠から出ることはない。
const PLAY_CAPTION := (
	"実際に1局遊びながら、出す・ターンを終える・\n" + "攻撃する・反転するを順に覚えます。\n" + "案内役のすなえるが、次に何をすればよいかを教えてくれます。"
)
const READ_ITEMS: Array[Dictionary] = [
	{
		"label": "遊び方",
		"caption": "砂時計の読み方から勝ち方まで、\n盤面を動かしながら順に説明します。",
	},
	{
		"label": "画面の見かた",
		"caption": "対局画面に出ているものの意味を、\n盤面を光らせて示します。",
	},
	{
		"label": "キーワード辞書",
		"caption": "守護・硝子・貫通などの意味と、\nその語を持つ砂時計を引けます。",
	},
]


func _ready() -> void:
	_build_play_frame()
	_build_read_frame()


func _build_play_frame() -> void:
	var rect := Rect2(FRAME_RECT.position, Vector2(FRAME_RECT.size.x, PLAY_FRAME_HEIGHT))
	_add_frame(rect, "遊んで覚える")
	var first_time := not UiState.has_done_tutorial()
	var button_size: Vector2 = PLAY_BUTTON_SIZE if first_time else PLAY_BUTTON_SIZE_DONE
	var button := CodedButton.make("1局遊んで覚える", button_size)
	button.add_theme_font_size_override(
		"font_size", PLAY_FONT_SIZE if first_time else PLAY_FONT_SIZE_DONE
	)
	button.position = Vector2(
		rect.position.x + FRAME_PADDING,
		rect.position.y + 44.0 + (rect.size.y - 44.0 - button_size.y - FRAME_PADDING) * 0.5
	)
	button.pressed.connect(func() -> void: tutorial_requested.emit())
	add_child(button)

	var caption_left: float = button.position.x + PLAY_BUTTON_SIZE.x + FRAME_PADDING
	_add_caption(
		PLAY_CAPTION,
		Rect2(
			Vector2(caption_left, rect.position.y + 48.0),
			Vector2(rect.end.x - caption_left - FRAME_PADDING, rect.size.y - 62.0)
		)
	)


func _build_read_frame() -> void:
	var top: float = FRAME_RECT.position.y + PLAY_FRAME_HEIGHT + FRAME_GAP
	var rect := Rect2(
		Vector2(FRAME_RECT.position.x, top), Vector2(FRAME_RECT.size.x, READ_FRAME_HEIGHT)
	)
	_add_frame(rect, "読んで覚える")
	var width: float = READ_BUTTON_SIZE.x * READ_ITEMS.size() + READ_GAP * (READ_ITEMS.size() - 1)
	var left: float = rect.position.x + (rect.size.x - width) * 0.5
	var handlers: Array[Callable] = [
		func() -> void: rules_requested.emit(),
		func() -> void: screen_guide_requested.emit(),
		func() -> void: keyword_dict_requested.emit(),
	]
	for i in READ_ITEMS.size():
		var item: Dictionary = READ_ITEMS[i]
		var at := Vector2(left + (READ_BUTTON_SIZE.x + READ_GAP) * i, rect.position.y + 56.0)
		var button := CodedButton.make(str(item["label"]), READ_BUTTON_SIZE)
		button.add_theme_font_size_override("font_size", READ_FONT_SIZE)
		button.position = at
		button.pressed.connect(handlers[i])
		add_child(button)
		_add_caption(
			str(item["caption"]),
			Rect2(
				at + Vector2(0.0, READ_BUTTON_SIZE.y + 12.0),
				Vector2(READ_BUTTON_SIZE.x, rect.end.y - at.y - READ_BUTTON_SIZE.y - 24.0)
			)
		)


## 枠。中身は絶対座標で置くため、器はパネルと見出しだけを持つ。
func _add_frame(rect: Rect2, heading: String) -> void:
	var panel := Panel.new()
	panel.position = rect.position
	panel.size = rect.size
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var style: StyleBox = load("res://resources/theme/content_panel.tres")
	if style != null:
		panel.add_theme_stylebox_override("panel", style)
	add_child(panel)

	var label := Label.new()
	label.text = heading
	label.position = rect.position + Vector2(FRAME_PADDING, 12.0)
	label.size = Vector2(rect.size.x - FRAME_PADDING * 2.0, 28)
	label.add_theme_font_size_override("font_size", HEADING_FONT_SIZE)
	label.add_theme_color_override("font_color", UiPalette.GLOW_AMBER)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(label)


func _add_caption(text: String, rect: Rect2) -> void:
	var label := Label.new()
	label.text = text
	# **`autowrap_mode` は `size` より先に立てる。**折り返しが無効なあいだ Label の最小幅は
	# 文章そのものの幅であり、Control はそれより小さくならない。後から折り返しを有効にしても
	# 既に広がった `size` は戻らず、説明文どうしが重なる(実際にそうなった)。
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.position = rect.position
	label.size = rect.size
	label.add_theme_font_size_override("font_size", CAPTION_FONT_SIZE)
	label.add_theme_color_override("font_color", UiPalette.TEXT_OFFWHITE)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(label)
