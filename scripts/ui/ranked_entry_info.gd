class_name RankedEntryInfo
extends Control
## たたかうタブの「対戦する」の札に載せる中身(GameDesign.md 9章)。
## いまの段位・★の進み具合・次の段位まで・シーズンの残り日数と、待っている人の行を出す。
## 札(`HomeTile`)の子として全面に敷き、押下は札へ通す。

const TEXT_COLOR := HomeTile.SUB_ON_BRASS
const STAR_COLOR := Color(0.55, 0.33, 0.05)
const WAITING_COLOR := Color(0.62, 0.18, 0.10)
const LEFT := 40.0
## 見出しと副題(`HomeTile` が上に描く)の下から並べる。
const TOP := 124.0
const CAPTION_SIZE := 18
const TIER_SIZE := 48
const STAR_SIZE := 40
const LINE_SIZE := 18
const WAITING_SIZE := 22
const STAR_GAP := 24.0
## 行の間隔(見出しの下 / 段位の下 / 1行ぶん)。
const CAPTION_GAP := 6.0
const TIER_GAP := 18.0
const LINE_GAP := 10.0
## 待機の行は札の下端からこれだけ上に置く。
const WAITING_BOTTOM := 60.0
const FILLED_STAR := "★"
const EMPTY_STAR := "☆"

var _caption: Label
var _tier: Label
var _stars: Label
var _next: Label
var _season: Label
var _waiting: Label


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_caption = _make_label(CAPTION_SIZE, TEXT_COLOR)
	_caption.text = "いまの段位"
	_tier = _make_label(TIER_SIZE, TEXT_COLOR)
	_stars = _make_label(STAR_SIZE, STAR_COLOR)
	_next = _make_label(LINE_SIZE, TEXT_COLOR)
	_season = _make_label(LINE_SIZE, TEXT_COLOR)
	_waiting = _make_label(LINE_SIZE, TEXT_COLOR)
	_waiting.visible = false


func refresh() -> void:
	var tier := AccountService.rank_tier()
	var stars := AccountService.rank_stars()
	# 前のシーズンの段位は、ランクマッチへ入った時点で初期化される(GameDesign.md 28章)。
	var season := AccountService.rank_season()
	if season != "" and season != RankProgress.current_season_key():
		tier = RankRules.INITIAL_TIER
		stars = 0
	_tier.text = RankRules.display_name(tier)
	if tier == RankRules.PLATINUM_KEY:
		_stars.text = "レート %d" % AccountService.rank_rating()
		_next.text = ""
	else:
		var need := RankRules.star_requirement(tier)
		_stars.text = FILLED_STAR.repeat(stars) + EMPTY_STAR.repeat(maxi(need - stars, 0))
		var next_tier: String = RankRules.advance_stars(tier, need)["tier"]
		_next.text = ("あと★%dつで %s" % [maxi(need - stars, 1), RankRules.display_name(next_tier)])
	_season.text = "シーズン終了まで %d日" % RankProgress.days_left_in_season()
	_layout()


## 待っている人の数。負なら行ごと隠す(通信できない)。0人のときは人数を出さない。
func set_waiting(count: int) -> void:
	_waiting.visible = count >= 0
	if count > 0:
		_waiting.text = "● いま %d人が相手を待っています" % count
		_restyle(_waiting, WAITING_SIZE, WAITING_COLOR)
	else:
		_waiting.text = "待っている間はCPUと対戦できます"
		_restyle(_waiting, LINE_SIZE, TEXT_COLOR)
	_layout()


func _layout() -> void:
	var font := get_theme_default_font()
	var y := TOP
	_caption.position = Vector2(LEFT, y)
	y += CAPTION_SIZE + CAPTION_GAP
	_tier.position = Vector2(LEFT, y)
	var tier_width := 0.0
	if font != null:
		tier_width = font.get_string_size(_tier.text, HORIZONTAL_ALIGNMENT_LEFT, -1, TIER_SIZE).x
	_stars.position = Vector2(LEFT + tier_width + STAR_GAP, y + (TIER_SIZE - STAR_SIZE) * 0.5)
	y += TIER_SIZE + TIER_GAP
	_next.position = Vector2(LEFT, y)
	if not _next.text.is_empty():
		y += LINE_SIZE + LINE_GAP
	_season.position = Vector2(LEFT, y)
	_waiting.position = Vector2(LEFT, size.y - WAITING_BOTTOM)


func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED:
		_layout()


func _make_label(font_size: int, color: Color) -> Label:
	var label := Label.new()
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_restyle(label, font_size, color)
	add_child(label)
	return label


static func _restyle(label: Label, font_size: int, color: Color) -> void:
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
