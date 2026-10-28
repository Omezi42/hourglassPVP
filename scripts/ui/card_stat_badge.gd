class_name CardStatBadge
extends RefCounted
## カードを並べる画面(デッキ編集の棚・リスト・工房の在庫棚・図鑑の一覧)の攻撃力と体力の丸
## (GameDesign.md 9章)。数値は場に出た時点のもの。4画面で別々に描くと必ず片方だけ古くなるので、
## ここへ集める(`EmblemSeal` と同じ流儀で第1引数に `CanvasItem` を取る)。
## **砂術は攻撃力・体力を持たないため、体力の位置へ「術」だけを出す**(空欄だと0と見分けが付かない)。

const ATTACK_TOP := Color(1.0, 0.72, 0.34)
const ATTACK_BOTTOM := Color(0.74, 0.36, 0.06)
const HEALTH_TOP := Color(0.98, 0.48, 0.42)
const HEALTH_BOTTOM := Color(0.58, 0.12, 0.10)
const SPELL_TOP := Color(0.72, 0.80, 1.0)
const SPELL_BOTTOM := Color(0.28, 0.36, 0.68)
const EDGE := Color(0.10, 0.04, 0.03)
const NUMBER := Color.WHITE
const NUMBER_SHADOW := Color(0, 0, 0, 0.6)
const SPELL_MARK := Color(0.14, 0.08, 0.03)
const SPELL_TEXT := "術"


## 攻撃力を `attack_at`、体力を `health_at` へ描く。砂術は `health_at` へ「術」だけ。
static func pair(
	ci: CanvasItem, font: Font, attack_at: Vector2, health_at: Vector2, card: CardData, r: float
) -> void:
	if card.is_spell:
		_disc(ci, health_at, r, SPELL_TOP, SPELL_BOTTOM)
		_text(ci, font, health_at, SPELL_TEXT, int(r + 1), SPELL_MARK, false)
		return
	_disc(ci, attack_at, r, ATTACK_TOP, ATTACK_BOTTOM)
	_text(ci, font, attack_at, str(card.initial_attack), int(r + 2), NUMBER, true)
	_disc(ci, health_at, r, HEALTH_TOP, HEALTH_BOTTOM)
	_text(ci, font, health_at, str(card.initial_health()), int(r + 2), NUMBER, true)


static func _disc(ci: CanvasItem, center: Vector2, r: float, top: Color, bottom: Color) -> void:
	var rid := ci.get_canvas_item()
	UiPaint.fill_gradient_polygon(
		rid,
		UiPaint.circle_points(center, r, 20),
		Rect2(center - Vector2(r, r), Vector2(r, r) * 2.0),
		[[0.0, top], [1.0, bottom]]
	)
	UiPaint.draw_ring(rid, center, r, EDGE, 1.6, 20)


static func _text(
	ci: CanvasItem,
	font: Font,
	center: Vector2,
	text: String,
	font_size: int,
	color: Color,
	shadow: bool
) -> void:
	var width: float = font_size * 3.0
	var at := Vector2(center.x - width * 0.5, center.y + font_size * 0.36)
	if shadow:
		ci.draw_string(
			font,
			at + Vector2.ONE,
			text,
			HORIZONTAL_ALIGNMENT_CENTER,
			width,
			font_size,
			NUMBER_SHADOW
		)
	ci.draw_string(font, at, text, HORIZONTAL_ALIGNMENT_CENTER, width, font_size, color)
