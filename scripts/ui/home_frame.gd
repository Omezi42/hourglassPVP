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

var _font: Font
var _panel: StyleBox
var _plate: StyleBox


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
	_panel = load(PANEL_PATH)
	_plate = load(PLATE_PATH)


func _draw() -> void:
	if _panel != null:
		draw_style_box(_panel, Rect2(Vector2.ZERO, size))
	if heading.is_empty() or _font == null:
		return
	var text_width: float = (
		_font.get_string_size(heading, HORIZONTAL_ALIGNMENT_LEFT, -1, HEADING_FONT_SIZE).x
	)
	var plate := Rect2(
		Vector2(HEADING_LEFT, -HEADING_HEIGHT * HEADING_OVERLAP),
		Vector2(text_width + HEADING_PADDING * 2.0, HEADING_HEIGHT)
	)
	if _plate != null:
		draw_style_box(_plate, plate)
	draw_string(
		_font,
		plate.position + Vector2(HEADING_PADDING, HEADING_HEIGHT * 0.68),
		heading,
		HORIZONTAL_ALIGNMENT_LEFT,
		-1,
		HEADING_FONT_SIZE,
		HEADING_COLOR
	)
	_draw_rows()


func _draw_rows() -> void:
	for i in rows.size():
		var row: Dictionary = rows[i]
		var done: bool = row.get("done", false)
		var y: float = rows_top + float(i) * ROW_HEIGHT + float(ROW_FONT_SIZE)
		draw_string(
			_font,
			Vector2(rows_left, y),
			"●" if done else "○",
			HORIZONTAL_ALIGNMENT_LEFT,
			-1,
			ROW_FONT_SIZE,
			MARK_DONE if done else MARK_TODO
		)
		draw_string(
			_font,
			Vector2(rows_left + ROW_MARK_GAP, y),
			str(row.get("text", "")),
			HORIZONTAL_ALIGNMENT_LEFT,
			-1,
			ROW_FONT_SIZE,
			ROW_TEXT_DONE if done else ROW_TEXT_TODO
		)
		draw_string(
			_font,
			Vector2(rows_count_left, y),
			str(row.get("count", "")),
			HORIZONTAL_ALIGNMENT_LEFT,
			-1,
			ROW_FONT_SIZE,
			ROW_COUNT_COLOR
		)
