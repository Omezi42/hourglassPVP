class_name ActionColumnPanel
extends Control
## 対局画面右端「行動の列」の地(GameDesign.md 9章「対局画面の見た目」)。
## 卓の脇に立てた1枚の硝子の面で、3つの群(`ActionColumnLayout`)の間を罫線で区切る。
##
## 矩形は `CardMatchLayout.action_panel_rect`(`CardMatchArrange` が置く)。
## ボタンより先に `add_child()` して背面へ置く。

const CORNER_RADIUS := 16.0
const PANEL_ALPHA := 0.92
const DIVIDER_INSET := UiPalette.S3


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func _draw() -> void:
	var ci := get_canvas_item()
	var rect := Rect2(Vector2.ZERO, size)
	UiKit.glass(ci, rect, CORNER_RADIUS, 1.0, PANEL_ALPHA)
	for divider_y: float in ActionColumnLayout.DIVIDER_YS:
		var y := divider_y - position.y
		UiKit.hairline(ci, Vector2(DIVIDER_INSET, y), Vector2(rect.size.x - DIVIDER_INSET, y))
