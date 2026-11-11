class_name EmblemSeal
extends RefCounted
## カード固有の紋章を「押した印」として描く(GameDesign.md 9章)。
##
## **色相だけでは50種を見分けられない**ため、実際に見分けているのは紋章である。
## にもかかわらず、カードを並べる画面(図鑑の一覧・工房の在庫棚・編成中の棚)には
## 紋章が出ていなかった。3画面で別々に描くと必ず片方だけ古くなるので、ここへ集める。
## 印そのものは `UiKit.seal()` が描く(手札の札と同じ)。
##
## `UiPaint` と違って第1引数に `CanvasItem` を取る(`RoomPaint` と同じ流儀)。


## 真鍮の印。**絵の右上へ押す**(手札の紋章の印と同じ置き場。左下は攻撃力が使う)。
static func brass(ci: CanvasItem, center: Vector2, emblem: Texture2D, radius: float) -> void:
	if emblem == null:
		return
	UiKit.seal(ci.get_canvas_item(), center, radius, emblem)
