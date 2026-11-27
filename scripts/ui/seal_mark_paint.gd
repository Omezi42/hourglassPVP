class_name SealMarkPaint
extends RefCounted
## 駒の台座に出す封じの小さな印(GameDesign.md 9章。封じの刻)。鎖は「次の手番は攻撃できない」、
## 檻はケージの封じ。台座の左の端に付ける小さな札(丸い地に鎖か檻)で、台座の上面は砂時計の足・
## 攻撃力と体力の石・紋章の印で埋まっているため、石の上の空きへ出す。
## 描画だけを持つ(状態は `CardView.lock_mark`)。多角形は `UiKit` / `UiPaint` を通す(Pitfalls.md)。

## 台座の半径に対する、札の中心の位置。左の端の、攻撃力の石の上。
const CENTER_RATIO := Vector2(-0.92, -1.75)
## 札の半径と、縁・記号の線の太さ。
const TOKEN_RADIUS := 8.5
const TOKEN_SEGMENTS := 20
const RIM_WIDTH := 1.2
const SYMBOL_WIDTH := 1.3
const GROUND_ALPHA := 0.88
## 鎖: 斜めに噛み合う2つの環。環の半径(長い辺・短い辺)・傾き・中心のずれ。
const LINK_RADII := Vector2(4.4, 2.5)
const LINK_ANGLE := 0.6
const LINK_OFFSET := 2.4
const LINK_SEGMENTS := 14
## 檻: 枠の大きさ・角の丸み・縦の棒の数。
const CAGE_HALF := Vector2(4.6, 4.2)
const CAGE_CORNER := 2.2
const CAGE_BARS := 2


## `caged` が真なら檻、偽なら鎖。`CardSealEffects` を型で持たない(読み込みが輪になるため。Pitfalls.md)。
static func draw(ci: RID, caged: bool, top_center: Vector2, radius: Vector2) -> void:
	var center := top_center + radius * CENTER_RATIO
	UiPaint.fill_circle(
		ci, center, TOKEN_RADIUS, Color(UiPalette.BRASS_INK, GROUND_ALPHA), TOKEN_SEGMENTS
	)
	UiPaint.draw_ring(ci, center, TOKEN_RADIUS, UiPalette.GOLD, RIM_WIDTH, TOKEN_SEGMENTS)
	if caged:
		_cage(ci, center)
	else:
		_chain(ci, center)


## 斜めに噛み合う2つの環。
static func _chain(ci: RID, center: Vector2) -> void:
	for side in [-1.0, 1.0]:
		var at := center + Vector2(LINK_OFFSET * side, -LINK_OFFSET * side * 0.5)
		var points := UiKit.ellipse(Vector2.ZERO, LINK_RADII, LINK_SEGMENTS)
		var turn := Transform2D(-LINK_ANGLE * side, at)
		UiKit.stroke(ci, turn * points, UiPalette.IVORY, SYMBOL_WIDTH)


## 小さな檻。枠と縦の棒。
static func _cage(ci: RID, center: Vector2) -> void:
	var rect := Rect2(center - CAGE_HALF, CAGE_HALF * 2.0)
	UiKit.stroke(ci, UiKit.rr(rect, CAGE_CORNER), UiPalette.IVORY, SYMBOL_WIDTH)
	for i in CAGE_BARS:
		var t := float(i + 1) / float(CAGE_BARS + 1)
		var x := rect.position.x + rect.size.x * t
		var bar := Rect2(x - SYMBOL_WIDTH * 0.5, rect.position.y, SYMBOL_WIDTH, rect.size.y)
		UiKit.fill(ci, UiKit.rr(bar, 0.0), UiPalette.IVORY)
