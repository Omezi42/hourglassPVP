class_name FlipReachOverlay
extends Control
## 反転時、行動した側の陣地から対象の駒へ向かって伸びる光の筋(GameDesign.md 9章、T-1)。
## 「相手の駒を反転させた場合、盤面を挟んで手を伸ばしたように見える」を実現するため、
## 始点・終点はMatchActionPresenter側でGameBoard.get_board_slot_rect()から求めた画面座標を
## そのまま受け取るだけで、位置の意味づけ自体は持たない。BoardTable/BarPanelと同じ
## 「Control._draw()のみのコード描画」方針(色はUiPalette、円の塗りはUiPaint経由)。
## GameBoardの最後の子として重ね、mouse_filter=IGNOREで盤面の操作を一切妨げない。

## 光が始点から終点へ伸びきるまでの時間。MatchActionPresenterはこの定数だけ待ってから
## HourglassSlot.play_flip_lift()を呼び、「光が届いた瞬間に持ち上がる」を実現する。
const REACH_DURATION := 0.2
## 伸びきった後、筋自体がフェードアウトするまでの時間。
const BEAM_FADE_DURATION := 0.25
## 着弾点で一瞬だけ膨らむ光の輪がフェードアウトするまでの時間。
const IMPACT_FADE_DURATION := 0.3

const BEAM_WIDTH := 4.0
const BEAM_GLOW_WIDTH := 12.0
const BEAM_GLOW_ALPHA_SCALE := 0.3
const IMPACT_RADIUS := 16.0
const IMPACT_GROWTH := 10.0

var _source := Vector2.ZERO
var _target := Vector2.ZERO
var _beam_progress := 0.0
var _beam_alpha := 0.0
var _impact_alpha := 0.0
var _beam_tween: Tween
var _impact_tween: Tween


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE


## source/target はGameBoard基準のグローバル座標(get_board_slot_rect().get_center()等)を
## そのまま渡してよい(このオーバーレイ内でローカル座標へ変換する。Controlはto_local()を
## 持たないため、CanvasItem.get_global_transform()の逆変換を使う)。
func play_reach(source_global: Vector2, target_global: Vector2) -> void:
	if _beam_tween != null and _beam_tween.is_valid():
		_beam_tween.kill()
	if _impact_tween != null and _impact_tween.is_valid():
		_impact_tween.kill()
	var inverse := get_global_transform().affine_inverse()
	_source = inverse * source_global
	_target = inverse * target_global
	_beam_progress = 0.0
	_beam_alpha = 1.0
	_impact_alpha = 0.0
	queue_redraw()

	_beam_tween = create_tween()
	_beam_tween.tween_method(_set_beam_progress, 0.0, 1.0, REACH_DURATION)
	_beam_tween.tween_callback(_flash_impact)
	_beam_tween.tween_method(_set_beam_alpha, 1.0, 0.0, BEAM_FADE_DURATION)


func _set_beam_progress(value: float) -> void:
	_beam_progress = value
	queue_redraw()


func _set_beam_alpha(value: float) -> void:
	_beam_alpha = value
	queue_redraw()


## 光が届いた瞬間、着弾点に一瞬だけ光の輪を膨らませる(HourglassSlot.play_flip_lift()の
## 持ち上げと同じタイミングで始まるよう、REACH_DURATION経過後にこの関数が呼ばれる)。
func _flash_impact() -> void:
	_impact_alpha = 1.0
	queue_redraw()
	_impact_tween = create_tween()
	_impact_tween.tween_method(_set_impact_alpha, 1.0, 0.0, IMPACT_FADE_DURATION)


func _set_impact_alpha(value: float) -> void:
	_impact_alpha = value
	queue_redraw()


func _draw() -> void:
	if _beam_alpha <= 0.0 and _impact_alpha <= 0.0:
		return
	var ci := get_canvas_item()
	if _beam_alpha > 0.0 and _beam_progress > 0.0 and _source != _target:
		var tip := _source.lerp(_target, _beam_progress)
		var color := Color(
			UiPalette.GLOW_AMBER.r, UiPalette.GLOW_AMBER.g, UiPalette.GLOW_AMBER.b, _beam_alpha
		)
		var glow := Color(color.r, color.g, color.b, color.a * BEAM_GLOW_ALPHA_SCALE)
		draw_line(_source, tip, glow, BEAM_GLOW_WIDTH, true)
		draw_line(_source, tip, color, BEAM_WIDTH, true)
	if _impact_alpha > 0.0:
		var impact_color := Color(
			UiPalette.GLOW_AMBER.r,
			UiPalette.GLOW_AMBER.g,
			UiPalette.GLOW_AMBER.b,
			_impact_alpha * 0.85
		)
		var radius := IMPACT_RADIUS + (1.0 - _impact_alpha) * IMPACT_GROWTH
		UiPaint.fill_circle(ci, _target, radius, impact_color, 20)
