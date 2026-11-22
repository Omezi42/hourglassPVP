class_name ShopPackInfo
extends RefCounted
## ショップの詳細のパックの欄(GameDesign.md 21章)。確率の表と「レジェンド確定まで あと n パック」のバー。
## **出る確率を見せずに引かせない**ため、`PackDefinition` の値をそのまま表にする。

const TABLE_HEIGHT := 128.0
const TABLE_PAD := 10.0
const HEAD_HEIGHT := 46.0
const ROW_LABEL_WIDTH := 0.2
const GEM_HALF := 7.0
const NOTE_GAP := 18.0
const PITY_GAP := 40.0
const BAR_GAP := 10.0
const BAR_HEIGHT := 14.0
const PITY_NOTE_GAP := 20.0
const ROW_LABELS: Array[String] = ["1〜%d枚目", "%d枚目"]
const NONE_MARK := "—"


## 確率の表から天井の注記までを描き、使った高さの下端を返す。
static func draw(ci: CanvasItem, font: Font, top: float, width: float, pack_id: String) -> float:
	var pack := PackDefinition.load_pack(pack_id)
	if pack == null or font == null:
		return top
	var rid := ci.get_canvas_item()
	var table := Rect2(0.0, top, width, TABLE_HEIGHT)
	UiKit.well(rid, table)
	var inner := table.grow(-TABLE_PAD)
	var label_w := inner.size.x * ROW_LABEL_WIDTH
	var column_w := (inner.size.x - label_w) / CardEnums.Rarity.size()
	for rarity: CardEnums.Rarity in CardEnums.Rarity.values():
		var x := inner.position.x + label_w + column_w * rarity
		var hue := RarityPaint.color(rarity)
		RarityPaint.gem(
			rid, Vector2(x + column_w * 0.5, inner.position.y + GEM_HALF + 2.0), GEM_HALF, rarity
		)
		ci.draw_string(
			font,
			Vector2(x, inner.position.y + HEAD_HEIGHT - UiPalette.S2),
			RarityPaint.rarity_name(rarity),
			HORIZONTAL_ALIGNMENT_CENTER,
			column_w,
			UiPalette.T_MICRO,
			UiPalette.IVORY if rarity == CardEnums.Rarity.COMMON else hue
		)
	var row_h := (inner.size.y - HEAD_HEIGHT) * 0.5
	for row in 2:
		var last := row == 1
		var base := inner.position.y + HEAD_HEIGHT + row_h * (row + 0.5) + UiPalette.T_SMALL * 0.36
		UiKit.rule(
			rid,
			Vector2(inner.position.x, base - row_h * 0.5 - UiPalette.T_SMALL * 0.36),
			Vector2(inner.end.x, base - row_h * 0.5 - UiPalette.T_SMALL * 0.36)
		)
		var label := ROW_LABELS[row] % (pack.cards_per_pack - (1 if not last else 0))
		ci.draw_string(
			font,
			Vector2(inner.position.x, base),
			label,
			HORIZONTAL_ALIGNMENT_CENTER,
			label_w,
			UiPalette.T_SMALL,
			UiPalette.MUTED
		)
		for rarity: CardEnums.Rarity in CardEnums.Rarity.values():
			var rate := pack.rate(rarity, last)
			ci.draw_string(
				font,
				Vector2(inner.position.x + label_w + column_w * rarity, base),
				percent_text(rate) if rate > 0.0 else NONE_MARK,
				HORIZONTAL_ALIGNMENT_CENTER,
				column_w,
				UiPalette.T_SMALL,
				UiPalette.IVORY
			)
	var y := table.end.y + NOTE_GAP
	ci.draw_string(
		font,
		Vector2(0.0, y),
		"%d枚目はレア以上が必ず出ます" % pack.cards_per_pack,
		HORIZONTAL_ALIGNMENT_LEFT,
		width,
		UiPalette.T_MICRO,
		UiPalette.MUTED
	)
	y += PITY_GAP
	var pity := AccountService.pack_pity(pack_id)
	var left := PackDraw.packs_until_pity(pack, pity)
	ci.draw_string(
		font,
		Vector2(0.0, y),
		"レジェンド確定まで",
		HORIZONTAL_ALIGNMENT_LEFT,
		width,
		UiPalette.T_BODY,
		UiPalette.IVORY
	)
	ci.draw_string(
		font,
		Vector2(0.0, y),
		"あと %dパック" % left,
		HORIZONTAL_ALIGNMENT_RIGHT,
		width,
		UiPalette.T_BODY,
		UiPalette.SAND_HI
	)
	var bar := Rect2(0.0, y + BAR_GAP, width, BAR_HEIGHT)
	UiKit.sand_bar(rid, bar, float(pity) / float(maxi(pack.pity_packs - 1, 1)))
	y = bar.end.y + PITY_NOTE_GAP
	ci.draw_string(
		font,
		Vector2(0.0, y),
		"%dパック目の%d枚目はレジェンドになります" % [pack.pity_packs, pack.cards_per_pack],
		HORIZONTAL_ALIGNMENT_LEFT,
		width,
		UiPalette.T_MICRO,
		UiPalette.MUTED
	)
	return y


## 0.035 → "3.5%"、0.2 → "20%"。
static func percent_text(rate: float) -> String:
	var value := snappedf(rate * 100.0, 0.1)
	if is_equal_approx(value, roundf(value)):
		return "%d%%" % roundi(value)
	return "%.1f%%" % value
