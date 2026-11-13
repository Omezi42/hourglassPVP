class_name CodedPanelStyle
extends StyleBox
## コード描画のパネルの面(GameDesign.md 9章「面の素材は5つだけ」/ Architecture.md 4.0節)。
## `surface` で硝子の面(情報の入れ物)か彫り込み(入力欄)を選ぶ。素材は `UiKit` が描く。
## `highlighted` は入力欄のフォーカス(縁を照りへ)、`dimmed` は読み取り専用(縁と面を沈める)。
## 入力欄は字を読み書きする場所のため、状態で面の色は変えない。

enum Surface { GLASS, WELL }

const DIMMED_ALPHA := 0.5
const FOCUS_WIDTH := 1.5
## 上部中央の紋章の印(詳細パネル)の大きさ。幅に対する比と上下限。
const BADGE_RADIUS_RATIO := 0.1
const BADGE_RADIUS_MIN := 16.0
const BADGE_RADIUS_MAX := 30.0
const BADGE_INSET_RATIO := 0.55

## 角の丸みと縁の太さは短辺から決まる(`UiKit`)。この2つは古い `.tres` が持つ値で、描画には使わない。
@export var corner_radius: float = 16.0
@export var frame_thickness: float = 8.0
@export var has_header_emblem: bool = false
@export var highlighted: bool = false
@export var dimmed: bool = false
## 下の絵を透かさない(縦の誘導対局の帯。下に相手のマナと直前の手が重なるため)。
@export var opaque: bool = false
@export var surface: Surface = Surface.GLASS


func _draw(to_canvas_item: RID, rect: Rect2) -> void:
	if surface == Surface.WELL:
		_draw_well(to_canvas_item, rect)
	else:
		var alpha := 1.0 if opaque else UiKit.GLASS_ALPHA * (DIMMED_ALPHA if dimmed else 1.0)
		var lit := 1.0 if highlighted else 0.0
		UiKit.glass(to_canvas_item, rect, -1.0, 1.0, alpha, [], lit)
	if has_header_emblem:
		_draw_header_seal(to_canvas_item, rect)


func _draw_well(ci: RID, rect: Rect2) -> void:
	var corner := minf(rect.size.y * 0.5, UiKit.WELL_RADIUS_MAX)
	UiKit.well(ci, rect, corner)
	if highlighted:
		UiKit.stroke_grad(ci, UiKit.rr(rect, corner), UiKit.rim_brass(1.0), FOCUS_WIDTH)
	elif not dimmed:
		UiKit.stroke_grad(
			ci, UiKit.rr(rect, corner), _thin(UiKit.rim_brass(), DIMMED_ALPHA), UiKit.LINE_MIN
		)


## 上端へ半分重なる砂時計の印(このパネルが砂時計の情報を出していることを示す)。
func _draw_header_seal(ci: RID, rect: Rect2) -> void:
	var rad: float = clampf(rect.size.x * BADGE_RADIUS_RATIO, BADGE_RADIUS_MIN, BADGE_RADIUS_MAX)
	var center := Vector2(rect.get_center().x, rect.position.y + rad * BADGE_INSET_RATIO)
	UiKit.seal(ci, center, rad, UiPaint.HOURGLASS_ICON)


static func _thin(stops: Array, alpha: float) -> Array:
	var result := []
	for stop in stops:
		var color: Color = stop[1]
		result.append([stop[0], Color(color, alpha)])
	return result
