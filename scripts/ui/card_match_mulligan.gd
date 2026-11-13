class_name CardMatchMulligan
extends Control
## 対局開始前のマリガン画面(GameDesign.md 2章・9章)。
## 初期手札を並べて引き直すカードを選ばせ、確定した位置を返すところまでが責務で、
## 実際の引き直しは `MatchState.mulligan()` が行う。

signal confirmed(indices: Array)

## 札の姿勢が変わる理由。尺と補間が理由ごとに違う。
enum PoseKind { HOVER, PRESS, SETTLE, PICK }

## 初期手札は対局の手札より大きく並べ、効果の文まで読めるようにする(詳細パネルはマリガン中に出さない)。
const CARD_SCALE := 1.35
const CARD_SIZE := CardView.HAND_SIZE_PX * CARD_SCALE
const CARD_GAP := 28.0
## 縦は札を2列に折り返し、名前とキーワードが縦の目安の文字に届く倍率で並べる(GameDesign.md 9章「縦画面」)。
const PORTRAIT_CARD_SCALE := 2.0
const PORTRAIT_COLUMNS := 2
const PORTRAIT_ROW_GAP := 20.0
const PORTRAIT_BUTTON_SIZE := Vector2(320, 80)
const PORTRAIT_TURN_ORDER_FONT := 28
const PORTRAIT_HINT_FONT := 24
## 札の列の下端から確定ボタンまで。
const BUTTON_MARGIN := 48.0
## 見出しから確定ボタンまでの一群を画面の縦の中ほどへ置く(上端は `CardMatchLayout.mulligan_top`)。
## 誘導対局ではこの下へ帯が入る(`CardMatchTutorial` が `confirm_rect()` から決める)。値は一群の上端からの距離。
const TITLE_Y := 32.0
const HINT_Y := 90.0
const CARD_ROW_Y := 152.0
const BUTTON_SIZE := Vector2(280, 60)
const BUTTON_Y := 410.0
const TURN_ORDER_FONT := UiPalette.T_LEAD
const HINT_FONT := 20
## 札の列の後ろの光だまりが、列の左右と上下へはみ出す量。
const STAGE_MARGIN := Vector2(150, 70)
## 引き直すカードは沈めて、押したことが手札の並びの中で分かるようにする。
const PICKED_SINK := 18.0
const PICK_DURATION := 0.14
## 札の姿勢(`_pose()`)。乗せると浮いて少し膨らみ、押している間は沈む(駒と同じ0.08秒)。
## 拡大の軸は札の中心。札の間隔が狭いため、手札の1.22倍にはしない。
const HOVER_LIFT := 8.0
const PORTRAIT_HOVER_LIFT := 10.0
const HOVER_SCALE := 1.04
const PRESS_SCALE := 0.97
const HOVER_DURATION := 0.10
const PRESS_DURATION := 0.08
const SETTLE_DURATION := 0.16
## 確定ボタンの文言が変わったとき、ボタンが小さく脈打つ。
const BUTTON_PULSE_SCALE := 1.05
const BUTTON_PULSE_UP := 0.06
const BUTTON_PULSE_DOWN := 0.10
## 確定した瞬間: 見出しとヒントの差し替え、札が「もう触れない」色へ落ちる。
const TEXT_SWAP_OUT := 0.10
const TEXT_SWAP_IN := 0.14
const LOCK_DURATION := 0.2
const LOCK_TINT := Color(0.82, 0.82, 0.86)
## 相手を待つ間、見出しだけがゆっくり明滅する。
const WAIT_PULSE_LOW := 0.55
const WAIT_PULSE_PERIOD := 1.6
## 閉じるとき: 札を手札の方向へ下げながら薄れさせ、暗幕ごと畳む。
const CLOSE_CARD_DROP := 40.0
const CLOSE_CARD_DURATION := 0.18
const CLOSE_CARD_STAGGER := 0.03
const CLOSE_TEXT_FADE := 0.12
## 開いた瞬間、手札が配られるように下から浮き上がってくる距離と間隔。
const DEAL_RISE := 46.0
const DEAL_DURATION := 0.32
const DEAL_STAGGER := 0.05
const DIM_FADE_DURATION := 0.3
## 開く前に先手・後手の一文だけを中央へ大きく出し、止めてから見出しの上へ移す(GameDesign.md 9章)。
const ORDER_INTRO_FONT := 56
## 縦は「後手(コイン1枚)」の一文が横幅に収まる大きさに抑える。
const PORTRAIT_ORDER_INTRO_FONT := 40
const ORDER_INTRO_FADE := 0.2
const ORDER_INTRO_HOLD := 0.8
const ORDER_INTRO_MOVE := 0.4
const LABEL_PAD := 12

## 誘導対局の間は札を選べない(GameDesign.md 18章)。「このままで開始」だけを受け付ける。
var picking_disabled := false
var _views: Array[CardView] = []
var _marks: Array[MulliganPickMark] = []
var _picked: Array[bool] = []
var _title: Label
var _hint: Label
## 自分が先手か後手か(GameDesign.md 9章)。残す札の重さの判断が手番で変わるため見出しの上に出す。
var _turn_order: Label
var _button: Button
var _waiting := false
var _dim: ColorRect
var _stage: MulliganStageLight
var _tween: Tween
var _pose_tweens: Dictionary = {}
var _swap_tween: Tween
var _wait_tween: Tween
var _lock_tween: Tween
var _button_tween: Tween
var _close_tween: Tween
var _hovered := -1
var _pressed := -1
var _portrait := false
## 閉じる演出の間は下の盤面を操作でき、この画面はもう何も受け付けない。
var _closing := false
var _saved_filters: Dictionary = {}
var _button_text_set := false
var _screen_size := Vector2(ScreenOrientation.LANDSCAPE_SIZE)
var _top := 0.0
var _card_gap := CARD_GAP
var _card_size := CARD_SIZE
var _columns := MatchState.SECOND_PLAYER_HAND
var _button_y := 0.0
var _turn_order_font := TURN_ORDER_FONT
var _order_intro_font := ORDER_INTRO_FONT
## 先手・後手の一文を見せている間は札も確定ボタンもまだ出ていないので、押させない。
var _intro_playing := false


func _ready() -> void:
	visible = false
	mouse_filter = Control.MOUSE_FILTER_STOP
	# **`set_anchors_preset()` は使わない**。コードで生成した直後(サイズ0)のノードへ使うと
	# 0サイズのまま固定され、暗幕が何も覆わない(Architecture.md 4章の既知の落とし穴)。
	_build()


## 向きに合わせて置き直す(`CardMatchArrange`)。開いている間に呼ばれても札の選択は保つ。
func apply_layout(layout: CardMatchLayout) -> void:
	_screen_size = layout.screen_size
	_card_gap = layout.mulligan_card_gap
	_card_size = CardView.HAND_SIZE_PX * (PORTRAIT_CARD_SCALE if layout.portrait else CARD_SCALE)
	_columns = PORTRAIT_COLUMNS if layout.portrait else MatchState.SECOND_PLAYER_HAND
	_button_y = button_offset(layout.portrait)
	_top = layout.mulligan_top
	_portrait = layout.portrait
	size = _screen_size
	_dim.size = _screen_size
	_turn_order_font = PORTRAIT_TURN_ORDER_FONT if layout.portrait else TURN_ORDER_FONT
	_order_intro_font = PORTRAIT_ORDER_INTRO_FONT if layout.portrait else ORDER_INTRO_FONT
	_turn_order.add_theme_font_size_override("font_size", _turn_order_font)
	_hint.add_theme_font_size_override(
		"font_size", PORTRAIT_HINT_FONT if layout.portrait else HINT_FONT
	)
	for pair in [[_turn_order, 0.0], [_title, TITLE_Y], [_hint, HINT_Y]]:
		var label: Label = pair[0]
		label.position = Vector2(0, _top + pair[1])
		label.size.x = _screen_size.x
	var button_size := PORTRAIT_BUTTON_SIZE if layout.portrait else BUTTON_SIZE
	_button.custom_minimum_size = button_size
	_button.size = button_size
	_button.position = Vector2((_screen_size.x - button_size.x) * 0.5, _top + _button_y)
	_reset_poses()
	for i in _views.size():
		_views[i].size = _card_size
		_views[i].pivot_offset = _card_size * 0.5
		_marks[i].position = _views[i]._hand_art_box().get_center() - _marks[i].size * 0.5
	_place_cards()


## 一群の上端から確定ボタンの上端まで。札の行数は初期手札の最大枚数で決める(先手・後手で一群が動かないように)。
static func button_offset(portrait: bool) -> float:
	if not portrait:
		return BUTTON_Y
	var rows := ceili(float(MatchState.SECOND_PLAYER_HAND) / PORTRAIT_COLUMNS)
	var card_height := CardView.HAND_SIZE_PX.y * PORTRAIT_CARD_SCALE
	return CARD_ROW_Y + rows * card_height + (rows - 1) * PORTRAIT_ROW_GAP + BUTTON_MARGIN


## 一群の高さ(上端から確定ボタンの下端まで)。
static func content_height(portrait: bool) -> float:
	var button_size := PORTRAIT_BUTTON_SIZE if portrait else BUTTON_SIZE
	return button_offset(portrait) + button_size.y


## 札の列と後ろの光だまり。`_columns` 枚ごとに折り返し、端数の行も中央へ寄せる。
func _place_cards() -> void:
	var total := _views.size()
	var per_row := mini(total, _columns)
	var rows := ceili(float(total) / maxi(per_row, 1))
	var width := per_row * _card_size.x + maxf(per_row - 1, 0) * _card_gap
	var height := rows * _card_size.y + maxf(rows - 1, 0) * PORTRAIT_ROW_GAP
	_stage.position = Vector2((_screen_size.x - width) * 0.5, _top + CARD_ROW_Y) - STAGE_MARGIN
	_stage.size = Vector2(width, height) + STAGE_MARGIN * 2.0
	_stage.queue_redraw()
	for i in total:
		_views[i].position = Vector2(_column_x(i), _row_y(i))


func _column_x(index: int) -> float:
	var total := _views.size()
	var row_start := index - index % _columns
	var in_row := mini(_columns, total - row_start)
	var width := in_row * _card_size.x + maxf(in_row - 1, 0) * _card_gap
	var left := (_screen_size.x - width) * 0.5
	return left + (index - row_start) * (_card_size.x + _card_gap)


func _row_y(index: int) -> float:
	var picked: bool = index < _picked.size() and _picked[index]
	var row := int(float(index) / _columns)
	var y := _top + CARD_ROW_Y + row * (_card_size.y + PORTRAIT_ROW_GAP)
	return y + (PICKED_SINK if picked else 0.0)


## 初期手札を並べて開く。`has_coin` は後手がコインを持って始めるか(2章)。
func show_hand(cards: Array, is_first: bool, has_coin: bool) -> void:
	# 閉じている途中に開き直されても、前の演出を残さない。
	_stop_tweens()
	_finish_close()
	if is_first:
		_turn_order.text = "あなたは先手です"
	else:
		_turn_order.text = "あなたは後手です" + ("(コイン1枚)" if has_coin else "")
	_waiting = false
	_picked.clear()
	for view in _views:
		view.queue_free()
	_views.clear()
	_marks.clear()
	_pose_tweens.clear()
	_hovered = -1
	_pressed = -1
	_button_text_set = false
	for i in cards.size():
		var view := CardView.new()
		view.mode = CardView.Mode.HAND
		view.pressed.connect(_on_card_pressed)
		add_child(view)
		view.mouse_entered.connect(_on_card_entered.bind(view))
		view.mouse_exited.connect(_on_card_exited.bind(view))
		view.gui_input.connect(_on_card_input.bind(view))
		view.show_card(cards[i], true)
		view.size = _card_size
		view.pivot_offset = _card_size * 0.5
		# 裏返した印は絵の窓の中央へ重ねる。
		var mark := MulliganPickMark.new()
		view.add_child(mark)
		mark.position = view._hand_art_box().get_center() - mark.size * 0.5
		_views.append(view)
		_marks.append(mark)
		_picked.append(false)
	_place_cards()
	_refresh(false)
	visible = true
	# 誘導対局(札を選ばせない)では省く。すなえるの指示と重なるため。
	if picking_disabled:
		_start_entrance()
	else:
		_start_order_intro()


## 先手・後手の一文を暗幕の中央へ大きく出し、少し止めてから見出しの上の定位置へ
## 縮めながら移す。移し終えたところで手札を配る。
func _start_order_intro() -> void:
	if _tween != null and _tween.is_valid():
		_tween.kill()
	_intro_playing = true
	for node in [_stage, _title, _hint, _button] + _views:
		node.modulate.a = 0.0
	_place_turn_order(0.0)
	_turn_order.modulate.a = 0.0
	_dim.modulate.a = 0.0
	SoundBank.play(SoundBank.Sfx.TURN_ORDER)
	_tween = create_tween()
	_tween.tween_property(_dim, "modulate:a", 1.0, CardMatchLayout.OVERLAY_DIM_FADE)
	_tween.parallel().tween_property(_turn_order, "modulate:a", 1.0, ORDER_INTRO_FADE)
	_tween.tween_interval(ORDER_INTRO_HOLD)
	(
		_tween
		. tween_method(_place_turn_order, 0.0, 1.0, ORDER_INTRO_MOVE)
		. set_trans(Tween.TRANS_CUBIC)
		. set_ease(Tween.EASE_IN_OUT)
	)
	_tween.tween_callback(_end_order_intro)


## 0 は画面の中央に大きく、1 は見出しの上の定位置(`apply_layout()` と同じ位置・大きさ)。
func _place_turn_order(progress: float) -> void:
	var font_size := roundi(lerpf(_order_intro_font, _turn_order_font, progress))
	var height := font_size + LABEL_PAD
	var start_center := _screen_size.y * 0.5
	var end_center := _top + (_turn_order_font + LABEL_PAD) * 0.5
	_turn_order.add_theme_font_size_override("font_size", font_size)
	_turn_order.size = Vector2(_screen_size.x, height)
	_turn_order.position = Vector2(0, lerpf(start_center, end_center, progress) - height * 0.5)


func _end_order_intro() -> void:
	_intro_playing = false
	_start_entrance(false)


## **手札が配られるように**下から浮き上がらせる(GameDesign.md 9章の
## 「場に出した砂時計は台座の少し上から落ちて着地する」と同じ思想を、
## 対局の入口であるマリガンにも及ぼす)。暗幕もあわせてフェードインさせ、
## 唐突に画面が切り替わったように見せない。
## `with_dim` が false のときは、暗幕と先手・後手の一文が既に出ている(`_start_order_intro()` の続き)。
func _start_entrance(with_dim := true) -> void:
	if _tween != null and _tween.is_valid():
		_tween.kill()
	_tween = create_tween()
	_tween.set_parallel(true)
	if with_dim:
		_dim.modulate.a = 0.0
		_tween.tween_property(_dim, "modulate:a", 1.0, CardMatchLayout.OVERLAY_DIM_FADE)
		_turn_order.modulate.a = 0.0
		_tween.tween_property(_turn_order, "modulate:a", 1.0, DIM_FADE_DURATION)
	_button.modulate.a = 0.0
	_tween.tween_property(_button, "modulate:a", 1.0, DIM_FADE_DURATION)
	_stage.modulate.a = 0.0
	_tween.tween_property(_stage, "modulate:a", 1.0, DIM_FADE_DURATION)
	_title.modulate.a = 0.0
	_hint.modulate.a = 0.0
	_tween.tween_property(_title, "modulate:a", 1.0, DIM_FADE_DURATION)
	_tween.tween_property(_hint, "modulate:a", 1.0, DIM_FADE_DURATION)
	for i in _views.size():
		var view: CardView = _views[i]
		var target_y := view.position.y
		view.position.y = target_y + DEAL_RISE
		view.modulate.a = 0.0
		(
			_tween
			. tween_property(view, "position:y", target_y, DEAL_DURATION)
			. set_trans(Tween.TRANS_SINE)
			. set_ease(Tween.EASE_OUT)
			. set_delay(i * DEAL_STAGGER)
		)
		_tween.tween_property(view, "modulate:a", 1.0, DEAL_DURATION).set_delay(i * DEAL_STAGGER)


## 見えているときだけ畳む。`immediate` は演出なしで即座に閉じる(対局のやり直し・撮影の後始末)。
func close(immediate := false) -> void:
	if not visible:
		return
	if immediate:
		_stop_tweens()
		_finish_close()
		return
	if _closing:
		return
	_start_close()


## 開いているか。閉じる演出の間は盤面を操作できるため、開いているとは数えない。
func is_open() -> bool:
	return visible and not _closing


func _start_close() -> void:
	_stop_tweens()
	_closing = true
	_hovered = -1
	_pressed = -1
	_saved_filters.clear()
	for child in get_children():
		var control := child as Control
		if control != null:
			_saved_filters[control] = control.mouse_filter
			control.mouse_filter = Control.MOUSE_FILTER_IGNORE
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_close_tween = create_tween()
	_close_tween.set_parallel(true)
	for i in _views.size():
		var view: CardView = _views[i]
		var delay := i * CLOSE_CARD_STAGGER
		(
			_close_tween
			. tween_property(
				view, "position:y", view.position.y + CLOSE_CARD_DROP, CLOSE_CARD_DURATION
			)
			. set_trans(Tween.TRANS_CUBIC)
			. set_ease(Tween.EASE_IN)
			. set_delay(delay)
		)
		(
			_close_tween
			. tween_property(view, "modulate:a", 0.0, CLOSE_CARD_DURATION)
			. set_trans(Tween.TRANS_CUBIC)
			. set_ease(Tween.EASE_IN)
			. set_delay(delay)
		)
	for node in [_turn_order, _title, _hint, _button]:
		_close_tween.tween_property(node, "modulate:a", 0.0, CLOSE_TEXT_FADE)
	for node in [_dim, _stage]:
		_close_tween.tween_property(node, "modulate:a", 0.0, CardMatchLayout.OVERLAY_DIM_FADE)
	_close_tween.chain().tween_callback(_finish_close)


## 閉じる演出で動かしたものを初期値へ戻し、非表示にする。
func _finish_close() -> void:
	_closing = false
	visible = false
	mouse_filter = Control.MOUSE_FILTER_STOP
	for control in _saved_filters:
		if is_instance_valid(control):
			control.mouse_filter = _saved_filters[control]
	_saved_filters.clear()
	for node in [_dim, _stage, _turn_order, _title, _hint, _button]:
		node.modulate.a = 1.0
	_button.scale = Vector2.ONE
	for view in _views:
		view.modulate.a = 1.0
		view.self_modulate = Color.WHITE
		view.scale = Vector2.ONE
	_hovered = -1
	_pressed = -1
	_place_cards()


func _stop_tweens() -> void:
	for tween in [_tween, _swap_tween, _wait_tween, _lock_tween, _button_tween, _close_tween]:
		_kill(tween)
	for tween in _pose_tweens.values():
		_kill(tween)
	_pose_tweens.clear()
	_intro_playing = false


static func _kill(tween: Tween) -> void:
	if tween != null and tween.is_valid():
		tween.kill()


## 札が乗せた・押した・選んだ・外した、に返事をする状態か。確定後(相手待ち)と誘導対局では何も反応させない。
func _reactive() -> bool:
	return not (_waiting or picking_disabled or _closing)


## 配りの途中は札の位置を配りの動きが決めているため、姿勢を動かさない。
func _posable() -> bool:
	var dealing := _tween != null and _tween.is_valid() and _tween.is_running()
	return _reactive() and not _intro_playing and not dealing


func _on_card_entered(view: CardView) -> void:
	var index := _views.find(view)
	if index < 0 or not _posable():
		return
	_hovered = index
	# 選んだ札は `enabled=false` で、札自身はホバー音を鳴らさない。未選択の札と同じ音をここで出す。
	if _picked[index]:
		SoundBank.play(SoundBank.Sfx.HOVER)
	_pose(index, PoseKind.HOVER)


func _on_card_exited(view: CardView) -> void:
	var index := _views.find(view)
	if index < 0 or (_hovered != index and _pressed != index):
		return
	_hovered = -1
	_pressed = -1
	_pose(index, PoseKind.SETTLE)


func _on_card_input(event: InputEvent, view: CardView) -> void:
	var button := event as InputEventMouseButton
	if button == null or button.button_index != MOUSE_BUTTON_LEFT:
		return
	var index := _views.find(view)
	if index < 0:
		return
	if button.pressed:
		if _posable():
			_pressed = index
			_pose(index, PoseKind.PRESS)
	elif _pressed == index:
		_pressed = -1
		_pose(index, PoseKind.HOVER if _hovered == index else PoseKind.SETTLE)


func _on_card_pressed(view: CardView) -> void:
	if _waiting or picking_disabled or _intro_playing or _closing:
		return
	var index := _views.find(view)
	if index < 0:
		return
	_picked[index] = not _picked[index]
	_refresh()
	_pose(index, PoseKind.PICK if _picked[index] else PoseKind.SETTLE)


## 確定ボタンの位置。誘導対局が押す場所として囲む(GameDesign.md 18章)。
func confirm_rect() -> Rect2:
	return _button.get_global_rect()


func _on_confirm_pressed() -> void:
	if _waiting or _intro_playing or _closing:
		return
	var indices: Array = []
	for i in _picked.size():
		if _picked[i]:
			indices.append(i)
	# 相手の確定を待つ間も画面は出したままにする(何を選んだかを見返せるようにするため)。
	_waiting = true
	_refresh()
	_lock_in()
	confirmed.emit(indices)


## 確定した瞬間、札を通常の姿勢へ戻し、選んだ/選ばないにかかわらず全体を少し落として「もう触れない」ことを伝える。
## 印は札の子だが `self_modulate` は子へ及ばないため、そのまま残る。
func _lock_in() -> void:
	_hovered = -1
	_pressed = -1
	_kill(_lock_tween)
	_lock_tween = create_tween()
	_lock_tween.set_parallel(true)
	for i in _views.size():
		_pose(i, PoseKind.SETTLE)
		_lock_tween.tween_property(_views[i], "self_modulate", LOCK_TINT, LOCK_DURATION)


## 札の姿勢を1つに決める: 沈み(選んだ)・ホバーの持ち上げ・押下の縮み。位置と拡大を1本の tween で動かす。
func _pose(index: int, kind: PoseKind) -> void:
	var view: CardView = _views[index]
	var y := _row_y(index)
	if _hovered == index:
		y -= PORTRAIT_HOVER_LIFT if _portrait else HOVER_LIFT
	var factor := 1.0
	if _pressed == index:
		factor = PRESS_SCALE
	elif _hovered == index:
		factor = HOVER_SCALE
	var duration := SETTLE_DURATION
	var trans := Tween.TRANS_BACK
	match kind:
		PoseKind.HOVER:
			duration = HOVER_DURATION
			trans = Tween.TRANS_CUBIC
		PoseKind.PRESS:
			duration = PRESS_DURATION
			trans = Tween.TRANS_SINE
		PoseKind.PICK:
			duration = PICK_DURATION
			trans = Tween.TRANS_SINE
	_kill(_pose_tweens.get(view))
	var tween := create_tween()
	tween.set_parallel(true)
	tween.set_trans(trans).set_ease(Tween.EASE_OUT)
	tween.tween_property(view, "position:y", y, duration)
	tween.tween_property(view, "scale", Vector2.ONE * factor, duration)
	_pose_tweens[view] = tween


## 向きを変えたときは、動いている姿勢を止めて素の大きさへ戻す。
func _reset_poses() -> void:
	for tween in _pose_tweens.values():
		_kill(tween)
	_pose_tweens.clear()
	_hovered = -1
	_pressed = -1
	for view in _views:
		view.scale = Vector2.ONE


## `animate` が false のときは見出しの差し替えを即座に行う(開いた直後は配る演出が動かしているため)。
func _refresh(animate: bool = true) -> void:
	var count := 0
	var reactive := _reactive()
	for i in _views.size():
		var view: CardView = _views[i]
		var picked: bool = _picked[i]
		if picked:
			count += 1
		view.enabled = not picked
		view.badge = "戻す" if picked else ""
		# 選んだ札も押せる(外せる)ので指のカーソルを出す。操作できない間は札へのホバーそのものを止める。
		view.mouse_filter = Control.MOUSE_FILTER_STOP if reactive else Control.MOUSE_FILTER_IGNORE
		view.mouse_default_cursor_shape = (
			Control.CURSOR_POINTING_HAND if reactive else Control.CURSOR_ARROW
		)
		_marks[i].set_shown(picked)
		view.queue_redraw()
	if _waiting:
		_set_texts("相手を待っています", "両者が確定すると対局が始まります", animate)
		_button.disabled = true
		_set_button_text("確定しました")
		return
	var hint := "すなえるの指示に従って、そのまま開始してください" if picking_disabled else "選んだカードは山札へ戻し、同じ枚数を引き直します"
	_set_texts("引き直すカードを選んでください", hint, animate)
	_button.disabled = false
	_set_button_text("このままで開始" if count == 0 else "%d枚を引き直す" % count)


func _set_texts(title: String, hint: String, animate: bool) -> void:
	if _title.text == title and _hint.text == hint:
		return
	_kill(_swap_tween)
	_kill(_wait_tween)
	if not animate:
		_title.text = title
		_hint.text = hint
		return
	_swap_tween = create_tween()
	_swap_tween.tween_property(_title, "modulate:a", 0.0, TEXT_SWAP_OUT)
	_swap_tween.parallel().tween_property(_hint, "modulate:a", 0.0, TEXT_SWAP_OUT)
	_swap_tween.tween_callback(
		func() -> void:
			_title.text = title
			_hint.text = hint
	)
	_swap_tween.tween_property(_title, "modulate:a", 1.0, TEXT_SWAP_IN)
	_swap_tween.parallel().tween_property(_hint, "modulate:a", 1.0, TEXT_SWAP_IN)
	_swap_tween.tween_callback(_start_wait_pulse)


## 相手を待つ間、見出しだけを往復させる。他は動かさない。
func _start_wait_pulse() -> void:
	if not _waiting or _closing:
		return
	_kill(_wait_tween)
	_wait_tween = create_tween().set_loops()
	var half := WAIT_PULSE_PERIOD * 0.5
	_wait_tween.tween_property(_title, "modulate:a", WAIT_PULSE_LOW, half).set_trans(
		Tween.TRANS_SINE
	)
	_wait_tween.tween_property(_title, "modulate:a", 1.0, half).set_trans(Tween.TRANS_SINE)


## 文言が実際に変わったときだけ脈打たせる。開いた直後の初回の設定では鳴らさない。
func _set_button_text(text: String) -> void:
	var changed := _button.text != text
	_button.text = text
	if changed and _button_text_set:
		_pulse_button()
	_button_text_set = true


func _pulse_button() -> void:
	_kill(_button_tween)
	_button.pivot_offset = _button.size * 0.5
	_button.scale = Vector2.ONE
	_button_tween = create_tween()
	(
		_button_tween
		. tween_property(_button, "scale", Vector2.ONE * BUTTON_PULSE_SCALE, BUTTON_PULSE_UP)
		. set_trans(Tween.TRANS_SINE)
	)
	_button_tween.tween_property(_button, "scale", Vector2.ONE, BUTTON_PULSE_DOWN).set_trans(
		Tween.TRANS_SINE
	)


func _build() -> void:
	_dim = ColorRect.new()
	_dim.color = Color(0, 0, 0, CardMatchLayout.OVERLAY_DIM_ALPHA)
	_dim.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(_dim)
	_stage = MulliganStageLight.new()
	add_child(_stage)

	_turn_order = _make_label(TURN_ORDER_FONT)
	_turn_order.add_theme_color_override("font_color", UiPalette.SAND_HI)
	_title = _make_label(40)
	_hint = _make_label(HINT_FONT)
	_hint.add_theme_color_override("font_color", UiPalette.GOLD)

	_button = CodedButton.make("このままで開始", BUTTON_SIZE)
	_button.pressed.connect(_on_confirm_pressed)
	add_child(_button)


func _make_label(font_size: int) -> Label:
	var label := Label.new()
	label.size = Vector2(_screen_size.x, font_size + 12)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", font_size)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(label)
	return label
