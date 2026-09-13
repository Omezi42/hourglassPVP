class_name EmblemStrikeFx
extends Control
## 設置効果が単体の砂時計へダメージ/破壊を与えるときの演出(GameDesign.md 9章)。
## 光の筋だけでは「効果が対象に当たった」ことしか伝わらないため、効果を持つ駒自身の
## 紋章を対象へ向けて飛ばし、実際に打撃しているように見せる。
##
## 攻撃(`CardViewStrike`)の全身の動きとは違う、紋章1枚だけの軽い一撃として作る。
## `CardMatchStrike` と同じく、盤面より手前へ重ねる独立したオーバーレイとして持つ
## (`Control._draw()` は自分の子より背面に描かれるため、画面側で描くと盤面に隠れる)。

signal impact
signal finished

const SCREEN_SIZE := Vector2(1280, 720)
## 飛んでいく尺と、着弾後に消えるまでの尺。
const FLIGHT := 0.22
const SETTLE := 0.14
## 描く大きさと、直進より「投げた」手応えを出すための放物線の高さ。
const ICON_SIZE := 40.0
const ARC_HEIGHT := 30.0

var _emblem: Texture2D
var _from := Vector2.ZERO
var _to := Vector2.ZERO
var _progress := 0.0
var _visible_amount := 0.0
var _tween: Tween


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	# **`set_anchors_preset()` は使わない**(Architecture.md 11章)。コードで生成した
	# 直後のサイズ0のノードへ使うと0のまま固定され、描いても見えない。
	size = SCREEN_SIZE
	z_index = 24


## 紋章を `from` から `to` へ飛ばす。同じ瞬間に複数飛ぶことは無い(効果の解決は
## 1枚のカードにつき1度だけ)ため、`CardFlipBeam` と違い同時に1本しか持たない。
func play(emblem: Texture2D, from: Vector2, to: Vector2) -> void:
	if _tween != null and _tween.is_valid():
		_tween.kill()
	_emblem = emblem
	_from = from
	_to = to
	_progress = 0.0
	_visible_amount = 1.0
	_tween = create_tween()
	_tween.tween_method(_set_progress, 0.0, 1.0, FLIGHT).set_trans(Tween.TRANS_CUBIC).set_ease(
		Tween.EASE_IN
	)
	_tween.tween_callback(_on_impact)
	_tween.tween_method(_set_visible_amount, 1.0, 0.0, SETTLE)
	_tween.tween_callback(_on_finished)


func _set_progress(value: float) -> void:
	_progress = value
	queue_redraw()


func _set_visible_amount(value: float) -> void:
	_visible_amount = value
	queue_redraw()


func _on_impact() -> void:
	impact.emit()


func _on_finished() -> void:
	_emblem = null
	finished.emit()


func _draw() -> void:
	if _emblem == null or _visible_amount <= 0.0:
		return
	var at := _from.lerp(_to, _progress)
	at.y -= sin(_progress * PI) * ARC_HEIGHT
	var scale := 1.0 + 0.35 * sin(_progress * PI)
	var half := Vector2(ICON_SIZE, ICON_SIZE) * 0.5 * scale
	draw_texture_rect(_emblem, Rect2(at - half, half * 2.0), false, Color(1, 1, 1, _visible_amount))
