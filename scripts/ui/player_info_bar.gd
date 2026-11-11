class_name PlayerInfoBar
extends Control
## 片方のプレイヤーの情報帯(GameDesign.md 9章「対局画面」)。
## HP・マナ・山札の残り・墓地の枚数を並べ、相手側は手札の枚数も出す(中身は伏せる)。

signal face_pressed
signal graveyard_pressed

const BAR_HEIGHT := 56.0
const DANGER_RATIO := 0.4
## 帯は1枚の板で囲わず、卓の台座・ターン終了ボタンと同じ語彙の「真鍮の器具」を
## 横に並べる(GameDesign.md 9章「対局画面の見た目」)。**左の群(肖像のメダル / 名札 / HPの器)と
## 右の群(マナの計器 / 山札・墓地・手札の札)に分け、中央は空ける**(卓の真上の吊りランプを見せる)。
## 上下の帯で同じ位置に同じものを置く。座標はすべて帯のローカル(高さ BAR_HEIGHT)。
const CENTER_Y := BAR_HEIGHT * 0.5
## 肖像のメダル。真鍮の太い輪の中にアイコンを嵌める。
const PORTRAIT_CENTER := Vector2(30.0, CENTER_Y)
const PORTRAIT_RADIUS := 25.0
const PORTRAIT_RING_WIDTH := 3.5
## 名札。メダルの右から伸びる硝子の面。
const NAME_PLATE_RECT := Rect2(44.0, 9.0, 152.0, 38.0)
const NAME_TEXT_X := 66.0
const TITLE_FONT := UiPalette.T_MICRO
const NAME_FONT := UiPalette.T_LEAD
## 称号と表示名の2行を、帯の上下の中央からそれぞれ上・下へずらす量。
const NAME_LINE_OFFSET := 13.0
const TITLE_LINE_OFFSET := 7.0
## HPの器。真鍮の縁 + ガラス越しの砂。右端に体力の丸いバッジ(場の駒と同じ語彙)を嵌める。
const HP_BAR_X := 206.0
const HP_BAR_SIZE := Vector2(180, 26)
const HP_RIM_WIDTH := 2.5
const HP_BADGE_RADIUS := 18.0
const HP_CAP_FONT := UiPalette.T_SMALL
const HP_CAP_GAP := 8.0
const HP_DANGER_LIGHT := Color(1.0, 0.50, 0.42)
const HP_SHEEN := Color(1, 1, 1, 0.10)
const HP_SHEEN_INSET := Vector2(6.0, 2.5)
const HP_SHEEN_RATIO := 0.3
## マナの計器。コストと同じ青の丸いバッジに現在値、右の溝へ最大値ぶんの粒。
## 溝の長さは最大マナ(`MatchState.MAX_MANA`)の粒がちょうど収まる幅から求める。
const MANA_BADGE_CENTER := Vector2(15.0, CENTER_Y)
const MANA_BADGE_RADIUS := 16.0
const MANA_TROUGH_X := 39.0
const MANA_TROUGH_Y := 17.0
const MANA_TROUGH_HEIGHT := 22.0
const PIP_START_X := 51.0
const PIP_STEP := 18.0
const PIP_RADIUS := 7.0
const PIP_SEGMENTS := 20
const PIP_LIGHT := Color(0.70, 0.88, 1.0)
const PIP_GLOW := Color(0.4, 0.7, 1.0, 0.35)
const PIP_EMPTY := Color(1, 1, 1, 0.10)
const MANA_TROUGH_WIDTH := (
	(PIP_START_X - MANA_TROUGH_X) * 2.0 + (MatchState.MAX_MANA - 1) * PIP_STEP
)
const MANA_TROUGH_RECT := Rect2(MANA_TROUGH_X, MANA_TROUGH_Y, MANA_TROUGH_WIDTH, MANA_TROUGH_HEIGHT)
## コインはマナのバッジの肩に載せる小さな金貨。
const COIN_CENTER := Vector2(27.0, 15.0)
const COIN_RADIUS := 6.5
## 山札・墓地・手札の札。マナの溝の右に並べる。手札は相手側だけで、自分側はその位置を空ける。
const PILE_SIZE := Vector2(62, 32)
const PILE_TOP := 12.0
const PILE_PAD := 7.0
const PILE_LABEL_FONT := UiPalette.T_MICRO
const PILE_COUNT_FONT := UiPalette.T_BODY
const PILE_GAP := 4.0
const TROUGH_PILE_GAP := 12.0
const DECK_PILE_X := MANA_TROUGH_X + MANA_TROUGH_WIDTH + TROUGH_PILE_GAP
const GRAVE_PILE_X := DECK_PILE_X + PILE_SIZE.x + PILE_GAP
const HAND_PILE_X := GRAVE_PILE_X + PILE_SIZE.x + PILE_GAP
## 右の群は帯の右端から `RIGHT_GROUP_WIDTH` の位置を原点に置く(帯の幅が画面ごとに違っても右端に揃う)。
const RIGHT_GROUP_WIDTH := HAND_PILE_X + PILE_SIZE.x
## 左の群の右端(HPの器のバッジ)。
const LEFT_GROUP_WIDTH := HP_BAR_X + HP_BAR_SIZE.x + HP_BADGE_RADIUS
## 左の群の右端から右の群までに最低限空ける幅。帯の最小幅を決める。
const GROUP_MIN_GAP := 24.0
const MIN_WIDTH := LEFT_GROUP_WIDTH + GROUP_MIN_GAP + RIGHT_GROUP_WIDTH
## 縦画面の2段(`stacked`)。左の群と右の群を左端へ揃えて上下に積む。幅は広いほうの群に合わせる。
const STACK_GAP := 2.0
const STACKED_WIDTH := (
	LEFT_GROUP_WIDTH if LEFT_GROUP_WIDTH > RIGHT_GROUP_WIDTH else RIGHT_GROUP_WIDTH
)
const STACKED_HEIGHT := BAR_HEIGHT * 2.0 + STACK_GAP
const PILE_RADIUS := 9.0
const HP_BAR_RADIUS := HP_BAR_SIZE.y * 0.5
## 器具ごとの落ち影。板で囲わないぶん、1つずつが卓の上に置かれた物として影を持つ。
const SHADOW_BLUR := 8.0
const SHADOW_ALPHA := 0.5
## 文字の下へ1pxずらして敷く暗い影(GameDesign.md 9章「数字は必ず読める」)。
const TEXT_SHADOW := Color(0.05, 0.03, 0.02, 0.85)
## 被弾の演出(GameDesign.md 9章)。バーは補間して減らし、光らせ、増減を数字で浮かせる。
const HP_SLIDE_DURATION := 0.35
const FLASH_DURATION := 0.4
const FLOAT_DURATION := 0.9
const FLOAT_RISE := 16.0
## ダメージの大きさで数字を強める(GameDesign.md 9章)。ここに達したところで最大。
## 総量の大きい駒でも8前後で殴ってくるため、そのあたりを頭打ちにする。
const FLOAT_HEAVY_DAMAGE := 8.0
const FLOAT_FONT_SIZE := 22
const FLOAT_HEAVY_FONT_SIZE := 40
const FLOAT_HEAVY_RISE := 26.0
## 小さい数字はバーの右隣へ、大きい数字はバーの真上へ右揃えで出す。
const FLOAT_BASELINE := 18.0
const FLOAT_HEAVY_WIDTH := 120.0
const FLOAT_HEAVY_LIFT := 6.0
## 大ダメージほど赤から橙へ寄せる。赤のまま大きくするより、危険の度合いが読みやすい。
const FLOAT_HEAVY_COLOR := Color(1.0, 0.45, 0.15)
## 山札の脈打ち(GameDesign.md 9章)。ドローと疲労の発生源を山札そのもので示す。
const DECK_PULSE_DURATION := 0.45
## HPの砂に光る粒を散らす(GameDesign.md 9章「器に入った砂」の作り込み)。塗りの帯だけでは
## 平坦に見えるため、砂粒に光が当たっている点をいくつか置き、ゆっくり明滅させる。
## 位置はHPバーの幅に対する割合で固定し(=常に同じ粒が光る)、**残っている砂の範囲だけ**
## 描く(ratioで隠れた位置は描かない)ことで、減った砂の中にきらめきが浮かないようにする。
const SAND_GLINT_FRACTIONS := [0.10, 0.28, 0.47, 0.66, 0.85]
const SAND_GLINT_SPEED := 0.9
const SAND_GLINT_RADIUS := 1.6
## マナのピップの光と吸い込み(GameDesign.md 9章「対局画面の手触り」)。ホバー中の札の
## コストぶんを脈打たせ、支払った瞬間はそのぶんが札の方向へ吸われて消える。
## 脈打ちは `PlayerInfoBarFx` が持つ。
const PIP_GLOW_SPEED := 6.0
const PIP_GLOW_EXTRA := 3.0
const SPEND_DURATION := 0.25
const SPEND_PIP_COLOR := Color(1.0, 0.95, 0.72)
const DECK_PULSE_FILL_ALPHA := 0.18

## 相手側かどうか。相手側だけ手札の枚数を出す。
var is_opponent := false:
	set(value):
		is_opponent = value
		queue_redraw()
## 表示名(未設定なら「あなた」「相手」)。
var display_name := "":
	set(value):
		display_name = value
		queue_redraw()
## アイコンID(GameDesign.md 14章)。
var icon_id := UserProfileLibrary.DEFAULT_ICON_ID:
	set(value):
		icon_id = value
		queue_redraw()
## 称号ID(GameDesign.md 14章)。
var title_id := UserProfileLibrary.DEFAULT_TITLE_ID:
	set(value):
		title_id = value
		queue_redraw()
## 左の群(メダル・名札・HP)と右の群(マナ・山)を2段に積む(縦画面。Architecture.md 4.7節)。
var stacked := false:
	set(value):
		stacked = value
		_sync_vessel()
		_redraw_all()
## 2段のとき、右の群(マナの段)を上の段に置く。
var mana_row_first := false:
	set(value):
		mana_row_first = value
		_sync_vessel()
		_redraw_all()
## 攻撃の対象として選べる状態か。光らせて示す。
var targetable := false:
	set(value):
		if targetable == value:
			return
		targetable = value
		queue_redraw()
## 自分の駒をこの帯へドラッグして放したときに呼ぶ処理(GameDesign.md 9章)。空なら受けない。
var drop_handler := Callable()
## いまこの側の手番か。手番の側だけ明るくして、どちらが指す番かを示す
## (GameDesign.md 9章)。
var active := false:
	set(value):
		if active == value:
			return
		active = value
		queue_redraw()

var _hp := MatchState.INITIAL_HP
## HPの器の上限。ソロモード(遠征)の恩恵「丈夫な体」で`MatchState.INITIAL_HP`を超える
## (GameDesign.md 27章「恩恵」、Architecture.md 10.15節)。
var _max_hp := MatchState.INITIAL_HP
var _mana := 0
var _max_mana := 0
var _deck := 0
var _graveyard := 0
var _hand := 0
var _has_coin := false
var _font: Font
## HPの器のひび・鼓動・砕け(GameDesign.md 9章「決着の瞬間」)。
var _vessel: HpVesselFx
## 絶えず動く光(砂粒のきらめき・手番の輪・的の縁・ピップの脈打ち)。
var _fx: PlayerInfoBarFx
var _tracker := PressTracker.new()
## 被弾の演出。HPは瞬時に減らさず、この値から実際の値へ補間する。
var _shown_hp := float(MatchState.INITIAL_HP)
var _flash := 0.0
## 浮かせている増減の量と残り時間。
var _float_amount := 0
var _float_left := 0.0
var _hp_tween: Tween
## 一度でも状態を受け取ったか。初回の差し替えを被弾として見せないために持つ。
var _initialized := false
## 山札の脈打ちの強さと色。疲労だけ赤にして、ドローと区別する。
var _deck_pulse := 0.0
var _deck_pulse_color := UiPalette.SAND
var _deck_tween: Tween
## ホバー中の札のコスト。左からこの数だけピップを脈打たせる(0で消す)。
var _highlight_cost := 0
## 支払いで消えるピップの吸い込み(GameDesign.md 9章)。飛んでいる粒の出発位置(ピップの
## ローカル座標)と、行き先(出した札のローカル座標)、進捗を持つ。
var _spend_origins: Array[Vector2] = []
var _spend_to := Vector2.ZERO
var _spend_progress := 1.0
var _spend_tween: Tween
var _spend_shapes: Array[PaintedShape] = []
## 本体とは別に描き直す層。本体は影・板・真鍮の輪を重ねた重い絵で、描き直すたびに
## Web版ではGLの番号を数百個使い捨てる(Pitfalls.md)。被弾・支払い・山札の動きはこちらで出す。
var _hp_layer: PaintedShape
var _float_layer: PaintedShape
var _deck_pulse_shape: PaintedShape


func _ready() -> void:
	_font = get_theme_default_font()
	if _font == null:
		_font = ThemeDB.fallback_font
	custom_minimum_size = Vector2(0, BAR_HEIGHT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	_hp_layer = PaintedShape.new(_paint_hp)
	add_child(_hp_layer)
	_deck_pulse_shape = PaintedShape.new(_paint_deck_pulse)
	_deck_pulse_shape.modulate.a = 0.0
	add_child(_deck_pulse_shape)
	_float_layer = PaintedShape.new(_paint_float)
	add_child(_float_layer)
	_fx = PlayerInfoBarFx.new(self)
	add_child(_fx)
	_vessel = HpVesselFx.new()
	_vessel.badge_radius = HP_BADGE_RADIUS
	_sync_vessel()
	add_child(_vessel)


func _sync_vessel() -> void:
	if _vessel == null:
		return
	_vessel.vessel_rect = hp_bar_rect()
	_vessel.badge_center = Vector2(hp_bar_rect().end.x, hp_bar_rect().get_center().y)
	_vessel.queue_redraw()


## 対局の状態から自分の側の値をまとめて取り込む。`max_hp`はソロモードの遠征だけ
## `MatchState.INITIAL_HP`と異なる(GameDesign.md 27章「恩恵」)。
func show_state(state: MatchState, side: int, max_hp: int = MatchState.INITIAL_HP) -> void:
	var before := _shown_values()
	var previous := _hp
	_hp = state.hp[side]
	_max_hp = max_hp
	if _vessel != null:
		_vessel.hp = _hp
	# **最初の1回は演出しない。**教材の盤面(ルール画面・画面の見かた)は初期値30から
	# 教材用のHPへ差し替えるため、そのままだと開いた瞬間に「-6」が浮いてしまう。
	if not _initialized:
		_initialized = true
		_shown_hp = float(_hp)
	elif previous != _hp:
		_animate_hp(previous)
	_mana = state.mana[side]
	_max_mana = state.max_mana[side]
	_deck = state.deck[side].size()
	_graveyard = state.graveyard[side].size()
	_hand = state.hand[side].size()
	_has_coin = state.coin_available.get(side, false)
	# 対局画面は1手ごとに両方の帯へ値を配り直す。変わっていない帯まで描き直さない。
	if _shown_values() != before:
		_redraw_all()


func _shown_values() -> Array:
	return [_hp, _max_hp, _shown_hp, _mana, _max_mana, _deck, _graveyard, _hand, _has_coin]


func _redraw_all() -> void:
	queue_redraw()
	if _hp_layer != null:
		_hp_layer.repaint()
		_float_layer.repaint()


## 前の対局の値を消して、まだ何も対局を見ていない状態へ戻す。次の `show_state()`
## までのあいだ(オンライン対戦の山札・種の交換を待っている間など)、前の対局の
## HP・マナ・山札の枚数が居座って見えることを防ぐ。
func reset() -> void:
	if _hp_tween != null and _hp_tween.is_valid():
		_hp_tween.kill()
	if _deck_tween != null and _deck_tween.is_valid():
		_deck_tween.kill()
	if _spend_tween != null and _spend_tween.is_valid():
		_spend_tween.kill()
	_hp = MatchState.INITIAL_HP
	_max_hp = MatchState.INITIAL_HP
	_shown_hp = float(_hp)
	_mana = 0
	_max_mana = 0
	_deck = 0
	_graveyard = 0
	_hand = 0
	_has_coin = false
	_initialized = false
	if _vessel != null:
		_vessel.reset()
	_flash = 0.0
	_float_left = 0.0
	_deck_pulse = 0.0
	_highlight_cost = 0
	_spend_origins.clear()
	_spend_progress = 1.0
	active = false
	targetable = false
	if _deck_pulse_shape != null:
		_deck_pulse_shape.modulate.a = 0.0
		_place_spend_flight()
	_redraw_all()


## エモートの吹き出しを名札付近へ出す(GameDesign.md 9章)。
func show_emote(text: String) -> void:
	for child in get_children():
		if child is EmoteBubble:
			child.queue_free()
	var bubble := EmoteBubble.new()
	bubble.text = text
	bubble.is_opponent = is_opponent
	# 相手側(画面上部)なら下へ、自分側(画面下部)なら上へ出す
	bubble.position = Vector2(10.0, size.y - 8.0 if is_opponent else -36.0)
	add_child(bubble)


## 手札の札にカーソルを乗せている間、支払うぶんのマナのピップを脈打たせる
## (GameDesign.md 9章「対局画面の手触り」)。**左から n 個**。n が現在のマナを超えるなら
## 払えないため光らせない。`highlight_cost(0)` で消す。
func highlight_cost(n: int) -> void:
	if _highlight_cost == n:
		return
	_highlight_cost = n
	queue_redraw()


## 支払いで消える n 個のピップを、`target_global`(出した札/撃った砂術の手札位置)へ
## 吸い込ませて消す(GameDesign.md 9章)。**呼ばれた時点でまだ `show_state()` を挟んで
## いない場合**(`unit_played`/`spell_cast` は支払いの直後・盤面の再同期より前に発火する)、
## `_mana` は支払う前の値のままなので、そこから左へ n 個を数えられる。
func spend_toward(n: int, target_global: Vector2) -> void:
	var count := mini(n, _mana)
	if count <= 0:
		return
	_spend_origins.clear()
	for i in count:
		_spend_origins.append(_right(Vector2(PIP_START_X + i * PIP_STEP, CENTER_Y)))
	_spend_to = get_global_transform().affine_inverse() * target_global
	if _spend_tween != null and _spend_tween.is_valid():
		_spend_tween.kill()
	_spend_progress = 0.0
	_spend_tween = create_tween()
	_spend_tween.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
	_spend_tween.tween_method(_set_spend_progress, 0.0, 1.0, SPEND_DURATION)
	_spend_tween.finished.connect(_on_spend_finished)


func _set_spend_progress(value: float) -> void:
	_spend_progress = value
	_place_spend_flight()


func _on_spend_finished() -> void:
	_spend_progress = 1.0
	_spend_origins.clear()
	_place_spend_flight()


## マナの数字の位置(グローバル)。支払いの吸い込みの行き先を控えられなかったとき
## (CPU・相手の手など、手札の札が画面に無い場合)の既定の行き先にする(GameDesign.md 9章)。
func mana_label_global() -> Vector2:
	return get_global_transform() * _right(MANA_BADGE_CENTER)


## 相手のHP帯へ駒を落として本体を殴る。押して選ぶ経路と同じ判定を `drop_handler` が持つ。
func _can_drop_data(_at_position: Vector2, data: Variant) -> bool:
	if not targetable or not drop_handler.is_valid() or not data is Dictionary:
		return false
	return (data as Dictionary).get("card_view") is CardView


func _drop_data(_at_position: Vector2, data: Variant) -> void:
	drop_handler.call((data as Dictionary)["card_view"])


func _gui_input(event: InputEvent) -> void:
	if _tracker.feed(event, size) != PressTracker.Result.CONFIRMED:
		return
	var position: Vector2 = (event as InputEventMouseButton).position
	if _graveyard_rect().has_point(position):
		graveyard_pressed.emit()
	elif targetable:
		face_pressed.emit()


func _draw() -> void:
	var ci := get_canvas_item()
	_draw_name_plate()
	_draw_portrait(ci)
	_draw_hp()
	_draw_mana()
	_pile(deck_pile_rect(), "山札", _deck)
	_pile(_graveyard_rect(), "墓地", _graveyard)
	if is_opponent:
		_pile(hand_pile_rect(), "手札", _hand)
	if _has_coin:
		_draw_coin()
	_sync_fx()


## 動く光の層へ、いま描いた帯の状態を渡す。
func _sync_fx() -> void:
	if _fx == null:
		return
	var glow_centers: Array[Vector2] = []
	# 払えない(n > 現在マナ)ぶんは光らせない(GameDesign.md 9章)。
	if _highlight_cost <= _mana:
		for i in mini(_highlight_cost, _max_mana):
			glow_centers.append(_right(Vector2(PIP_START_X + i * PIP_STEP, CENTER_Y)))
	var ratio := clampf(_shown_hp / float(maxi(_max_hp, 1)), 0.0, 1.0)
	_fx.sync(active, targetable, hp_bar_rect(), ratio, glow_centers)


## 右の群の原点(帯のローカルx)。2段のときは左端へ揃える。
func _right_x() -> float:
	return 0.0 if stacked else size.x - RIGHT_GROUP_WIDTH


## 2段のときの各群の段の上端(帯のローカルy)。
func _right_y() -> float:
	return BAR_HEIGHT + STACK_GAP if stacked and not mana_row_first else 0.0


func _left_y() -> float:
	return BAR_HEIGHT + STACK_GAP if stacked and mana_row_first else 0.0


func _right(offset: Vector2) -> Vector2:
	return Vector2(_right_x() + offset.x, _right_y() + offset.y)


func _left(offset: Vector2) -> Vector2:
	return offset + Vector2(0.0, _left_y())


## 肖像のメダルの中心。手番の輪(`PlayerInfoBarFx`)が引く。
func portrait_center() -> Vector2:
	return _left(PORTRAIT_CENTER)


func _draw_closed(item: CanvasItem, points: PackedVector2Array, color: Color, width: float) -> void:
	var closed := points.duplicate()
	closed.append(points[0])
	ShapePaint.polyline(item.get_canvas_item(), closed, color, width, true)


## 器具1つぶんの落ち影。
func _shadow(ci: RID, rect: Rect2, radius: float) -> void:
	UiKit.shadow(ci, rect, radius, SHADOW_BLUR, SHADOW_ALPHA)


func _shadow_circle(ci: RID, center: Vector2, radius: float) -> void:
	var box := Rect2(center - Vector2.ONE * radius, Vector2.ONE * radius * 2.0)
	UiKit.shadow(ci, box, radius, SHADOW_BLUR, SHADOW_ALPHA)


## 真鍮の輪(上が照り、下が影)。肖像のメダルが使う。
func _brass_ring(ci: RID, center: Vector2, radius: float, width: float) -> void:
	var mid := radius - width * 0.5
	UiKit.stroke(
		ci, UiKit.ellipse(center, Vector2(mid, mid)), UiPalette.BRASS_INK, width + UiKit.LINE_MIN
	)
	UiKit.stroke_grad(
		ci,
		UiKit.ellipse(center, Vector2(mid, mid)),
		[[0.0, UiPalette.GOLD_HI], [0.5, UiPalette.BRASS], [1.0, UiPalette.BRASS_DEEP]],
		width
	)


## 肖像のメダル。真鍮の輪でアイコンを囲む。
## 手番の側はこの輪の外へ琥珀の光の輪を足す(GameDesign.md 9章)。
func _draw_portrait(ci: RID) -> void:
	var center := portrait_center()
	_shadow_circle(ci, center, PORTRAIT_RADIUS)
	var inner_radius := PORTRAIT_RADIUS - PORTRAIT_RING_WIDTH
	UiKit.vgrad(
		ci,
		UiKit.ellipse(center, Vector2(inner_radius, inner_radius)),
		[[0.0, UiPalette.INK_600], [1.0, UiPalette.INK_900]]
	)
	var icon_tex := UserProfileLibrary.get_icon_texture(icon_id)
	if icon_tex != null:
		var r := inner_radius - 2.0
		draw_texture_rect(icon_tex, Rect2(center - Vector2.ONE * r, Vector2.ONE * r * 2.0), false)
	_brass_ring(ci, center, PORTRAIT_RADIUS, PORTRAIT_RING_WIDTH)


## 名札。板を持たず、メダルの右へ称号(小)と表示名(大)を字だけで置く
## (GameDesign.md 9章・14章)。
func _draw_name_plate() -> void:
	var label := display_name
	if label.is_empty():
		label = "相手" if is_opponent else "あなた"
	var title_text := UserProfileLibrary.get_title_display(title_id)
	var mid := _left(Vector2(NAME_TEXT_X, CENTER_Y))
	if title_text.is_empty():
		_text_mid(self, mid, label, NAME_FONT, UiPalette.IVORY, true)
		return
	_text_mid(
		self, mid + Vector2(0, -NAME_LINE_OFFSET), title_text, TITLE_FONT, UiPalette.GOLD, true
	)
	_text_mid(self, mid + Vector2(0, TITLE_LINE_OFFSET), label, NAME_FONT, UiPalette.IVORY, true)


## 山札の山。ドロー・疲労の演出の出どころとして画面側からも引く。
func deck_pile_rect() -> Rect2:
	return Rect2(_right(Vector2(DECK_PILE_X, PILE_TOP)), PILE_SIZE)


## 相手側だけに出る手札の山。ドローの行き先として使う。
func hand_pile_rect() -> Rect2:
	return Rect2(_right(Vector2(HAND_PILE_X, PILE_TOP)), PILE_SIZE)


## 決着でHPが0になった。器にひびが走って砕ける(GameDesign.md 9章)。
func play_shatter() -> void:
	if _vessel != null:
		_vessel.play_shatter()


## 山札を脈打たせる。`danger` は疲労(GameDesign.md 9章)。
func play_deck_pulse(danger: bool) -> void:
	_deck_pulse_color = UiPalette.HEALTH if danger else UiPalette.SAND
	_deck_pulse_shape.repaint()
	if _deck_tween != null and _deck_tween.is_valid():
		_deck_tween.kill()
	_deck_tween = create_tween()
	_deck_tween.tween_method(_set_deck_pulse, 1.0, 0.0, DECK_PULSE_DURATION)


func _set_deck_pulse(value: float) -> void:
	_deck_pulse = value
	_deck_pulse_shape.modulate.a = value


func _graveyard_rect() -> Rect2:
	return Rect2(_right(Vector2(GRAVE_PILE_X, PILE_TOP)), PILE_SIZE)


## HPバーは彫り込まれた溝に見せる(角丸 + 内側の落ち込み影)。残量の色は
## 十分なうちは琥珀、危険域まで減ったら赤(GameDesign.md 9章)。
## HPバーの矩形。攻撃の演出が本体を狙うときの的であり、被弾の演出の出どころでもある。
## マナの数字のバッジと粒の列を合わせた矩形(ローカル)。誘導対局で「使ったマナ」を光らせる。
func mana_rect() -> Rect2:
	var badge := Rect2(
		_right(MANA_BADGE_CENTER) - Vector2.ONE * MANA_BADGE_RADIUS,
		Vector2.ONE * MANA_BADGE_RADIUS * 2.0
	)
	return badge.merge(Rect2(_right(MANA_TROUGH_RECT.position), MANA_TROUGH_RECT.size))


func hp_bar_rect() -> Rect2:
	return Rect2(_left(Vector2(HP_BAR_X, CENTER_Y - HP_BAR_SIZE.y * 0.5)), HP_BAR_SIZE)


func _draw_hp() -> void:
	var ci := get_canvas_item()
	var rect := hp_bar_rect()
	var radius := rect.size.y * 0.5
	_shadow(ci, rect, radius)
	# 真鍮の管(暗い外縁 + 金の縁)。中は彫り込みの溝で、砂は別の層が描く。
	var rim := rect.grow(HP_RIM_WIDTH * 0.5)
	UiKit.fill(ci, UiKit.rr(rect.grow(HP_RIM_WIDTH), radius + HP_RIM_WIDTH), UiPalette.BRASS_INK)
	UiKit.vgrad(
		ci,
		UiKit.rr(rim, radius + HP_RIM_WIDTH * 0.5),
		[[0.0, UiPalette.GOLD], [1.0, UiPalette.BRASS_DEEP]],
		true
	)
	UiKit.fill(ci, UiKit.rr(rect, radius), UiPalette.INK_900)
	UiKit.well(ci, rect, radius)


## 器の中身から上(砂・ガラス・宝石)。被弾の補間で毎フレーム変わるため、
## 本体とは別の層(`_hp_layer`)へ描き、本体の重い絵を巻き込まない。
func _paint_hp(item: PaintedShape) -> void:
	var ci := item.get_canvas_item()
	var rect := hp_bar_rect()
	var radius := rect.size.y * 0.5
	var ratio := clampf(_shown_hp / float(maxi(_max_hp, 1)), 0.0, 1.0)
	var inner := rect.grow(-UiKit.SAND_INSET)
	if ratio > 0.0:
		# 角丸の半径より細い残量は角が潰れて塗れないため、幅の下限を高さにする(docs/Pitfalls.md)。
		var fill_rect := Rect2(
			inner.position, Vector2(maxf(inner.size.x * ratio, inner.size.y), inner.size.y)
		)
		var light := UiPalette.SAND_HI if ratio > DANGER_RATIO else HP_DANGER_LIGHT
		var deep := UiPalette.SAND_DEEP if ratio > DANGER_RATIO else UiPalette.HEALTH_DEEP
		UiKit.vgrad(
			ci,
			UiKit.rr(fill_rect, fill_rect.size.y * 0.5),
			[[0.0, light], [UiKit.SAND_FOLD, light.lerp(deep, UiKit.SAND_FOLD)], [1.0, deep]],
			true
		)
	# ガラス越しに見せる。上側へ白い反射の帯を薄く敷く。
	var sheen := Rect2(
		rect.position + HP_SHEEN_INSET,
		Vector2(rect.size.x - HP_SHEEN_INSET.x * 2.0, rect.size.y * HP_SHEEN_RATIO)
	)
	UiKit.fill(ci, UiKit.rr(sheen, sheen.size.y * 0.5), HP_SHEEN)
	if _flash > 0.0:
		UiKit.fill(ci, UiKit.rr(rect, radius), Color(1, 0.95, 0.8, 0.4 * _flash))
	# 上限は器の中に小さく、現在値は右端の赤い宝石に(場の駒の体力と同じ語彙)。
	var cap_text := "/ %d" % _max_hp
	var cap_width := _font.get_string_size(cap_text, HORIZONTAL_ALIGNMENT_LEFT, -1, HP_CAP_FONT).x
	_text_mid(
		item,
		Vector2(rect.end.x - HP_BADGE_RADIUS - HP_CAP_GAP - cap_width, rect.get_center().y),
		cap_text,
		HP_CAP_FONT,
		UiPalette.MUTED,
		true
	)
	_badge(
		item,
		Vector2(rect.end.x, rect.get_center().y),
		_hp,
		UiPalette.HEALTH,
		UiPalette.HEALTH_DEEP,
		HP_BADGE_RADIUS
	)


## 数値の宝石。場の駒の体力・攻撃力・手札のコストと同じ語彙(真鍮で嵌めた色の石 + 白い数字)。
func _badge(
	item: CanvasItem, center: Vector2, value: int, light: Color, deep: Color, radius: float
) -> void:
	var ci := item.get_canvas_item()
	UiKit.gem(ci, center, radius, light, deep)
	UiKit.gem_text(ci, _font, center, radius, str(value))


## マナは青い宝石に現在値、右の溝に最大値ぶんの粒(GameDesign.md 9章「数字とピップの併記」)。
func _draw_mana() -> void:
	var ci := get_canvas_item()
	var trough_rect := Rect2(_right(MANA_TROUGH_RECT.position), MANA_TROUGH_RECT.size)
	UiKit.well(ci, trough_rect, trough_rect.size.y * 0.5)
	for i in _max_mana:
		var center := _right(Vector2(PIP_START_X + i * PIP_STEP, CENTER_Y))
		var pip := UiKit.ellipse(center, Vector2(PIP_RADIUS, PIP_RADIUS), PIP_SEGMENTS)
		if i < _mana:
			UiKit.glow(ci, center, Vector2.ONE * PIP_RADIUS * 2.0, PIP_GLOW)
			UiKit.vgrad(ci, pip, [[0.0, PIP_LIGHT], [1.0, UiPalette.COST]], true)
		else:
			UiKit.fill(ci, pip, PIP_EMPTY)
	_badge(
		self,
		_right(MANA_BADGE_CENTER),
		_mana,
		UiPalette.COST,
		UiPalette.COST_DEEP,
		MANA_BADGE_RADIUS
	)


## 支払いで消えるピップが、出した札(または撃った砂術)の方向へ吸われて消える
## (GameDesign.md 9章)。
func _place_spend_flight() -> void:
	var flying := not _spend_origins.is_empty() and _spend_progress < 1.0
	var fade := 1.0 - _spend_progress
	while _spend_shapes.size() < _spend_origins.size():
		var shape := PaintedShape.new(_paint_spend_pip)
		add_child(shape)
		move_child(shape, _fx.get_index())
		_spend_shapes.append(shape)
	for i in _spend_shapes.size():
		var shape := _spend_shapes[i]
		shape.visible = flying and i < _spend_origins.size()
		if not shape.visible:
			continue
		var grow := 0.55 + 0.45 * fade
		shape.position = _spend_origins[i].lerp(_spend_to, _spend_progress)
		shape.scale = Vector2(grow, grow)
		shape.modulate.a = fade


func _paint_spend_pip(shape: PaintedShape) -> void:
	UiPaint.fill_circle(shape.get_canvas_item(), Vector2.ZERO, PIP_RADIUS, SPEND_PIP_COLOR, 12)


## 山札の脈打ちの光(縁 + 薄い面)。形は山札の札に合わせて1度だけ描き、強さは不透明度で出す。
func _paint_deck_pulse(shape: PaintedShape) -> void:
	var rect := deck_pile_rect()
	var points := UiKit.rr(rect, PILE_RADIUS)
	UiKit.fill(shape.get_canvas_item(), points, Color(_deck_pulse_color, DECK_PULSE_FILL_ALPHA))
	_draw_closed(shape, points, Color(_deck_pulse_color, 1.0), 3.0)


## コインを持っている間だけ、マナの宝石の肩に金貨を載せる。
func _draw_coin() -> void:
	var ci := get_canvas_item()
	var coin := _right(COIN_CENTER)
	UiKit.fill(
		ci,
		UiKit.ellipse(coin, Vector2.ONE * (COIN_RADIUS + UiKit.BADGE_RING), PIP_SEGMENTS),
		UiPalette.BRASS_INK
	)
	UiKit.vgrad(
		ci,
		UiKit.ellipse(coin, Vector2.ONE * COIN_RADIUS, PIP_SEGMENTS),
		[[0.0, UiPalette.GOLD_HI], [1.0, UiPalette.SAND_DEEP]],
		true
	)


## 山札・墓地・手札の枚数。彫り込みの小さな札に「見出し 数字」を横1行で置く。
func _pile(rect: Rect2, label: String, count: int) -> void:
	UiKit.well(get_canvas_item(), rect, PILE_RADIUS)
	var mid := rect.get_center().y
	_text_mid(
		self, Vector2(rect.position.x + PILE_PAD, mid), label, PILE_LABEL_FONT, UiPalette.MUTED
	)
	var text := str(count)
	var width := _font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, PILE_COUNT_FONT).x
	_text_mid(
		self, Vector2(rect.end.x - PILE_PAD - width, mid), text, PILE_COUNT_FONT, UiPalette.IVORY
	)


func _text(
	item: CanvasItem, pos: Vector2, value: String, font_size: int, color: Color = UiPalette.IVORY
) -> void:
	item.draw_string(_font, pos, value, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, color)


## 行の上下の中央が `at.y` に来るように置く。`shadowed` は地の上へ直に置く字(暗い影を敷く)。
func _text_mid(
	item: CanvasItem, at: Vector2, value: String, font_size: int, color: Color, shadowed := false
) -> void:
	var base := Vector2(
		at.x, at.y + (_font.get_ascent(font_size) - _font.get_descent(font_size)) * 0.5
	)
	if shadowed:
		_text(item, base + Vector2.ONE, value, font_size, TEXT_SHADOW)
	_text(item, base, value, font_size, color)


func _animate_hp(previous: int) -> void:
	_float_amount = _hp - previous
	_float_left = FLOAT_DURATION
	_flash = 1.0
	if _hp_tween != null and _hp_tween.is_valid():
		_hp_tween.kill()
	_hp_tween = create_tween()
	_hp_tween.tween_method(_set_shown_hp, _shown_hp, float(_hp), HP_SLIDE_DURATION)
	_hp_tween.parallel().tween_method(_set_flash, 1.0, 0.0, FLASH_DURATION)
	_hp_tween.parallel().tween_method(_set_float_left, FLOAT_DURATION, 0.0, FLOAT_DURATION)


func _set_shown_hp(value: float) -> void:
	_shown_hp = value
	_hp_layer.repaint()
	# 砂粒のきらめきは残っている砂の範囲だけに置くため、割合を渡し直す。
	_sync_fx()


func _set_flash(value: float) -> void:
	_flash = value
	_hp_layer.repaint()


func _set_float_left(value: float) -> void:
	_float_left = value
	_float_layer.repaint()


## 増減のフローティング数字。減ったら赤、回復したら琥珀。
##
## **ダメージは大きさと色でも示す**(GameDesign.md 9章)。1と7が同じ見た目だと、
## 盤面へ目を戻す前に「どれだけ削られたのか」が分からない。**回復は大きさを変えない**
## ——受け身の出来事であり、強調する理由がないため。
func _paint_float(item: PaintedShape) -> void:
	if _float_left <= 0.0:
		return
	var rect := hp_bar_rect()
	var ratio := _float_left / FLOAT_DURATION
	var color := UiPalette.SAND if _float_amount > 0 else CardView.HEALTH_RED
	var text := "+%d" % _float_amount if _float_amount > 0 else str(_float_amount)
	var weight := 0.0
	if _float_amount < 0:
		weight = clampf(float(-_float_amount) / FLOAT_HEAVY_DAMAGE, 0.0, 1.0)
		color = color.lerp(FLOAT_HEAVY_COLOR, weight)
	var size := int(round(lerpf(FLOAT_FONT_SIZE, FLOAT_HEAVY_FONT_SIZE, weight)))
	var rise := (1.0 - ratio) * lerpf(FLOAT_RISE, FLOAT_HEAVY_RISE, weight)
	# **大きい数字はバーの真上へ逃がす。**バーの右隣にはマナの数字とピップが並んでおり、
	# 文字を大きくしたぶんだけそこへ食い込む(実際に描画して重なりを確認した)。
	var at := Vector2(rect.end.x + HP_BADGE_RADIUS + 8.0, rect.position.y + FLOAT_BASELINE - rise)
	var align := HORIZONTAL_ALIGNMENT_LEFT
	var width := -1.0
	if weight > 0.0:
		at = Vector2(rect.end.x - FLOAT_HEAVY_WIDTH, rect.position.y - FLOAT_HEAVY_LIFT - rise)
		align = HORIZONTAL_ALIGNMENT_RIGHT
		width = FLOAT_HEAVY_WIDTH
	item.draw_string(_font, at, text, align, width, size, Color(color, minf(ratio * 2.0, 1.0)))
