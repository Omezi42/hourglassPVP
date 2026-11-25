class_name CardArtLayer
extends Control
## 場の駒の「台座の面」と「砂時計の絵」を、`CardView` の背面へ敷く子ノード(Architecture.md 4.0節)。
##
## **攻撃の演出で動くのは絵だけ**。絵を別ノードにして `position` / `rotation` で動かせば、
## 駒全体(台座・輪・数字・名前)を毎コマ描き直さずに済む。親の描画の順(台座 → 絵 → 輪 →
## 銘板 → 数字)は、2つの層を `show_behind_parent` で親の手前でなく背面へ並べて保つ。
## 台座の面は親が描き直したときだけ、絵は親が描き直したときと閃光・砂の動きのときだけ描く。

enum Part { PEDESTAL, ART }

var _view: CardView
var _part: int = Part.ART


func _init(view: CardView, part: int) -> void:
	_view = view
	_part = part
	show_behind_parent = true
	mouse_filter = Control.MOUSE_FILTER_IGNORE


## 攻撃で絵を回す支点(駒の上端寄り)。回転は `rotation` が `pivot_offset` を軸に行う。
func set_strike_pivot(pivot: Vector2) -> void:
	pivot_offset = pivot


func _draw() -> void:
	if _view.mode != CardView.Mode.BOARD:
		return
	if _part == Part.PEDESTAL:
		CardViewPaint.pedestal_base(_view, self)
		return
	if _view.card == null:
		return
	var tint := _view._tint()
	var sink := CardView.SUMMONED_SINK if _view.unit != null and _view.unit.is_fresh() else 0.0
	_draw_art(tint, sink)
	if _view.striking:
		_draw_strike_flash()
	_view._sand.draw(self)


func _draw_art(tint: Color, sink: float) -> void:
	var still := _view._icon()
	if still == null:
		return
	var lift := _view._fx.land_offset()
	var box := _view.board_art_box().grow_individual(0, sink, 0, sink)
	# 大きさと位置は止めた絵で決める。動く絵は同じ縦横比で、解像度だけが違う。
	var rect := _view._fit_art(still, box)
	rect.position.y += lift
	var texture := _view._shown(still)
	if _view._flip_progress >= 0.0:
		CardViewPaint.flipping_art(_view, self, texture, rect, tint)
	else:
		draw_texture_rect(texture, rect, false, tint)
	# 硝子は枠ではなくガラスそのものへ膜を掛ける(GameDesign.md 9章)。
	if _view.unit != null and _view.unit.glass_intact:
		UiPaint.fill_ellipse(
			get_canvas_item(), rect.get_center(), rect.size * 0.42, Color(0.6, 0.85, 1.0, 0.16), 28
		)


## 当たった瞬間の閃光。絵の下端(当たった側)へ出す。
func _draw_strike_flash() -> void:
	var flash := _view.strike_flash
	if flash <= 0.01:
		return
	var box := _view.board_art_box()
	var at := Vector2(box.get_center().x, box.end.y - 8.0)
	var radius := 10.0 + 14.0 * (1.0 - flash)
	UiPaint.fill_circle(get_canvas_item(), at, radius, Color(1.0, 0.94, 0.72, 0.55 * flash), 20)
