class_name MissionEntryInfo
extends Control
## ホームの「ミッション」の札に載せる中身(GameDesign.md 9章・23章)。
## 見出し「ミッション」と「今日 N / 3 達成」、右上に贈り物の箱の絵と受け取れる数、その下に今日の3つを罫線で区切って1つずつ。
## **日課は目に入らないと忘れられる**ため、件数だけでなく中身と進み具合までホームで見せる。
## 札(`HomeTile`)の子として全面に敷き、押下は札へ通す。

const TITLE := "ミッション"
const CLAIMABLE := "受け取れます"
const CLAIMED := "受け取り済み"
## 文字と余白。横 / 縦(GameDesign.md 9章「縦画面」の目安)。
const PAD := UiPalette.S5 - UiPalette.S1
const PORTRAIT_PAD := UiPalette.S4 + 2.0
const HEAD_SIZE := UiPalette.T_HEAD
const PORTRAIT_HEAD_SIZE := 30
const BODY_SIZE := UiPalette.T_BODY
const PORTRAIT_BODY_SIZE := 24
const NOTE_SIZE := UiPalette.T_SMALL
const PORTRAIT_NOTE_SIZE := 20
## これより小さくは縮めない(長い文を行へ収めるとき)。
const MIN_TEXT_SIZE := UiPalette.T_MICRO
## 見出し → 達成数 → 行の、文字の大きさに対する送り。
const HEAD_LEADING := 1.3
const SUMMARY_LEADING := 1.9
const TEXT_LEADING := 1.35
const BAR_GAP := 10.0
const BAR_HEIGHT := 10.0
const PORTRAIT_BAR_HEIGHT := 14.0
const BOTTOM_PAD := 6.0
const GIFT_SIZE := Vector2(72, 56)
const PORTRAIT_GIFT_SCALE := 1.15
const GIFT_NUDGE := Vector2(6, -6)
const BADGE_RADIUS := 9.0
const PORTRAIT_BADGE_RADIUS := 11.0
const BADGE_INSET := Vector2(6, 8)
## 受け取れる行の左端に立てる砂色の印。
const READY_MARK := Rect2(5, 12, 3, 0)
const COUNT_GAP := UiPalette.S3

var portrait := false:
	set(value):
		portrait = value
		queue_redraw()

var _rows: Array[Dictionary] = []
var _font: Font
var _display: Font


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func _ready() -> void:
	_font = get_theme_default_font()
	if _font == null:
		_font = ThemeDB.fallback_font
	_display = UiFonts.display_font(_font)


func set_rows(rows: Array[Dictionary]) -> void:
	_rows = rows
	queue_redraw()


func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED:
		queue_redraw()


func _draw() -> void:
	if _font == null:
		return
	var ci := get_canvas_item()
	var pad := PORTRAIT_PAD if portrait else PAD
	var head := PORTRAIT_HEAD_SIZE if portrait else HEAD_SIZE
	var note := PORTRAIT_NOTE_SIZE if portrait else NOTE_SIZE
	var done := 0
	var claimable := 0
	for row in _rows:
		if row["done"]:
			done += 1
			if not row["claimed"]:
				claimable += 1
	_text(_display, TITLE, Vector2(pad, pad - UiPalette.S1), head, UiPalette.IVORY)
	var summary_top := pad + head * HEAD_LEADING
	_text(
		_font,
		"今日 %d / %d 達成" % [done, _rows.size()],
		Vector2(pad, summary_top),
		note,
		UiPalette.SAND_HI
	)
	var gift_size := GIFT_SIZE * (PORTRAIT_GIFT_SCALE if portrait else 1.0)
	var gift := Rect2(
		Vector2(size.x - pad - gift_size.x + GIFT_NUDGE.x, pad + GIFT_NUDGE.y), gift_size
	)
	var tile := get_parent() as HomeTile
	if tile != null:
		HomeProps.draw(HomeProps.Kind.GIFT, self, gift, tile.prop_hover(), tile.prop_play())
	else:
		HomeProps.draw(HomeProps.Kind.GIFT, self, gift)
	draw_set_transform_matrix(Transform2D.IDENTITY)
	if claimable > 0:
		UiKit.badge(
			ci,
			_font,
			Vector2(gift.end.x - BADGE_INSET.x, gift.position.y + BADGE_INSET.y),
			PORTRAIT_BADGE_RADIUS if portrait else BADGE_RADIUS,
			str(claimable)
		)
	if _rows.is_empty():
		return
	var top := summary_top + note * SUMMARY_LEADING
	var row_height := (size.y - BOTTOM_PAD - top) / float(_rows.size())
	for i in _rows.size():
		_draw_row(_rows[i], Rect2(pad, top + row_height * i, size.x - pad * 2.0, row_height))


func _draw_row(row: Dictionary, rect: Rect2) -> void:
	var ci := get_canvas_item()
	var body := PORTRAIT_BODY_SIZE if portrait else BODY_SIZE
	var note := PORTRAIT_NOTE_SIZE if portrait else NOTE_SIZE
	var bar_height := PORTRAIT_BAR_HEIGHT if portrait else BAR_HEIGHT
	UiKit.rule(ci, rect.position, Vector2(rect.end.x, rect.position.y))
	var block := body * TEXT_LEADING + BAR_GAP + bar_height
	var text_top := rect.position.y + (rect.size.y - block) * 0.5
	var done: bool = row["done"]
	var claimed: bool = row["claimed"]
	var ready := done and not claimed
	if ready:
		var mark := Rect2(
			READY_MARK.position.x,
			rect.position.y + READY_MARK.position.y,
			READY_MARK.size.x,
			rect.size.y - READY_MARK.position.y * 2.0
		)
		UiKit.fill(ci, UiKit.rr(mark, mark.size.x * 0.5), UiPalette.SAND)
	var goal := maxi(int(row["goal"]), 1)
	var progress := int(row["progress"])
	# 受け取れるときは数の位置へ「受け取れます」を出す(バーが満ちているので数は重ねない)。
	var right := "%d / %d" % [progress, goal]
	var right_color := UiPalette.MUTED
	if ready:
		right = CLAIMABLE
		right_color = UiPalette.SAND_HI
	elif claimed:
		right = CLAIMED
		right_color = UiPalette.FAINT
	var right_width := _font.get_string_size(right, HORIZONTAL_ALIGNMENT_LEFT, -1, note).x
	var note_top := text_top + (body - note) * 0.6
	_text(_font, right, Vector2(rect.end.x - right_width, note_top), note, right_color)
	var label := str(row["text"])
	var label_width := rect.size.x - right_width - COUNT_GAP
	var label_size := _fit(label, body, label_width)
	_text(
		_font,
		label,
		Vector2(rect.position.x, text_top + (body - label_size) * 0.6),
		label_size,
		UiPalette.MUTED if claimed else UiPalette.IVORY
	)
	UiKit.sand_bar(
		ci,
		Rect2(rect.position.x, text_top + body * TEXT_LEADING + BAR_GAP, rect.size.x, bar_height),
		float(progress) / float(goal)
	)


## `at` は行の左上。
func _text(font: Font, value: String, at: Vector2, px: int, color: Color) -> void:
	draw_string(
		font, at + Vector2(0, font.get_ascent(px)), value, HORIZONTAL_ALIGNMENT_LEFT, -1, px, color
	)


## 幅へ収まる文字の大きさ(収まらなければ下限まで縮める)。
func _fit(value: String, px: int, width: float) -> int:
	var fitted := px
	while (
		fitted > MIN_TEXT_SIZE
		and _font.get_string_size(value, HORIZONTAL_ALIGNMENT_LEFT, -1, fitted).x > width
	):
		fitted -= 1
	return fitted
