class_name CardMatchStartCurtain
extends RefCounted
## 対局開始の幕(GameDesign.md 9章)。`CardMatchTurnFeed` が経過秒を渡して描かせる。
## 状態を持たず、砂粒の飛び方も添字から決める(描き直すたびに同じ軌跡になるように)。

const DURATION := 2.0
const TITLE := "対局開始"
const TITLE_FONT_SIZE := 58
const NAME_FONT_SIZE := 26
const FADE_IN := 0.15
const FADE_OUT := 0.35
const DIM_ALPHA := 0.5
## 帯は中央から左右へ伸びる。値は伸び始めと伸びきる秒。
const BAND_GROW := Vector2(0.06, 0.4)
const BAND_HEIGHT := 96.0
const BAND_NOTCH := 40.0
## 帯の幅は卓の幅に対する比。
const BAND_WIDTH_RATIO := 0.86
## 文字は大きめに出てから定位置の大きさへ縮む。
const TITLE_IN := Vector2(0.2, 0.48)
const TITLE_PUNCH := 0.4
const NAME_IN := Vector2(0.42, 0.8)
const NAME_GAP := 34.0
const NAME_SLIDE := 36.0
const RAY_COUNT := 18
const RAY_SPIN := 0.35
const RAY_REACH := Vector2(70.0, 260.0)
const RAY_WIDTH := 2.5
const GRAIN_COUNT := 56
const GRAIN_START := 0.22
const GRAIN_LIFE := 1.3
const GRAIN_SPEED := Vector2(140.0, 420.0)
const GRAIN_GRAVITY := 300.0
const GRAIN_SIZE := Vector2(2.0, 4.5)
const SAND_COLOR := Color(0.95, 0.8, 0.5)


static func draw(
	item: CanvasItem, font: Font, t: float, table: Rect2, own_name: String, foe_name: String
) -> void:
	var alpha := clampf(t / FADE_IN, 0.0, 1.0) * clampf((DURATION - t) / FADE_OUT, 0.0, 1.0)
	var center := table.get_center()
	var screen := Rect2(Vector2.ZERO, item.get_viewport_rect().size)
	item.draw_rect(screen, Color(0, 0, 0, DIM_ALPHA * alpha))
	_draw_rays(item, center, t, alpha)
	_draw_grains(item, center, t, alpha)
	var band := _band_rect(center, table, t)
	if band.size.x > BAND_NOTCH * 2.0:
		_draw_band(item, band, alpha)
	_draw_title(item, font, center, t, alpha)
	var rise := 1.0 - _ease_out(_phase(t, NAME_IN))
	var name_alpha := alpha * _phase(t, NAME_IN)
	var half := BAND_HEIGHT * 0.5 + NAME_GAP
	_draw_name(
		item, font, foe_name, Vector2(center.x, center.y - half - rise * NAME_SLIDE), name_alpha
	)
	_draw_name(
		item,
		font,
		own_name,
		Vector2(center.x, center.y + half + NAME_FONT_SIZE + rise * NAME_SLIDE),
		name_alpha
	)


## 区間 `span`(始まりと終わりの秒)の中での進み具合 0〜1。
static func _phase(t: float, span: Vector2) -> float:
	return clampf((t - span.x) / (span.y - span.x), 0.0, 1.0)


static func _ease_out(x: float) -> float:
	return 1.0 - pow(1.0 - x, 3.0)


static func _band_rect(center: Vector2, table: Rect2, t: float) -> Rect2:
	var width := table.size.x * BAND_WIDTH_RATIO * _ease_out(_phase(t, BAND_GROW))
	return Rect2(
		Vector2(center.x - width * 0.5, center.y - BAND_HEIGHT * 0.5), Vector2(width, BAND_HEIGHT)
	)


static func _draw_band(item: CanvasItem, band: Rect2, alpha: float) -> void:
	var ci := item.get_canvas_item()
	var points := UiPaint.banner_points(band, BAND_NOTCH)
	(
		UiPaint
		. fill_gradient_polygon(
			ci,
			points,
			band,
			[
				[0.0, Color(UiPalette.NAMEPLATE_PANEL_TOP, alpha * 0.92)],
				[0.5, Color(UiPalette.NAMEPLATE_PANEL_BOTTOM, alpha * 0.92)],
				[1.0, Color(UiPalette.NAMEPLATE_PANEL_TOP, alpha * 0.92)],
			]
		)
	)
	var outline := points.duplicate()
	outline.append(points[0])
	ShapePaint.polyline(ci, outline, Color(UiPalette.BRASS_HIGHLIGHT, alpha), 2.0, true)


static func _draw_title(
	item: CanvasItem, font: Font, center: Vector2, t: float, alpha: float
) -> void:
	var p := _phase(t, TITLE_IN)
	if p <= 0.0:
		return
	var scale := 1.0 + TITLE_PUNCH * (1.0 - _ease_out(p))
	var width := font.get_string_size(TITLE, HORIZONTAL_ALIGNMENT_LEFT, -1, TITLE_FONT_SIZE).x
	item.draw_set_transform(center, 0.0, Vector2.ONE * scale)
	item.draw_string(
		font,
		Vector2(-width * 0.5, TITLE_FONT_SIZE * 0.36),
		TITLE,
		HORIZONTAL_ALIGNMENT_LEFT,
		-1,
		TITLE_FONT_SIZE,
		Color(UiPalette.GLOW_AMBER, alpha * minf(p * 3.0, 1.0))
	)
	item.draw_set_transform(Vector2.ZERO)


## 名前はプレイヤーの入力なので本文用のフォントで描く(Pitfalls.md)。
static func _draw_name(
	item: CanvasItem, font: Font, text: String, baseline_center: Vector2, alpha: float
) -> void:
	if alpha <= 0.0 or text.is_empty():
		return
	var width := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, NAME_FONT_SIZE).x
	var at := Vector2(baseline_center.x - width * 0.5, baseline_center.y)
	item.draw_string(
		font,
		at + Vector2(0, 2),
		text,
		HORIZONTAL_ALIGNMENT_LEFT,
		-1,
		NAME_FONT_SIZE,
		Color(0, 0, 0, alpha * 0.8)
	)
	item.draw_string(
		font,
		at,
		text,
		HORIZONTAL_ALIGNMENT_LEFT,
		-1,
		NAME_FONT_SIZE,
		Color(UiPalette.TEXT_OFFWHITE, alpha)
	)


## 帯の後ろの光条。ゆっくり回りながら、帯が伸びるのに合わせて長くなる。
static func _draw_rays(item: CanvasItem, center: Vector2, t: float, alpha: float) -> void:
	var reach := lerpf(RAY_REACH.x, RAY_REACH.y, _ease_out(_phase(t, BAND_GROW)))
	for i in RAY_COUNT:
		var angle := TAU * float(i) / float(RAY_COUNT) + t * RAY_SPIN
		var dir := Vector2(cos(angle), sin(angle))
		var length := reach * (0.7 if i % 2 == 1 else 1.0)
		item.draw_line(
			center + dir * RAY_REACH.x * 0.6,
			center + dir * length,
			Color(UiPalette.GLOW_AMBER, alpha * 0.35),
			RAY_WIDTH
		)


## 帯の中央から舞い散る砂粒。向き・速さ・大きさは添字から決める。
static func _draw_grains(item: CanvasItem, center: Vector2, t: float, alpha: float) -> void:
	var age := t - GRAIN_START
	if age <= 0.0 or age >= GRAIN_LIFE:
		return
	var life := 1.0 - age / GRAIN_LIFE
	for i in GRAIN_COUNT:
		var r1 := _hash01(i, 1)
		var angle := TAU * r1
		var speed := lerpf(GRAIN_SPEED.x, GRAIN_SPEED.y, _hash01(i, 2))
		var velocity := Vector2(cos(angle), sin(angle) * 0.6) * speed
		var pos := center + velocity * age + Vector2(0, GRAIN_GRAVITY * age * age * 0.5)
		var grain := lerpf(GRAIN_SIZE.x, GRAIN_SIZE.y, _hash01(i, 3))
		item.draw_rect(
			Rect2(pos - Vector2.ONE * grain * 0.5, Vector2.ONE * grain),
			Color(SAND_COLOR, alpha * life)
		)


static func _hash01(index: int, salt: int) -> float:
	return float(absi(hash(index * 7919 + salt * 104729)) % 10000) / 10000.0
