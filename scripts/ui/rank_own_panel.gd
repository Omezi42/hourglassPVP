class_name RankOwnPanel
extends Control
## ランク画面の左、自分の段位と月末報酬の段(GameDesign.md 28章「ランク画面」)。
## パネル(`content_panel.tres`)の上へ全面に重ね、中身だけを描く。

const PAD := Vector2(24, 20)
const HEAD_BASELINE := 44.0
const HEAD_SIZE := 16
const DAYS_SIZE := 15
const MEDAL_CENTER_Y := 128.0
const MEDAL_RADIUS := 60.0
const STAR_Y := 214.0
const STAR_RADIUS := 10.0
const STAR_SPACING := 26.0
const TIER_BASELINE := 272.0
const TIER_SIZE := 40
const NEXT_BASELINE := 306.0
const NEXT_SIZE := 20
const RATING_SIZE := 26
const STREAK_TOP := 322.0
const STREAK_HEIGHT := 30.0
const STREAK_PAD := 36.0
const STREAK_SIZE := 16
const RULE_Y := 372.0
const REWARD_HEAD_BASELINE := RULE_Y + 30.0
const REWARD_HEAD_SIZE := 17
const REWARD_NOTE_SIZE := 13
const REWARD_SLOT_TOP := RULE_Y + 46.0
const REWARD_SLOT_HEIGHT := 100.0
const REWARD_SLOT_GAP := 8.0
const REWARD_SLOT_RADIUS := 10.0
const REWARD_MEDAL_Y := RULE_Y + 80.0
const REWARD_MEDAL_RADIUS := 20.0
const REWARD_NAME_BASELINE := RULE_Y + 118.0
const REWARD_AMOUNT_BASELINE := RULE_Y + 137.0
const REWARD_TEXT_SIZE := 13
const CORNER_SEGMENTS := 8
## 月末報酬の段に並べる帯(刻印を打たない帯そのもののメダル)。
const REWARD_TIERS: Array[String] = ["bronze1", "silver1", "gold1", "platinum"]
const TEXT_SHADOW := Color(0, 0, 0, 0.6)
const TEXT_SHADOW_OFFSET := Vector2(0, 1.5)

var _tier := RankRules.INITIAL_TIER
var _stars := 0
var _rating := 0
var _streak := 0
var _peak := RankRules.INITIAL_TIER
var _days_left := 0
var _font: Font
var _display: Font


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func _ready() -> void:
	_font = get_theme_default_font()
	_display = UiFonts.display_font(_font)


## `RankProgress.standing()` の値を渡す。
func show_standing(standing: Dictionary, days_left: int) -> void:
	_tier = standing["tier"]
	_stars = standing["stars"]
	_rating = standing["rating"]
	_streak = standing["streak"]
	_peak = standing["peak"]
	_days_left = days_left
	queue_redraw()


func _draw() -> void:
	if _font == null:
		return
	var inner := Rect2(PAD, size - PAD * 2.0)
	var platinum := _tier == RankRules.PLATINUM_KEY
	_text(_font, Vector2(inner.position.x, HEAD_BASELINE), "いまの段位", HEAD_SIZE, UiPalette.TEXT_MUTED)
	_text(
		_font,
		Vector2(inner.position.x, HEAD_BASELINE),
		"シーズン終了まで %d日" % _days_left,
		DAYS_SIZE,
		UiPalette.TEXT_MUTED,
		HORIZONTAL_ALIGNMENT_RIGHT,
		inner.size.x
	)
	var center_x := inner.get_center().x
	RankMedal.draw_medal(self, Vector2(center_x, MEDAL_CENTER_Y), MEDAL_RADIUS, _tier, _display)
	if not platinum:
		_draw_stars(center_x)
	_text(
		_display,
		Vector2(inner.position.x, TIER_BASELINE),
		_tier_label(),
		TIER_SIZE,
		UiPalette.TEXT_OFFWHITE,
		HORIZONTAL_ALIGNMENT_CENTER,
		inner.size.x
	)
	_text(
		_font,
		Vector2(inner.position.x, NEXT_BASELINE),
		_next_line(),
		RATING_SIZE if platinum else NEXT_SIZE,
		UiPalette.BRASS_HIGHLIGHT,
		HORIZONTAL_ALIGNMENT_CENTER,
		inner.size.x
	)
	# 連勝ボーナス(GameDesign.md 28章)はプラチナには効かないため、そこでは出さない。
	if not platinum and _streak > 0:
		_draw_streak(center_x)
	_draw_rewards(inner)


func _draw_stars(center_x: float) -> void:
	var need := RankRules.star_requirement(_tier)
	var left := center_x - STAR_SPACING * float(need - 1) * 0.5
	var outline := RankMedal.star_outline(STAR_RADIUS)
	for i in need:
		var at := Vector2(left + STAR_SPACING * float(i), STAR_Y)
		if i < _stars:
			RankMedal.draw_filled_star(self, at, STAR_RADIUS)
			continue
		var points := RankMedal.star_points(at, STAR_RADIUS)
		draw_colored_polygon(points, Color(0, 0, 0, 0.35))
		draw_polyline(
			RankMedal.closed(points), Color(UiPalette.BRASS_HIGHLIGHT, 0.45), outline, true
		)


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


## 連勝の札。ボーナスが乗っている間だけ琥珀にする(見えない恩恵は活かされないため)。
func _draw_streak(center_x: float) -> void:
	var bonus := _streak >= RankRules.WIN_STREAK_BONUS_THRESHOLD
	var text := "%d連勝中 ・ " % _streak
	if bonus:
		text += "次の勝ちで★+%d" % (1 + RankRules.WIN_STREAK_BONUS_STARS)
	else:
		text += "%d連勝で★ボーナス" % RankRules.WIN_STREAK_BONUS_THRESHOLD
	var width := (
		_font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, STREAK_SIZE).x + STREAK_PAD
	)
	var pill := Rect2(center_x - width * 0.5, STREAK_TOP, width, STREAK_HEIGHT)
	var stops := (
		[[0.0, UiPalette.PANEL_AMBER_TOP], [1.0, UiPalette.PANEL_AMBER_BOTTOM.darkened(0.25)]]
		if bonus
		else [[0.0, UiPalette.PANEL_PRESSED_TOP], [1.0, UiPalette.PANEL_PRESSED_BOTTOM]]
	)
	UiPaint.fill_gradient_polygon(
		get_canvas_item(),
		UiPaint.rounded_rect_points_uniform(pill, STREAK_HEIGHT * 0.5, CORNER_SEGMENTS),
		pill,
		stops
	)
	_text(
		_font,
		Vector2(pill.position.x, pill.position.y + STREAK_HEIGHT * 0.7),
		text,
		STREAK_SIZE,
		UiPalette.TEXT_OFFWHITE,
		HORIZONTAL_ALIGNMENT_CENTER,
		pill.size.x
	)


## 月末報酬の段。今シーズンの最高段位の帯だけを光らせる(報酬はその帯の1つだけのため)。
func _draw_rewards(inner: Rect2) -> void:
	draw_line(
		Vector2(inner.position.x, RULE_Y),
		Vector2(inner.end.x, RULE_Y),
		Color(UiPalette.GLOW_AMBER, 0.3),
		1.0
	)
	_text(
		_font,
		Vector2(inner.position.x, REWARD_HEAD_BASELINE),
		"月末報酬",
		REWARD_HEAD_SIZE,
		UiPalette.TEXT_OFFWHITE
	)
	_text(
		_font,
		Vector2(inner.position.x, REWARD_HEAD_BASELINE),
		"今シーズンの最高段位で決まります",
		REWARD_NOTE_SIZE,
		UiPalette.TEXT_MUTED,
		HORIZONTAL_ALIGNMENT_RIGHT,
		inner.size.x
	)
	var peak_bracket := RankRules.bracket_of(_peak)
	var slot := inner.size.x / float(REWARD_TIERS.size())
	for i in REWARD_TIERS.size():
		var tier := REWARD_TIERS[i]
		var bracket := RankRules.bracket_of(tier)
		var reached := bracket == peak_bracket
		var rect := Rect2(
			inner.position.x + slot * float(i) + REWARD_SLOT_GAP * 0.5,
			REWARD_SLOT_TOP,
			slot - REWARD_SLOT_GAP,
			REWARD_SLOT_HEIGHT
		)
		if reached:
			var points := UiPaint.rounded_rect_points_uniform(
				rect, REWARD_SLOT_RADIUS, CORNER_SEGMENTS
			)
			draw_colored_polygon(points, Color(UiPalette.GLOW_AMBER, 0.14))
			draw_polyline(RankMedal.closed(points), Color(UiPalette.GLOW_AMBER, 0.8), 1.5, true)
		RankMedal.draw_medal(
			self,
			Vector2(rect.get_center().x, REWARD_MEDAL_Y),
			REWARD_MEDAL_RADIUS,
			tier,
			_display,
			not reached,
			tier == RankRules.PLATINUM_KEY
		)
		var name := (
			RankRules.PLATINUM_NAME
			if tier == RankRules.PLATINUM_KEY
			else str(RankRules.BRACKET_NAMES[bracket])
		)
		_text(
			_font,
			Vector2(rect.position.x, REWARD_NAME_BASELINE),
			name,
			REWARD_TEXT_SIZE,
			UiPalette.TEXT_OFFWHITE if reached else UiPalette.TEXT_MUTED,
			HORIZONTAL_ALIGNMENT_CENTER,
			rect.size.x
		)
		_text(
			_font,
			Vector2(rect.position.x, REWARD_AMOUNT_BASELINE),
			CurrencyRules.label_text(int(RankProgress.SEASON_REWARDS[bracket])),
			REWARD_TEXT_SIZE,
			UiPalette.BRASS_HIGHLIGHT if reached else Color(UiPalette.TEXT_MUTED, 0.7),
			HORIZONTAL_ALIGNMENT_CENTER,
			rect.size.x
		)


func _text(
	font: Font,
	at: Vector2,
	text: String,
	font_size: int,
	color: Color,
	align := HORIZONTAL_ALIGNMENT_LEFT,
	width := -1.0
) -> void:
	draw_string(font, at + TEXT_SHADOW_OFFSET, text, align, width, font_size, TEXT_SHADOW)
	draw_string(font, at, text, align, width, font_size, color)
