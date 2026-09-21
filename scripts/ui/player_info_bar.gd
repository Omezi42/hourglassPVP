class_name PlayerInfoBar
extends Control
## 片方のプレイヤーの情報帯(GameDesign.md 9章「対局画面」)。
## HP・マナ・山札の残り・墓地の枚数を並べ、相手側は手札の枚数も出す(中身は伏せる)。

signal face_pressed
signal graveyard_pressed

const BAR_HEIGHT := 56.0
const MANA_BLUE := Color(0.35, 0.6, 0.95, 1.0)
const MANA_EMPTY := Color(0.2, 0.22, 0.28, 1.0)
const HP_BAR_SIZE := Vector2(240, 24)
const PILE_SIZE := Vector2(74, 40)
const DANGER_RATIO := 0.4
## マナのピップの間隔と半径。上限10まで並べても情報帯の幅に収まる。
const PIP_STEP := 20.0
const PIP_RADIUS := 7.0
## 帯の中の横位置。マナのピップは上限10まで並ぶため、山札の山と重ならない位置から始める。
const NAME_PLATE_RECT := Rect2(8, 8, 146, 40)
## アイコンの円を名札の帯の左端よりこれだけ左へ食い込ませる(段階2、GameDesign.md 9章)。
const NAME_ICON_OVERLAP := 6.0
const HP_BAR_X := 162.0
const MANA_TEXT_X := 418.0
const PIP_START_X := 516.0
const DECK_PILE_X := 730.0
const GRAVE_PILE_X := 812.0
const HAND_PILE_X := 894.0
## 持ち時間の丸(段階2)。中心x座標。右端(CLOCK_X + CLOCK_RADIUS)が
## `CardMatchScreen.BAR_WIDTH`(1060)からはみ出さない位置に置く。
const CLOCK_X := 1034.0
const CLOCK_DIAMETER := 40.0
const CLOCK_RADIUS := CLOCK_DIAMETER * 0.5
const BAR_CORNER := 10.0
const HP_BAR_RADIUS := 6.0
const PILE_RADIUS := 6.0
## 山札・墓地・手札の山(_pile)の質感(段階2)。地は帯より少し明るい濃紺
## (`UiPalette.NAVY_PANEL_PILE`)、グレインは小さい面のため控えめに、
## 輪郭は真鍮の細い単線に留める。
const PILE_GRAIN_ALPHA := 0.06
const PILE_OUTLINE_WIDTH := 1.0
## 持ち時間の丸(_draw_clock)の質感。脈動パルス・危険域の縁取りは動的な色を
## そのまま残し、平常時だけ真鍮の輪へ差し替える。
const CLOCK_GRAIN_ALPHA := 0.05
const CLOCK_BEVEL_WIDTH := 1.5
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
## 残り持ち時間(秒)。負の値なら表示しない(CPU戦は持ち時間を使わない)。
var clock_seconds := -1.0
## その手番に与えられた持ち時間。**時間切れを重ねた側は短くなる**(GameDesign.md 5章)ため、
## 危険域を固定の秒数で決めると、半減した手番が最初から赤いままになる。割合で判定する。
var clock_total := MatchClock.DEFAULT_TURN_SECONDS
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
	clock_seconds = -1.0
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
		_spend_origins.append(Vector2(PIP_START_X + i * PIP_STEP, 28))
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
	return global_position + Vector2(MANA_TEXT_X, 30.0)


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
	var rect := Rect2(Vector2.ZERO, size)
	var points := UiPaint.rounded_rect_points_uniform(rect, BAR_CORNER, 6)
	# 地は濃紺のフェルトと同じ系統にし、卓と同じ光を受けて見せる(GameDesign.md 9章「再構築」)。
	UiPaint.fill_gradient_polygon(
		ci, points, rect, [[0.0, UiPalette.NAVY_PANEL_TOP], [1.0, UiPalette.NAVY_PANEL_BOTTOM]]
	)
	UiPaint.apply_grain(ci, rect, 0.06)
	UiPaint.draw_inner_shadow(ci, rect, BAR_CORNER, 4, 5, Color(0, 0, 0), 0.35)
	var outline := points.duplicate()
	outline.append(points[0])
	var edge := Color(UiPalette.BRASS_MID, 0.95)
	var width := 2.0
	if targetable:
		edge = UiPalette.WARNING_RED
		width = 3.0
	elif active:
		# 手番の側だけ縁を明るくする。どちらが指す番かを常に読めるようにするため
		# (GameDesign.md 9章)。
		edge = UiPalette.GLOW_AMBER
		width = 3.0
	draw_polyline(outline, edge, width, true)
	_draw_name_plate()
	_draw_hp()
	_draw_mana()
	_draw_spend_flight()
	_pile(deck_pile_rect().position, "山札", _deck)
	_pile(_graveyard_rect().position, "墓地", _graveyard)
	if is_opponent:
		_pile(Vector2(HAND_PILE_X, 8), "手札", _hand)
	if _has_coin:
		_draw_coin()
	if clock_seconds >= 0.0:
		_draw_clock()


## 名前・アイコン・称号は真鍮の名札に載せる(GameDesign.md 9章・14章)。
func _draw_name_plate() -> void:
	var ci := get_canvas_item()
	var label := display_name
	if label.is_empty():
		label = "相手" if is_opponent else "あなた"
	var points := UiPaint.rounded_rect_points_uniform(NAME_PLATE_RECT, 6.0, 5)
	UiPaint.fill_gradient_polygon(
		ci,
		points,
		NAME_PLATE_RECT,
		[[0.0, UiPalette.NAMEPLATE_PANEL_TOP], [1.0, UiPalette.NAMEPLATE_PANEL_BOTTOM]]
	)
	var outline := points.duplicate()
	outline.append(points[0])
	draw_polyline(outline, UiPalette.BRASS_LIGHT, 1.5, true)

	# アイコン描画(段階2: 名札の帯へ左へ6pxほど食い込ませ、真鍮の二重の輪で囲む)。
	var icon_radius := 14.0
	var ring_inner_radius := icon_radius + 1.0
	var ring_outer_radius := icon_radius + 3.0
	var icon_center := Vector2(
		NAME_PLATE_RECT.position.x - NAME_ICON_OVERLAP + ring_outer_radius,
		NAME_PLATE_RECT.position.y + NAME_PLATE_RECT.size.y * 0.5
	)
	var icon_rect := Rect2(icon_center - Vector2.ONE * icon_radius, Vector2.ONE * icon_radius * 2.0)
	var icon_tex := UserProfileLibrary.get_icon_texture(icon_id)
	if icon_tex != null:
		draw_texture_rect(icon_tex, icon_rect, false)
	draw_arc(icon_center, ring_inner_radius, 0.0, TAU, 24, UiPalette.BRASS_MID, 2.0)
	draw_arc(icon_center, ring_outer_radius, 0.0, TAU, 24, UiPalette.BRASS_HIGHLIGHT, 1.0)

	# 称号と表示名の描画
	var title_text := UserProfileLibrary.get_title_display(title_id)
	var text_x := 48.0
	if not title_text.is_empty():
		_text(
			Vector2(text_x, NAME_PLATE_RECT.position.y + 16),
			title_text,
			11,
			UiPalette.BRASS_HIGHLIGHT
		)
		_text(Vector2(text_x, NAME_PLATE_RECT.position.y + 32), label, 15, UiPalette.TEXT_OFFWHITE)
	else:
		_text(Vector2(text_x, NAME_PLATE_RECT.position.y + 26), label, 17, UiPalette.TEXT_OFFWHITE)


## 残り時間は情報帯の右端の丸に置く(段階2、GameDesign.md 9章「対局画面の再構築」)。
## 地は真鍮の放射(暗→中の2段の同心円)+輪。矩形のプレートより盤面の台座(丸い皿)と
## 意匠が揃う。
func _draw_clock() -> void:
	var ci := get_canvas_item()
	var center := Vector2(CLOCK_X, size.y * 0.5)
	var is_critical := clock_seconds <= 15.0 and active
	var is_low := clock_seconds <= maxf(clock_total, 1.0) * 0.5

	# 地: 暗い真鍮の円の上へ、一回り小さい中間真鍮の円を重ねて放射風にする。
	UiPaint.fill_circle(ci, center, CLOCK_RADIUS, UiPalette.BRASS_DARK, 24)
	UiPaint.fill_circle(ci, center, CLOCK_RADIUS * 0.7, UiPalette.BRASS_MID, 24)
	UiPaint.apply_grain(
		ci,
		Rect2(center - Vector2.ONE * CLOCK_RADIUS, Vector2.ONE * CLOCK_RADIUS * 2.0),
		CLOCK_GRAIN_ALPHA
	)

	# 輪 (残り15秒以下かつ手番中なら脈動パルス)
	if is_critical:
		var pulse := (sin(Time.get_ticks_msec() * 0.008) + 1.0) * 0.5
		var pulse_color := UiPalette.WARNING_RED.lerp(UiPalette.GLOW_AMBER, pulse * 0.4)
		UiPaint.draw_ring(ci, center, CLOCK_RADIUS, pulse_color, 2.5, 24)
		var glow_radius := CLOCK_RADIUS + 1.5
		draw_rect(
			Rect2(center - Vector2.ONE * glow_radius, Vector2.ONE * glow_radius * 2.0),
			Color(pulse_color, 0.15 * pulse)
		)
	elif is_low:
		UiPaint.draw_ring(ci, center, CLOCK_RADIUS, Color(UiPalette.WARNING_RED, 0.8), 1.5, 24)
	else:
		UiPaint.draw_ring(
			ci, center, CLOCK_RADIUS, UiPalette.BRASS_HIGHLIGHT, CLOCK_BEVEL_WIDTH, 24
		)

	var minutes := int(clock_seconds) / 60
	var seconds := int(clock_seconds) % 60
	var text_color := UiPalette.TEXT_OFFWHITE
	if is_critical:
		var pulse := (sin(Time.get_ticks_msec() * 0.008) + 1.0) * 0.5
		text_color = Color(1.0, 0.35 + 0.35 * pulse, 0.35 + 0.35 * pulse, 1.0)
	elif is_low:
		text_color = UiPalette.WARNING_RED

	draw_string(
		_font,
		Vector2(center.x - CLOCK_RADIUS, center.y + 5.0),
		"%d:%02d" % [minutes, seconds],
		HORIZONTAL_ALIGNMENT_CENTER,
		CLOCK_RADIUS * 2.0,
		15,
		text_color
	)


## 山札の山。ドロー・疲労の演出の出どころとして画面側からも引く。
func deck_pile_rect() -> Rect2:
	return Rect2(Vector2(DECK_PILE_X, 8), PILE_SIZE)


## 相手側だけに出る手札の山。ドローの行き先として使う。
func hand_pile_rect() -> Rect2:
	return Rect2(Vector2(HAND_PILE_X, 8), PILE_SIZE)


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
	return Rect2(Vector2(GRAVE_PILE_X, 8), PILE_SIZE)


## HPバーは彫り込まれた溝に見せる(角丸 + 内側の落ち込み影)。残量の色は
## 十分なうちは琥珀、危険域まで減ったら赤(GameDesign.md 9章)。
## HPバーの矩形。攻撃の演出が本体を狙うときの的であり、被弾の演出の出どころでもある。
func hp_bar_rect() -> Rect2:
	return Rect2(Vector2(HP_BAR_X, 16), HP_BAR_SIZE)


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
	var track := UiPaint.rounded_rect_points_uniform(rect, HP_BAR_RADIUS, 5)
	UiPaint.fill_gradient_polygon(
		ci, track, rect, [[0.0, Color(0.06, 0.05, 0.05, 1.0)], [1.0, Color(0.14, 0.11, 0.1, 1.0)]]
	)
	var ratio := clampf(_shown_hp / float(MatchState.INITIAL_HP), 0.0, 1.0)
	if ratio > 0.0:
		var fill_rect := Rect2(rect.position, Vector2(rect.size.x * ratio, rect.size.y))
		var color := UiPalette.GLOW_AMBER if ratio > DANGER_RATIO else UiPalette.WARNING_RED
		var fill := UiPaint.rounded_rect_points_uniform(
			fill_rect, minf(HP_BAR_RADIUS, fill_rect.size.x * 0.5), 5
		)
		UiPaint.fill_gradient_polygon(
			ci, fill, fill_rect, [[0.0, color.lightened(0.28)], [1.0, color.darkened(0.22)]]
		)
		_draw_sand_glints(ci, fill_rect, ratio)
	UiPaint.draw_inner_shadow(ci, rect, HP_BAR_RADIUS, 5, 3, Color(0, 0, 0, 1), 0.5)
	var outline := track.duplicate()
	outline.append(track[0])
	draw_polyline(outline, UiPalette.BRASS_MID, 1.5, true)
	if _flash > 0.0:
		var glow := UiPaint.rounded_rect_points_uniform(rect, HP_BAR_RADIUS, 5)
		UiPaint.fill_gradient_polygon(
			ci,
			glow,
			rect,
			[[0.0, Color(1, 1, 1, 0.5 * _flash)], [1.0, Color(1, 0.9, 0.7, 0.2 * _flash)]]
		)
	_text(
		Vector2(rect.position.x + 96, rect.position.y + 19),
		"%d / %d" % [_hp, MatchState.INITIAL_HP],
		17
	)
	if _float_left > 0.0:
		_draw_float(rect)


func _draw_mana() -> void:
	_text(Vector2(MANA_TEXT_X, 36), "マナ %d/%d" % [_mana, _max_mana], 18)
	var ci := get_canvas_item()
	# 払えない(n > 現在マナ)ぶんは光らせない(GameDesign.md 9章)。
	var glow_count := _highlight_cost if _highlight_cost <= _mana else 0
	for i in _max_mana:
		var center := Vector2(PIP_START_X + i * PIP_STEP, 28)
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


## コインを持っている間だけ、マナの並びの右隣に金色の粒を出す。
func _draw_coin() -> void:
	var center := Vector2(PIP_START_X + _max_mana * PIP_STEP + 6, 28)
	draw_circle(center, PIP_RADIUS + 1.0, UiPalette.GLOW_AMBER)
	draw_arc(center, PIP_RADIUS + 1.0, 0.0, TAU, 16, UiPalette.BRASS_HIGHLIGHT, 1.5)


## 山札・墓地・手札の枚数。小さな山を模した角丸のプレートに枚数を載せる。
## 段階2: 地を`NAVY_PANEL_PILE`(帯より少し明るい濃紺)にし、輪郭は真鍮1pxの
## 単線にする(ベベルではなく細い縁取りに留め、帯の地との差を色だけで見せる)。
func _pile(pos: Vector2, label: String, count: int) -> void:
	var ci := get_canvas_item()
	var rect := Rect2(pos, PILE_SIZE)
	var points := UiPaint.rounded_rect_points_uniform(rect, PILE_RADIUS, 5)
	UiPaint.fill_gradient_polygon(
		ci, points, rect, [[0.0, UiPalette.NAVY_PANEL_PILE], [1.0, UiPalette.NAVY_PANEL_BOTTOM]]
	)
	UiPaint.apply_grain(ci, rect, PILE_GRAIN_ALPHA)
	var outline := points.duplicate()
	outline.append(points[0])
	var pulsing: bool = _deck_pulse > 0.0 and is_equal_approx(pos.x, DECK_PILE_X)
	if pulsing:
		draw_polyline(outline, Color(_deck_pulse_color, _deck_pulse), 3.0, true)
		draw_rect(rect.grow(2.0), Color(_deck_pulse_color, 0.18 * _deck_pulse))
	else:
		draw_polyline(outline, UiPalette.BRASS_MID, PILE_OUTLINE_WIDTH, true)
	_text(Vector2(pos.x + 8, pos.y + 26), label, 15)
	_text(Vector2(pos.x + 46, pos.y + 27), str(count), 19, UiPalette.GLOW_AMBER)


func _fill(rect: Rect2, top: Color, bottom: Color) -> void:
	var points := PackedVector2Array(
		[
			rect.position,
			Vector2(rect.end.x, rect.position.y),
			rect.end,
			Vector2(rect.position.x, rect.end.y)
		]
	)
	draw_polygon(points, PackedColorArray([top, top, bottom, bottom]))


func _text(
	pos: Vector2, value: String, font_size: int, color: Color = UiPalette.TEXT_OFFWHITE
) -> void:
	draw_string(_font, pos, value, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, color)


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
	var at := Vector2(rect.end.x + 8.0, rect.position.y + FLOAT_BASELINE - rise)
	var align := HORIZONTAL_ALIGNMENT_LEFT
	var width := -1.0
	if weight > 0.0:
		at = Vector2(rect.end.x - FLOAT_HEAVY_WIDTH, rect.position.y - FLOAT_HEAVY_LIFT - rise)
		align = HORIZONTAL_ALIGNMENT_RIGHT
		width = FLOAT_HEAVY_WIDTH
	draw_string(_font, at, text, align, width, size, Color(color, minf(ratio * 2.0, 1.0)))
