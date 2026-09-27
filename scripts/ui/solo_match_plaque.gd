class_name SoloMatchPlaque
extends Control
## 遠征の対局中に出す「遠征の札」(GameDesign.md 27章「画面」節「遠征の札」)。
## 直前の手の列(`CardMatchActionHistory`)の下に、1件と同じ幅・同じ語彙
## (濃紺の板に真鍮の縁)で常に置く。生成・更新・後始末は `CardMatchSolo` が持つ
## (Architecture.md 10.15節)。遠征以外の対局では作らない。
##
## 「段目」の行き先の説明はホバーで出す(対局・最終戦は説明を持たないため出さない)。
## `CardDetailPanel` はカードの絵・紋章・総量を前提に組まれており、関門のような
## カードでないものの説明だけを出す用途には合わないため、同じ額縁の見た目
## (`content_panel.tres`)で文字だけを出す小さいパネルをここに持つ。

const HEIGHT := 74.0
const TILE_RADIUS := 7.0
const RIM_WIDTH := 1.5
const GRAIN_ALPHA := 0.06
const MARGIN_X := 12.0
const FLOOR_BASELINE := 18.0
const KIND_BASELINE := 40.0
const GOAL_BASELINE := 62.0
const FLOOR_FONT_SIZE := 11
const KIND_FONT_SIZE := 15
const GOAL_FONT_SIZE := 12

## 残りの数が変わった瞬間の跳ね(`WorkshopStockItem`の「2/2」バッジと同じ流儀)。
const PUNCH_DURATION := 0.25
const PUNCH_SCALE := 0.3

## 関門の説明パネル(額縁だけ`CardDetailPanel`と共通の`content_panel.tres`)。
const HOVER_STYLE := "res://resources/theme/content_panel.tres"
const HOVER_WIDTH := 300.0
const HOVER_MARGIN := 14.0
## 札の右へ余白ぶんずらして出す(札は左端に固定されており、右側は卓の余白のため)。
const HOVER_OFFSET := Vector2(10.0, 0.0)

var _screen: CardMatchScreen
var _solo: CardMatchSolo
var _font: Font
var _run: SoloRun
var _gate: SoloGateData
var _floor_text := ""
var _kind_text := ""
var _goal_lead := ""
var _goal_value := -1
var _goal_tail := ""
var _prev_goal_value := -1
var _goal_punch := 0.0
var _punch_tween: Tween
var _hover_panel: PanelContainer
var _hover_label: Label


func _init(screen: CardMatchScreen, solo: CardMatchSolo) -> void:
	_screen = screen
	_solo = solo
	mouse_filter = Control.MOUSE_FILTER_STOP
	mouse_entered.connect(_on_mouse_entered)
	mouse_exited.connect(_on_mouse_exited)


func _ready() -> void:
	_font = TextGlyphs.ui_font()
	# 直前の手の列(`CardMatchActionHistory`)の下端+間隔に置く。実行時に読むことで、
	# 互いのconstをconstから参照して読み込みが循環する不具合(Pitfalls.md)を避ける。
	position = Vector2(
		CardMatchActionHistory.ORIGIN.x,
		(
			CardMatchActionHistory.ORIGIN.y
			+ (
				(CardMatchActionHistory.TILE_SIZE.y + CardMatchActionHistory.TILE_GAP)
				* CardMatchActionHistory.MAX_TILES
			)
			+ CardMatchActionHistory.TILE_GAP
		)
	)
	size = Vector2(CardMatchActionHistory.TILE_SIZE.x, HEIGHT)
	visible = false
	_build_hover_panel()


## 遠征の対局を始めたときに呼ぶ(GameDesign.md 27章)。
func start(run: SoloRun, gate: SoloGateData) -> void:
	_run = run
	_gate = gate
	_floor_text = "遠征 ・ %d段目" % (run.floor + 1)
	if run.floor == SoloRun.FLOOR_COUNT - 1:
		_kind_text = "最終戦"
	elif gate != null:
		_kind_text = "関門『%s』" % gate.display_name
	else:
		_kind_text = "対局"
	_prev_goal_value = -1
	_goal_punch = 0.0
	visible = true
	_sync_goal()
	queue_redraw()


func close() -> void:
	_run = null
	_gate = null
	visible = false
	_hover_panel.visible = false


## 手番開始・破壊のたびに呼ぶ(特殊勝利条件の関門だけ持つ残りの数の更新元)。
func refresh() -> void:
	if _run == null:
		return
	_sync_goal()
	queue_redraw()


func _sync_goal() -> void:
	_goal_lead = ""
	_goal_tail = ""
	_goal_value = _solo.remaining_for(_gate)
	if _goal_value < 0:
		return
	match _gate.win_condition:
		SoloGateData.WinCondition.SURVIVE_TURNS:
			_goal_lead = "あと"
			_goal_tail = "手番"
		SoloGateData.WinCondition.DESTROY_ALL_ENEMY_UNITS:
			_goal_lead = "相手の場に あと"
			_goal_tail = "体"
	if _prev_goal_value >= 0 and _goal_value != _prev_goal_value:
		_start_punch()
	_prev_goal_value = _goal_value


func _start_punch() -> void:
	_goal_punch = 1.0
	if _punch_tween != null and _punch_tween.is_valid():
		_punch_tween.kill()
	_punch_tween = create_tween()
	_punch_tween.set_ease(Tween.EASE_OUT)
	_punch_tween.tween_method(_set_goal_punch, 1.0, 0.0, PUNCH_DURATION)


func _set_goal_punch(value: float) -> void:
	_goal_punch = value
	queue_redraw()


func _draw() -> void:
	if _run == null:
		return
	var rect := Rect2(Vector2.ZERO, size)
	var ci := get_canvas_item()
	var points := UiPaint.rounded_rect_points_uniform(rect, TILE_RADIUS, 5)
	UiPaint.fill_gradient_polygon(
		ci, points, rect, [[0.0, UiPalette.NAVY_PANEL_TOP], [1.0, UiPalette.NAVY_PANEL_BOTTOM]]
	)
	UiPaint.apply_grain(ci, rect, GRAIN_ALPHA)
	var outline := points.duplicate()
	outline.append(points[0])
	draw_polyline(outline, UiPalette.OUTLINE_DARK, 1.0, true)
	UiPaint.draw_bevel(
		ci, points, UiPalette.BRASS_RIM_LIGHT, UiPalette.BRASS_DARK, RIM_WIDTH, false
	)
	var max_width := size.x - MARGIN_X * 2.0
	_text(
		Vector2(MARGIN_X, FLOOR_BASELINE),
		_floor_text,
		FLOOR_FONT_SIZE,
		UiPalette.TEXT_MUTED,
		max_width
	)
	_text(
		Vector2(MARGIN_X, KIND_BASELINE),
		_kind_text,
		KIND_FONT_SIZE,
		UiPalette.TEXT_OFFWHITE,
		max_width
	)
	if _goal_value >= 0:
		_draw_goal(Vector2(MARGIN_X, GOAL_BASELINE), max_width)


func _draw_goal(pos: Vector2, max_width: float) -> void:
	var text := "%s %d %s" % [_goal_lead, _goal_value, _goal_tail]
	var boost := 1.0 + _goal_punch * PUNCH_SCALE
	draw_set_transform(pos, 0.0, Vector2.ONE * boost)
	_text(Vector2.ZERO, text, GOAL_FONT_SIZE, UiPalette.GLOW_AMBER, max_width / boost)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


## 幅を超える文字は`…`で切る(`CardMatchActionHistory._text()`と同じ流儀)。
func _text(pos: Vector2, value: String, font_size: int, color: Color, max_width: float) -> void:
	var shown := value
	while (
		shown.length() > 1
		and _font.get_string_size(shown, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x > max_width
	):
		shown = shown.left(shown.length() - 2) + "…"
	draw_string(
		_font,
		pos + Vector2.ONE,
		shown,
		HORIZONTAL_ALIGNMENT_LEFT,
		-1,
		font_size,
		PlayerInfoBar.TEXT_SHADOW
	)
	draw_string(_font, pos, shown, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, color)


## 関門の説明(GameDesign.md 27章「関門(特殊ルール)」)。対局・最終戦は説明を持たないため出さない。
func _on_mouse_entered() -> void:
	if _gate == null:
		return
	_hover_label.text = _gate.description
	_hover_panel.position = Vector2(size.x, 0.0) + HOVER_OFFSET
	_hover_panel.visible = true
	_hover_panel.move_to_front()


func _on_mouse_exited() -> void:
	_hover_panel.visible = false


func _build_hover_panel() -> void:
	_hover_panel = PanelContainer.new()
	_hover_panel.custom_minimum_size = Vector2(HOVER_WIDTH, 0)
	var style: StyleBox = load(HOVER_STYLE)
	if style != null:
		_hover_panel.add_theme_stylebox_override("panel", style)
	_hover_panel.visible = false
	# パネルは押す操作を持たない(GameDesign.md 27章)。ホバーを奪うと札自体から
	# 外れた扱いになり、消えたり点滅したりするため触らせない。
	_hover_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var margin := MarginContainer.new()
	for side in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, HOVER_MARGIN)
	_hover_panel.add_child(margin)
	_hover_label = Label.new()
	_hover_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_hover_label.custom_minimum_size = Vector2(HOVER_WIDTH - HOVER_MARGIN * 2.0, 0)
	_hover_label.add_theme_font_size_override("font_size", 15)
	_hover_label.add_theme_color_override("font_color", UiPalette.TEXT_OFFWHITE)
	margin.add_child(_hover_label)
	add_child(_hover_panel)
