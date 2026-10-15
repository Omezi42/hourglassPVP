class_name PortraitTabs
extends RefCounted
## 縦画面で2つの面を「切り替えて1つずつ出す」ための切り替えのボタン(GameDesign.md 9章「縦画面」)。
## ヘッダーの主アクションの行へ並べ、横では隠す。選んでいる側は真鍮の面、ほかは凹んだ面で描く
## (図鑑・デッキ編集の切り替えと同じ見た目)。

const TAB_GROUP := CodedButton.WIDE_GROUP


## `labels` の数だけボタンを作ってヘッダーの主アクションへ足す。`width` は1つぶんの幅。
## 押されると `on_select` へ番号を渡す。
static func make(
	header: ScreenHeader, labels: Array, width: float, on_select: Callable
) -> Array[Button]:
	var buttons: Array[Button] = []
	for i in labels.size():
		var tab := CodedButton.make_in_group(
			str(labels[i]), Vector2(width, ScreenHeader.PORTRAIT_ACTION_HEIGHT), TAB_GROUP
		)
		tab.visible = false
		tab.pressed.connect(on_select.bind(i))
		header.add_action(tab)
		buttons.append(tab)
	return buttons


## 縦なら出して `active` 番目を選んだ見た目にし、横なら隠す。
static func mark(buttons: Array[Button], active: int, portrait: bool) -> void:
	for i in buttons.size():
		buttons[i].visible = portrait
		CodedButton.apply_styles(
			buttons[i], CodedButton.PRIMARY_ACTION_GROUP if i == active else TAB_GROUP
		)
