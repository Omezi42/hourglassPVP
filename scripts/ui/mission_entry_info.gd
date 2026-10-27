class_name MissionEntryInfo
extends Control
## ホームの「ミッション」の札に載せる中身(GameDesign.md 9章・23章)。
## 見出し「ミッション」と「今日 N / 3 達成」、右上に贈り物の箱の絵と受け取れる数、その下に今日の3つを凹んだ枠で1つずつ。
## **日課は目に入らないと忘れられる**ため、件数だけでなく中身と進み具合までホームで見せる。
## 札(`HomeTile`)の子として全面に敷き、押下は札へ通す。

const TITLE := "ミッション"
const TITLE_POS := Vector2(24, 50)
const TITLE_SIZE := 28
const SUMMARY_POS := Vector2(26, 82)
const SUMMARY_SIZE := 17
const GIFT_SIDE := 86.0
const GIFT_RIGHT := 104.0
const GIFT_TOP := 14.0
const BADGE_INSET := Vector2(6, 10)
const ROW_TOP := 118.0
const ROW_STEP := 96.0
const ROW_HEIGHT := 84.0
const ROW_INSET := 18.0
const ROW_PAD := 14.0
const ROW_TEXT_BASELINE := 30.0
const ROW_TEXT_SIZE := 17
const BAR_TOP := 46.0
const BAR_HEIGHT := 12.0
const BAR_COUNT_WIDTH := 70.0
const BAR_COUNT_GAP := 10.0
const COUNT_SIZE := 15
const NOTE_BASELINE := 76.0
const NOTE_SIZE := 14
const BAR_TRACK := [[0.0, Color(0, 0, 0, 0.5)], [1.0, Color(0, 0, 0, 0.5)]]
const CLAIMABLE := "受け取れます"
const CLAIMED := "受け取り済み"

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
	var done := 0
	var claimable := 0
	for row in _rows:
		if row["done"]:
			done += 1
			if not row["claimed"]:
				claimable += 1
	draw_string(
		_display,
		TITLE_POS,
		TITLE,
		HORIZONTAL_ALIGNMENT_LEFT,
		-1,
		TITLE_SIZE,
		UiPalette.TEXT_OFFWHITE
	)
	draw_string(
		_font,
		SUMMARY_POS,
		"今日 %d / %d 達成" % [done, _rows.size()],
		HORIZONTAL_ALIGNMENT_LEFT,
		-1,
		SUMMARY_SIZE,
		HomeTile.SUB_COLOR
	)
	var gift := Rect2(size.x - GIFT_RIGHT, GIFT_TOP, GIFT_SIDE, GIFT_SIDE)
	HomeProps.draw(HomeProps.Kind.GIFT, self, gift)
	if claimable > 0:
		HomeTile.draw_badge(
			self, Vector2(gift.end.x - BADGE_INSET.x, gift.position.y + BADGE_INSET.y), claimable
		)
	for i in _rows.size():
		_draw_row(i, _rows[i])


func _draw_row(index: int, row: Dictionary) -> void:
	var rect := Rect2(
		ROW_INSET, ROW_TOP + ROW_STEP * float(index), size.x - ROW_INSET * 2.0, ROW_HEIGHT
	)
	EntryTilePaint.draw_well(self, rect, false)
	var done: bool = row["done"]
	var width := rect.size.x - ROW_PAD * 2.0
	draw_string(
		_font,
		rect.position + Vector2(ROW_PAD, ROW_TEXT_BASELINE),
		str(row["text"]),
		HORIZONTAL_ALIGNMENT_LEFT,
		width,
		ROW_TEXT_SIZE,
		HomeTile.SUB_COLOR if done else EntryTilePaint.WELL_TEXT
	)
	var goal := maxi(int(row["goal"]), 1)
	var progress := int(row["progress"])
	var bar := Rect2(
		rect.position + Vector2(ROW_PAD, BAR_TOP),
		Vector2(rect.size.x - ROW_PAD * 2.0 - BAR_COUNT_WIDTH, BAR_HEIGHT)
	)
	var radius := BAR_HEIGHT * 0.5
	UiPaint.fill_gradient_polygon(
		get_canvas_item(), UiPaint.rounded_rect_points_uniform(bar, radius, 6), bar, BAR_TRACK
	)
	var filled := Rect2(
		bar.position, Vector2(bar.size.x * float(progress) / float(goal), BAR_HEIGHT)
	)
	# 角丸の半径より細い残量は角が潰れて塗れないため、幅が足りるときだけ描く(docs/Pitfalls.md)。
	if filled.size.x > BAR_HEIGHT:
		UiPaint.fill_gradient_polygon(
			get_canvas_item(),
			UiPaint.rounded_rect_points_uniform(filled, radius, 6),
			filled,
			HomeProps.BRASS
		)
	draw_string(
		_font,
		Vector2(bar.end.x + BAR_COUNT_GAP, bar.end.y + 1.0),
		"%d/%d" % [progress, goal],
		HORIZONTAL_ALIGNMENT_LEFT,
		-1,
		COUNT_SIZE,
		EntryTilePaint.WELL_MUTED
	)
	if not done:
		return
	draw_string(
		_font,
		rect.position + Vector2(ROW_PAD, NOTE_BASELINE),
		CLAIMED if row["claimed"] else CLAIMABLE,
		HORIZONTAL_ALIGNMENT_LEFT,
		-1,
		NOTE_SIZE,
		EntryTilePaint.WELL_MUTED if row["claimed"] else UiPalette.GLOW_AMBER
	)
