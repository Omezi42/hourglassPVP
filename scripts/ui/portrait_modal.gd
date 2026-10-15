class_name PortraitModal
extends RefCounted
## 暗幕 + 中央のパネルで出すモーダルの縦画面(GameDesign.md 9章「縦画面」/ Architecture.md 4.7節)。
## **パネルは中身ごと拡大する**(対局画面の詳細パネルと同じ)。中の文字・ボタンの大きさを
## 1つずつ持ち直さずに、本文24px・押せる背丈の目安を満たすため。
## 縦のパネルは論理幅 `WIDTH` で組み、`SCALE` 倍で画面の幅いっぱい(672px)になる。

const SCALE := 1.4
const WIDTH := 480.0


## いまの向きの画面の大きさ(モーダルの暗幕を敷く範囲)。
static func screen_size() -> Vector2:
	return Vector2(ScreenOrientation.base_size())


## パネルを縦では中心から拡大し、横では等倍に戻す。中心は大きさが変わるたびに取り直す。
## **コンテナの子は渡さない**(コンテナは子を並べ直すたびに `scale` を1へ戻す)。
## `CenterContainer` で中央へ置くモーダルは、その `CenterContainer` を渡す。
static func fit(panel: Control) -> void:
	if not panel.has_meta("portrait_modal"):
		panel.set_meta("portrait_modal", true)
		panel.resized.connect(func() -> void: panel.pivot_offset = panel.size * 0.5)
	panel.pivot_offset = panel.size * 0.5
	panel.scale = Vector2.ONE * (SCALE if ScreenOrientation.is_portrait() else 1.0)


## 開いている間に向きが変わったら `relayout` を呼ぶ(`Main` が向きを決め直した後に届くよう遅らせる)。
static func watch(modal: Control, relayout: Callable) -> void:
	modal.get_tree().root.size_changed.connect(
		func() -> void:
			if modal.visible:
				relayout.call_deferred()
	)
