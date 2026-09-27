class_name SoloEntryInfo
extends Control
## たたかうタブの「ソロモード」の札に載せる中身(GameDesign.md 9章)。
## 「対戦する」の札(`RankedEntryInfo`)と同じ組み立てで、遠征中なら作戦名と6段の進み具合、
## 遠征が無ければ記録を描く。札(`HomeTile`)の子として全面に敷き、押下は札へ通す。

const ROUTE_TOP_GAP := 20.0
const NODE_RADIUS := 7.0
const FINAL_RADIUS := 10.0
const NODE_RIM := 2.0
const ROUTE_LINE_WIDTH := 4.0
const NODE_DONE := Color(0.55, 0.36, 0.12)
const NODE_NOW := Color(1.0, 0.9, 0.6)
const NODE_AHEAD := Color(0.78, 0.62, 0.34)
const CONTINUE_DOT := Color(1.0, 0.78, 0.34)
const PULSE_SPEED := 3.2

var _run: SoloRun = null
var _best_wins := 0
var _clears := 0
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


func refresh(uid: String) -> void:
	_run = SoloProgress.load_run(uid)
	_best_wins = SoloProgress.best_wins(uid)
	_clears = SoloProgress.clears(uid)
	queue_redraw()


func _process(delta: float) -> void:
	if _run != null and is_visible_in_tree():
		_phase = fmod(_phase + delta * PULSE_SPEED, TAU)
		queue_redraw()


func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED:
		queue_redraw()


func _draw() -> void:
	if _font == null:
		return
	if _run == null:
		_draw_departure()
	else:
		_draw_running()


func _draw_departure() -> void:
	EntryTilePaint.draw_caption(self, _font, "つぎの遠征")
	EntryTilePaint.draw_head(self, _display, "作戦を選んで出発")
	EntryTilePaint.draw_line_text(self, _font, "いちばん多く勝った数 %d ・ 踏破 %d回" % [_best_wins, _clears])
	var rect := EntryTilePaint.well_rect(size)
	EntryTilePaint.draw_well(self, rect, false)
	draw_string(
		_font,
		Vector2(rect.position.x + EntryTilePaint.WELL_INSET, EntryTilePaint.well_baseline(rect)),
		"毎回ちがう道で山札を育てる",
		HORIZONTAL_ALIGNMENT_LEFT,
		-1,
		EntryTilePaint.WELL_TEXT_SIZE,
		EntryTilePaint.WELL_TEXT
	)


func _draw_running() -> void:
	var caption := "遠征中の作戦 ・ 深さ%d" % _run.depth if _run.depth > 0 else "遠征中の作戦"
	EntryTilePaint.draw_caption(self, _font, caption)
	EntryTilePaint.draw_head(self, _display, CardCpuDecks.name_of(_run.theme_id))
	_draw_route(EntryTilePaint.rule_y() + ROUTE_TOP_GAP)
	var rect := EntryTilePaint.well_rect(size)
	EntryTilePaint.draw_well(self, rect, false)
	EntryTilePaint.draw_dot(self, EntryTilePaint.well_dot_center(rect), CONTINUE_DOT, _phase)
	draw_string(
		_font,
		Vector2(EntryTilePaint.well_text_left(rect), EntryTilePaint.well_baseline(rect)),
		"続きから進める",
		HORIZONTAL_ALIGNMENT_LEFT,
		-1,
		EntryTilePaint.WELL_TEXT_SIZE,
		EntryTilePaint.WELL_TEXT
	)
	EntryTilePaint.draw_well_right(
		self, _font, rect, "%d勝 ・ HP %d/%d" % [_run.wins, _run.hp, _run.max_hp]
	)


## 6段の道。選び終えた段は濃い真鍮、いまの段は明るく、先の段は沈める。最終戦は一回り大きい。
func _draw_route(center_y: float) -> void:
	var left := EntryTilePaint.LEFT + FINAL_RADIUS
	var step := (EntryTilePaint.RULE_LENGTH - FINAL_RADIUS * 2.0) / float(SoloRun.FLOOR_COUNT - 1)
	for i in SoloRun.FLOOR_COUNT - 1:
		var from := Vector2(left + step * float(i), center_y)
		var line_alpha := 0.9 if i < _run.floor else 0.35
		draw_line(
			from,
			from + Vector2(step, 0.0),
			Color(EntryTilePaint.ENGRAVE_COLOR, line_alpha),
			ROUTE_LINE_WIDTH
		)
	for i in SoloRun.FLOOR_COUNT:
		var center := Vector2(left + step * float(i), center_y)
		var radius := FINAL_RADIUS if i == SoloRun.FLOOR_COUNT - 1 else NODE_RADIUS
		var fill := NODE_AHEAD
		if i < _run.floor:
			fill = NODE_DONE
		elif i == _run.floor:
			fill = NODE_NOW
		EntryTilePaint.fill_circle(self, center, radius + NODE_RIM, EntryTilePaint.ENGRAVE_COLOR)
		EntryTilePaint.fill_circle(self, center, radius, fill)
