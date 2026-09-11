class_name TouchScroll
extends RefCounted
## `ScrollContainer` は素のままだと、指でつまんで動かす操作を持たない
## (実際に反応するのはスクロールバーそのものとマウスホイール/パンジェスチャーだけ)。
## GameDesign.md 9章のタッチ配慮の一環として、指でコンテンツをつかんで動かせるようにする。
##
## サブクラスは作らず、既存の `gui_input` シグナルへ後付けする。native(.tscn)・
## コード生成のどちらの `ScrollContainer` にも同じ1行で足せるため。


## 生成した(または `.tscn` から取り出した)ScrollContainerへ、指でのドラッグ
## スクロールを1つ足す。呼ぶのはScrollContainerを組み立てた直後の1箇所でよい。
static func enable(scroll: ScrollContainer) -> void:
	scroll.gui_input.connect(_on_gui_input.bind(scroll))


static func _on_gui_input(event: InputEvent, scroll: ScrollContainer) -> void:
	if not (event is InputEventScreenDrag):
		return
	if scroll.horizontal_scroll_mode != ScrollContainer.SCROLL_MODE_DISABLED:
		scroll.scroll_horizontal -= int(event.relative.x)
	if scroll.vertical_scroll_mode != ScrollContainer.SCROLL_MODE_DISABLED:
		scroll.scroll_vertical -= int(event.relative.y)
