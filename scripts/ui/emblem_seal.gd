class_name EmblemSeal
extends RefCounted
## カード固有の紋章を「押した印」として描く(GameDesign.md 9章)。
##
## **色相だけでは50種を見分けられない**ため、実際に見分けているのは紋章である。
## にもかかわらず、カードを並べる画面(図鑑の一覧・工房の在庫棚・編成中の棚)には
## 紋章が出ていなかった。3画面で別々に描くと必ず片方だけ古くなるので、ここへ集める。
##
## `UiPaint` と違って第1引数に `CanvasItem` を取る(`InkFigure` と同じ流儀)。
## 紋章はテクスチャであり、`RenderingServer` 経由ではなく `draw_texture_rect()` で描く。

const RIM := Color(0.62, 0.50, 0.30)
const FACE_TOP := Color(0.36, 0.26, 0.16)
const FACE_BOTTOM := Color(0.16, 0.11, 0.07)
const MARK := Color(0.96, 0.86, 0.62)


## 真鍮の印。**絵の左下へ押す**(手札の封蝋と同じ置き場)。
static func brass(ci: CanvasItem, center: Vector2, emblem: Texture2D, radius: float) -> void:
	if emblem == null:
		return
	var rid := ci.get_canvas_item()
	UiPaint.fill_gradient_polygon(
		rid,
		UiPaint.circle_points(center, radius, 18),
		Rect2(center - Vector2(radius, radius), Vector2(radius, radius) * 2.0),
		[[0.0, FACE_TOP], [1.0, FACE_BOTTOM]]
	)
	UiPaint.draw_ring(rid, center, radius, RIM, maxf(radius * 0.13, 1.2), 18)
	var side: float = radius * 1.22
	ci.draw_texture_rect(
		emblem, Rect2(center - Vector2(side, side) * 0.5, Vector2(side, side)), false, MARK
	)
