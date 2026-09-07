class_name DiscordCardArt
extends Control
## Discordの `/card` コマンド用に最適化した、カード1枚の静止画(GameDesign.md 26章)。
##
## 砂時計図鑑の右のページ(`AlmanacPage`)を元にするが、個人の戦績・裏返し操作・
## キーワードの押せるボタンは持たない。**カードを見せるためだけの1枚絵**として描く。
## 実演は別途GIFとして添えるため、ここには含めない(Architecture.md 10.14節)。

const SIZE := Vector2(720.0, 400.0)
const INK := Color(0.20, 0.135, 0.075)
const INK_SOFT := Color(0.40, 0.30, 0.19)
const PAPER_TOP := Color(0.90, 0.845, 0.70)
const PAPER_BOTTOM := Color(0.775, 0.695, 0.535)
const ART_WIDTH := 220.0
const DATA_GAP := 32.0
const FIELD_GAP := 150.0

var card: CardData

var _font: Font


func _ready() -> void:
	custom_minimum_size = SIZE
	size = SIZE
	_font = get_theme_default_font()
	if _font == null:
		_font = ThemeDB.fallback_font


func show_card(new_card: CardData) -> void:
	card = new_card
	queue_redraw()


func _draw() -> void:
	if card == null:
		return
	_draw_paper()
	draw_string(_font, Vector2(28, 48), card.display_name, HORIZONTAL_ALIGNMENT_LEFT, -1, 34, INK)
	_draw_rule(Vector2(28, 62), size.x - 56)

	var art_rect := Rect2(Vector2(28, 88), Vector2(ART_WIDTH, ART_WIDTH * 1.30))
	if card.is_spell:
		_draw_spell_plate(art_rect)
	else:
		var icon := card.icon_upright
		if icon != null:
			draw_texture_rect(icon, art_rect, false)
		EmblemSeal.brass(
			self, Vector2(art_rect.position.x - 2.0, art_rect.end.y - 12.0), card.emblem, 16.0
		)

	var data_x := art_rect.end.x + DATA_GAP
	_draw_field(Vector2(data_x, 88), "コスト", str(card.cost))
	_draw_field(
		Vector2(data_x + FIELD_GAP, 88), "総量", "—" if card.is_spell else str(card.total_sand)
	)
	_draw_field(Vector2(data_x + FIELD_GAP * 2.0, 88), "分類", "砂術" if card.is_spell else "砂時計")
	draw_multiline_string(
		_font,
		Vector2(data_x, 170),
		card.describe(),
		HORIZONTAL_ALIGNMENT_LEFT,
		size.x - data_x - 28,
		20,
		6,
		INK
	)


func _draw_paper() -> void:
	var rect := Rect2(Vector2.ZERO, size)
	UiPaint.fill_gradient_polygon(
		get_canvas_item(),
		UiPaint.rounded_rect_points_uniform(rect, 8.0, 6),
		rect,
		[[0.0, PAPER_TOP], [1.0, PAPER_BOTTOM]]
	)
	UiPaint.apply_grain(get_canvas_item(), rect, 0.09)


## 砂術の札。図鑑と同じく、盤面へ出ない札であることを藍の枠と紋章で示す。
func _draw_spell_plate(rect: Rect2) -> void:
	var points := UiPaint.rounded_rect_points_uniform(rect.grow(-4), 6.0, 6)
	UiPaint.fill_gradient_polygon(
		get_canvas_item(),
		points,
		rect,
		[[0.0, Color(0.34, 0.40, 0.56)], [1.0, Color(0.18, 0.22, 0.36)]]
	)
	var closed := points.duplicate()
	closed.append(points[0])
	draw_polyline(closed, Color(0.20, 0.26, 0.42), 2.4)
	if card.emblem != null:
		var side: float = rect.size.x * 0.62
		draw_texture_rect(
			card.emblem,
			Rect2(rect.get_center() - Vector2(side, side) * 0.5, Vector2(side, side)),
			false,
			Color(0.92, 0.95, 1.0)
		)


func _draw_field(at: Vector2, label: String, value: String) -> void:
	draw_string(_font, at + Vector2(0, 15), label, HORIZONTAL_ALIGNMENT_LEFT, -1, 15, INK_SOFT)
	draw_string(_font, at + Vector2(0, 46), value, HORIZONTAL_ALIGNMENT_LEFT, -1, 28, INK)


func _draw_rule(at: Vector2, width: float) -> void:
	draw_line(at, at + Vector2(width, 0), Color(0.45, 0.33, 0.18, 0.6), 1.4)
