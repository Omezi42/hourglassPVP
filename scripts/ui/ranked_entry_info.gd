class_name RankedEntryInfo
extends Control
## ホームの「バトル」と、対局の種類を選ぶモーダルの「ランクマッチ」の札に載せる中身(GameDesign.md 9章)。
## 段位の徽章(帯ごとの金属のメダル+★)・段位名・次の段位まで、下端の凹んだ行に
## 待っている人の数とシーズンの残り日数を描く。途中の対局があるときは下端の行が琥珀の知らせになる。
## 札が縦長なら中央へ縦に積み(`tall`)、横長なら右に徽章・左に文字を置く(縦画面)。
## 札(`HomeTile`)の子として全面に敷き、押下は札へ通す。彫り文字と凹んだ行は `EntryTilePaint` と共用する。

## 真鍮へ彫り込んだ文字: 本体の暗色と、彫りの下縁に返る光。
const STAR_EMPTY_FILL := Color(0.22, 0.13, 0.05, 0.38)
const LIVE_DOT := Color(0.97, 0.40, 0.27)
const RESUME_DOT := Color(1.0, 0.78, 0.34)

## 徽章の半径は札の背に比例させ、上限で止める。
const MEDAL_RATIO := 0.2
const MEDAL_MAX_RADIUS := 80.0
const MEDAL_RIGHT := 64.0
const MEDAL_CENTER_RATIO := 0.4
## ★は徽章の半径に対する比で大きさと並びを決める。
const STAR_RATIO := 0.17
const STAR_ROW := 1.33
const STAR_SPACING := 2.7
const PULSE_SPEED := 3.2

## 縦長の札の組み方。位置は札の背に対する比で決める(ホームの列とモーダルの札で背が違うため)。
const TALL_MEDAL_RATIO := 0.2
const TALL_CAPTION_Y := 0.11
const TALL_MEDAL_Y := 0.31
const TALL_TIER_Y := 0.62
const TALL_NEXT_Y := 0.68
const TALL_HEAD_Y := 0.815
const TALL_TIER_SIZE := 36
const TALL_NEXT_SIZE := 18
const TALL_HEAD_SIZE := 52
## 見出しを上に置く組み方(モーダルの「ランクマッチ」。待機の行を持たない)。
const TOP_HEAD_Y := 0.17
const TOP_MEDAL_Y := 0.45
const TOP_MEDAL_RATIO := 0.19
const TOP_MEDAL_MAX := 64.0
const TOP_TIER_Y := 0.75
const TOP_NEXT_Y := 0.83
const TOP_HEAD_SIZE := 34
const TOP_TIER_SIZE := 26
const TOP_NEXT_SIZE := 17

## 縦長の札として中央へ積む。
var tall := false
## 縦長のときに札の中へ彫る見出し(「バトル」「対局へ戻る」「ランクマッチ」)。
var head_text := ""
## 見出しを上に置き、下端の行を出さない(モーダルの「ランクマッチ」)。
var head_on_top := false
var show_well := true

var _tier := RankRules.INITIAL_TIER
var _stars := 0
var _rating := 0
var _days_left := 0
## 待っている人の数。負なら行を出さない(通信できない)。
var _waiting := -1
var _resume := false
var _phase := 0.0
var _font: Font
var _display: Font


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func _ready() -> void:
	_font = get_theme_default_font()
	if _font == null:
		_font = ThemeDB.fallback_font
	_display = UiFonts.display_font(_font)


func refresh() -> void:
	var standing := RankProgress.standing()
	_tier = standing["tier"]
	_stars = standing["stars"]
	_rating = standing["rating"]
	_days_left = RankProgress.days_left_in_season()
	queue_redraw()


func set_waiting(count: int) -> void:
	_waiting = count
	queue_redraw()


## 途中の対局があるときは、下端の行を琥珀の知らせにする(GameDesign.md 9章)。
func set_resume(pending: bool) -> void:
	_resume = pending
	queue_redraw()


func _process(delta: float) -> void:
	if _resume or _waiting > 0:
		_phase = fmod(_phase + delta * PULSE_SPEED, TAU)
		queue_redraw()


func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED:
		queue_redraw()


func _draw() -> void:
	if _font == null:
		return
	if tall:
		_draw_tall()
		return
	_draw_left_column()
	var radius: float = minf(size.y * MEDAL_RATIO, MEDAL_MAX_RADIUS)
	var center := Vector2(size.x - MEDAL_RIGHT - radius, size.y * MEDAL_CENTER_RATIO)
	_draw_medal(center, radius)
	_draw_stars(center + Vector2(0.0, radius * STAR_ROW), radius * STAR_RATIO)
	if show_well:
		_draw_well()


func _draw_tall() -> void:
	var h := size.y
	if head_on_top:
		_engraved_center(head_text, h * TOP_HEAD_Y, TOP_HEAD_SIZE, _display)
		var top_radius: float = minf(size.x * TOP_MEDAL_RATIO, TOP_MEDAL_MAX)
		_draw_medal_column(h * TOP_MEDAL_Y, top_radius)
		_engraved_center(_tier_label(), h * TOP_TIER_Y, TOP_TIER_SIZE, _display)
		_engraved_center(_next_line(), h * TOP_NEXT_Y, TOP_NEXT_SIZE, _font)
		return
	_engraved_center("いまの段位", h * TALL_CAPTION_Y, EntryTilePaint.CAPTION_SIZE, _font)
	_draw_medal_column(h * TALL_MEDAL_Y, minf(size.x * TALL_MEDAL_RATIO, MEDAL_MAX_RADIUS))
	_engraved_center(_tier_label(), h * TALL_TIER_Y, TALL_TIER_SIZE, _display)
	_engraved_center(_next_line(), h * TALL_NEXT_Y, TALL_NEXT_SIZE, _font)
	_engraved_center(head_text, h * TALL_HEAD_Y, TALL_HEAD_SIZE, _display)
	if show_well:
		_draw_well()


func _draw_medal_column(center_y: float, radius: float) -> void:
	var center := Vector2(size.x * 0.5, center_y)
	_draw_medal(center, radius)
	_draw_stars(center + Vector2(0.0, radius * STAR_ROW), radius * STAR_RATIO)


func _engraved_center(text: String, baseline: float, font_size: int, font: Font) -> void:
	var width := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x
	EntryTilePaint.draw_engraved(
		self, font, Vector2((size.x - width) * 0.5, baseline), text, font_size
	)


func _draw_left_column() -> void:
	EntryTilePaint.draw_caption(self, _font, "いまの段位")
	EntryTilePaint.draw_head(self, _display, _tier_label())
	EntryTilePaint.draw_line_text(self, _font, _next_line())


## 段位名。段の数字は徽章にも打つが、名前として読めるよう左にも添える。
func _tier_label() -> String:
	var parsed := RankRules.parse(_tier)
	if _tier == RankRules.PLATINUM_KEY or parsed.is_empty():
		return RankRules.display_name(_tier)
	return "%s %d" % [RankRules.BRACKET_NAMES[parsed["bracket"]], int(parsed["step"])]


func _next_line() -> String:
	if _tier == RankRules.PLATINUM_KEY:
		return "レート %d" % _rating
	var need := RankRules.star_requirement(_tier)
	var next_tier: String = RankRules.advance_stars(_tier, need)["tier"]
	return "あと★%dつで %s" % [maxi(need - _stars, 1), RankRules.display_name(next_tier)]


func _draw_medal(center: Vector2, radius: float) -> void:
	RankMedal.draw_medal(self, center, radius, _tier, _display)


## 徽章の下に★を並べる。取った★は琥珀に光り、まだの★は真鍮へ彫った窪みにする。
func _draw_stars(center: Vector2, radius: float) -> void:
	if _tier == RankRules.PLATINUM_KEY:
		return
	var need := RankRules.star_requirement(_tier)
	var spacing := radius * STAR_SPACING
	var left := center.x - spacing * float(need - 1) * 0.5
	var outline := RankMedal.star_outline(radius)
	for i in need:
		var at := Vector2(left + spacing * float(i), center.y)
		if i < _stars:
			RankMedal.draw_filled_star(self, at, radius)
			continue
		var points := RankMedal.star_points(at, radius)
		var closed := RankMedal.closed(points)
		ShapePaint.colored_polygon(get_canvas_item(), points, STAR_EMPTY_FILL)
		ShapePaint.polyline(
			get_canvas_item(),
			_offset(closed, Vector2(0.0, 1.0)),
			EntryTilePaint.ENGRAVE_LIGHT,
			outline,
			true
		)
		ShapePaint.polyline(
			get_canvas_item(), closed, Color(EntryTilePaint.ENGRAVE_COLOR, 0.55), outline, true
		)


## 下端の凹んだ行。左に待っている人(または途中の対局の知らせ)、右にシーズンの残り日数。
func _draw_well() -> void:
	var rect := EntryTilePaint.well_rect(size)
	EntryTilePaint.draw_well(self, rect, _resume)
	var baseline := EntryTilePaint.well_baseline(rect)
	var dot_center := EntryTilePaint.well_dot_center(rect)
	var text_left := EntryTilePaint.well_text_left(rect)
	if _resume:
		EntryTilePaint.draw_dot(self, dot_center, RESUME_DOT, _phase)
		_well_text(
			text_left,
			baseline,
			"途中の対局が残っています",
			EntryTilePaint.WELL_TEXT_SIZE,
			EntryTilePaint.ACCENT_TEXT
		)
		return
	if _waiting > 0:
		EntryTilePaint.draw_dot(self, dot_center, LIVE_DOT, _phase)
		_well_text(
			text_left,
			baseline,
			"いま %d人が相手を待っています" % _waiting,
			EntryTilePaint.WELL_TEXT_SIZE,
			EntryTilePaint.WELL_TEXT
		)
	elif _waiting == 0:
		_well_text(
			rect.position.x + EntryTilePaint.WELL_INSET,
			baseline,
			"待っている間はCPUと対戦できます",
			EntryTilePaint.WELL_SMALL_SIZE,
			EntryTilePaint.WELL_MUTED
		)
	EntryTilePaint.draw_well_right(self, _font, rect, "シーズン終了まで %d日" % _days_left)


func _well_text(x: float, baseline: float, text: String, font_size: int, color: Color) -> void:
	draw_string(_font, Vector2(x, baseline), text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, color)


static func _offset(points: PackedVector2Array, by: Vector2) -> PackedVector2Array:
	var moved := PackedVector2Array()
	for point in points:
		moved.append(point + by)
	return moved
