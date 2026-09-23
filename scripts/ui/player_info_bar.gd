class_name PlayerInfoBar
extends Control
## 片方のプレイヤーの情報帯(GameDesign.md 9章「対局画面」)。
## HP・マナ・山札の残り・墓地の枚数を並べ、相手側は手札の枚数も出す(中身は伏せる)。

signal face_pressed
signal graveyard_pressed

const BAR_HEIGHT := 56.0
const MANA_BLUE := Color(0.35, 0.6, 0.95, 1.0)
const MANA_EMPTY := Color(0.2, 0.22, 0.28, 1.0)
const DANGER_RATIO := 0.4
## 帯は1枚の板で囲わず、卓の台座・ターン終了ボタンと同じ語彙の「真鍮の器具」を
## 横に並べる(GameDesign.md 9章「対局画面の見た目」)。**左の群(肖像のメダル / 名札 / HPの器)と
## 右の群(マナの計器 / 山札・墓地・手札の札)に分け、中央は空ける**(卓の真上の吊りランプを見せる)。
## 上下の帯で同じ位置に同じものを置く。座標はすべて帯のローカル(高さ BAR_HEIGHT)。
const CENTER_Y := BAR_HEIGHT * 0.5
## 肖像のメダル。真鍮の太い輪の中にアイコンを嵌める。
const PORTRAIT_CENTER := Vector2(30.0, CENTER_Y)
const PORTRAIT_RADIUS := 26.0
const PORTRAIT_RING_WIDTH := 4.0
## 名札。メダルの右から伸びる濃紺の板。
const NAME_PLATE_RECT := Rect2(44.0, 9.0, 152.0, 38.0)
const NAME_TEXT_X := 64.0
## HPの器。真鍮の縁 + ガラス越しの砂。右端に体力の丸いバッジ(場の駒と同じ語彙)を嵌める。
const HP_BAR_X := 206.0
const HP_BAR_SIZE := Vector2(180, 32)
const HP_RIM_WIDTH := 3.0
const HP_BADGE_RADIUS := 17.0
## 右の群は帯の右端から `RIGHT_GROUP_WIDTH` の位置を原点に置く(帯の幅が画面ごとに違っても右端に揃う)。
const RIGHT_GROUP_WIDTH := 413.0
## マナの計器。コストと同じ青の丸いバッジに現在値、右の溝へ最大値ぶんの粒。
const MANA_BADGE_CENTER := Vector2(15.0, CENTER_Y)
const MANA_BADGE_RADIUS := 15.0
const MANA_TROUGH_RECT := Rect2(39.0, 17.0, 168.0, 22.0)
const PIP_START_X := 51.0
const PIP_STEP := 16.0
const PIP_RADIUS := 6.5
## コインはマナのバッジの肩に載せる小さな金貨。
const COIN_CENTER := Vector2(27.0, 15.0)
const COIN_RADIUS := 6.5
## 山札・墓地・手札の札。帯の右端へ詰める。手札は相手側だけで、自分側はその位置を空ける。
const PILE_SIZE := Vector2(62, 40)
const PILE_TOP := 8.0
const DECK_PILE_X := 219.0
const GRAVE_PILE_X := 285.0
const HAND_PILE_X := 351.0
## 左の群の右端(HPの器のバッジ)から右の群までに最低限空ける幅。帯の最小幅を決める。
const GROUP_MIN_GAP := 24.0
const MIN_WIDTH := HP_BAR_X + HP_BAR_SIZE.x + HP_BADGE_RADIUS + GROUP_MIN_GAP + RIGHT_GROUP_WIDTH
const PILE_RADIUS := 6.0
const PILE_GRAIN_ALPHA := 0.06
const HP_BAR_RADIUS := 8.0
## 器具ごとの落ち影。板で囲わないぶん、1つずつが卓の上に置かれた物として影を持つ。
const SHADOW_OFFSET := Vector2(0.0, 3.0)
const SHADOW_LAYERS := 3
const SHADOW_ALPHA := 0.32
## 細い真鍮の縁(名札・山の札)。
const RIM_WIDTH := 2.0
## 文字の下へ1pxずらして敷く暗い影(GameDesign.md 9章「数字は必ず読める」)。
const TEXT_SHADOW := Color(0.05, 0.03, 0.02, 0.85)
## マナのピップ(_draw_mana)の質感。小さい円のため、面取りではなく
## 「縁を暗く・内側に小さなハイライト」の2色使いで浮き彫りに見せる。
const PIP_RIM_DARKEN := 0.25
const PIP_CORE_RATIO := 0.88
const PIP_HIGHLIGHT_RATIO := 0.32
const PIP_HIGHLIGHT_OFFSET := 0.34
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
## 脈は `_glint_time`(砂粒のきらめきと同じ経過時間)へ乗せ、専用のタイマーを増やさない。
const PIP_GLOW_SPEED := 6.0
const PIP_GLOW_EXTRA := 3.0
const SPEND_DURATION := 0.25

## 相手側かどうか。相手側だけ手札の枚数を出す。
var is_opponent := false
## 表示名(未設定なら「あなた」「相手」)。
var display_name := ""
## アイコンID(GameDesign.md 14章)。
var icon_id := UserProfileLibrary.DEFAULT_ICON_ID
## 称号ID(GameDesign.md 14章)。
var title_id := UserProfileLibrary.DEFAULT_TITLE_ID
## 攻撃の対象として選べる状態か。光らせて示す。
var targetable := false
## 自分の駒をこの帯へドラッグして放したときに呼ぶ処理(GameDesign.md 9章)。空なら受けない。
var drop_handler := Callable()
## いまこの側の手番か。手番の側だけ明るくして、どちらが指す番かを示す
## (GameDesign.md 9章)。
var active := false

var _hp := MatchState.INITIAL_HP
var _mana := 0
var _max_mana := 0
var _deck := 0
var _graveyard := 0
var _hand := 0
var _has_coin := false
var _font: Font
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
var _deck_pulse_color := UiPalette.GLOW_AMBER
var _deck_tween: Tween
## HPの砂粒のきらめきを進める経過時間。
var _glint_time := 0.0
## ホバー中の札のコスト。左からこの数だけピップを脈打たせる(0で消す)。
var _highlight_cost := 0
## 支払いで消えるピップの吸い込み(GameDesign.md 9章)。飛んでいる粒の出発位置(ピップの
## ローカル座標)と、行き先(出した札のローカル座標)、進捗を持つ。
var _spend_origins: Array[Vector2] = []
var _spend_to := Vector2.ZERO
var _spend_progress := 1.0
var _spend_tween: Tween


func _ready() -> void:
	_font = get_theme_default_font()
	if _font == null:
		_font = ThemeDB.fallback_font
	custom_minimum_size = Vector2(0, BAR_HEIGHT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	set_process(true)


## HPの砂粒のきらめきだけを進める(GameDesign.md 9章)。他の変化は従来どおり
## `queue_redraw()` を都度呼ぶ側が持つため、ここでは経過時間を進めるだけでよい。
func _process(delta: float) -> void:
	_glint_time += delta
	queue_redraw()


## 対局の状態から自分の側の値をまとめて取り込む。
func show_state(state: MatchState, side: int) -> void:
	var previous := _hp
	_hp = state.hp[side]
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
	queue_redraw()


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
	_shown_hp = float(_hp)
	_mana = 0
	_max_mana = 0
	_deck = 0
	_graveyard = 0
	_hand = 0
	_has_coin = false
	_initialized = false
	_flash = 0.0
	_float_left = 0.0
	_deck_pulse = 0.0
	_highlight_cost = 0
	_spend_origins.clear()
	_spend_progress = 1.0
	active = false
	targetable = false
	queue_redraw()


## エモートの吹き出しを名札付近へ出す(GameDesign.md 9章)。
func show_emote(text: String) -> void:
	for child in get_children():
		if child is EmoteBubble:
			child.queue_free()
	var bubble := EmoteBubble.new()
	bubble.text = text
	bubble.is_opponent = is_opponent
	# 相手側(画面上部)なら下へ、自分側(画面下部)なら上へ出す
	bubble.position = Vector2(10.0, 48.0 if is_opponent else -36.0)
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
		_spend_origins.append(Vector2(_right_x() + PIP_START_X + i * PIP_STEP, CENTER_Y))
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
	queue_redraw()


func _on_spend_finished() -> void:
	_spend_progress = 1.0
	_spend_origins.clear()
	queue_redraw()


## マナの数字の位置(グローバル)。支払いの吸い込みの行き先を控えられなかったとき
## (CPU・相手の手など、手札の札が画面に無い場合)の既定の行き先にする(GameDesign.md 9章)。
func mana_label_global() -> Vector2:
	return global_position + _right(MANA_BADGE_CENTER)


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
	_draw_spend_flight()
	_pile(deck_pile_rect(), "山札", _deck)
	_pile(_graveyard_rect(), "墓地", _graveyard)
	if is_opponent:
		_pile(hand_pile_rect(), "手札", _hand)
	if _has_coin:
		_draw_coin()


## 右の群の原点(帯のローカルx)。
func _right_x() -> float:
	return size.x - RIGHT_GROUP_WIDTH


func _right(offset: Vector2) -> Vector2:
	return Vector2(_right_x() + offset.x, offset.y)


func _draw_closed(points: PackedVector2Array, color: Color, width: float) -> void:
	var closed := points.duplicate()
	closed.append(points[0])
	draw_polyline(closed, color, width, true)


## 器具1つぶんの落ち影。大きく薄い層から小さく濃い層へ重ねる(`MatchBackdrop` と同じ形)。
func _shadow(ci: RID, rect: Rect2, radius: float) -> void:
	for i in SHADOW_LAYERS:
		var grow := float(SHADOW_LAYERS - i) * 1.5
		var alpha := SHADOW_ALPHA * float(i + 1) / float(SHADOW_LAYERS)
		var layer := Rect2(rect.position + SHADOW_OFFSET, rect.size).grow(grow)
		var points := UiPaint.rounded_rect_points_uniform(layer, radius + grow, 6)
		var color := Color(0, 0, 0, alpha)
		UiPaint.fill_gradient_polygon(ci, points, layer, [[0.0, color], [1.0, color]])


func _shadow_circle(ci: RID, center: Vector2, radius: float) -> void:
	for i in SHADOW_LAYERS:
		var grow := float(SHADOW_LAYERS - i) * 1.5
		var alpha := SHADOW_ALPHA * float(i + 1) / float(SHADOW_LAYERS)
		UiPaint.fill_circle(ci, center + SHADOW_OFFSET, radius + grow, Color(0, 0, 0, alpha), 28)


## 真鍮の輪(明→暗の縦グラデーション + 外の暗い輪郭 + 内の明線)。メダル・バッジが共用する。
func _brass_ring(ci: RID, center: Vector2, radius: float, width: float) -> void:
	UiPaint.draw_ring(ci, center, radius + 0.5, UiPalette.OUTLINE_DARK, 1.0, 32)
	var outer := UiPaint.circle_points(center, radius, 32)
	var inner := UiPaint.circle_points(center, radius - width, 32)
	var ring := PackedVector2Array()
	ring.append_array(outer)
	ring.append(outer[0])
	ring.append(inner[0])
	var reversed := inner.duplicate()
	reversed.reverse()
	ring.append_array(reversed)
	var rect := Rect2(center - Vector2.ONE * radius, Vector2.ONE * radius * 2.0)
	UiPaint.fill_gradient_polygon(
		ci,
		ring,
		rect,
		[
			[0.0, UiPalette.BRASS_HIGHLIGHT],
			[0.45, UiPalette.BRASS_MID],
			[0.8, UiPalette.BRASS_DARK],
			[1.0, UiPalette.BRASS_LIGHT]
		]
	)
	UiPaint.draw_ring(ci, center, radius - width, Color(UiPalette.BRASS_RIM_LIGHT, 0.6), 1.0, 32)


## 濃紺の板(名札・山の札)。面取りの真鍮の細い縁を持つ。
func _plate(ci: RID, rect: Rect2, radius: float) -> PackedVector2Array:
	_shadow(ci, rect, radius)
	var points := UiPaint.rounded_rect_points_uniform(rect, radius, 5)
	UiPaint.fill_gradient_polygon(
		ci, points, rect, [[0.0, UiPalette.NAVY_PANEL_TOP], [1.0, UiPalette.NAVY_PANEL_BOTTOM]]
	)
	UiPaint.apply_grain(ci, rect, PILE_GRAIN_ALPHA)
	UiPaint.draw_inner_shadow(ci, rect, radius, 5, 3, Color(0, 0, 0), 0.35)
	_draw_closed(
		UiPaint.rounded_rect_points_uniform(rect.grow(1.0), radius + 1.0, 5),
		UiPalette.OUTLINE_DARK,
		1.0
	)
	UiPaint.draw_bevel(
		ci, points, UiPalette.BRASS_RIM_LIGHT, UiPalette.BRASS_DARK, RIM_WIDTH, false
	)
	return points


## 肖像のメダル。名札の左端へ重ね、真鍮の太い輪でアイコンを囲む。
## 手番の側はこの輪の外へ琥珀の光の輪を足す(GameDesign.md 9章)。
func _draw_portrait(ci: RID) -> void:
	_shadow_circle(ci, PORTRAIT_CENTER, PORTRAIT_RADIUS)
	var inner_radius := PORTRAIT_RADIUS - PORTRAIT_RING_WIDTH
	UiPaint.fill_circle(ci, PORTRAIT_CENTER, inner_radius, Color(0.05, 0.04, 0.03, 1.0), 32)
	var icon_tex := UserProfileLibrary.get_icon_texture(icon_id)
	if icon_tex != null:
		var r := inner_radius - 2.0
		draw_texture_rect(
			icon_tex, Rect2(PORTRAIT_CENTER - Vector2.ONE * r, Vector2.ONE * r * 2.0), false
		)
	_brass_ring(ci, PORTRAIT_CENTER, PORTRAIT_RADIUS, PORTRAIT_RING_WIDTH)
	if active:
		var pulse := (sin(_glint_time * 3.0) + 1.0) * 0.5
		UiPaint.draw_ring(
			ci,
			PORTRAIT_CENTER,
			PORTRAIT_RADIUS + 2.5,
			Color(UiPalette.GLOW_AMBER, 0.55 + 0.35 * pulse),
			2.5,
			32
		)


## 名札。メダルの右から伸びる濃紺の板に、称号(小)と表示名(大)を載せる
## (GameDesign.md 9章・14章)。
func _draw_name_plate() -> void:
	var ci := get_canvas_item()
	var label := display_name
	if label.is_empty():
		label = "相手" if is_opponent else "あなた"
	var points := _plate(ci, NAME_PLATE_RECT, 7.0)
	if active:
		_draw_closed(points, Color(UiPalette.GLOW_AMBER, 0.85), 1.5)
	var title_text := UserProfileLibrary.get_title_display(title_id)
	var top := NAME_PLATE_RECT.position.y
	if not title_text.is_empty():
		_text(Vector2(NAME_TEXT_X, top + 15), title_text, 11, UiPalette.BRASS_HIGHLIGHT)
		_text_shadowed(Vector2(NAME_TEXT_X, top + 32), label, 16)
	else:
		_text_shadowed(Vector2(NAME_TEXT_X, top + 26), label, 18)


## 山札の山。ドロー・疲労の演出の出どころとして画面側からも引く。
func deck_pile_rect() -> Rect2:
	return Rect2(Vector2(_right_x() + DECK_PILE_X, PILE_TOP), PILE_SIZE)


## 相手側だけに出る手札の山。ドローの行き先として使う。
func hand_pile_rect() -> Rect2:
	return Rect2(Vector2(_right_x() + HAND_PILE_X, PILE_TOP), PILE_SIZE)


## 山札を脈打たせる。`danger` は疲労(GameDesign.md 9章)。
func play_deck_pulse(danger: bool) -> void:
	_deck_pulse_color = UiPalette.WARNING_RED if danger else UiPalette.GLOW_AMBER
	if _deck_tween != null and _deck_tween.is_valid():
		_deck_tween.kill()
	_deck_tween = create_tween()
	_deck_tween.tween_method(_set_deck_pulse, 1.0, 0.0, DECK_PULSE_DURATION)


func _set_deck_pulse(value: float) -> void:
	_deck_pulse = value
	queue_redraw()


func _graveyard_rect() -> Rect2:
	return Rect2(Vector2(_right_x() + GRAVE_PILE_X, PILE_TOP), PILE_SIZE)


## HPバーは彫り込まれた溝に見せる(角丸 + 内側の落ち込み影)。残量の色は
## 十分なうちは琥珀、危険域まで減ったら赤(GameDesign.md 9章)。
## HPバーの矩形。攻撃の演出が本体を狙うときの的であり、被弾の演出の出どころでもある。
func hp_bar_rect() -> Rect2:
	return Rect2(Vector2(HP_BAR_X, CENTER_Y - HP_BAR_SIZE.y * 0.5), HP_BAR_SIZE)


## HPの砂に光が当たっている粒をいくつか置き、ゆっくり明滅させる。**残っている砂の
## 範囲だけ**描く(割合を超えた位置は隠れているので描かない)。
func _draw_sand_glints(ci: RID, fill_rect: Rect2, ratio: float) -> void:
	for i in SAND_GLINT_FRACTIONS.size():
		var frac: float = SAND_GLINT_FRACTIONS[i]
		if frac > ratio:
			continue
		var phase := float(i) * 1.7
		var pulse := (sin(_glint_time * SAND_GLINT_SPEED + phase) + 1.0) * 0.5
		var alpha := 0.15 + pulse * 0.45
		var center := Vector2(
			fill_rect.position.x + fill_rect.size.x * frac,
			fill_rect.position.y + fill_rect.size.y * (0.35 + 0.3 * sin(phase))
		)
		UiPaint.fill_gradient_polygon(
			ci,
			UiPaint.circle_points(center, SAND_GLINT_RADIUS, 8),
			Rect2(
				center - Vector2(SAND_GLINT_RADIUS, SAND_GLINT_RADIUS),
				Vector2(SAND_GLINT_RADIUS, SAND_GLINT_RADIUS) * 2.0
			),
			[[0.0, Color(1.0, 0.96, 0.82, alpha)], [1.0, Color(1.0, 0.96, 0.82, 0.0)]]
		)


func _draw_hp() -> void:
	var ci := get_canvas_item()
	var rect := hp_bar_rect()
	_shadow(ci, rect, HP_BAR_RADIUS)
	var track := UiPaint.rounded_rect_points_uniform(rect, HP_BAR_RADIUS, 6)
	UiPaint.fill_gradient_polygon(
		ci, track, rect, [[0.0, Color(0.05, 0.04, 0.04, 1.0)], [1.0, Color(0.12, 0.09, 0.08, 1.0)]]
	)
	var ratio := clampf(_shown_hp / float(MatchState.INITIAL_HP), 0.0, 1.0)
	var inner := rect.grow(-HP_RIM_WIDTH)
	if ratio > 0.0:
		var fill_rect := Rect2(inner.position, Vector2(inner.size.x * ratio, inner.size.y))
		var color := UiPalette.GLOW_AMBER if ratio > DANGER_RATIO else UiPalette.WARNING_RED
		var fill := UiPaint.rounded_rect_points_uniform(
			fill_rect, minf(HP_BAR_RADIUS - HP_RIM_WIDTH, fill_rect.size.x * 0.5), 5
		)
		UiPaint.fill_gradient_polygon(
			ci,
			fill,
			fill_rect,
			[[0.0, color.lightened(0.3)], [0.55, color], [1.0, color.darkened(0.3)]]
		)
		UiPaint.apply_grain(ci, fill_rect, 0.12)
		_draw_sand_glints(ci, fill_rect, ratio)
	# ガラス越しに見せる。上側3分の1へ白い反射の帯を薄く敷き、砂も器の地も同じ膜の下に置く。
	var glass := Rect2(
		inner.position + Vector2(4.0, 2.0), Vector2(inner.size.x - 8.0, inner.size.y * 0.32)
	)
	UiPaint.fill_gradient_polygon(
		ci,
		UiPaint.rounded_rect_points_uniform(glass, glass.size.y * 0.5, 4),
		glass,
		[[0.0, Color(1, 1, 1, 0.22)], [1.0, Color(1, 1, 1, 0.02)]]
	)
	UiPaint.draw_inner_shadow(ci, rect, HP_BAR_RADIUS, 6, 3, Color(0, 0, 0, 1), 0.55)
	# 真鍮の縁。攻撃の的になっている間は赤く光る(GameDesign.md 9章)。
	_draw_closed(
		UiPaint.rounded_rect_points_uniform(rect.grow(1.0), HP_BAR_RADIUS + 1.0, 6),
		UiPalette.OUTLINE_DARK,
		1.0
	)
	UiPaint.draw_bevel(
		ci, track, UiPalette.BRASS_RIM_LIGHT, UiPalette.BRASS_DARK, HP_RIM_WIDTH, false
	)
	if targetable:
		var pulse := (sin(_glint_time * 4.0) + 1.0) * 0.5
		_draw_closed(
			UiPaint.rounded_rect_points_uniform(rect.grow(2.5), HP_BAR_RADIUS + 2.5, 6),
			Color(UiPalette.WARNING_RED, 0.6 + 0.4 * pulse),
			2.5
		)
	if _flash > 0.0:
		UiPaint.fill_gradient_polygon(
			ci,
			track,
			rect,
			[[0.0, Color(1, 1, 1, 0.5 * _flash)], [1.0, Color(1, 0.9, 0.7, 0.2 * _flash)]]
		)
	# 上限は器の中に小さく、現在値は右端の丸いバッジに(場の駒の体力バッジと同じ語彙)。
	_text_shadowed(
		Vector2(rect.end.x - HP_BADGE_RADIUS - 44.0, rect.position.y + 21),
		"/ %d" % MatchState.INITIAL_HP,
		13,
		Color(UiPalette.TEXT_OFFWHITE, 0.85)
	)
	_badge(
		ci, Vector2(rect.end.x, rect.get_center().y), _hp, CardView.HEALTH_RED, HP_BADGE_RADIUS, 20
	)
	if _float_left > 0.0:
		_draw_float(rect)


## 丸いバッジ。場の駒の体力・攻撃力・手札のコストと同じ語彙(暗い地 + 色の輪 + 数字)を、
## 真鍮の縁で器へ嵌め込んだ形にする。
func _badge(
	ci: RID, center: Vector2, value: int, color: Color, radius: float, font_size: int
) -> void:
	_shadow_circle(ci, center, radius)
	UiPaint.draw_ring(ci, center, radius + 2.0, UiPalette.BRASS_MID, 2.0, 32)
	UiPaint.draw_ring(ci, center, radius + 3.5, UiPalette.OUTLINE_DARK, 1.0, 32)
	UiPaint.fill_circle(ci, center, radius, Color(0.08, 0.07, 0.06, 1.0), 32)
	UiPaint.draw_ring(ci, center, radius - 1.0, color, 2.5, 32)
	var text := str(value)
	var width := _font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x
	var at := center + Vector2(-width * 0.5, font_size * 0.36)
	_text(at + Vector2.ONE, text, font_size, TEXT_SHADOW)
	_text(at, text, font_size, color)


## マナは青のバッジに現在値、右の溝に最大値ぶんの粒(GameDesign.md 9章「数字とピップの併記」)。
func _draw_mana() -> void:
	var ci := get_canvas_item()
	var trough_rect := Rect2(_right(MANA_TROUGH_RECT.position), MANA_TROUGH_RECT.size)
	var trough_radius := trough_rect.size.y * 0.5
	_shadow(ci, trough_rect, trough_radius)
	var trough := UiPaint.rounded_rect_points_uniform(trough_rect, trough_radius, 6)
	UiPaint.fill_gradient_polygon(
		ci,
		trough,
		trough_rect,
		[[0.0, Color(0.03, 0.04, 0.09, 1.0)], [1.0, Color(0.08, 0.10, 0.19, 1.0)]]
	)
	UiPaint.draw_inner_shadow(ci, trough_rect, trough_radius, 6, 3, Color(0, 0, 0, 1), 0.5)
	UiPaint.draw_bevel(ci, trough, UiPalette.BRASS_RIM_LIGHT, UiPalette.BRASS_DARK, 1.5, false)
	# 払えない(n > 現在マナ)ぶんは光らせない(GameDesign.md 9章)。
	var glow_count := _highlight_cost if _highlight_cost <= _mana else 0
	for i in _max_mana:
		var center := Vector2(_right_x() + PIP_START_X + i * PIP_STEP, CENTER_Y)
		var filled: bool = i < _mana
		var base_color := MANA_BLUE if filled else MANA_EMPTY
		# 縁を暗く落としてから内側をひとまわり小さく塗り、面取り相当の立体感を出す。
		draw_circle(center, PIP_RADIUS, base_color.darkened(PIP_RIM_DARKEN))
		draw_circle(center, PIP_RADIUS * PIP_CORE_RATIO, base_color)
		var highlight_center := center + Vector2(-1, -1) * PIP_RADIUS * PIP_HIGHLIGHT_OFFSET
		var highlight_alpha := 0.4 if filled else 0.14
		draw_circle(
			highlight_center, PIP_RADIUS * PIP_HIGHLIGHT_RATIO, Color(1, 1, 1, highlight_alpha)
		)
		var arc_color := Color(0.75, 0.85, 1.0, 0.6) if filled else Color(0.4, 0.42, 0.48, 0.5)
		draw_arc(center, PIP_RADIUS, 0.0, TAU, 16, arc_color, 1.5)
		if i < glow_count:
			_draw_pip_glow(ci, center)
	_badge(ci, _right(MANA_BADGE_CENTER), _mana, MANA_BLUE, MANA_BADGE_RADIUS, 18)


## 支払うぶんのピップの脈打ち。HPの砂粒のきらめきと同じ経過時間(`_glint_time`)へ乗せる。
func _draw_pip_glow(ci: RID, center: Vector2) -> void:
	var pulse := (sin(_glint_time * PIP_GLOW_SPEED) + 1.0) * 0.5
	var radius := PIP_RADIUS + PIP_GLOW_EXTRA * pulse
	UiPaint.draw_ring(ci, center, radius, Color(1.0, 0.92, 0.6, 0.5 + 0.4 * pulse), 2.0, 16)


## 支払いで消えるピップが、出した札(または撃った砂術)の方向へ吸われて消える
## (GameDesign.md 9章)。
func _draw_spend_flight() -> void:
	if _spend_origins.is_empty() or _spend_progress >= 1.0:
		return
	var ci := get_canvas_item()
	var fade := 1.0 - _spend_progress
	for origin in _spend_origins:
		var pos: Vector2 = origin.lerp(_spend_to, _spend_progress)
		var radius := PIP_RADIUS * (0.55 + 0.45 * fade)
		UiPaint.fill_circle(ci, pos, radius, Color(1.0, 0.95, 0.72, fade), 12)


## コインを持っている間だけ、マナのバッジの肩に金貨を載せる。
func _draw_coin() -> void:
	var ci := get_canvas_item()
	var coin := _right(COIN_CENTER)
	_shadow_circle(ci, coin, COIN_RADIUS)
	UiPaint.fill_gradient_polygon(
		ci,
		UiPaint.circle_points(coin, COIN_RADIUS, 20),
		Rect2(coin - Vector2.ONE * COIN_RADIUS, Vector2.ONE * COIN_RADIUS * 2.0),
		[[0.0, Color(1.0, 0.9, 0.55)], [1.0, UiPalette.GLOW_AMBER.darkened(0.2)]]
	)
	UiPaint.draw_ring(ci, coin, COIN_RADIUS, UiPalette.BRASS_HIGHLIGHT, 1.5, 20)
	UiPaint.draw_ring(ci, coin, COIN_RADIUS * 0.55, Color(UiPalette.BRASS_DARK, 0.7), 1.0, 16)


## 山札・墓地・手札の枚数。濃紺の小さな札に、見出しを小さく上へ、枚数を大きく右下へ。
func _pile(rect: Rect2, label: String, count: int) -> void:
	var ci := get_canvas_item()
	var points := _plate(ci, rect, PILE_RADIUS)
	var pulsing: bool = (
		_deck_pulse > 0.0 and is_equal_approx(rect.position.x, deck_pile_rect().position.x)
	)
	if pulsing:
		_draw_closed(points, Color(_deck_pulse_color, _deck_pulse), 3.0)
		draw_rect(rect.grow(2.0), Color(_deck_pulse_color, 0.18 * _deck_pulse))
	_text(rect.position + Vector2(7, 15), label, 11, UiPalette.BRASS_HIGHLIGHT)
	var text := str(count)
	var width := _font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, 21).x
	var at := Vector2(rect.end.x - 8.0 - width, rect.position.y + 34)
	_text(at + Vector2.ONE, text, 21, TEXT_SHADOW)
	_text(at, text, 21, UiPalette.GLOW_AMBER)


func _text(
	pos: Vector2, value: String, font_size: int, color: Color = UiPalette.TEXT_OFFWHITE
) -> void:
	draw_string(_font, pos, value, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, color)


## 数値は砂の上でも地の上でも同じ色で読めるよう、暗い影を1pxずらして敷く(GameDesign.md 9章)。
func _text_shadowed(
	pos: Vector2, value: String, font_size: int, color: Color = UiPalette.TEXT_OFFWHITE
) -> void:
	_text(pos + Vector2.ONE, value, font_size, TEXT_SHADOW)
	_text(pos, value, font_size, color)


## HPが動いた。**瞬時に差し替えず補間し、バーを光らせ、増減を数字で浮かせる**
## (GameDesign.md 9章)。数字が入れ替わるだけでは、何点入ったのかが分からない。
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
	queue_redraw()


func _set_flash(value: float) -> void:
	_flash = value
	queue_redraw()


func _set_float_left(value: float) -> void:
	_float_left = value
	queue_redraw()


## 増減のフローティング数字。減ったら赤、回復したら琥珀。
##
## **ダメージは大きさと色でも示す**(GameDesign.md 9章)。1と7が同じ見た目だと、
## 盤面へ目を戻す前に「どれだけ削られたのか」が分からない。**回復は大きさを変えない**
## ——受け身の出来事であり、強調する理由がないため。
func _draw_float(rect: Rect2) -> void:
	var ratio := _float_left / FLOAT_DURATION
	var color := UiPalette.GLOW_AMBER if _float_amount > 0 else CardView.HEALTH_RED
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
	draw_string(_font, at, text, align, width, size, Color(color, minf(ratio * 2.0, 1.0)))
