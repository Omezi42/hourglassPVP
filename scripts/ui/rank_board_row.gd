class_name RankBoardRow
extends Control
## ランキングの1行(GameDesign.md 28章「ランク画面」)。一覧の行と、最下段に固定する自分の行で共用する。
## 左から 順位 / アイコン / 称号・表示名 / 段位のメダル・帯と階級・★(プラチナはレート)。

const HEIGHT := 42.0
const RADIUS := 8.0
const CORNER_SEGMENTS := 8
const RANK_CENTER_X := 30.0
const RANK_SIZE := 19
const OUTSIDE_SIZE := 14
const PODIUM_RADIUS := 14.0
const PODIUM_TEXT_WIDTH := 40.0
const PORTRAIT_X := 82.0
const PORTRAIT_RADIUS := 17.0
const PORTRAIT_ICON := 14.0
const PORTRAIT_RING := 2.5
const NAME_X := 110.0
const NAME_SIZE := 18
const NAME_WITH_TITLE_SIZE := 17
const TITLE_SIZE := 11
const RIGHT_PAD := 14.0
const STAR_RADIUS := 7.5
const STAR_STEP := 20.0
const RATING_SIZE := 21
const RATING_WIDTH := 90.0
const TIER_SIZE := 15
const TIER_RIGHT := 110.0
const TIER_WIDTH := 110.0
const MEDAL_RIGHT := 238.0
const MEDAL_RADIUS := 15.0
const ZEBRA := Color(1, 1, 1, 0.035)
const PORTRAIT_BACK := Color(0.05, 0.04, 0.03)
const EMPTY_STAR_FILL := Color(0, 0, 0, 0.35)
const TEXT_SHADOW := Color(0, 0, 0, 0.6)
const TEXT_SHADOW_OFFSET := Vector2(0, 1.5)

## 順位。0以下は上位の一覧に入っていない(「圏外」)。
var rank := 0
var display_name := ""
var icon_id := UserProfileLibrary.DEFAULT_ICON_ID
var title_id := UserProfileLibrary.DEFAULT_TITLE_ID
var tier := RankRules.INITIAL_TIER
var stars := 0
var rating := 0
var mine := false
var zebra := false
var _font: Font
var _display: Font


func _init() -> void:
	custom_minimum_size.y = HEIGHT
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func _ready() -> void:
	_font = get_theme_default_font()
	_display = UiFonts.display_font(_font)


func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED:
		queue_redraw()


func _draw() -> void:
	# 並べられる前(幅0)は角丸の点列が潰れて塗れない。
	if _font == null or size.x <= RADIUS * 2.0:
		return
	var rect := Rect2(Vector2.ZERO, size)
	var points := UiPaint.rounded_rect_points_uniform(rect, RADIUS, CORNER_SEGMENTS)
	if mine:
		UiPaint.fill_gradient_polygon(
			get_canvas_item(),
			points,
			rect,
			[
				[0.0, Color(UiPalette.PANEL_AMBER_TOP, 0.55)],
				[1.0, Color(UiPalette.PANEL_AMBER_TOP.lightened(0.1), 0.35)]
			]
		)
		draw_polyline(RankMedal.closed(points), Color(UiPalette.GLOW_AMBER, 0.85), 1.5, true)
	elif zebra:
		draw_colored_polygon(points, ZEBRA)
	var center_y := size.y * 0.5
	_draw_rank(center_y)
	_draw_portrait(Vector2(PORTRAIT_X, center_y))
	_draw_name(center_y)
	_draw_standing(center_y)


## 1〜3位は金銀銅の丸に数字を打つ。
func _draw_rank(center_y: float) -> void:
	var center := Vector2(RANK_CENTER_X, center_y)
	if rank >= 1 and rank <= RankMedal.PODIUM_BRACKETS.size():
		var colors := RankMedal.metal(RankMedal.PODIUM_BRACKETS[rank - 1])
		UiPaint.fill_circle(
			get_canvas_item(),
			center + Vector2(0, 1.5),
			PODIUM_RADIUS + 1.0,
			Color(0, 0, 0, 0.4),
			RankMedal.SEGMENTS
		)
		RankMedal.fill_gradient_circle(
			self, center, PODIUM_RADIUS, [[0.0, colors[0]], [0.5, colors[1]], [1.0, colors[2]]]
		)
		RankMedal.draw_struck_number(
			self, center, PODIUM_RADIUS * 1.3, str(rank), _display, colors[0], colors[2]
		)
		return
	var label := str(rank) if rank > 0 else "圏外"
	_text(
		label,
		Vector2(RANK_CENTER_X - PODIUM_TEXT_WIDTH * 0.5, center_y + 7.0),
		RANK_SIZE if rank > 0 else OUTSIDE_SIZE,
		UiPalette.TEXT_OFFWHITE if rank > 0 else UiPalette.TEXT_MUTED,
		HORIZONTAL_ALIGNMENT_CENTER,
		PODIUM_TEXT_WIDTH
	)


func _draw_portrait(center: Vector2) -> void:
	UiPaint.fill_circle(
		get_canvas_item(), center, PORTRAIT_RADIUS, PORTRAIT_BACK, RankMedal.SEGMENTS
	)
	var texture := UserProfileLibrary.get_icon_texture(icon_id)
	if texture != null:
		draw_texture_rect(
			texture,
			Rect2(center - Vector2.ONE * PORTRAIT_ICON, Vector2.ONE * PORTRAIT_ICON * 2.0),
			false
		)
	draw_arc(
		center,
		PORTRAIT_RADIUS,
		0.0,
		TAU,
		RankMedal.SEGMENTS,
		UiPalette.BRASS_RIM_LIGHT,
		PORTRAIT_RING,
		true
	)


## 称号(小)と表示名(大)。対局の名札(`PlayerInfoBar`)と同じ並び。
func _draw_name(center_y: float) -> void:
	var name_width := size.x - MEDAL_RIGHT - MEDAL_RADIUS - NAME_X - RIGHT_PAD
	var title := UserProfileLibrary.get_title_display(title_id)
	if title.is_empty():
		_text(
			display_name,
			Vector2(NAME_X, center_y + 7.0),
			NAME_SIZE,
			UiPalette.TEXT_OFFWHITE,
			HORIZONTAL_ALIGNMENT_LEFT,
			name_width
		)
		return
	draw_string(
		_font,
		Vector2(NAME_X, center_y - 5.0),
		title,
		HORIZONTAL_ALIGNMENT_LEFT,
		name_width,
		TITLE_SIZE,
		UiPalette.BRASS_HIGHLIGHT
	)
	_text(
		display_name,
		Vector2(NAME_X, center_y + 14.0),
		NAME_WITH_TITLE_SIZE,
		UiPalette.TEXT_OFFWHITE,
		HORIZONTAL_ALIGNMENT_LEFT,
		name_width
	)


func _draw_standing(center_y: float) -> void:
	var right := size.x - RIGHT_PAD
	if tier == RankRules.PLATINUM_KEY:
		_text(
			str(rating),
			Vector2(right - RATING_WIDTH, center_y + 8.0),
			RATING_SIZE,
			UiPalette.TEXT_OFFWHITE,
			HORIZONTAL_ALIGNMENT_RIGHT,
			RATING_WIDTH
		)
	else:
		_draw_stars(right, center_y)
	_text(
		RankRules.display_name(tier),
		Vector2(right - TIER_RIGHT - TIER_WIDTH, center_y + 6.0),
		TIER_SIZE,
		UiPalette.TEXT_OFFWHITE,
		HORIZONTAL_ALIGNMENT_RIGHT,
		TIER_WIDTH
	)
	RankMedal.draw_medal(self, Vector2(right - MEDAL_RIGHT, center_y), MEDAL_RADIUS, tier, _display)


func _draw_stars(right: float, center_y: float) -> void:
	var need := RankRules.star_requirement(tier)
	var outline := RankMedal.star_outline(STAR_RADIUS)
	for i in need:
		var at := Vector2(right - STAR_RADIUS - STAR_STEP * float(need - 1 - i), center_y)
		if i < stars:
			RankMedal.draw_filled_star(self, at, STAR_RADIUS)
			continue
		var points := RankMedal.star_points(at, STAR_RADIUS)
		draw_colored_polygon(points, EMPTY_STAR_FILL)
		draw_polyline(
			RankMedal.closed(points), Color(UiPalette.BRASS_HIGHLIGHT, 0.45), outline, true
		)


func _text(
	text: String,
	at: Vector2,
	font_size: int,
	color: Color,
	align: HorizontalAlignment,
	width: float
) -> void:
	draw_string(_font, at + TEXT_SHADOW_OFFSET, text, align, width, font_size, TEXT_SHADOW)
	draw_string(_font, at, text, align, width, font_size, color)
