class_name CardFlightFx
extends Control
## 汎用の飛翔演出オーバーレイ(GameDesign.md 9章「メニュー画面群の手触り」)。
## 「一覧の札 ⇄ 棚の枠」「品の絵 ⇄ 砂金チップ」のように、1枚の絵が画面上のある
## 矩形から別の矩形へ飛ぶ演出をまとめて引き受ける。生成・破棄は `fly()` の中で
## 完結するため、呼び出し側は `await CardFlightFx.fly(...)` するだけでよい。

const DEFAULT_DURATION := 0.42
## 飛んでいくにつれて小さくする比率。
const SHRINK_TO := 0.55

var _texture: Texture2D
var _emblem: UiPaint.Emblem = UiPaint.Emblem.HOURGLASS


## `root` はこの飛翔を乗せる先(暗幕より手前に見せたい場合は、暗幕より後で
## `add_child()` された画面・モーダルそのものを渡す)。`from_rect` / `to_rect` は
## `get_global_rect()` で得たグローバル座標でよい(内部で `root` のローカル座標へ
## 変換する)。`texture` を渡さなければ砂金の紋章(真鍮の砂時計)を描く。
static func fly(
	root: Control,
	from_rect: Rect2,
	to_rect: Rect2,
	duration: float = DEFAULT_DURATION,
	texture: Texture2D = null
) -> void:
	var fx := CardFlightFx.new()
	fx._texture = texture
	fx.mouse_filter = Control.MOUSE_FILTER_IGNORE
	fx.size = from_rect.size
	fx.pivot_offset = fx.size * 0.5
	var inverse := root.get_global_transform().affine_inverse()
	fx.position = inverse * from_rect.position
	var target_center: Vector2 = inverse * to_rect.get_center()
	root.add_child(fx)

	var tween := fx.create_tween()
	tween.set_parallel(true)
	(
		tween
		. tween_property(fx, "position", target_center - fx.size * 0.5, duration)
		. set_trans(Tween.TRANS_SINE)
		. set_ease(Tween.EASE_IN)
	)
	tween.tween_property(fx, "scale", Vector2.ONE * SHRINK_TO, duration)
	tween.tween_property(fx, "modulate:a", 0.25, duration * 0.6).set_delay(duration * 0.4)
	await tween.finished
	fx.queue_free()


func _draw() -> void:
	if _texture != null:
		draw_texture_rect(_texture, Rect2(Vector2.ZERO, size), false)
		return
	UiPaint.draw_emblem(get_canvas_item(), _emblem, size * 0.5, size.x * 0.5)
