class_name EscClose
extends Node
## Escでいちばん手前のモーダルを閉じる(GameDesign.md 9章「操作」)。モーダルの子として付け、
## モーダルが見えている間だけEscを受ける。
##
## `_unhandled_input` は木の後ろ(手前に描かれる側)から順に届くため、重なったモーダルは
## 手前のものから閉じ、その下の画面の「戻る」(`Main`)や選択の取り消し(対局画面)へは届かない。

var _close: Callable
var _host: CanvasItem


## `host` が見えている間のEscで `close` を呼ぶ。`host` は暗幕ごと出し消しするノード。
static func attach(host: CanvasItem, close: Callable) -> void:
	var node := EscClose.new()
	node._host = host
	node._close = close
	host.add_child(node)


func _unhandled_input(event: InputEvent) -> void:
	if not event.is_action_pressed("ui_cancel") or not _host.is_visible_in_tree():
		return
	get_viewport().set_input_as_handled()
	_close.call()
