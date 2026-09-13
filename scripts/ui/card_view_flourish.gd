class_name CardViewFlourish
extends RefCounted
## 駒の紋章まわりの軽い合図(GameDesign.md 9章)。全身が渡っていく攻撃
## (`CardViewStrike`)とは違う、紋章だけの短い動きをここへ集める。
##
## `CardView` から切り出したのは、1ファイル1000行の上限に達したため
## (Architecture.md 11章)。状態(`counter_offset` / `spark_amount`)は `CardView` に
## 残し、描画もそちらが行う。ここが持つのは Tween を組む段取りだけ。

## 相打ちの反撃(GameDesign.md 9章)。
const COUNTER_OUT := 0.09
const COUNTER_RETURN := 0.16
const COUNTER_DISTANCE := 10.0
const COUNTER_LIFT := 3.0
## ドローを起こした合図の光の輪(GameDesign.md 9章)。
const SPARK_DURATION := 0.32

var _view: CardView
var _counter_tween: Tween
var _spark_tween: Tween


func _init(view: CardView) -> void:
	_view = view


## 相打ちの反撃:紋章が攻撃側へ向けて短く突き出し、すぐ戻る(GameDesign.md 9章)。
## `dir_x` は突き出す向き(正で右、負で左)。全身が渡っていく攻撃側の演出とは違う、
## 紋章だけの軽い一撃として作る(誰が仕掛けたのかは攻撃側の動きだけで示す)。
func play_counter(dir_x: float) -> void:
	if _counter_tween != null and _counter_tween.is_valid():
		_counter_tween.kill()
	var out := Vector2(dir_x * COUNTER_DISTANCE, -COUNTER_LIFT)
	_counter_tween = _view.create_tween()
	(
		_counter_tween
		. tween_method(_set_counter_offset, Vector2.ZERO, out, COUNTER_OUT)
		. set_trans(Tween.TRANS_CUBIC)
		. set_ease(Tween.EASE_OUT)
	)
	(
		_counter_tween
		. tween_method(_set_counter_offset, out, Vector2.ZERO, COUNTER_RETURN)
		. set_trans(Tween.TRANS_BACK)
		. set_ease(Tween.EASE_OUT)
	)


func _set_counter_offset(value: Vector2) -> void:
	_view.counter_offset = value
	_view.queue_redraw()


## 効果を持つ駒が発火した:紋章の周りへ短い光の輪を出す(GameDesign.md 9章)。
## エコー・クラック・ページ・メモリーのようにドローを起こす設置効果・トリガーが、
## その駒自身から働いたことを示す軽い合図。盤面を動かさないため、揺れも移動も伴わない。
func play_spark() -> void:
	if _spark_tween != null and _spark_tween.is_valid():
		_spark_tween.kill()
	_spark_tween = _view.create_tween()
	(
		_spark_tween
		. tween_method(_set_spark_amount, 1.0, 0.0, SPARK_DURATION)
		. set_trans(Tween.TRANS_SINE)
		. set_ease(Tween.EASE_OUT)
	)


func _set_spark_amount(value: float) -> void:
	_view.spark_amount = value
	_view.queue_redraw()
