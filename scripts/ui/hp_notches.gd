class_name HpNotches
extends RefCounted
## HPの器(真鍮の管)に彫る刻み目(GameDesign.md 9章、Architecture.md 10.10.3節)。
## 刻み線(2章)の位置を、管の「その線に届くHP」の所へ縦に1本ずつ彫る。
## ともる前は沈んだ真鍮、届いたら琥珀の光、攻撃の予測が越えるときは淡い光。
## 太さと光の広がりは管の高さに対する比で決める(拡大・縦画面でも同じ見え方にするため)。

## 刻み目の太さと光の半径(管の高さに対する比)。
const WIDTH_RATIO := 0.1
const GLOW_RATIO := 0.9
## 沈んだ刻み目:暗い溝と、その右の明るい縁。
const GROOVE := Color(0.10, 0.06, 0.02, 0.62)
const EDGE := Color(1.0, 0.93, 0.72, 0.26)
## ともった刻み目の芯と光。
const LIT_CORE := UiPalette.GOLD_HI
const LIT_GLOW := Color(0.96, 0.68, 0.24, 0.55)
## 届いた瞬間の白い閃き(1→0)。
const FLASH := Color(1.0, 0.97, 0.85)
## 予測が越える刻み目の淡い光。
const PREVIEW_CORE := Color(1.0, 0.93, 0.72, 0.7)
const PREVIEW_GLOW := Color(0.96, 0.68, 0.24, 0.3)


## 線 `line` が届くHP(その値以下になると、失ったHPが線に届く)。管に載らない線は 0 以下を返す。
static func hp_at(line: int, max_hp: int) -> int:
	return max_hp - line


## 管の中での刻み目の中心x。`inner` は砂の入る内側の矩形。載らない線は -1。
static func x_at(line: int, max_hp: int, inner: Rect2) -> float:
	var hp := hp_at(line, max_hp)
	if hp <= 0 or hp >= max_hp:
		return -1.0
	return inner.position.x + inner.size.x * float(hp) / float(max_hp)


## 刻み目をすべて描く。`lit` は届いた線の数、`flash_index` / `flash` は届いた瞬間の閃き、
## `preview_from` から `preview_count` 本は予測が越える線。
static func paint(
	item: CanvasItem, rect: Rect2, inner: Rect2, lines: Array[int], max_hp: int, state: Dictionary
) -> void:
	var ci := item.get_canvas_item()
	var lit: int = state.get("lit", 0)
	var flash_index: int = state.get("flash_index", -1)
	var flash: float = state.get("flash", 0.0)
	var preview_from: int = state.get("preview_from", 0)
	var preview_count: int = state.get("preview_count", 0)
	var width := maxf(rect.size.y * WIDTH_RATIO, 1.5)
	var glow := rect.size.y * GLOW_RATIO
	for i in lines.size():
		var x := x_at(lines[i], max_hp, inner)
		if x < 0.0:
			continue
		var core := Rect2(Vector2(x - width * 0.5, inner.position.y), Vector2(width, inner.size.y))
		if i < lit:
			ShapePaint.radial_glow(
				ci, Vector2(x, inner.get_center().y), Vector2(glow, glow), LIT_GLOW
			)
			UiKit.fill(ci, UiKit.rr(core, width * 0.5), LIT_CORE)
		else:
			UiKit.fill(ci, UiKit.rr(core, width * 0.5), GROOVE)
			var edge := Rect2(
				core.position + Vector2(width, 0.0), Vector2(width * 0.5, core.size.y)
			)
			UiKit.fill(ci, UiKit.rr(edge, width * 0.25), EDGE)
			if i >= preview_from and i < preview_from + preview_count:
				ShapePaint.radial_glow(
					ci, Vector2(x, inner.get_center().y), Vector2(glow, glow), PREVIEW_GLOW
				)
				UiKit.fill(ci, UiKit.rr(core, width * 0.5), PREVIEW_CORE)
		if i == flash_index and flash > 0.0:
			var reach := glow * (1.0 + 1.4 * (1.0 - flash))
			ShapePaint.radial_glow(
				ci,
				Vector2(x, inner.get_center().y),
				Vector2(reach, reach),
				Color(FLASH, 0.8 * flash)
			)
