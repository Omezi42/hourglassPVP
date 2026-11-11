class_name CardStatBadge
extends RefCounted
## カードを並べる画面(デッキ編集の棚・リスト・工房の在庫棚・図鑑の一覧)の攻撃力と体力の丸
## (GameDesign.md 9章)。数値は場に出た時点のもの。4画面で別々に描くと必ず片方だけ古くなるので、
## ここへ集める(`EmblemSeal` と同じ流儀で第1引数に `CanvasItem` を取る)。丸は `UiKit.gem()`。
## **砂術は攻撃力・体力を持たないため、体力の位置へ「術」だけを出す**(空欄だと0と見分けが付かない)。

const SPELL_TOP := Color(0.72, 0.80, 1.0)
const SPELL_BOTTOM := Color(0.28, 0.36, 0.68)
const SPELL_TEXT := "術"
## 菱形の縁の太さと、数字の大きさ(菱形の半径に対する比。宝石と同じ数字の描き方を使うため)。
const DIAMOND_OUTLINE := 2.0
const DIAMOND_TEXT_RATIO := 0.9


## 攻撃力を `attack_at`、体力を `health_at` へ描く。砂術は `health_at` へ「術」だけ。
static func pair(
	ci: CanvasItem, font: Font, attack_at: Vector2, health_at: Vector2, card: CardData, r: float
) -> void:
	var rid := ci.get_canvas_item()
	if card.is_spell:
		UiKit.gem(rid, health_at, r, SPELL_TOP, SPELL_BOTTOM)
		UiKit.gem_text(rid, font, health_at, r, SPELL_TEXT, UiPalette.IVORY)
		return
	UiKit.gem(rid, attack_at, r, UiPalette.ATTACK, UiPalette.ATTACK_DEEP)
	UiKit.gem_text(rid, font, attack_at, r, str(card.initial_attack))
	UiKit.gem(rid, health_at, r, UiPalette.HEALTH, UiPalette.HEALTH_DEEP)
	UiKit.gem_text(rid, font, health_at, r, str(card.initial_health()))


## コストの菱形(青)。数字は宝石と同じ描き方。`tint` は押せないカードを沈める色。
static func cost_diamond(
	ci: CanvasItem, font: Font, center: Vector2, value: int, r: float, tint := Color.WHITE
) -> void:
	var rid := ci.get_canvas_item()
	var points := PackedVector2Array(
		[
			center + Vector2(0, -r),
			center + Vector2(r, 0),
			center + Vector2(0, r),
			center + Vector2(-r, 0),
		]
	)
	UiKit.vgrad(
		rid, points, [[0.0, UiPalette.COST * tint], [1.0, UiPalette.COST_DEEP * tint]], true
	)
	UiKit.stroke(rid, points, UiPalette.INK_900, DIAMOND_OUTLINE)
	UiKit.gem_text(rid, font, center, r * DIAMOND_TEXT_RATIO, str(value), Color.WHITE * tint)
