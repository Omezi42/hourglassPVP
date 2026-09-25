class_name CardViewSandFx
extends RefCounted
## 駒の砂の動きの演出(GameDesign.md 9章)。**消える砂と落ちる砂は必ず描き分ける**。
## この2つを取り違えるとルールを誤解するため、演出上もっとも重要な区別として扱う。
##
## `CardViewStrike` / `CardViewFlourish` と同じく `CardView` から切り出した(Architecture.md 4.0節)。
## 絵の上へ重ねるため、描画は `CardView._draw()` の最後から `draw()` を呼んで行う。

enum Effect {
	NONE,
	## ダメージ。砂は消える(総量が減る)ので、砕けて外へ散る。
	SHATTER,
	## ターン終了の1粒。砂は落ちる(総量は変わらない)ので、下の部屋へ流れる。
	DROP,
	## 効果で砂が上へ戻る。落砂の逆向きで、下の部屋から上の部屋へ流れる(総量は変わらない)。
	RAISE,
}

const SHATTER_DURATION := 0.42
const DROP_DURATION := 0.45
const SHARD_COUNT := 9

var _view: CardView
var _effect: int = Effect.NONE
var _progress := 0.0
var _amount := 0
var _tween: Tween


func _init(view: CardView) -> void:
	_view = view


func play_shatter(amount: int) -> void:
	_amount = amount
	_start(Effect.SHATTER, SHATTER_DURATION)


func play_drop() -> void:
	_start(Effect.DROP, DROP_DURATION)


func play_raise() -> void:
	_start(Effect.RAISE, DROP_DURATION)


func _start(kind: int, duration: float) -> void:
	if _tween != null and _tween.is_valid():
		_tween.kill()
	_effect = kind
	_progress = 0.0
	_tween = _view.create_tween()
	_tween.tween_method(_set_progress, 0.0, 1.0, duration)
	_tween.finished.connect(_on_finished)


func _set_progress(value: float) -> void:
	_progress = value
	_view.queue_redraw()


func _on_finished() -> void:
	_effect = Effect.NONE
	_view.queue_redraw()


func draw() -> void:
	if _effect == Effect.NONE:
		return
	# 駒が倒されて枠が空になった後も、砕ける演出だけが残ることがある。
	# その場合は絵を引けないため何も描かない。
	if _view.card == null:
		return
	var rect := Rect2(Vector2.ZERO, _view.size)
	if _view.mode == CardView.Mode.BOARD:
		rect = _view._fit_art(_view._icon(), _view.board_art_box())
	if _effect == Effect.SHATTER:
		_draw_shatter(rect)
	elif _effect == Effect.RAISE:
		_draw_drop(rect, true)
	else:
		_draw_drop(rect)


## 砕けて散る:中心から破片が外へ飛び、赤みを帯びて消える。
func _draw_shatter(rect: Rect2) -> void:
	var center := rect.position + rect.size * Vector2(0.5, 0.45)
	var fade := 1.0 - _progress
	var reach := rect.size.x * (0.18 + 0.42 * _progress)
	var shards: int = SHARD_COUNT + mini(_amount, 6)
	for i in shards:
		var angle := TAU * float(i) / float(shards)
		var to := center + Vector2(cos(angle), sin(angle) * 0.8) * reach
		var shard_size := 4.0 * fade + 1.0
		_view.draw_circle(to, shard_size, Color(0.95, 0.5, 0.4, fade * 0.9))
	_view.draw_rect(rect, Color(1.0, 0.35, 0.3, fade * 0.18))


## 下の部屋へ流れる:中央を細い砂の筋が下りていく。総量は変わらない。
## `upward` なら逆向きに、下の部屋から上の部屋へ戻る(砂が上へ戻る効果)。
func _draw_drop(rect: Rect2, upward := false) -> void:
	var amber := CardView.SAND_AMBER
	var x := rect.position.x + rect.size.x * 0.5
	var top := rect.position.y + rect.size.y * 0.2
	var bottom := rect.position.y + rect.size.y * 0.78
	var from := bottom if upward else top
	var to := top if upward else bottom
	var head: float = lerpf(from, to, _progress)
	var back := 1.0 if upward else -1.0
	_view.draw_line(Vector2(x, from), Vector2(x, head), Color(amber, 0.55), 3.0)
	for i in 3:
		var y: float = head + back * float(i) * 6.0
		var outside: bool = y > bottom if upward else y < top
		if outside:
			continue
		_view.draw_circle(Vector2(x, y), 3.0 - i * 0.6, Color(amber, 0.9 - i * 0.25))
	if _progress > 0.85:
		var glow := (_progress - 0.85) / 0.15
		_view.draw_circle(Vector2(x, to), 8.0 * glow, Color(amber, 0.35 * (1.0 - glow)))
