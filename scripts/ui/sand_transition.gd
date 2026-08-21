class_name SandTransition
extends Control
## タイトル画面からホーム画面へ移るときだけ使う専用トランジション(GameDesign.md 9章)。
## 画面を上から金色の砂が満たし、切り替わった後に砂が下へ抜けていく。
## 砂時計というモチーフをそのまま画面の切り替えに使うため、他画面の
## クロスフェード(Main._show_only)とは別に用意している。
##
## 描画は_draw()のみのコード描画で、色はUiPalette、図形はUiPaintを経由する
## (BoardTable/BarPanel/FlipReachOverlayと同じ流儀)。

## 砂が画面を覆いきるまで。覆った瞬間に画面を差し替えるため、長すぎると待たされて感じる。
const COVER_DURATION := 0.62
## 砂が引いて次の画面が現れるまで。覆うときよりゆっくりにして、
## 「満ちる」より「流れ落ちる」ほうを見せ場にする。
const REVEAL_DURATION := 0.78
## 砂面の手前に散る砂粒の数。
const GRAIN_COUNT := 210
## 砂の中を縦に走る流れ線の数。
const STREAK_COUNT := 44
## 砂面のうねりの振幅(px)。
const WAVE_AMPLITUDE := 13.0
## 砂面を折れ線で近似するときの分割数。
const EDGE_SEGMENTS := 40
## 砂の色。奥ほど暗く、砂面へ向かうほど明るい琥珀になる。
## 段ごとの単色塗りだと帯の境目が縞に見えるため、頂点カラーで補間して塗る。
const SAND_DEEP := Color(0.16, 0.09, 0.04, 1.0)
const SAND_MID := Color(0.5, 0.32, 0.12, 1.0)
const SAND_SURFACE := Color(0.95, 0.75, 0.36, 1.0)
## 奥から砂面までのうち、SAND_MIDへ到達する位置。
const MID_STOP := 0.55

var _progress := 0.0
var _revealing := false
## x比率・うねりの位相・半径。毎フレーム乱数を引くとちらつくため先に決めておく。
var _grains: PackedVector3Array = PackedVector3Array()
## x比率・長さ比率。
var _streaks: PackedVector2Array = PackedVector2Array()
var _tween: Tween


func _ready() -> void:
	# アンカーは直接代入する。set_anchors_preset()は「今の矩形を保つように」offsetを
	# 計算し直すため、コードで生成した直後(サイズ0)のノードでは0サイズのまま固定される。
	anchor_right = 1.0
	anchor_bottom = 1.0
	# 砂が出ている間は下の画面を触らせない。遷移中の誤操作を防ぐ役目も兼ねる。
	mouse_filter = Control.MOUSE_FILTER_STOP
	visible = false
	var rng := RandomNumberGenerator.new()
	rng.seed = 20260821
	for i in range(GRAIN_COUNT):
		_grains.append(Vector3(rng.randf(), rng.randf() * TAU, rng.randf_range(1.2, 3.6)))
	for i in range(STREAK_COUNT):
		_streaks.append(Vector2(rng.randf(), rng.randf_range(0.15, 0.55)))


## 砂が上から降りて画面を覆いきるまで待つ。
func cover() -> void:
	_revealing = false
	visible = true
	await _run()


## 覆っていた砂が下へ抜けて消えるまで待つ。
func reveal() -> void:
	_revealing = true
	visible = true
	await _run()
	visible = false


func _run() -> void:
	if _tween != null and _tween.is_valid():
		_tween.kill()
	_progress = 0.0
	queue_redraw()
	var duration := REVEAL_DURATION if _revealing else COVER_DURATION
	_tween = create_tween()
	_tween.set_trans(Tween.TRANS_CUBIC)
	_tween.set_ease(Tween.EASE_IN_OUT)
	_tween.tween_method(_set_progress, 0.0, 1.0, duration)
	await _tween.finished


func _set_progress(value: float) -> void:
	_progress = value
	queue_redraw()


func _draw() -> void:
	var height := size.y
	if height <= 0.0:
		return
	# 砂面の位置。覆うときは上から降りてきて、引くときは同じ向きに下へ抜けていく。
	var edge := _progress * height
	var wave := WAVE_AMPLITUDE * (1.0 - absf(_progress * 2.0 - 1.0))
	var edge_points := _edge_points(edge, wave)
	_draw_body(edge_points, height)
	_draw_streaks(edge, height)
	_draw_surface(edge_points)
	_draw_grains(edge, wave)


## 砂面を左右に走る折れ線として求める。うねりは2つの正弦波を重ねて規則的に見えないようにする。
func _edge_points(edge: float, wave: float) -> PackedVector2Array:
	var points := PackedVector2Array()
	for i in range(EDGE_SEGMENTS + 1):
		var t := float(i) / float(EDGE_SEGMENTS)
		var x := t * size.x
		var y := edge + sin(t * 7.0 + _progress * 5.0) * wave + sin(t * 17.0) * wave * 0.35
		points.append(Vector2(x, y))
	return points


## 砂の層そのもの。覆うときは砂面より上、引くときは砂面より下を塗る。
## 砂面へ向かって明るくなる縦グラデーションを、セグメントごとの四辺形へ
## 頂点カラーで乗せる(段で塗り分けると境目が縞に見えるため)。
func _draw_body(edge_points: PackedVector2Array, height: float) -> void:
	var far_y := height if _revealing else 0.0
	# 砂がまだ厚みを持たない最初のフレームは、潰れた四辺形になり三角形分割に失敗する。
	if absf(edge_points[0].y - far_y) < 1.0:
		return
	_draw_band(edge_points, far_y, 0.0, MID_STOP, SAND_DEEP, SAND_MID)
	_draw_band(edge_points, far_y, MID_STOP, 1.0, SAND_MID, SAND_SURFACE)


func _draw_band(
	edge_points: PackedVector2Array,
	far_y: float,
	t0: float,
	t1: float,
	color_0: Color,
	color_1: Color
) -> void:
	var colors := PackedColorArray([color_0, color_0, color_1, color_1])
	for i in range(edge_points.size() - 1):
		var quad := PackedVector2Array(
			[
				_lerp_to_edge(edge_points[i], far_y, t0),
				_lerp_to_edge(edge_points[i + 1], far_y, t0),
				_lerp_to_edge(edge_points[i + 1], far_y, t1),
				_lerp_to_edge(edge_points[i], far_y, t1),
			]
		)
		draw_polygon(quad, colors)


func _lerp_to_edge(point: Vector2, far_y: float, t: float) -> Vector2:
	return Vector2(point.x, lerpf(far_y, point.y, t))


## 砂の中を縦に流れる筋。落ちている最中であることを示す。
func _draw_streaks(edge: float, height: float) -> void:
	var far_y := height if _revealing else 0.0
	for s in _streaks:
		var x := s.x * size.x
		var span := (edge - far_y) * s.y
		if absf(span) < 2.0:
			continue
		var from := Vector2(x, edge - span)
		var to := Vector2(x, edge)
		draw_line(from, to, Color(1.0, 0.88, 0.6, 0.22), 1.6)


## 砂面の縁。明るい線を引いて「砂の表面」として読ませる。
func _draw_surface(edge_points: PackedVector2Array) -> void:
	draw_polyline(edge_points, Color(1.0, 0.93, 0.7, 0.5), 6.0)
	draw_polyline(edge_points, Color(1.0, 0.97, 0.85, 0.95), 2.5)


## 砂面から飛び出した砂粒。落下方向へ散らす。
func _draw_grains(edge: float, wave: float) -> void:
	var spread := 46.0 * (1.0 - absf(_progress * 2.0 - 1.0)) + 10.0
	for g in _grains:
		var x := g.x * size.x
		var offset := (sin(g.y + _progress * 9.0) * 0.5 + 0.5) * spread
		var y := edge + offset + wave * 0.5
		if y < -8.0 or y > size.y + 8.0:
			continue
		var alpha := clampf(1.0 - offset / spread, 0.0, 1.0) * 0.8
		draw_circle(Vector2(x, y), g.z, Color(0.98, 0.82, 0.46, alpha))
