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
## **「遊んで覚える」の主役タイルには、すなえるの立ち絵をそのまま乗せる**
## (`SunaeruPortrait`。18章の案内役と同じ絵)。紋章として薄く透かすだけでは
## マスコットの表情も浮遊も伝わらず、このタブでいちばん押してほしい入口が
## 他の入口と見分けの付かない地味な帯になっていた。
##
## **「読んで覚える」の3枚は、押す前に分かるべきことを実データの件数で示す**
## (`DeckTab` の「収集 9 / 70」と同じ考え方)。件数は `RulePages` / `ScreenGuideEntries` /
## `KeywordEntries` から実行時に数える。表を並べ替えたり増やしたりしても
## このタブを書き換える作業が発生しない。
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
const FRAME_GAP := 20.0
## 枠の中身の左右へ取る余白と、見出しのぶん空ける上端。
const TILE_PAD := 22.0
const TILE_TOP := 46.0

const PLAY_FRAME_HEIGHT := 196.0
const READ_FRAME_HEIGHT := 204.0
## 誘導対局(GameDesign.md 18章)。**まだ遊んでいない間はこのタブの主役**として
## 塗りつぶした真鍮の面にする(9章の3段)。終えたら他と同じ面へ落とす。
const PLAY_TILE_SIZE := Vector2(956, 130)
const PLAY_FONT_SIZE := 30
const PLAY_FONT_SIZE_DONE := 24
## すなえるの立ち絵を乗せる大きさ。**まだ遊んでいない間のほうを大きく**して、
## いちばん押してほしい入口へ視線を集める。終えたら控えめに小さくする。
const PORTRAIT_SIZE := Vector2(132.0, 138.0)
const PORTRAIT_SIZE_DONE := Vector2(94.0, 98.0)
const PORTRAIT_RIGHT_PAD := 30.0

const READ_TILE_SIZE := Vector2(304, 134)
const READ_TILE_GAP := 322.0
const READ_FONT_SIZE := 23


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
		"すなえるが手順を案内します" if first_time else "いつでも、もう一度挑戦できます",
		"",
		PLAY_TILE_SIZE,
		PLAY_FONT_SIZE if first_time else PLAY_FONT_SIZE_DONE,
		first_time
	)
	# **紋章は薄い透かしでは表情が伝わらない。**代わりに18章の案内役と同じ立ち絵を
	# そのまま子ノードとして乗せる(浮遊アニメーション込み)。
	tile.emblem = null
	tile.position = rect.position + Vector2(TILE_PAD, TILE_TOP)
	tile.pressed.connect(func() -> void: tutorial_requested.emit())
	add_child(tile)

	var portrait := SunaeruPortrait.new()
	portrait.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var portrait_size := PORTRAIT_SIZE if first_time else PORTRAIT_SIZE_DONE
	portrait.size = portrait_size
	portrait.position = Vector2(
		PLAY_TILE_SIZE.x - portrait_size.x - PORTRAIT_RIGHT_PAD, PLAY_TILE_SIZE.y - portrait_size.y
	)
	tile.add_child(portrait)


func _build_read_frame(top: float) -> void:
	var rect := Rect2(Vector2(FRAME_X, top), Vector2(FRAME_W, READ_FRAME_HEIGHT))
	add_child(HomeFrame.make(rect, "読んで覚える"))
	var items := _read_items()
	var handlers: Array[Callable] = [
		func() -> void: rules_requested.emit(),
		func() -> void: screen_guide_requested.emit(),
		func() -> void: keyword_dict_requested.emit(),
	]
	for i in items.size():
		var item: Dictionary = items[i]
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


## **副題は実データの件数から組み立てる**(押す前に分かるべきことの1行。9章)。
## 件数を数字で持たないのは、章や語を1つ足すたびにこのタブを書き換える作業を
## 発生させないため。
func _read_items() -> Array[Dictionary]:
	return [
		{
			"label": "遊び方",
			"caption": "全%d章、盤面つきで読む" % RulePages.CHAPTERS.size(),
			"emblem": "hour",
		},
		{
			"label": "画面の見かた",
			"caption": "盤面の%d箇所を確かめる" % ScreenGuideEntries.ENTRIES.size(),
			"emblem": "eye",
		},
		{
			"label": "キーワード辞書",
			"caption": "%dの語をいつでも引ける" % KeywordEntries.all_entries().size(),
			"emblem": "halo",
		},
	]
