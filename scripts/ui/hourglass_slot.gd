class_name HourglassSlot
extends Control

signal slot_pressed
## 操作可否(_interactive)に関わらず、駒が置かれているマスがクリックされるたびに発火する
## (GameDesign.md 9章「対局中も、駒をクリックすればその駒の効果詳細を確認できる」)。
## 既存のslot_pressed(アクション選択用)とは独立して発火するため、選択導線を変更しない。
signal info_requested

const FLIP_HALF_DURATION := 0.12
const SPIN_DURATION := 0.5
const PEDESTAL_RING_COUNT := 3
## 移動先候補ハイライトの明滅(選択中のFrameとは別プロパティ・別ノードで表現する)。
const MOVE_TARGET_PULSE_MIN_ALPHA := 0.35
const MOVE_TARGET_PULSE_MAX_ALPHA := 0.9
const MOVE_TARGET_PULSE_DURATION := 0.6
## 操作できないタイミングで押された時の拒否演出。ホバー演出が使うposition(自分自身)とは
## 別に、子ノード(Icon)のposition:xだけを揺らすことでプロパティの競合を避ける。
const REJECT_SHAKE_OFFSET := 4.0
const REJECT_SHAKE_STEP_DURATION := 0.05
## 控え表示時、アイコンの彩度・明度を落としてわずかに透過させる(場と控えを見分けるため)。
## ホバー/押下演出は自分自身(Control)のmodulate/scaleを使うため、こちらは子のIconに
## 適用して競合を避ける。
const BENCH_ICON_TINT := Color(0.72, 0.72, 0.76, 0.82)
const BOARD_ICON_TINT := Color(1.0, 1.0, 1.0, 1.0)
## 控えの台座は場より控えめに(光量を落とす)。
const BENCH_PEDESTAL_SCALE := 0.6
## 「出撃中」ゴースト表示(HourglassSlotStripの場側3枠)は、控えよりさらに沈めて
## 参照専用であることを示す。バッジ・台座光は出さないため、ここでは彩度・アルファのみ使う。
const GHOST_ICON_TINT := Color(0.55, 0.55, 0.6, 0.4)
## 落ちきりダメージの発生源であることを示す一瞬の光。既存のFrame/MoveTargetFrameとは
## 別ノード(FallFlash)のmodulate:aを使うため、選択中枠・移動先ハイライトと競合しない。
const FALL_FLASH_PEAK_ALPHA := 0.85
const FALL_FLASH_IN_DURATION := 0.08
const FALL_FLASH_OUT_DURATION := 0.35

## 「落下中」の駒は次のターン進行で必ず「落ちきり」に到達しダメージが発生するため、
## 専用リング(FallWarningRing)で常時予告する(P-1)。敵味方で色を描き分ける:
## 相手の駒(自分がダメージを受ける)=危険色、自分の駒(相手にダメージを与える)=有利色。
const FALL_WARNING_HOSTILE_COLOR := Color(0.95, 0.28, 0.28, 1.0)
const FALL_WARNING_FRIENDLY_COLOR := Color(0.35, 0.85, 0.95, 1.0)
const FALL_WARNING_MIN_ALPHA := 0.25
const FALL_WARNING_MAX_ALPHA := 0.95
const FALL_WARNING_PULSE_DURATION := 0.5

## 自分の手番中、操作可能な駒であることを示すごく弱い脈動(P-7)。icon.modulateは
## 控え/ゴースト表示の彩度調整に使っているため、競合しないicon.self_modulateを使う。
const OPERABLE_PULSE_MIN_ALPHA := 0.82
const OPERABLE_PULSE_DURATION := 0.9

## ターン進行の逐次演出中、解決中のマスへ視線誘導するスポットライト(P-2)。
const SPOTLIGHT_DIM_COLOR := Color(0.42, 0.42, 0.42, 1.0)
const SPOTLIGHT_FOCUS_SCALE := 1.08
const SPOTLIGHT_TRANSITION_DURATION := 0.25

## 行動演出(移動/交代)で駒が定位置へ滑り込む時間(フェーズ14 S-2)。
const SLIDE_IN_DURATION := 0.3
## 滑り込み中は、通り道にある他のマスの駒より手前へ出す(すれ違いで隠れないようにする)。
const SLIDE_Z_INDEX := 1

## 反転演出(T-1)。光の筋が届いた瞬間に駒を持ち上げ、着地させるまでの時間。scaleは
## MatchActionPresenter._spotlight()が同じ瞬間にvisual_root.scaleをスポットライト用に
## 動かしているため、ここではposition:yのみを動かして競合を避ける
## (「VisualRootのposition/scaleだけを動かす」制約のうち、positionのみを使う判断)。
const FLIP_LIFT_HEIGHT := 16.0
const FLIP_LIFT_UP_DURATION := 0.14
const FLIP_LIFT_DOWN_DURATION := 0.18

## 予約マーク(GameDesign.md 4.3・9章)。行動を設定した瞬間に、そのマスへ何を設定したかを出す。
const RESERVATION_LABELS := {"flip": "反転", "move": "移動", "swap_in": "交代"}
## 配置フェーズで、そのマスに置いた駒がどの状態から始まるのか(GameDesign.md 5章)を示す文言。
const PLACEMENT_STATE_LABELS := {
	GameEnums.HourglassState.UPRIGHT: "上向きで開始",
	GameEnums.HourglassState.FALLING: "落下中で開始",
	GameEnums.HourglassState.FALLEN: "落ちきりで開始",
}
const RESERVATION_POP_SCALE := 1.6
const RESERVATION_POP_DURATION := 0.25

## 駒ごとの砂の色を、イラストから1度だけサンプリングして使い回す。
static var _accent_cache: Dictionary = {}

var _last_state: int = -1
var _accent := UiPalette.PEDESTAL_DEFAULT_ACCENT
var _has_piece := false
var _is_bench := false
## 盤面イラスト(祭壇テーブル)に台座が既に描かれている場では、自前描画の光る台座は
## 二重になるため消す。控えは背景に台座が無いため既定でtrueのまま使う。
var _show_pedestal := true

var _press_tracker := PressTracker.new()
var _interactive := true
var _reject_feedback := false
var _hovering := false
var _rest_position := Vector2.ZERO
var _move_target_tween: Tween
var _reject_shake_tween: Tween
var _fall_flash_tween: Tween
var _fall_warning_tween: Tween
var _fall_warning_style: StyleBoxFlat
var _operable_pulse_tween: Tween
var _spotlight_tween: Tween
var _slide_tween: Tween
var _flip_lift_tween: Tween
var _reservation_tween: Tween

## ホバー/押下のTween先。コンテナ(BoardRow/HourglassSlotStrip等)の直接の子である自分自身の
## position/scaleを外部から動かすと再レイアウト時に崩れるため、見た目専用の
## VisualRootへ逃がす(shake_rejected()が子のIconだけを揺らすのと同じ回避パターン)。
@onready var visual_root: Control = $VisualRoot
@onready var frame: Panel = $VisualRoot/Frame
@onready var move_target_frame: Panel = $VisualRoot/MoveTargetFrame
@onready var icon: TextureRect = $VisualRoot/Icon
@onready var lock_icon: Label = $VisualRoot/LockIcon
@onready var damage_badge: Label = $VisualRoot/DamageBadge
@onready var fall_flash: Panel = $VisualRoot/FallFlash
@onready var fall_warning_ring: Panel = $VisualRoot/FallWarningRing
@onready var reservation_badge: Label = $VisualRoot/ReservationBadge
@onready var placement_state_label: Label = $VisualRoot/PlacementStateLabel


func _ready() -> void:
	resized.connect(_on_resized)
	mouse_entered.connect(_on_mouse_entered)
	mouse_exited.connect(_on_mouse_exited)
	_fall_warning_style = StyleBoxFlat.new()
	_fall_warning_style.bg_color = Color(0, 0, 0, 0)
	_fall_warning_style.border_width_left = 3
	_fall_warning_style.border_width_top = 3
	_fall_warning_style.border_width_right = 3
	_fall_warning_style.border_width_bottom = 3
	_fall_warning_style.corner_radius_top_left = 10
	_fall_warning_style.corner_radius_top_right = 10
	_fall_warning_style.corner_radius_bottom_right = 10
	_fall_warning_style.corner_radius_bottom_left = 10
	fall_warning_ring.add_theme_stylebox_override("panel", _fall_warning_style)
	set_interactive(true)


func _gui_input(event: InputEvent) -> void:
	# 操作不可時(相手の手番待ち・観戦・リプレイ再生中など)でも、詳細確認のためのクリックは
	# 常に受け付ける。押下トラッカーは非操作時も共通で使い、確定(CONFIRMED)したら
	# info_requestedを発火するだけに留め、選択アニメーション・slot_pressedは出さない。
	var result: PressTracker.Result = _press_tracker.feed(event, size)
	if not _interactive:
		if _reject_feedback and ClickArea.is_primary_click(event):
			shake_rejected()
		if result == PressTracker.Result.CONFIRMED and _has_piece:
			info_requested.emit()
		return
	match result:
		PressTracker.Result.PRESSED:
			ClickArea.animate_press(visual_root, true)
		PressTracker.Result.CONFIRMED:
			ClickArea.animate_press(visual_root, false)
			slot_pressed.emit()
			if _has_piece:
				info_requested.emit()
		PressTracker.Result.CANCELED:
			ClickArea.animate_press(visual_root, false)


## 控え(場より控えめな表示にするマス)かどうかを設定する。HourglassSlotStripが自分のスロットに
## 対して呼び出す想定で、駒の見た目(アイコンの彩度・台座の光量)にのみ影響する。
func set_bench_mode(bench: bool) -> void:
	_is_bench = bench
	icon.modulate = BENCH_ICON_TINT if bench else BOARD_ICON_TINT
	queue_redraw()


## 台座イラストが既にある場所(盤面パネル上)に置く駒はfalseにして、自前描画の光る台座を消す。
func set_pedestal_visible(pedestal_visible: bool) -> void:
	_show_pedestal = pedestal_visible
	queue_redraw()


## 操作できない間(相手の手番待ち・観戦・リプレイ再生中など)は、押せると誤解させないよう
## ホバー表現とカーソル変更を止める。reject_feedbackがtrueの間だけ、押された時に
## shake_rejected()で「今は押せない」ことを伝える(対局中に自分の手番でない場合のみ想定)。
func set_interactive(interactive: bool, reject_feedback: bool = false) -> void:
	_interactive = interactive
	_reject_feedback = reject_feedback and not interactive
	mouse_default_cursor_shape = (
		Control.CURSOR_POINTING_HAND if interactive else Control.CURSOR_ARROW
	)
	if not interactive and _hovering:
		_on_mouse_exited()
	_apply_operable_pulse()


## 自分の手番中、操作可能な駒(自分の場・相手の場・控え)にごく弱い脈動を出し、
## 初見でも「押せる」ことに気付けるようにする(P-7)。
func _apply_operable_pulse() -> void:
	if _interactive and _has_piece:
		if _operable_pulse_tween != null and _operable_pulse_tween.is_valid():
			return
		icon.self_modulate.a = 1.0
		_operable_pulse_tween = create_tween()
		_operable_pulse_tween.set_loops()
		_operable_pulse_tween.tween_property(
			icon, "self_modulate:a", OPERABLE_PULSE_MIN_ALPHA, OPERABLE_PULSE_DURATION
		)
		_operable_pulse_tween.tween_property(icon, "self_modulate:a", 1.0, OPERABLE_PULSE_DURATION)
	else:
		if _operable_pulse_tween != null and _operable_pulse_tween.is_valid():
			_operable_pulse_tween.kill()
		icon.self_modulate.a = 1.0


## 移動先候補であることを示す(選択中を示すFrameとは別ノード・別色で表現し、
## 選択中のマスと混同しないようにする)。
func set_move_target(active: bool) -> void:
	move_target_frame.visible = active
	if active:
		_start_move_target_pulse()
	else:
		_stop_move_target_pulse()


func _start_move_target_pulse() -> void:
	if _move_target_tween != null and _move_target_tween.is_valid():
		_move_target_tween.kill()
	move_target_frame.modulate.a = MOVE_TARGET_PULSE_MAX_ALPHA
	_move_target_tween = create_tween()
	_move_target_tween.set_loops()
	_move_target_tween.tween_property(
		move_target_frame, "modulate:a", MOVE_TARGET_PULSE_MIN_ALPHA, MOVE_TARGET_PULSE_DURATION
	)
	_move_target_tween.tween_property(
		move_target_frame, "modulate:a", MOVE_TARGET_PULSE_MAX_ALPHA, MOVE_TARGET_PULSE_DURATION
	)


func _stop_move_target_pulse() -> void:
	if _move_target_tween != null and _move_target_tween.is_valid():
		_move_target_tween.kill()
	move_target_frame.modulate.a = 1.0


## 操作できないタイミングで押された時の拒否演出。子ノード(Icon)のposition:xだけを
## 揺らして戻すため、自分自身(HourglassSlot)のposition(ホバー演出が使用中)とは競合しない。
## 揺れ中の連打は既存のTweenが残っている間は無視する。
func shake_rejected() -> void:
	if _reject_shake_tween != null and _reject_shake_tween.is_valid():
		return
	var base_x := icon.position.x
	_reject_shake_tween = create_tween()
	_reject_shake_tween.tween_property(
		icon, "position:x", base_x - REJECT_SHAKE_OFFSET, REJECT_SHAKE_STEP_DURATION
	)
	_reject_shake_tween.tween_property(
		icon, "position:x", base_x + REJECT_SHAKE_OFFSET, REJECT_SHAKE_STEP_DURATION
	)
	_reject_shake_tween.tween_property(
		icon, "position:x", base_x - REJECT_SHAKE_OFFSET * 0.5, REJECT_SHAKE_STEP_DURATION
	)
	_reject_shake_tween.tween_property(icon, "position:x", base_x, REJECT_SHAKE_STEP_DURATION)


## この駒が落ちきってダメージを発生させたことを示す一瞬の光。プレイヤーが「どの駒が
## 原因でダメージが出たか」を追えるよう、飛んでいく浮遊数字と合わせてMatchScreenから呼ばれる。
func flash_fall_damage() -> void:
	if _fall_flash_tween != null and _fall_flash_tween.is_valid():
		_fall_flash_tween.kill()
	fall_flash.modulate.a = 0.0
	_fall_flash_tween = create_tween()
	_fall_flash_tween.tween_property(
		fall_flash, "modulate:a", FALL_FLASH_PEAK_ALPHA, FALL_FLASH_IN_DURATION
	)
	_fall_flash_tween.tween_property(fall_flash, "modulate:a", 0.0, FALL_FLASH_OUT_DURATION)


## 行動演出(移動/交代)用。駒の内容は既に新しいマスへ反映済みである前提で、見た目だけを
## offsetぶんずらした位置から定位置へ滑り込ませる(フェーズ14 S-2)。動かすのはホバー演出と
## 同じVisualRootのpositionだが、この演出中の盤面は非操作(_interactive=false)のため競合しない。
## arc_heightを与えると、直線ではなくその高さぶん上へ膨らむ弧を通る(正で上、負で下)。
## 移動で入れ替わる2駒は互いに逆向きの弧を指定し、すれ違う瞬間に重なって消えるのを防ぐ。
func play_slide_in(offset: Vector2, arc_height: float = 0.0) -> void:
	if _slide_tween != null and _slide_tween.is_valid():
		_slide_tween.kill()
	visual_root.z_index = SLIDE_Z_INDEX
	_apply_slide_progress(offset, arc_height, 0.0)
	_slide_tween = create_tween()
	_slide_tween.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
	_slide_tween.tween_method(
		func(t: float) -> void: _apply_slide_progress(offset, arc_height, t),
		0.0,
		1.0,
		SLIDE_IN_DURATION
	)
	_slide_tween.tween_callback(func() -> void: visual_root.z_index = 0)


func _apply_slide_progress(offset: Vector2, arc_height: float, progress: float) -> void:
	var arc := Vector2(0.0, -sin(progress * PI) * arc_height)
	visual_root.position = _rest_position + offset.lerp(Vector2.ZERO, progress) + arc


## 反転(GameDesign.md 9章、T-1)。行動した側から伸びる光の筋(FlipReachOverlay)が届いた
## 瞬間に呼ばれ、駒を持ち上げて着地させる。VisualRootのposition:yのみを動かし、GameStateの
## 状態にも既存の_animate_flip()(アイコン自体の回転、show_instance()経由で別途進行中)にも
## 触れない。play_slide_in()と同じVisualRoot.positionを使うため、互いのTweenを止め合う。
func play_flip_lift() -> void:
	if _slide_tween != null and _slide_tween.is_valid():
		_slide_tween.kill()
	if _flip_lift_tween != null and _flip_lift_tween.is_valid():
		_flip_lift_tween.kill()
	visual_root.position = _rest_position
	visual_root.z_index = SLIDE_Z_INDEX
	_flip_lift_tween = create_tween()
	_flip_lift_tween.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	_flip_lift_tween.tween_property(
		visual_root, "position:y", _rest_position.y - FLIP_LIFT_HEIGHT, FLIP_LIFT_UP_DURATION
	)
	_flip_lift_tween.set_ease(Tween.EASE_IN)
	_flip_lift_tween.tween_property(
		visual_root, "position:y", _rest_position.y, FLIP_LIFT_DOWN_DURATION
	)
	_flip_lift_tween.tween_callback(func() -> void: visual_root.z_index = 0)


## 「落下中」の駒に、次の進行で必ず落ちきりダメージが発生することを予告する(P-1)。
## hostile=trueは相手の駒(自分がダメージを受ける)、falseは自分の駒(相手にダメージを与える)。
func set_falling_warning(active: bool, hostile: bool) -> void:
	if not active:
		_stop_falling_warning()
		return
	fall_warning_ring.visible = true
	_fall_warning_style.border_color = (
		FALL_WARNING_HOSTILE_COLOR if hostile else FALL_WARNING_FRIENDLY_COLOR
	)
	if _fall_warning_tween != null and _fall_warning_tween.is_valid():
		return
	fall_warning_ring.modulate.a = FALL_WARNING_MAX_ALPHA
	_fall_warning_tween = create_tween()
	_fall_warning_tween.set_loops()
	_fall_warning_tween.tween_property(
		fall_warning_ring, "modulate:a", FALL_WARNING_MIN_ALPHA, FALL_WARNING_PULSE_DURATION
	)
	_fall_warning_tween.tween_property(
		fall_warning_ring, "modulate:a", FALL_WARNING_MAX_ALPHA, FALL_WARNING_PULSE_DURATION
	)


func _stop_falling_warning() -> void:
	if _fall_warning_tween != null and _fall_warning_tween.is_valid():
		_fall_warning_tween.kill()
	fall_warning_ring.visible = false
	fall_warning_ring.modulate.a = 1.0


## ターン進行の逐次演出中、解決中のマスへ視線誘導する(P-2)。focused=trueは今再生中の
## マス自体、dimmed=trueはそれ以外のマスを一段暗くする。両方falseで通常表示へ戻る。
func set_spotlight(focused: bool, dimmed: bool) -> void:
	if _spotlight_tween != null and _spotlight_tween.is_valid():
		_spotlight_tween.kill()
	_spotlight_tween = create_tween()
	var target_modulate := SPOTLIGHT_DIM_COLOR if dimmed else Color.WHITE
	var target_scale := Vector2.ONE * (SPOTLIGHT_FOCUS_SCALE if focused else 1.0)
	_spotlight_tween.tween_property(
		visual_root, "modulate", target_modulate, SPOTLIGHT_TRANSITION_DURATION
	)
	_spotlight_tween.parallel().tween_property(
		visual_root, "scale", target_scale, SPOTLIGHT_TRANSITION_DURATION
	)


func clear_spotlight() -> void:
	set_spotlight(false, false)


func _on_resized() -> void:
	queue_redraw()
	visual_root.pivot_offset = visual_root.size / 2.0
	if not _hovering:
		_rest_position = visual_root.position


func _on_mouse_entered() -> void:
	if not _interactive:
		return
	_hovering = true
	ClickArea.animate_hover(visual_root, true, _rest_position)


func _on_mouse_exited() -> void:
	_hovering = false
	ClickArea.animate_hover(visual_root, false, _rest_position)


## 駒の足元に、砂の色に合わせた光の台座を描く(盤面に置かれている感を出すため)。
## 楕円の点列生成・塗りはUiPaint.fill_ellipse(BoardTableの隅飾りと共通)へ委譲する
## (フェーズ12 Q-6)。_accentは駒ごとにイラストからサンプリングした色(UiPalette定数では
## ないため、ここではそのまま使う。既定値のみUiPalette.PEDESTAL_DEFAULT_ACCENTを参照)。
func _draw() -> void:
	if not _has_piece or not _show_pedestal:
		return
	var ci := get_canvas_item()
	var center := Vector2(size.x * 0.5, size.y * 0.9)
	var pedestal_scale := BENCH_PEDESTAL_SCALE if _is_bench else 1.0
	var radius := Vector2(size.x * 0.36, size.x * 0.1) * pedestal_scale
	for ring in range(PEDESTAL_RING_COUNT, 0, -1):
		var scale_factor := 1.0 + ring * 0.35
		var alpha := 0.1 / ring
		UiPaint.fill_ellipse(ci, center, radius * scale_factor, Color(_accent, alpha), 24)
	UiPaint.fill_ellipse(ci, center, radius, Color(_accent, 0.55), 24)


func show_instance(instance: HourglassInstance) -> void:
	visible = true
	_has_piece = true
	_show_placement_state(-1)
	_accent = _accent_for(instance.data)
	damage_badge.visible = true
	damage_badge.text = str(instance.data.fall_damage)
	queue_redraw()

	if _last_state == -1:
		_last_state = instance.state
		_update_icon(instance.data, instance.state)
		return
	if _last_state != instance.state:
		_last_state = instance.state
		_animate_state_change(instance.data, instance.state)
	else:
		_update_icon(instance.data, instance.state)


## 場に出ている駒を表す「出撃中」の参照専用表示(HourglassSlotStrip用)。実際の状態
## (上向き/落下中/落ちきり)は盤面本体(BoardRow)側が管理するため、ここでは常に
## 上向きイラストを固定表示し、バッジ・台座光など操作対象であるかのような情報は出さない。
func show_deployed(data: HourglassData) -> void:
	visible = true
	_has_piece = true
	_show_placement_state(-1)
	damage_badge.visible = false
	icon.texture = data.icon_upright
	icon.modulate = GHOST_ICON_TINT
	set_pedestal_visible(false)
	_stop_falling_warning()
	queue_redraw()


## ターン進行の逐次演出(GameDesign.md 9章)用。GameStateは一括で処理を終えるため、
## instance.stateは呼び出し時点で既に最終値へ進んでいることがある。そのため
## show_instance()のようにinstanceから読むのではなく、イベントごとに記録した
## new_stateを明示的な引数で受け取り、1マスずつ正しい遷移を再現できるようにする。
func show_state_step(data: HourglassData, new_state: int) -> void:
	visible = true
	_has_piece = true
	_accent = _accent_for(data)
	damage_badge.visible = true
	damage_badge.text = str(data.fall_damage)
	queue_redraw()

	if _last_state == new_state:
		_update_icon(data, new_state)
		return
	_last_state = new_state
	_animate_state_change(data, new_state)


## 配置フェーズ用の表示。対局前のため状態遷移は無く、そのマスの初期状態のイラストと
## 落下ダメージのバッジを表示する(HourglassSlotStripの手札5枠・GameBoardの自分の場3マスの
## 両方で使う)。start_stateが負のとき(まだ置き場所が決まっていない手札)は、どの状態から
## 始まるかが決まっていないため上向きイラストを使い、状態名も出さない。
func show_placement_card(data: HourglassData, start_state: int = -1) -> void:
	visible = true
	_has_piece = true
	_accent = _accent_for(data)
	var icon_state: int = start_state if start_state >= 0 else GameEnums.HourglassState.UPRIGHT
	_last_state = icon_state
	damage_badge.visible = true
	damage_badge.text = str(data.fall_damage)
	_update_icon(data, icon_state)
	icon.modulate = BOARD_ICON_TINT
	set_pedestal_visible(true)
	set_move_target(false)
	_stop_falling_warning()
	_show_placement_state(start_state)
	queue_redraw()


## 配置フェーズ用。自分の場の空きマス(まだ何も置かれていないマス)であることを示す。
## クリック可能であることが一目で分かるよう、既存のMoveTargetFrame(移動先ハイライト)と
## 同じ明滅表現を流用する(J-15)。clear()と異なりvisible=trueのままにする点が重要で、
## Godotは非表示のControlに入力イベントを渡さないため、clear()のままでは配置候補マスへの
## クリックがそもそも届かなかった(この不具合の修正を兼ねる)。
func show_placement_empty(start_state: int = -1) -> void:
	visible = true
	_has_piece = false
	icon.texture = null
	damage_badge.visible = false
	set_locked(false)
	set_selected(false)
	set_move_target(true)
	_stop_falling_warning()
	_show_placement_state(start_state)
	queue_redraw()


## 配置フェーズ専用の状態名を出す。start_stateが負のときは何も出さない。配置フェーズ以外の
## 表示経路(show_instance/show_deployed/show_state_step/clear)は必ずこれを負で呼び、
## 対局が始まったらラベルが残らないようにする。
func _show_placement_state(start_state: int) -> void:
	var text: String = PLACEMENT_STATE_LABELS.get(start_state, "")
	placement_state_label.text = text
	placement_state_label.visible = text != ""


func clear() -> void:
	visible = false
	_has_piece = false
	_show_placement_state(-1)
	icon.texture = null
	_last_state = -1
	damage_badge.visible = false
	set_selected(false)
	set_locked(false)
	set_move_target(false)
	_stop_falling_warning()
	_apply_operable_pulse()
	if _fall_flash_tween != null and _fall_flash_tween.is_valid():
		_fall_flash_tween.kill()
	fall_flash.modulate.a = 0.0
	# 非表示化のタイミング次第でmouse_exitedが飛ばないことがあるため、見た目を明示的に戻す
	_hovering = false
	visual_root.modulate = Color(1.0, 1.0, 1.0, 1.0)
	visual_root.scale = Vector2.ONE
	icon.position.x = 0.0
	queue_redraw()


func set_locked(locked: bool) -> void:
	lock_icon.visible = locked


## このマスに設定された行動(GameDesign.md 4.3)を予約マークとして表示する。kindが空文字なら
## 何も設定されていない状態として非表示にする。行動は指した瞬間には適用されず、
## ターン終了時の解決で初めて盤面が動くため、それまでの間これが唯一の手がかりになる。
func set_reservation(kind: String) -> void:
	var label: String = RESERVATION_LABELS.get(kind, "")
	reservation_badge.visible = label != ""
	if label == "":
		return
	if reservation_badge.text != label:
		reservation_badge.text = label
		_play_reservation_pop()


func _play_reservation_pop() -> void:
	if _reservation_tween != null and _reservation_tween.is_valid():
		_reservation_tween.kill()
	reservation_badge.pivot_offset = reservation_badge.size * 0.5
	reservation_badge.scale = Vector2(RESERVATION_POP_SCALE, RESERVATION_POP_SCALE)
	_reservation_tween = create_tween()
	_reservation_tween.set_trans(Tween.TRANS_BACK)
	_reservation_tween.set_ease(Tween.EASE_OUT)
	_reservation_tween.tween_property(
		reservation_badge, "scale", Vector2.ONE, RESERVATION_POP_DURATION
	)


func set_selected(selected: bool) -> void:
	frame.visible = selected


func _animate_state_change(data: HourglassData, state: int) -> void:
	icon.pivot_offset = icon.size / 2
	if state == GameEnums.HourglassState.UPRIGHT:
		_animate_flip(data, state)
	else:
		var tween := create_tween()
		tween.tween_property(icon, "scale:x", 0.0, FLIP_HALF_DURATION)
		tween.tween_callback(_update_icon.bind(data, state))
		tween.tween_property(icon, "scale:x", 1.0, FLIP_HALF_DURATION)


## 反転(どの状態からでも上向きに戻る)専用の演出。実際に手でひっくり返す動きを
## 感じさせるため、アイコン差し替えのフリップに加えて1回転させる。
func _animate_flip(data: HourglassData, state: int) -> void:
	icon.rotation_degrees = 0.0
	var tween := create_tween()
	tween.set_trans(Tween.TRANS_CUBIC)
	tween.set_ease(Tween.EASE_OUT)
	tween.tween_property(icon, "rotation_degrees", 360.0, SPIN_DURATION)
	tween.parallel().tween_property(icon, "scale:x", 0.0, SPIN_DURATION * 0.5)
	tween.tween_callback(_update_icon.bind(data, state))
	tween.tween_property(icon, "scale:x", 1.0, SPIN_DURATION * 0.5)
	tween.tween_callback(func() -> void: icon.rotation_degrees = 0.0)


func _update_icon(data: HourglassData, state: int) -> void:
	match state:
		GameEnums.HourglassState.UPRIGHT:
			icon.texture = data.icon_upright
		GameEnums.HourglassState.FALLING:
			icon.texture = data.icon_falling
		GameEnums.HourglassState.FALLEN:
			icon.texture = data.icon_fallen


## 落下中アイコンの砂の部分の色を、その駒のアクセントカラー(足元の台座光)として扱う。
## 駒ごとに新しいデータを持たせず、既存のイラストから自動で色を合わせるため。
func _accent_for(data: HourglassData) -> Color:
	if _accent_cache.has(data.id):
		return _accent_cache[data.id]

	var color := UiPalette.PEDESTAL_DEFAULT_ACCENT
	if data.icon_falling != null:
		var image := data.icon_falling.get_image()
		if image != null:
			var sample := image.get_pixel(image.get_width() / 2, int(image.get_height() * 0.55))
			if sample.a < 0.5:
				sample = image.get_pixel(image.get_width() / 2, image.get_height() / 2)
			sample.a = 1.0
			color = sample

	_accent_cache[data.id] = color
	return color
