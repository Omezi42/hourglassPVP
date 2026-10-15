class_name HomeFrame
extends Control
## ホーム画面のタブの中で、入口をひとまとめにする枠(GameDesign.md 9章)。
##
## 「だれかと / ひとりで」「今日の課題 / これまでの対局」「遊んで覚える / 読んで覚える」
## のように、**性質の違う入口を同じ列へ並べず枠で分ける**ための部品。以前は
## `RulesTab` が自分で `content_panel.tres` のパネルと見出しのラベルを組んでいたが、
## 同じ形を3つのタブで使うため切り出した。
##
## **見出しは真鍮のプレートに載せる。**ラベルだけを枠の内側へ置くと、枠の一部なのか
## 中身なのかが読めず、何をまとめた枠なのかが伝わらない。

const PANEL_PATH := "res://resources/theme/content_panel.tres"
## 見出しのプレートは、主要な操作と同じ「塗りつぶした真鍮」の面を使う。
const PLATE_PATH := "res://resources/theme/buttons/img_primary_action_normal.tres"

const HEADING_FONT_SIZE := 20
const HEADING_HEIGHT := 34.0
const HEADING_LEFT := 18.0
## プレートの左右へ取る余白。
const HEADING_PADDING := 21.0
## 枠の上端へどれだけ跨がらせるか(プレートの高さに対する比)。
const HEADING_OVERLAP := 0.44
const HEADING_COLOR := Color(0.16, 0.12, 0.06)

## 枠の右側へ並べる行(いまのところ日課の進み具合だけ)。1件は
## `{"text":, "count":, "done":}`。**枠が自分で描く**——枠は `Control` であり、
## その `_draw()` は子より背面に描かれるため、タブ側で描くと枠のパネルに隠れて
## 何も見えない(実際にミッションの進捗が消えた。Architecture.md 11章)。
const ROW_FONT_SIZE := 15
const ROW_HEIGHT := 26.0
const ROW_MARK_GAP := 22.0
const MARK_DONE := Color(0.85, 0.62, 0.22)
const MARK_TODO := Color(0.45, 0.42, 0.38)
const ROW_TEXT_DONE := Color(0.96, 0.94, 0.89)
const ROW_TEXT_TODO := Color(0.62, 0.58, 0.52)
const ROW_COUNT_COLOR := Color(0.72, 0.67, 0.58)

## 縦画面の値(GameDesign.md 9章「縦画面」: 本文24px以上・小さな見出し20px以上)。
## 縦のタブはどれも画面の幅いっぱいの枠を上から積む。
const PORTRAIT_X := 24.0
const PORTRAIT_W := 672.0
const PORTRAIT_PAD := 22.0
const PORTRAIT_GAP := 30.0
## 縦のタブの中身を置ける上端と下端(アカウント帯の下〜下部タブの上)。
const PORTRAIT_TOP := 136.0
const PORTRAIT_BOTTOM := 1130.0
const PORTRAIT_HEADING_FONT_SIZE := 26
const PORTRAIT_HEADING_HEIGHT := 42.0
const PORTRAIT_ROW_FONT_SIZE := 24
const PORTRAIT_ROW_HEIGHT := 38.0
const PORTRAIT_ROW_MARK_GAP := 32.0

var heading := "":
	set(value):
		heading = value
		queue_redraw()
var rows: Array[Dictionary] = []:
	set(value):
		rows = value
		queue_redraw()
## 行を並べ始める横位置と、その中で数を右へ寄せる位置(いずれも枠の左端から)。
var rows_left := 0.0
var rows_count_left := 0.0
var rows_top := 0.0
## 縦画面(GameDesign.md 9章「縦画面」)で文字を大きくするための値。既定は横の見た目のまま。
var heading_font_size := HEADING_FONT_SIZE
var heading_height := HEADING_HEIGHT
var row_font_size := ROW_FONT_SIZE
var row_height := ROW_HEIGHT
var row_mark_gap := ROW_MARK_GAP

var _font: Font
## 見出しだけは明朝体(`UiFonts.display_font()`)にする。行(`rows`)は数字を含む本文で
## あり続けて読みやすさを優先するため、`_font` のまま変えない。
var _heading_font: Font
var _panel: StyleBox
var _plate: StyleBox


## 縦横に合わせて見出しと行の文字の大きさを切り替える。
func set_portrait(portrait: bool) -> void:
	heading_font_size = PORTRAIT_HEADING_FONT_SIZE if portrait else HEADING_FONT_SIZE
	heading_height = PORTRAIT_HEADING_HEIGHT if portrait else HEADING_HEIGHT
	row_font_size = PORTRAIT_ROW_FONT_SIZE if portrait else ROW_FONT_SIZE
	row_height = PORTRAIT_ROW_HEIGHT if portrait else ROW_HEIGHT
	row_mark_gap = PORTRAIT_ROW_MARK_GAP if portrait else ROW_MARK_GAP
	queue_redraw()


## 札・枠を置き直す。**最小の大きさから先に変える**(`size` は最小より小さくならないため)。
static func place(node: Control, rect: Rect2) -> void:
	node.position = rect.position
	node.custom_minimum_size = rect.size
	node.size = rect.size


## 縦のタブで、高さの合計が `total` になる枠の並びを上下の中央へ置くときの上端。
static func portrait_stack_top(total: float) -> float:
	return PORTRAIT_TOP + maxf((PORTRAIT_BOTTOM - PORTRAIT_TOP - total) * 0.5, 0.0)


## 枠を1つ作る。中身は呼び出し側が `add_child()` するのではなく、**タブが同じ親へ
## 絶対座標で置く**(タブの札はいずれも位置を自分で決めているため)。
static func make(rect: Rect2, frame_heading: String) -> HomeFrame:
	var frame := HomeFrame.new()
	frame.heading = frame_heading
	frame.position = rect.position
	frame.size = rect.size
	frame.custom_minimum_size = rect.size
	# 中身(札)は枠の兄弟として置かれるため、枠自身はホバーも押下も受けない。
	frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return frame


func _ready() -> void:
	_font = get_theme_default_font()
	if _font == null:
		_font = ThemeDB.fallback_font
	_heading_font = UiFonts.display_font(_font)
	_panel = load(PANEL_PATH)
	_plate = load(PLATE_PATH)


func _draw() -> void:
	if _panel != null:
		draw_style_box(_panel, Rect2(Vector2.ZERO, size))
	if heading.is_empty() or _font == null:
		return
	var heading_font: Font = _heading_font if _heading_font != null else _font
	var text_width: float = (
		heading_font.get_string_size(heading, HORIZONTAL_ALIGNMENT_LEFT, -1, heading_font_size).x
	)
	var plate := Rect2(
		Vector2(HEADING_LEFT, -heading_height * HEADING_OVERLAP),
		Vector2(text_width + HEADING_PADDING * 2.0, heading_height)
	)
	if _plate != null:
		draw_style_box(_plate, plate)
	draw_string(
		heading_font,
		plate.position + Vector2(HEADING_PADDING, heading_height * 0.68),
		heading,
		HORIZONTAL_ALIGNMENT_LEFT,
		-1,
		heading_font_size,
		HEADING_COLOR
	)
	_draw_rows()


func _draw_rows() -> void:
	for i in rows.size():
		var row: Dictionary = rows[i]
		var done: bool = row.get("done", false)
		var y: float = rows_top + float(i) * row_height + float(row_font_size)
		draw_string(
			_font,
			Vector2(rows_left, y),
			"●" if done else "○",
			HORIZONTAL_ALIGNMENT_LEFT,
			-1,
			row_font_size,
			MARK_DONE if done else MARK_TODO
		)
		draw_string(
			_font,
			Vector2(rows_left + row_mark_gap, y),
			str(row.get("text", "")),
			HORIZONTAL_ALIGNMENT_LEFT,
			-1,
			row_font_size,
			ROW_TEXT_DONE if done else ROW_TEXT_TODO
		)
		draw_string(
			_font,
			Vector2(rows_count_left, y),
			str(row.get("count", "")),
			HORIZONTAL_ALIGNMENT_LEFT,
			-1,
			row_font_size,
			ROW_COUNT_COLOR
		)
