class_name CardViewStrike
extends RefCounted
## 攻撃の演出の段取り(GameDesign.md 9章)。「寄る → 溜める → 当てる → 戻る」の4段を
## 1本の Tween で組む。
##
## **CardView から切り出したのは、1ファイル1000行の上限に達したため**
## (Architecture.md 11章)。分ける線は「駒の見た目」と「殴りに行く段取り」に引いた。
## 状態(offset / angle / flash)と描画は CardView 側に残っている。駒の絵に掛ける変換は
## 描画のたびに要るもので、演出が終わってからも参照されるため。

var _view: CardView


func _init(p_view: CardView) -> void:
	_view = p_view


## 攻撃:駒が対象の斜め上まで渡っていき、反動をつけて当てる(GameDesign.md 9章)。
##
## **動かすのは絵だけで、台座は置いていく**。台座は盤面の設備であって駒の一部ではなく、
## 一緒に動くと枠ごと飛んでいくように見えるため。絵は `draw_set_transform_matrix()` で
## 上端を支点に回し、`Control` 自身の `position` / `rotation` は触らない
## (触ると台座も動き、盤面の当たり判定もずれる)。
##
## `target_center` はこのビューの**親の座標系**で渡す(`position` と同じ空間)。
## `quick` は同じターンの2回目以降で、尺を6割へ詰める。
## `follow_center` を渡すと、当てた後さらにそこまで抜けていく(貫通。GameDesign.md 9章)。
func play(target_center: Vector2, quick := false, follow_center := Vector2.INF) -> void:
	if _view.mode != CardView.Mode.BOARD:
		_view.strike_finished.emit()
		return
	if _view.strike_tween != null and _view.strike_tween.is_valid():
		_view.strike_tween.kill()
	var anchor := _view.position + _view.board_art_box().get_center()
	# 対象から見てこちら側の斜め上へ立つ。振り下ろす向きがこれで決まる。
	var side_x := signf(anchor.x - target_center.x)
	if is_zero_approx(side_x):
		side_x = 1.0
	var standoff := (
		_stop_inside_screen(
			(
				target_center
				+ Vector2(side_x * CardView.STRIKE_STANDOFF.x, -CardView.STRIKE_STANDOFF.y)
			)
		)
		- anchor
	)
	var contact: Vector2 = (
		_stop_inside_screen(
			target_center + Vector2(side_x * CardView.STRIKE_CONTACT.x, -CardView.STRIKE_CONTACT.y)
		)
		- anchor
	)
	var scale := CardView.STRIKE_QUICK_SCALE if quick else 1.0
	_view.striking = true
	_view.z_index = CardView.STRIKE_Z_INDEX

	_view.strike_tween = _view.create_tween()
	# 寄る:出だしを速く終わりを緩める。下端は慣性で遅れて振れる。
	var approach := _view.strike_tween.tween_method(
		_setstrike_offset, Vector2.ZERO, standoff, CardView.STRIKE_APPROACH * scale
	)
	approach.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	(
		_view
		. strike_tween
		. parallel()
		. tween_method(
			_setstrike_angle,
			0.0,
			-side_x * CardView.STRIKE_LAG_ANGLE,
			CardView.STRIKE_APPROACH * scale
		)
		. set_trans(Tween.TRANS_SINE)
	)
	# 溜める:上端を支点に後ろへ傾く。
	(
		_view
		. strike_tween
		. tween_method(
			_setstrike_angle,
			-side_x * CardView.STRIKE_LAG_ANGLE,
			-side_x * CardView.STRIKE_WIND_ANGLE,
			CardView.STRIKE_WIND_UP * scale
		)
		. set_trans(Tween.TRANS_SINE)
		. set_ease(Tween.EASE_OUT)
	)
	# 当てる:振り下ろして接触点まで。叩き潰さず、当たったところで止める。
	(
		_view
		. strike_tween
		. tween_method(
			_setstrike_angle,
			-side_x * CardView.STRIKE_WIND_ANGLE,
			side_x * CardView.STRIKE_HIT_ANGLE,
			CardView.STRIKE_HIT * scale
		)
		. set_trans(Tween.TRANS_CUBIC)
		. set_ease(Tween.EASE_IN)
	)
	(
		_view
		. strike_tween
		. parallel()
		. tween_method(_setstrike_offset, standoff, contact, CardView.STRIKE_HIT * scale)
		. set_trans(Tween.TRANS_CUBIC)
		. set_ease(Tween.EASE_IN)
	)
	_view.strike_tween.tween_callback(_on_impact)
	# 貫通:砕けた対象を通り抜けて、そのまま相手プレイヤーまで届く。
	var pierced := follow_center.is_finite()
	if pierced:
		var through := _stop_inside_screen(follow_center) - anchor
		(
			_view
			. strike_tween
			. tween_method(_setstrike_offset, contact, through, CardView.STRIKE_PIERCE * scale)
			. set_trans(Tween.TRANS_CUBIC)
			. set_ease(Tween.EASE_IN_OUT)
		)
		_view.strike_tween.tween_callback(_on_impact)
		contact = through
	# 当たった瞬間の閃光。戻りに合わせて消す。
	_view.strike_tween.parallel().tween_method(
		_setstrike_flash, 1.0, 0.0, CardView.STRIKE_RETURN * scale * 0.6
	)
	# 戻る:数回小さく揺れながら台座へ。
	(
		_view
		. strike_tween
		. tween_method(_setstrike_offset, contact, Vector2.ZERO, CardView.STRIKE_RETURN * scale)
		. set_trans(Tween.TRANS_CUBIC)
		. set_ease(Tween.EASE_OUT)
	)
	(
		_view
		. strike_tween
		. parallel()
		. tween_method(
			_setstrike_angle,
			side_x * CardView.STRIKE_HIT_ANGLE,
			0.0,
			CardView.STRIKE_RETURN * scale
		)
		. set_trans(Tween.TRANS_ELASTIC)
		. set_ease(Tween.EASE_OUT)
	)
	_view.strike_tween.tween_callback(_on_finished)


## 立ち止まる場所を画面の中へ収める。**相手プレイヤーを狙うとき、HPバーは画面の上端に
## あるため「その斜め上」が画面の外になる**。そのまま飛ばすと駒が消えたように見える。
func _stop_inside_screen(at: Vector2) -> Vector2:
	var area := _view.get_parent_area_size()
	if area.x <= 0.0 or area.y <= 0.0:
		return at
	var margin := (
		Vector2(CardView.BOARD_ART_SIDE, CardView.BOARD_ART_SIDE) * 0.5 + Vector2(8.0, 8.0)
	)
	return at.clamp(margin, area - margin)


func _setstrike_offset(value: Vector2) -> void:
	_view.strike_offset = value
	_view.queue_redraw()


func _setstrike_angle(value: float) -> void:
	_view.strike_angle = value
	_view.queue_redraw()


func _setstrike_flash(value: float) -> void:
	_view.strike_flash = value
	_view.queue_redraw()


func _on_impact() -> void:
	_view.strike_impact.emit()


func _on_finished() -> void:
	_view.striking = false
	_view.strike_offset = Vector2.ZERO
	_view.strike_angle = 0.0
	_view.strike_flash = 0.0
	_view.z_index = 0
	_view.queue_redraw()
	_view.strike_finished.emit()
