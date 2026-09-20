class_name EmblemStrikeFx
extends Control
## 単体・全体を狙う設置効果・砂術・余砂の演出(GameDesign.md 9章)。光の筋だけでは
## 「効果が対象に当たった」ことしか伝わらないため、効果の紋章そのものを対象へ向けて飛ばす。
##
## **型(`CardEnums.EffectVisualStyle`)によって紋章の動き方だけが変わる**。
## - STRIKE(打撃):弧を描いて飛び、当たった瞬間にわずかに膨らんで消える
## - DESCEND(恵与):ゆっくり舞い降り、当たった瞬間に柔らかい光の輪が広がる
## - DRAIN(払拭):直進して当たり、当たった瞬間に暗い輪へ収縮しながら消える
## - SPIN(反転):飛びながら紋章自身も回転する。実際の体力/攻撃力の入れ替えは
##   `CardView.play_flip()` 側が担うため、ここでは「回りながら飛ぶ」ことだけを見せる
## - PULSE(静止):飛ばない(`to == from`)。着弾で金色の輪が広がり、紋章自身も
##   わずかに膨らんで消える(対象を取らない砂術・余砂のドロー)
## - RECALL(回収):DRAINと同じ直進だが淡い水色寄りの白。着弾後の輪は外→内へ収縮する
##
## **紋章の出どころ(`CardEnums.EffectOrigin`)によって、飛び始める前の見せ方が変わる**
## (Architecture.md 4.0節)。UNITは即座に飛ぶが、SPELLは`RISE`のあいだ`from`の位置で
## 紋章が浮き上がってから、DEATHは`LINGER`のあいだ台座の銘板として残ってから飛ぶ。
##
## `CardMatchStrike`(実際の攻撃)と同じく、盤面より手前へ重ねる独立したオーバーレイ
## として持つ(`Control._draw()` は自分の子より背面に描かれるため)。
##
## **同時に複数飛ばせる**(`play_many()`)。全体に効く効果(スイープ等)が対象の数だけ
## 紋章を同時に飛ばすために使う。進捗(`_progress`)は全飛翔で共有するため、
## 対象の数によらず同時に発射・同時に着弾する。

signal impact
signal finished

const SCREEN_SIZE := Vector2(1280, 720)

const FLIGHT_STRIKE := 0.22
const FLIGHT_DESCEND := 0.34
const FLIGHT_DRAIN := 0.18
const FLIGHT_SPIN := 0.26
## 静止(PULSE)は移動しないぶん、弾ける前のわずかな溜めとして短く取る。
const FLIGHT_PULSE := 0.14
const SETTLE := 0.16
## SPELL/DEATH起源が飛ぶ前に持つ前置き(GameDesign.md 9章「紋章の出どころ」)。
const RISE_DURATION := 0.24
const LINGER_DURATION := 0.38
## SPELLの浮き上がりで、紋章がどこまで大きくなるか・どれだけ持ち上がるか。
const RISE_SCALE := 1.8
const RISE_LIFT := 10.0
## 描く大きさと、直進より「投げた」手応えを出すための放物線の高さ。
const ICON_SIZE := 40.0
const ARC_HEIGHT := 30.0
## 恵与は山なりを低く、ふわりと降りる印象にする。
const ARC_HEIGHT_DESCEND := 14.0
## 反転は紋章自身が飛びながら何回転するか。
const SPIN_TURNS := 1.5
## 着弾後に広がる輪(恵与)/縮む輪(払拭・回収)の大きさ。
const RING_MAX_RADIUS := 26.0
## 静止(PULSE)の輪は、それ以外より一回り大きく広がる。
const PULSE_RING_SCALE := 1.4
## 静止(PULSE)が消える間際に紋章がどれだけ膨らむか。
const PULSE_BUMP := 0.4

var _style: int = CardEnums.EffectVisualStyle.STRIKE
var _origin: int = CardEnums.EffectOrigin.UNIT
var _emblem: Texture2D
## 同時に飛んでいる紋章。各要素は {"from": Vector2, "to": Vector2}。
var _flights: Array[Dictionary] = []
var _progress := 0.0
var _visible_amount := 0.0
## SPELL/DEATH起源の前置き(RISE/LINGER)の進捗。この間は `_progress` を動かさない。
var _prelude := 0.0
var _in_prelude := false
## 着弾後(SETTLE中)かどうか。恵与/払拭/静止の輪はこの間だけ描く。
var _settling := false
var _tween: Tween


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	# **`set_anchors_preset()` は使わない**(Architecture.md 11章)。コードで生成した
	# 直後のサイズ0のノードへ使うと0のまま固定され、描いても見えない。
	size = SCREEN_SIZE
	z_index = 24


## 紋章を `from` から `to` へ1本だけ飛ばす(単体を狙う効果)。
func play(
	emblem: Texture2D,
	from: Vector2,
	to: Vector2,
	style: int,
	origin: int = CardEnums.EffectOrigin.UNIT
) -> void:
	_play_flights(emblem, [{"from": from, "to": to}], style, origin)


## 同じ紋章を `from` から `targets` それぞれへ同時に飛ばす(全体に効く効果。
## GameDesign.md 9章)。1体ずつ順に飛ばすのではなく、全飛翔が同じ進捗を共有して
## 同時に発射・同時に着弾する。
func play_many(
	emblem: Texture2D,
	from: Vector2,
	targets: Array[Vector2],
	style: int,
	origin: int = CardEnums.EffectOrigin.UNIT
) -> void:
	var flights: Array[Dictionary] = []
	for to in targets:
		flights.append({"from": from, "to": to})
	_play_flights(emblem, flights, style, origin)


func _play_flights(emblem: Texture2D, flights: Array[Dictionary], style: int, origin: int) -> void:
	if _tween != null and _tween.is_valid():
		_tween.kill()
	_style = style
	_origin = origin
	_emblem = emblem
	_flights = flights
	_progress = 0.0
	_prelude = 0.0
	_visible_amount = 1.0
	_settling = false
	_in_prelude = _prelude_duration() > 0.0
	_tween = create_tween()
	if _in_prelude:
		_tween.tween_method(_set_prelude, 0.0, 1.0, _prelude_duration())
		_tween.tween_callback(func() -> void: _in_prelude = false)
	var flight := _flight_duration()
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


## SPELL/DEATH起源だけが持つ前置き(GameDesign.md 9章「紋章の出どころ」)。
func _prelude_duration() -> float:
	match _origin:
		CardEnums.EffectOrigin.SPELL:
			return RISE_DURATION
		CardEnums.EffectOrigin.DEATH:
			return LINGER_DURATION
	return 0.0


func _flight_duration() -> float:
	match _style:
		CardEnums.EffectVisualStyle.DESCEND:
			return FLIGHT_DESCEND
		CardEnums.EffectVisualStyle.DRAIN, CardEnums.EffectVisualStyle.RECALL:
			return FLIGHT_DRAIN
		CardEnums.EffectVisualStyle.SPIN:
			return FLIGHT_SPIN
		CardEnums.EffectVisualStyle.PULSE:
			return FLIGHT_PULSE
	return FLIGHT_STRIKE


## 直進する型(飛距離が意味を持たない、または一直線に見せたいもの)。
func _uses_arc() -> bool:
	return (
		_style != CardEnums.EffectVisualStyle.DRAIN
		and _style != CardEnums.EffectVisualStyle.RECALL
		and _style != CardEnums.EffectVisualStyle.PULSE
	)


func _set_prelude(value: float) -> void:
	_prelude = value
	queue_redraw()


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
	_flights.clear()
	finished.emit()


func _draw() -> void:
	if _emblem == null or _visible_amount <= 0.0:
		return
	if _in_prelude:
		for flight in _flights:
			_draw_prelude(flight["from"])
		return
	for flight in _flights:
		_draw_flight(flight["from"], flight["to"])


## SPELL(RISE)/DEATH(LINGER)の前置き。飛び始める前に、出どころで一呼吸置く
## (GameDesign.md 9章「紋章の出どころ」)。
func _draw_prelude(from: Vector2) -> void:
	match _origin:
		CardEnums.EffectOrigin.SPELL:
			_draw_spell_rise(from)
		CardEnums.EffectOrigin.DEATH:
			_draw_death_linger(from)


## 砂術:自分の情報帯の上で紋章が大きく浮かび上がる。飛ぶときは通常の大きさへ戻る。
func _draw_spell_rise(from: Vector2) -> void:
	var scale_now := ICON_SIZE * RISE_SCALE * _prelude
	if scale_now <= 0.0:
		return
	var at := from - Vector2(0.0, RISE_LIFT * _prelude)
	var half := Vector2(scale_now, scale_now) * 0.5
	draw_texture_rect(_emblem, Rect2(at - half, half * 2.0), false, Color(_tint(), 1.0))


## 余砂:砕けた台座に銘板だけが残る(`CardViewPaint.pedestal_plaque()` と同じ見た目)。
func _draw_death_linger(at: Vector2) -> void:
	var ci := get_canvas_item()
	UiPaint.fill_circle(ci, at, CardView.EMBLEM_PLAQUE_RADIUS, Color(0.08, 0.06, 0.05, 0.85), 24)
	UiPaint.fill_circle(ci, at, CardView.EMBLEM_PLAQUE_RADIUS - 1.5, UiPalette.BRASS_MID, 24)
	var half := Vector2(CardView.EMBLEM_PLAQUE_SIDE, CardView.EMBLEM_PLAQUE_SIDE) * 0.5
	draw_texture_rect(
		_emblem,
		Rect2(at - half + Vector2(0.0, 1.0), half * 2.0),
		false,
		Color(0.08, 0.06, 0.04, 0.7)
	)
	draw_texture_rect(
		_emblem, Rect2(at - half, half * 2.0), false, Color(UiPalette.BRASS_HIGHLIGHT, 0.95)
	)
	UiPaint.draw_ring(ci, at, CardView.EMBLEM_PLAQUE_RADIUS, UiPalette.BRASS_HIGHLIGHT, 1.0, 24)


func _draw_flight(from: Vector2, to: Vector2) -> void:
	var at := from.lerp(to, _progress)
	if _uses_arc():
		var arc := (
			ARC_HEIGHT_DESCEND if _style == CardEnums.EffectVisualStyle.DESCEND else ARC_HEIGHT
		)
		at.y -= sin(_progress * PI) * arc
	var bump := _bump_amount()
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


## 打撃は飛んでいる間に膨らみ、静止(PULSE)は消える間際に膨らむ。
func _bump_amount() -> float:
	if _style == CardEnums.EffectVisualStyle.STRIKE:
		return 1.0 + 0.35 * sin(_progress * PI)
	if _style == CardEnums.EffectVisualStyle.PULSE and _settling:
		return 1.0 + PULSE_BUMP * (1.0 - _visible_amount)
	return 1.0


## 着弾後の余韻(GameDesign.md 9章)。恵与は光が馴染むように外へ広がる輪、
## 払拭・回収は色が抜けて収縮する輪、静止は金色の大きな輪にする。打撃・反転は
## ここでは何も足さない(打撃は盤面の揺れと砂の飛散、反転は `CardView.play_flip()` が担う)。
func _draw_settle_ring(at: Vector2) -> void:
	var fade := _visible_amount
	match _style:
		CardEnums.EffectVisualStyle.DESCEND:
			var radius := RING_MAX_RADIUS * (1.0 - fade)
			draw_arc(at, radius, 0.0, TAU, 24, Color(1.0, 0.92, 0.62, 0.6 * fade), 2.0)
		CardEnums.EffectVisualStyle.DRAIN:
			var radius_in := RING_MAX_RADIUS * fade
			draw_arc(at, radius_in, 0.0, TAU, 24, Color(0.2, 0.18, 0.22, 0.7 * fade), 2.0)
		CardEnums.EffectVisualStyle.RECALL:
			var radius_recall := RING_MAX_RADIUS * fade
			draw_arc(at, radius_recall, 0.0, TAU, 24, Color(0.78, 0.92, 1.0, 0.6 * fade), 2.0)
		CardEnums.EffectVisualStyle.PULSE:
			var radius_pulse := (RING_MAX_RADIUS * PULSE_RING_SCALE) * (1.0 - fade)
			draw_arc(at, radius_pulse, 0.0, TAU, 24, Color(1.0, 0.86, 0.42, 0.65 * fade), 2.2)


## 型ごとの色味(GameDesign.md 9章)。打撃=素の紋章のまま、恵与=温かい金、
## 払拭=くすんだ灰、反転=淡い水色、静止=金、回収=淡い水色寄りの白。
## 効果の性質を一目で見分けられるようにする。
func _tint() -> Color:
	match _style:
		CardEnums.EffectVisualStyle.DESCEND:
			return Color(1.0, 0.94, 0.78)
		CardEnums.EffectVisualStyle.DRAIN:
			return Color(0.62, 0.6, 0.66)
		CardEnums.EffectVisualStyle.SPIN:
			return Color(0.78, 0.92, 1.0)
		CardEnums.EffectVisualStyle.PULSE:
			return Color(1.0, 0.94, 0.7)
		CardEnums.EffectVisualStyle.RECALL:
			return Color(0.9, 0.96, 1.0)
	return Color(1, 1, 1)
