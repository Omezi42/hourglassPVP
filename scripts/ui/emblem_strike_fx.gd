class_name EmblemStrikeFx
extends Control
## 単体を狙う設置効果の演出(GameDesign.md 9章)。光の筋だけでは「効果が対象に
## 当たった」ことしか伝わらないため、効果を持つ駒自身の紋章を対象へ向けて飛ばす。
##
## **型(`CardEnums.EffectVisualStyle`)によって紋章の動き方だけが変わる**。
## - STRIKE(打撃):弧を描いて飛び、当たった瞬間にわずかに膨らんで消える
## - DESCEND(恵与):ゆっくり舞い降り、当たった瞬間に柔らかい光の輪が広がる
## - DRAIN(払拭):直進して当たり、当たった瞬間に暗い輪へ収縮しながら消える
## - SPIN(反転):飛びながら紋章自身も回転する。実際の体力/攻撃力の入れ替えは
##   `CardView.play_flip()` 側が担うため、ここでは「回りながら飛ぶ」ことだけを見せる
##
## `CardMatchStrike`(実際の攻撃)と同じく、盤面より手前へ重ねる独立したオーバーレイ
## として持つ(`Control._draw()` は自分の子より背面に描かれるため)。

signal impact
signal finished

const SCREEN_SIZE := Vector2(1280, 720)
## 飛んでいく尺と、着弾後に消えるまでの尺(型ごとに変える)。
const FLIGHT_STRIKE := 0.22
const FLIGHT_DESCEND := 0.34
const FLIGHT_DRAIN := 0.18
const FLIGHT_SPIN := 0.26
const SETTLE := 0.16
## 描く大きさと、直進より「投げた」手応えを出すための放物線の高さ。
const ICON_SIZE := 40.0
const ARC_HEIGHT := 30.0
## 恵与は山なりを低く、ふわりと降りる印象にする。
const ARC_HEIGHT_DESCEND := 14.0
## 反転は紋章自身が飛びながら何回転するか。
const SPIN_TURNS := 1.5
## 着弾後に広がる輪(恵与)/縮む輪(払拭)の大きさ。
const RING_MAX_RADIUS := 26.0

var _style: int = CardEnums.EffectVisualStyle.STRIKE
var _emblem: Texture2D
var _from := Vector2.ZERO
var _to := Vector2.ZERO
var _progress := 0.0
var _visible_amount := 0.0
## 着弾後(SETTLE中)かどうか。恵与/払拭の輪はこの間だけ描く。
var _settling := false
var _tween: Tween


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	# **`set_anchors_preset()` は使わない**(Architecture.md 11章)。コードで生成した
	# 直後のサイズ0のノードへ使うと0のまま固定され、描いても見えない。
	size = SCREEN_SIZE
	z_index = 24


## 紋章を `from` から `to` へ飛ばす。同じ瞬間に複数飛ぶことは無い(効果の解決は
## 1枚のカードにつき1度だけ)ため、`CardFlipBeam` と違い同時に1本しか持たない。
func play(emblem: Texture2D, from: Vector2, to: Vector2, style: int) -> void:
	if _tween != null and _tween.is_valid():
		_tween.kill()
	_style = style
	_emblem = emblem
	_from = from
	_to = to
	_progress = 0.0
	_visible_amount = 1.0
	_settling = false
	var flight := _flight_duration()
	_tween = create_tween()
	(
		_tween
		. tween_method(_set_progress, 0.0, 1.0, flight)
		. set_trans(
			Tween.TRANS_SINE if _style == CardEnums.EffectVisualStyle.DESCEND else Tween.TRANS_CUBIC
		)
		. set_ease(Tween.EASE_IN)
	)
	_tween.tween_callback(_on_impact)
	_tween.tween_callback(func() -> void: _settling = true)
	_tween.tween_method(_set_visible_amount, 1.0, 0.0, SETTLE)
	_tween.tween_callback(_on_finished)


func _flight_duration() -> float:
	match _style:
		CardEnums.EffectVisualStyle.DESCEND:
			return FLIGHT_DESCEND
		CardEnums.EffectVisualStyle.DRAIN:
			return FLIGHT_DRAIN
		CardEnums.EffectVisualStyle.SPIN:
			return FLIGHT_SPIN
	return FLIGHT_STRIKE


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
	if _style != CardEnums.EffectVisualStyle.DRAIN:
		var arc := (
			ARC_HEIGHT_DESCEND if _style == CardEnums.EffectVisualStyle.DESCEND else ARC_HEIGHT
		)
		at.y -= sin(_progress * PI) * arc
	var bump := (
		1.0 + 0.35 * sin(_progress * PI) if _style == CardEnums.EffectVisualStyle.STRIKE else 1.0
	)
	var half := Vector2(ICON_SIZE, ICON_SIZE) * 0.5 * bump
	var tint := _tint()
	if _style == CardEnums.EffectVisualStyle.SPIN:
		var rot := _progress * TAU * SPIN_TURNS
		draw_set_transform(at, rot, Vector2.ONE)
		draw_texture_rect(_emblem, Rect2(-half, half * 2.0), false, Color(tint, _visible_amount))
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	else:
		draw_texture_rect(
			_emblem, Rect2(at - half, half * 2.0), false, Color(tint, _visible_amount)
		)
	if _settling:
		_draw_settle_ring(at)


## 着弾後の余韻(GameDesign.md 9章)。恵与は光が馴染むように外へ広がる輪、
## 払拭は色が抜けて収縮する輪にする。打撃・反転はここでは何も足さない
## (打撃は盤面の揺れと砂の飛散、反転は `CardView.play_flip()` が担う)。
func _draw_settle_ring(at: Vector2) -> void:
	var fade := _visible_amount
	match _style:
		CardEnums.EffectVisualStyle.DESCEND:
			var radius := RING_MAX_RADIUS * (1.0 - fade)
			draw_arc(at, radius, 0.0, TAU, 24, Color(1.0, 0.92, 0.62, 0.6 * fade), 2.0)
		CardEnums.EffectVisualStyle.DRAIN:
			var radius_in := RING_MAX_RADIUS * fade
			draw_arc(at, radius_in, 0.0, TAU, 24, Color(0.2, 0.18, 0.22, 0.7 * fade), 2.0)


## 型ごとの色味(GameDesign.md 9章)。打撃=素の紋章のまま、恵与=温かい金、
## 払拭=くすんだ灰、反転=淡い水色。効果の性質を一目で見分けられるようにする。
func _tint() -> Color:
	match _style:
		CardEnums.EffectVisualStyle.DESCEND:
			return Color(1.0, 0.94, 0.78)
		CardEnums.EffectVisualStyle.DRAIN:
			return Color(0.62, 0.6, 0.66)
		CardEnums.EffectVisualStyle.SPIN:
			return Color(0.78, 0.92, 1.0)
	return Color(1, 1, 1)
