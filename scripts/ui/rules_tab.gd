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

## 縦画面(GameDesign.md 9章「縦画面」)。2つの枠は画面の幅いっぱいにし、読んで覚える3枚は縦に積む。
const PORTRAIT_TILE_W := 628.0
const PORTRAIT_TILE_TOP := 52.0
const PORTRAIT_PLAY_HEIGHT := 150.0
const PORTRAIT_PLAY_FONT := 36
const PORTRAIT_PLAY_FONT_DONE := 32
const PORTRAIT_READ_HEIGHT := 104.0
const PORTRAIT_READ_GAP := 12.0
const PORTRAIT_READ_FONT := 32

var _play_frame: HomeFrame
var _play_tile: HomeTile
var _sunaeru: SunaeruPortrait
var _read_frame: HomeFrame
var _read_tiles: Array[HomeTile] = []
var _first_time := false
var _portrait := false


func _ready() -> void:
	_build_play_frame()
	_build_read_frame()
	_layout()


func _build_play_frame() -> void:
	_play_frame = HomeFrame.make(Rect2(), "遊んで覚える")
	add_child(_play_frame)
	_first_time = not UiState.has_done_tutorial()
	_play_tile = HomeTile.make(
		"1局遊んで覚える",
		"すなえるが手順を案内します" if _first_time else "いつでも、もう一度挑戦できます",
		"",
		PLAY_TILE_SIZE,
		PLAY_FONT_SIZE if _first_time else PLAY_FONT_SIZE_DONE,
		_first_time
	)
	# **紋章は薄い透かしでは表情が伝わらない。**代わりに18章の案内役と同じ立ち絵を
	# そのまま子ノードとして乗せる(浮遊アニメーション込み)。
	_play_tile.emblem = null
	_play_tile.pressed.connect(func() -> void: tutorial_requested.emit())
	add_child(_play_tile)

	_sunaeru = SunaeruPortrait.new()
	_sunaeru.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_sunaeru.size = PORTRAIT_SIZE if _first_time else PORTRAIT_SIZE_DONE
	_play_tile.add_child(_sunaeru)


func _build_read_frame() -> void:
	_read_frame = HomeFrame.make(Rect2(), "読んで覚える")
	add_child(_read_frame)
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
		tile.pressed.connect(handlers[i])
		add_child(tile)
		_read_tiles.append(tile)


## 縦横が変わったときに `HomeScreen` から呼ばれる(Architecture.md 4.7節)。
func apply_orientation(portrait: bool) -> void:
	_portrait = portrait
	if _play_tile != null:
		_layout()


func _layout() -> void:
	HomeTile.set_portrait_text(
		_play_tile,
		_portrait,
		PORTRAIT_PLAY_FONT if _first_time else PORTRAIT_PLAY_FONT_DONE,
		PLAY_FONT_SIZE if _first_time else PLAY_FONT_SIZE_DONE
	)
	for tile in _read_tiles:
		HomeTile.set_portrait_text(tile, _portrait, PORTRAIT_READ_FONT, READ_FONT_SIZE)
	_play_frame.set_portrait(_portrait)
	_read_frame.set_portrait(_portrait)
	var play_rect: Rect2
	var read_rect: Rect2
	var play_tile := Rect2()
	var read_tiles: Array[Rect2] = []
	if _portrait:
		var step := PORTRAIT_READ_HEIGHT + PORTRAIT_READ_GAP
		var play_height := PORTRAIT_TILE_TOP + PORTRAIT_PLAY_HEIGHT + TILE_PAD
		var read_height := (
			PORTRAIT_TILE_TOP + step * float(_read_tiles.size()) - PORTRAIT_READ_GAP + TILE_PAD
		)
		var top := HomeFrame.portrait_stack_top(play_height + HomeFrame.PORTRAIT_GAP + read_height)
		play_rect = Rect2(HomeFrame.PORTRAIT_X, top, HomeFrame.PORTRAIT_W, play_height)
		read_rect = Rect2(
			HomeFrame.PORTRAIT_X,
			play_rect.end.y + HomeFrame.PORTRAIT_GAP,
			HomeFrame.PORTRAIT_W,
			read_height
		)
		play_tile = Rect2(
			play_rect.position + Vector2(TILE_PAD, PORTRAIT_TILE_TOP),
			Vector2(PORTRAIT_TILE_W, PORTRAIT_PLAY_HEIGHT)
		)
		for i in _read_tiles.size():
			read_tiles.append(
				Rect2(
					read_rect.position + Vector2(TILE_PAD, PORTRAIT_TILE_TOP + step * float(i)),
					Vector2(PORTRAIT_TILE_W, PORTRAIT_READ_HEIGHT)
				)
			)
	else:
		var stack: float = PLAY_FRAME_HEIGHT + FRAME_GAP + READ_FRAME_HEIGHT
		var top: float = TOP_BAND + (BOTTOM - TOP_BAND - stack) * 0.5
		play_rect = Rect2(Vector2(FRAME_X, top), Vector2(FRAME_W, PLAY_FRAME_HEIGHT))
		read_rect = Rect2(
			Vector2(FRAME_X, top + PLAY_FRAME_HEIGHT + FRAME_GAP),
			Vector2(FRAME_W, READ_FRAME_HEIGHT)
		)
		play_tile = Rect2(play_rect.position + Vector2(TILE_PAD, TILE_TOP), PLAY_TILE_SIZE)
		for i in _read_tiles.size():
			read_tiles.append(
				Rect2(
					(
						read_rect.position
						+ Vector2(TILE_PAD + float(i) * READ_TILE_GAP, TILE_TOP + 4.0)
					),
					READ_TILE_SIZE
				)
			)
	HomeFrame.place(_play_frame, play_rect)
	HomeFrame.place(_read_frame, read_rect)
	HomeFrame.place(_play_tile, play_tile)
	for i in _read_tiles.size():
		HomeFrame.place(_read_tiles[i], read_tiles[i])
	_sunaeru.position = Vector2(
		play_tile.size.x - _sunaeru.size.x - PORTRAIT_RIGHT_PAD, play_tile.size.y - _sunaeru.size.y
	)


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
