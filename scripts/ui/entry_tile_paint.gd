class_name EntryTilePaint
## たたかうタブの真鍮の札(「対戦する」「ソロモード」)に共通する描画(GameDesign.md 9章)。
## 2枚を同格に見せるため、真鍮へ彫り込んだ文字・罫と下端の凹んだ行をここにまとめる。
## 光は左上から当たるものとして陰影を付ける。

## 真鍮へ彫り込んだ文字: 本体の暗色と、彫りの下縁に返る光。
const ENGRAVE_COLOR := Color(0.23, 0.14, 0.05)
const ENGRAVE_LIGHT := Color(1.0, 0.93, 0.74, 0.55)
const CAPTION_COLOR := Color(0.23, 0.14, 0.05, 0.72)
const SHADOW_COLOR := Color(0.10, 0.06, 0.02)
## 下端の凹んだ行。
const WELL_TOP := Color(0.11, 0.07, 0.04, 0.94)
const WELL_BOTTOM := Color(0.22, 0.15, 0.08, 0.94)
const WELL_ACCENT_TOP := Color(0.36, 0.18, 0.03, 0.96)
const WELL_ACCENT_BOTTOM := Color(0.55, 0.31, 0.07, 0.96)
const WELL_EDGE_LIGHT := Color(1.0, 0.9, 0.66, 0.4)
const WELL_TEXT := Color(0.96, 0.94, 0.89)
const WELL_MUTED := Color(0.78, 0.71, 0.58)
const ACCENT_TEXT := Color(1.0, 0.9, 0.64)

## 左の列の縦の組み(小見出し → 彫り文字 → 罫 → 1行)。
const LEFT := 40.0
const CAPTION_BASELINE := 124.0
const HEAD_SIZE := 44
const HEAD_GAP := 12.0
const CAPTION_SIZE := 16
const LINE_SIZE := 19
const RULE_LENGTH := 250.0

const WELL_HEIGHT := 50.0
const WELL_INSET := 14.0
const WELL_RADIUS := 8.0
const WELL_SHADOW_LAYERS := 4
const WELL_SHADOW_ALPHA := 0.55
const WELL_TEXT_SIZE := 19
const WELL_SMALL_SIZE := 16
const DOT_RADIUS := 6.0
const DOT_TEXT_GAP := 10.0
const SEGMENTS := 48
const CORNER_SEGMENTS := 12


static func head_baseline() -> float:
	return CAPTION_BASELINE + HEAD_GAP + float(HEAD_SIZE)


static func rule_y() -> float:
	return head_baseline() + HEAD_GAP


## 罫の下に置く1行の基準線。
static func line_baseline() -> float:
	return rule_y() + HEAD_GAP + float(LINE_SIZE)


static func draw_caption(target: CanvasItem, font: Font, text: String) -> void:
	target.draw_string(
		font,
		Vector2(LEFT, CAPTION_BASELINE),
		text,
		HORIZONTAL_ALIGNMENT_LEFT,
		-1,
		CAPTION_SIZE,
		CAPTION_COLOR
	)


## 小見出しの下の大きな彫り文字と、その下の罫。
static func draw_head(target: CanvasItem, font: Font, text: String) -> void:
	draw_engraved(target, font, Vector2(LEFT, head_baseline()), text, HEAD_SIZE)
	var y := rule_y()
	target.draw_line(
		Vector2(LEFT, y), Vector2(LEFT + RULE_LENGTH, y), Color(ENGRAVE_COLOR, 0.35), 1.0
	)
	target.draw_line(
		Vector2(LEFT, y + 1.0), Vector2(LEFT + RULE_LENGTH, y + 1.0), ENGRAVE_LIGHT, 1.0
	)


static func draw_line_text(target: CanvasItem, font: Font, text: String) -> void:
	target.draw_string(
		font,
		Vector2(LEFT, line_baseline()),
		text,
		HORIZONTAL_ALIGNMENT_LEFT,
		-1,
		LINE_SIZE,
		ENGRAVE_COLOR
	)


## 彫り込んだ文字: 下縁へ返る光を1段下に置き、その上へ暗い本体を重ねる。
static func draw_engraved(
	target: CanvasItem, font: Font, at: Vector2, text: String, font_size: int
) -> void:
	var offset: float = maxf(1.0, float(font_size) * 0.03)
	target.draw_string(
		font,
		at + Vector2(0.0, offset),
		text,
		HORIZONTAL_ALIGNMENT_LEFT,
		-1,
		font_size,
		ENGRAVE_LIGHT
	)
	target.draw_string(font, at, text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, ENGRAVE_COLOR)


static func well_rect(tile_size: Vector2) -> Rect2:
	return Rect2(
		WELL_INSET,
		tile_size.y - WELL_INSET - WELL_HEIGHT,
		tile_size.x - WELL_INSET * 2.0,
		WELL_HEIGHT
	)


## 下端の凹んだ行の面。`accent` は琥珀の知らせ(途中の対局・遠征の続き)。
static func draw_well(target: CanvasItem, rect: Rect2, accent: bool) -> void:
	var points := UiPaint.rounded_rect_points_uniform(rect, WELL_RADIUS, CORNER_SEGMENTS)
	var stops := (
		[[0.0, WELL_ACCENT_TOP], [1.0, WELL_ACCENT_BOTTOM]]
		if accent
		else [[0.0, WELL_TOP], [1.0, WELL_BOTTOM]]
	)
	UiPaint.fill_gradient_polygon(target.get_canvas_item(), points, rect, stops)
	UiPaint.draw_inner_shadow(
		target.get_canvas_item(),
		rect,
		WELL_RADIUS,
		CORNER_SEGMENTS,
		WELL_SHADOW_LAYERS,
		SHADOW_COLOR,
		WELL_SHADOW_ALPHA
	)
	target.draw_line(
		Vector2(rect.position.x + WELL_RADIUS, rect.end.y + 1.0),
		Vector2(rect.end.x - WELL_RADIUS, rect.end.y + 1.0),
		WELL_EDGE_LIGHT,
		1.0
	)


static func well_baseline(rect: Rect2) -> float:
	return rect.get_center().y + float(WELL_TEXT_SIZE) * 0.36


## 凹んだ行の左端に置く点の中心と、その右から始まる文字の左端。
static func well_dot_center(rect: Rect2) -> Vector2:
	return Vector2(rect.position.x + WELL_INSET + DOT_RADIUS, rect.get_center().y)


static func well_text_left(rect: Rect2) -> float:
	return well_dot_center(rect).x + DOT_RADIUS + DOT_TEXT_GAP


## 凹んだ行の右端へ寄せる沈んだ文字。
static func draw_well_right(target: CanvasItem, font: Font, rect: Rect2, text: String) -> void:
	target.draw_string(
		font,
		Vector2(rect.position.x, well_baseline(rect)),
		text,
		HORIZONTAL_ALIGNMENT_RIGHT,
		rect.size.x - WELL_INSET,
		WELL_SMALL_SIZE,
		WELL_MUTED
	)


## 脈打つ点。外側の光の輪だけを脈打たせ、点そのものは動かさない(読みやすさを保つ)。
static func draw_dot(target: CanvasItem, center: Vector2, color: Color, phase: float) -> void:
	var pulse := 0.5 + 0.5 * sin(phase)
	fill_circle(
		target, center, DOT_RADIUS * (1.6 + pulse * 0.6), Color(color, 0.08 + 0.18 * (1.0 - pulse))
	)
	fill_circle(target, center, DOT_RADIUS, color)
	fill_circle(
		target, center - Vector2.ONE * DOT_RADIUS * 0.25, DOT_RADIUS * 0.4, Color(1, 1, 1, 0.55)
	)


static func fill_circle(target: CanvasItem, center: Vector2, radius: float, color: Color) -> void:
	target.draw_colored_polygon(UiPaint.circle_points(center, radius, SEGMENTS), color)
