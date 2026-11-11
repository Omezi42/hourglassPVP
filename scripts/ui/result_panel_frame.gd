class_name ResultPanelFrame
extends RefCounted
## 結果パネル本体の質感(GameDesign.md 9章の硝子の面)。対局・リーサルパズル・ソロモードの
## 結果パネルが共有する。勝ち(bright)は真鍮の縁、負けは冷えた藍灰の縁へ縁だけを差し替える。

const RADIUS := 20.0
const GLASS_OPACITY := 0.96
const LOSS_RIM_COLOR := UiPalette.FAINT


static func draw(ci: RID, panel_size: Vector2, bright: bool) -> void:
	# 大きさが決まる前(中身に合わせて伸びるパネル)は描かない。角丸の点列が潰れる。
	if panel_size.x < RADIUS * 2.0 or panel_size.y < RADIUS * 2.0:
		return
	var rect := Rect2(Vector2.ZERO, panel_size)
	UiKit.glass(
		ci, rect, RADIUS, 1.0, GLASS_OPACITY, [] if bright else UiKit.rim_color(LOSS_RIM_COLOR)
	)
