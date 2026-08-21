class_name PieceMarks
extends Control
## 駒が持つスキルの紋章と、受動効果を持つことを示す印を駒へ重ねる(GameDesign.md 9章)。
## 10種のうち9種がスキルを持ち、毎手番の判断が「起こすか、能力を使うか」であるため、
## どの駒が何をできるのかは盤面から直接読み取れる必要がある。
##
## 落下ダメージのバッジと対になる位置(バッジが右下なら左下、右上なら左上)へ置き、
## 置かれた枠の大きさから縮尺を決める。どの紋章を出すかは SkillVisuals から引く
## (駒データは効果だけを持ち、見た目を持たない)。

## 落下ダメージのバッジが枠のどこにあるかは使う場所で異なるため、置き場所を選べるようにする。
## CENTER は詳細パネルの見出しのように、印だけを単独で置きたい場所で使う。
enum Corner { BOTTOM_LEFT, TOP_LEFT, CENTER }

## 枠の縁からの距離。落下ダメージのバッジの余白に合わせるため、置き場所ごとに持つ
## (盤面のスロットは下端から2px、カード・編成枠は上端から6px)。
const MARGIN := 4.0
const MARGIN_TOP_LEFT := 6.0
## メダリオンの半径は枠の幅に比例させつつ、小さすぎて紋章が潰れない範囲に収める。
const RADIUS_RATIO := 0.14
const RADIUS_MIN := 11.0
const RADIUS_MAX := 15.0
## UiPaint.draw_emblem() の size は紋章の半分の広がりに相当する。メダリオンの内側へ
## 収まるよう半径に対する比率で渡す。
const EMBLEM_RATIO := 0.6
const RING_WIDTH := 2.0
const RING_SEGMENTS := 24
## 受動効果の印。種類は描き分けず、有無だけを伝える小さな輪。
const PASSIVE_RADIUS_RATIO := 0.34
const PASSIVE_GAP := 4.0
const PASSIVE_SEGMENTS := 16

## 落下ダメージのバッジ(hourglass_slot.tscn の StyleBoxFlat)と同じ下地・縁の色にして、
## 左右のバッジが対になって見えるようにする。
const MEDALLION_FILL := Color(0.16, 0.12, 0.09, 0.95)
const RING_COLOR := Color(0.85, 0.62, 0.22, 1.0)
const PASSIVE_FILL := Color(0.16, 0.12, 0.09, 0.95)
## 受動の印はスキルの紋章より明るい縁にして、同じ琥珀系のまま役割の違いを示す。
const PASSIVE_RING_COLOR := Color(0.96, 0.82, 0.5, 0.95)

## (Corner を型注釈に使うと class_name と衝突してパースできないため int で持つ)
@export var corner: int = Corner.BOTTOM_LEFT

var _emblem: int = UiPaint.Emblem.NONE
var _has_passive := false


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func show_for(data: HourglassData) -> void:
	_emblem = SkillVisuals.emblem_for(data.skill) if data.has_skill() else UiPaint.Emblem.NONE
	_has_passive = not data.effects.is_empty()
	visible = _emblem != UiPaint.Emblem.NONE or _has_passive
	queue_redraw()


func clear_marks() -> void:
	_emblem = UiPaint.Emblem.NONE
	_has_passive = false
	visible = false
	queue_redraw()


func _draw() -> void:
	var ci := get_canvas_item()
	var radius: float = clampf(size.x * RADIUS_RATIO, RADIUS_MIN, RADIUS_MAX)
	var center := Vector2(MARGIN + radius, size.y - MARGIN - radius)
	if corner == Corner.TOP_LEFT:
		center = Vector2(MARGIN_TOP_LEFT + radius, MARGIN_TOP_LEFT + radius)
	elif corner == Corner.CENTER:
		radius = minf(size.x, size.y) * 0.5 - MARGIN
		center = size * 0.5
	if _emblem != UiPaint.Emblem.NONE:
		UiPaint.fill_circle(ci, center, radius, MEDALLION_FILL, RING_SEGMENTS)
		UiPaint.draw_ring(ci, center, radius, RING_COLOR, RING_WIDTH, RING_SEGMENTS)
		UiPaint.draw_emblem(ci, _emblem, center, radius * EMBLEM_RATIO)
	if not _has_passive:
		return
	var passive_radius := radius * PASSIVE_RADIUS_RATIO
	var passive_center := center
	if _emblem != UiPaint.Emblem.NONE:
		var offset := radius + PASSIVE_GAP + passive_radius
		passive_center.y += offset if corner == Corner.TOP_LEFT else -offset
	UiPaint.fill_circle(ci, passive_center, passive_radius, PASSIVE_FILL, PASSIVE_SEGMENTS)
	UiPaint.draw_ring(
		ci, passive_center, passive_radius, PASSIVE_RING_COLOR, RING_WIDTH, PASSIVE_SEGMENTS
	)
