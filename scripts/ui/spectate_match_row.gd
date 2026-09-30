class_name SpectateMatchRow
extends Button
## 観戦一覧の1行(GameDesign.md 12章)。左に先手、右に後手のアイコン・名前・段位を向かい合わせに置き、
## 中央に経過したターン数を出す。行そのものを押すと観戦へ入る。

const HEIGHT := 76.0
const EDGE_PAD := 22.0
const PORTRAIT_RADIUS := 20.0
const PORTRAIT_ICON := 16.0
const PORTRAIT_RING := 2.5
const NAME_GAP := 14.0
const NAME_SIZE := 18
const STANDING_SIZE := 13
const MEDAL_RADIUS := 15.0
const MEDAL_GAP := 8.0
const CENTER_WIDTH := 150.0
const TURN_SIZE := 20
const VS_SIZE := 13
const PORTRAIT_BACK := Color(0.05, 0.04, 0.03)
const TEXT_SHADOW := Color(0, 0, 0, 0.6)
const TEXT_SHADOW_OFFSET := Vector2(0, 1.5)

var match_id := ""
var turn := 1
## `players/{uid}` のフィールド(空なら名無し・ブロンズ1として描く)。
var player_a: Dictionary = {}
var player_b: Dictionary = {}
var _font: Font
var _display: Font


func _init() -> void:
	custom_minimum_size.y = HEIGHT
	focus_mode = Control.FOCUS_NONE
	CodedButton.apply_styles(self, CodedButton.WIDE_GROUP)


func _ready() -> void:
	_font = get_theme_default_font()
	_display = UiFonts.display_font(_font)


func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED:
		queue_redraw()


func _draw() -> void:
	if _font == null or size.x <= CENTER_WIDTH:
		return
	var center_y := size.y * 0.5
	var half := (size.x - CENTER_WIDTH) * 0.5
	_draw_player(player_a, EDGE_PAD, half - EDGE_PAD, center_y, false)
	_draw_player(player_b, size.x - EDGE_PAD, half - EDGE_PAD, center_y, true)
	var mid := size.x * 0.5 - CENTER_WIDTH * 0.5
	_text("対", Vector2(mid, center_y - 8.0), VS_SIZE, UiPalette.TEXT_MUTED, CENTER_WIDTH)
	_text(
		"%dターン目" % turn,
		Vector2(mid, center_y + 18.0),
		TURN_SIZE,
		UiPalette.TEXT_OFFWHITE,
		CENTER_WIDTH
	)


## `edge` は外側の端のx。`mirrored` なら右端から内へ向けて並べる。
func _draw_player(
	fields: Dictionary, edge: float, width: float, center_y: float, mirrored: bool
) -> void:
	var dir := -1.0 if mirrored else 1.0
	var portrait := Vector2(edge + dir * PORTRAIT_RADIUS, center_y)
	_draw_portrait(portrait, str(fields.get("icon_id", "")))
	var tier := str(fields.get("rank_tier", RankRules.INITIAL_TIER))
	if not RankRules.is_valid_tier(tier):
		tier = RankRules.INITIAL_TIER
	var medal := Vector2(
		edge + dir * (PORTRAIT_RADIUS * 2.0 + NAME_GAP + MEDAL_RADIUS), center_y + 2.0
	)
	RankMedal.draw_medal(self, medal, MEDAL_RADIUS, tier, _display)
	var text_start := PORTRAIT_RADIUS * 2.0 + NAME_GAP + MEDAL_RADIUS * 2.0 + MEDAL_GAP
	var text_width := width - text_start
	var text_x := edge + text_start if not mirrored else edge - text_start - text_width
	var align := HORIZONTAL_ALIGNMENT_RIGHT if mirrored else HORIZONTAL_ALIGNMENT_LEFT
	var name := TextGlyphs.replace_unsupported(str(fields.get("display_name", "")))
	if name.is_empty():
		name = CardRankScreen.NAMELESS
	_text(
		name, Vector2(text_x, center_y - 3.0), NAME_SIZE, UiPalette.TEXT_OFFWHITE, text_width, align
	)
	_text(
		_standing_text(fields, tier),
		Vector2(text_x, center_y + 19.0),
		STANDING_SIZE,
		UiPalette.BRASS_HIGHLIGHT,
		text_width,
		align
	)


## 「ゴールド3 ★2」。プラチナはレートを出す(GameDesign.md 28章)。
static func _standing_text(fields: Dictionary, tier: String) -> String:
	if tier == RankRules.PLATINUM_KEY:
		return "%s %d" % [RankRules.display_name(tier), int(fields.get("rank_rating", 0))]
	return "%s ★%d" % [RankRules.display_name(tier), int(fields.get("rank_stars", 0))]


func _draw_portrait(center: Vector2, icon_id: String) -> void:
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


func _text(
	text: String,
	at: Vector2,
	font_size: int,
	color: Color,
	width: float,
	align := HORIZONTAL_ALIGNMENT_CENTER
) -> void:
	draw_string(_font, at + TEXT_SHADOW_OFFSET, text, align, width, font_size, TEXT_SHADOW)
	draw_string(_font, at, text, align, width, font_size, color)
