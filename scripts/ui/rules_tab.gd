class_name RulesTab
extends Control
## ホーム画面の「おぼえる」タブ(GameDesign.md 9章)。
##
## **「遊んで覚える」と「読んで覚える」の2つの枠に分ける**(9章)。前者は誘導対局
## (18章)、後者は「遊び方」(16章)・「画面の見かた」(20章)・「キーワード辞書」(17章)。
## **入口を縦に4つ並べる形は採らない。**タブの高さは下部タブとアカウント帯に挟まれた
## 448pxしかなく4行では収まらず、加えて手を動かして覚える道と読んで覚える道は
## 性質が違うため、同じ列に並べるより枠を分けたほうが選びやすい。
##
## **入口は他のタブと同じ `HomeTile`** にする。以前はここだけ「文字だけのボタン + その外に
## 置いた説明文」で組んでおり、4タブを切り替えると**このタブだけ作りが違って見えた**。
## 説明は札の副題として1行に収める(9章「添えるのは文で1行までとし」)。
##
## 章の目次や語の一覧はそれぞれの画面側にあり、ここへ並べると同じ一覧が2箇所に出て
## どちらが本体か分からなくなるため、入口だけを置く。
## `DeckTab` / `BattleTab` と違い `.tscn` を持たず、`HomeScreen` がコードで生成する。

signal tutorial_requested
signal rules_requested
signal screen_guide_requested
signal keyword_dict_requested

## アカウント帯(ホーム画面のヘッダー)を避ける上端と、下部タブに接する下端。
const TOP_BAND := 112.0
const BOTTOM := 560.0
const FRAME_X := 140.0
const FRAME_W := 1000.0
const FRAME_GAP := 18.0
## 枠の中身の左右へ取る余白と、見出しのぶん空ける上端。
const TILE_PAD := 20.0
const TILE_TOP := 46.0

const PLAY_FRAME_HEIGHT := 150.0
const READ_FRAME_HEIGHT := 190.0
## 誘導対局(GameDesign.md 18章)。**まだ遊んでいない間はこのタブの主役**として
## 塗りつぶした真鍮の面にする(9章の3段)。終えたら他と同じ面へ落とす。
const PLAY_TILE_SIZE := Vector2(960, 84)
const PLAY_FONT_SIZE := 28
const PLAY_FONT_SIZE_DONE := 24

const READ_TILE_SIZE := Vector2(306, 118)
const READ_TILE_GAP := 320.0
const READ_FONT_SIZE := 22

## 副題は1行。**押す前に「そこで何ができるか」が分かれば足りる**ので、中身の説明は
## それぞれの画面が持つ。
const READ_ITEMS: Array[Dictionary] = [
	{"label": "遊び方", "caption": "ルールを順に読む", "emblem": "hour"},
	{"label": "画面の見かた", "caption": "表示の意味を引く", "emblem": "eye"},
	{"label": "キーワード辞書", "caption": "語を引く", "emblem": "halo"},
]


func _ready() -> void:
	var stack: float = PLAY_FRAME_HEIGHT + FRAME_GAP + READ_FRAME_HEIGHT
	var top: float = TOP_BAND + (BOTTOM - TOP_BAND - stack) * 0.5
	_build_play_frame(top)
	_build_read_frame(top + PLAY_FRAME_HEIGHT + FRAME_GAP)


func _build_play_frame(top: float) -> void:
	var rect := Rect2(Vector2(FRAME_X, top), Vector2(FRAME_W, PLAY_FRAME_HEIGHT))
	add_child(HomeFrame.make(rect, "遊んで覚える"))
	var first_time := not UiState.has_done_tutorial()
	var tile := HomeTile.make(
		"1局遊んで覚える",
		"すなえるが手順を案内します",
		"mascot",
		PLAY_TILE_SIZE,
		PLAY_FONT_SIZE if first_time else PLAY_FONT_SIZE_DONE,
		first_time
	)
	tile.position = rect.position + Vector2(TILE_PAD, TILE_TOP)
	tile.pressed.connect(func() -> void: tutorial_requested.emit())
	add_child(tile)


func _build_read_frame(top: float) -> void:
	var rect := Rect2(Vector2(FRAME_X, top), Vector2(FRAME_W, READ_FRAME_HEIGHT))
	add_child(HomeFrame.make(rect, "読んで覚える"))
	var handlers: Array[Callable] = [
		func() -> void: rules_requested.emit(),
		func() -> void: screen_guide_requested.emit(),
		func() -> void: keyword_dict_requested.emit(),
	]
	for i in READ_ITEMS.size():
		var item: Dictionary = READ_ITEMS[i]
		var tile := HomeTile.make(
			str(item["label"]),
			str(item["caption"]),
			str(item["emblem"]),
			READ_TILE_SIZE,
			READ_FONT_SIZE
		)
		tile.position = rect.position + Vector2(TILE_PAD + float(i) * READ_TILE_GAP, TILE_TOP + 4.0)
		tile.pressed.connect(handlers[i])
		add_child(tile)
