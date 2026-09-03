class_name CardUnitFx
extends Control
## 場の砂時計に重ねる演出のうち、**駒そのものの状態ではないもの**を描く
## (GameDesign.md 9章)。設置の着地・破壊の崩落・硝子の割れる閃光の3つ。
##
## `CardView` の子として同じ矩形に重ね、この3つの描画と進行だけを持つ。
## `Control._draw()` は親より手前に描かれるため、駒の絵の上へ出せる。
##
## **`CardView` から切り出しているのは行数の都合ではなく、この3つが「盤面の状態」を
## 一切持たないため**である。体力・攻撃力・キーワードのように毎フレーム参照する値と違い、
## いずれも起きた瞬間に渡された引数だけで完結する。

## 設置:台座の少し上から落ちて着地する。
const LAND_DURATION := 0.26
const LAND_HEIGHT := 34.0
## 着地の砂ぼこりを出し始める進捗。
const LAND_DUST_AT := 0.66
## 破壊:ガラスが割れ、残っていた砂が台座へこぼれてから消える。
const BREAK_DURATION := 0.55
const BREAK_SAND_GRAINS := 16
## 縦に割る枚数と、割れた片が外へ開く量・落ちる量。
const BREAK_SLICES := 3
const BREAK_SPREAD := 13.0
const BREAK_FALL := 26.0
## 割れたガラスの破片(GameDesign.md 9章)。**砂より速く外へ飛んで先に消える**。
## 同じ瞬間に出しても速さが違えば2つは混ざらず、「器が割れて中身がこぼれた」と読める。
const BREAK_SHARDS := 10
const BREAK_SHARD_REACH := 74.0
const BREAK_SHARD_FADE := 0.62
## こぼれる砂が横へ流れる量。真下へ落とすと器ではなく穴から漏れたように見える。
const BREAK_SAND_DRIFT := 26.0
## 硝子:膜が割れる閃光。
const GLASS_DURATION := 0.3
const GLASS_SHARDS := 8

const SAND_AMBER := Color(0.93, 0.78, 0.42, 1.0)
const GLASS_BLUE := Color(0.72, 0.92, 1.0, 1.0)
const BREAK_WHITE := Color(1.0, 0.93, 0.82, 1.0)

var _land := -1.0
var _break := -1.0
var _glass := -1.0
## 崩れ落ちる駒の絵。破壊されると枠が空になるため、その瞬間に控える。
var _break_texture: Texture2D
var _break_rect := Rect2()
var _glass_rect := Rect2()
var _land_tween: Tween
var _break_tween: Tween
var _glass_tween: Tween


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE


## 設置の着地で、駒の絵を持ち上げる量(負の値)。`CardView` が描画位置へ足す。
func land_offset() -> float:
	if _land < 0.0:
		return 0.0
	var left := 1.0 - _land
	return -LAND_HEIGHT * left * left


func play_land() -> void:
	_land_tween = _restart(_land_tween, _set_land, LAND_DURATION)


## 破壊された。**枠が空になった後も描き続ける**ため、絵と位置をここで受け取る。
func play_break(texture: Texture2D, rect: Rect2) -> void:
	if texture == null:
		return
	_break_texture = texture
	_break_rect = rect
	_break_tween = _restart(_break_tween, _set_break, BREAK_DURATION)


## 硝子が最初のダメージを吸った。
func play_glass_break(rect: Rect2) -> void:
	_glass_rect = rect
	_glass_tween = _restart(_glass_tween, _set_glass, GLASS_DURATION)


func _restart(tween: Tween, setter: Callable, duration: float) -> Tween:
	if tween != null and tween.is_valid():
		tween.kill()
	var next := create_tween()
	next.tween_method(setter, 0.0, 1.0, duration)
	next.finished.connect(setter.bind(-1.0))
	return next


func _set_land(value: float) -> void:
	_land = value
	# 着地は駒の絵そのものを動かすため、親にも描き直しを頼む。
	queue_redraw()
	get_parent().queue_redraw()


func _set_break(value: float) -> void:
	_break = value
	queue_redraw()


func _set_glass(value: float) -> void:
	_glass = value
	queue_redraw()


func _draw() -> void:
	if _land >= LAND_DUST_AT:
		_draw_land_dust()
	if _break >= 0.0:
		_draw_break()
	if _glass >= 0.0:
		_draw_glass()


## 着地の砂ぼこり。台座と同じ扁平な楕円を外へ広げ、足元へ粒を散らす。
func _draw_land_dust() -> void:
	var ratio := (_land - LAND_DUST_AT) / (1.0 - LAND_DUST_AT)
	var center := Vector2(size.x * 0.5, CardView.PEDESTAL_CENTER_Y)
	UiPaint.draw_ellipse_ring(
		get_canvas_item(),
		center,
		CardView.PEDESTAL_RADIUS * (0.7 + 0.6 * ratio),
		Color(SAND_AMBER, 0.55 * (1.0 - ratio)),
		2.5,
		40
	)
	for i in 6:
		var angle := PI * (0.15 + 0.7 * float(i) / 5.0)
		var reach := 16.0 + 22.0 * ratio
		var at := center + Vector2(cos(angle) * reach, -sin(angle) * reach * 0.35)
		draw_circle(at, 2.6 * (1.0 - ratio), Color(SAND_AMBER, 0.8 * (1.0 - ratio)))


## 破壊:絵が縦に3つへ割れて左右へずれながら落ち、残っていた砂が台座へこぼれる。
## **砕けて散る被ダメージ(`CardView._draw_shatter()`)とは向きで描き分ける。**
## あちらは外へ飛び、こちらは下へ崩れる。**割れ目を線で描くだけでは、絵が薄くなった
## だけに見えて「壊れた」と読めなかった**(実際に描画して確認した)。
func _draw_break() -> void:
	var fade: float = pow(1.0 - _break, 1.4)
	var size_x: float = _break_rect.size.x / float(BREAK_SLICES)
	var source := _break_texture.get_size()
	for i in BREAK_SLICES:
		# 中央の一片は真下へ、左右の一片は外へ開きながら落ちる。
		var direction := float(i) - (BREAK_SLICES - 1) * 0.5
		var fall: float = BREAK_FALL * _break * _break + absf(direction) * 8.0 * _break
		var at := Vector2(
			_break_rect.position.x + size_x * i + direction * BREAK_SPREAD * _break,
			_break_rect.position.y + fall
		)
		draw_texture_rect_region(
			_break_texture,
			Rect2(at, Vector2(size_x, _break_rect.size.y)),
			Rect2(
				Vector2(source.x * i / float(BREAK_SLICES), 0.0),
				Vector2(source.x / float(BREAK_SLICES), source.y)
			),
			Color(1, 1, 1, fade)
		)
	var center := _break_rect.get_center()
	if _break < 0.3:
		# 割れた瞬間の閃光。ここが無いと、いつ壊れたのかが分からない。
		var flash := 1.0 - _break / 0.3
		UiPaint.fill_ellipse(
			get_canvas_item(), center, _break_rect.size * 0.36, Color(BREAK_WHITE, 0.5 * flash), 28
		)
	_draw_break_shards(center)
	_draw_break_sand(center, fade)


## 割れたガラスの破片。**砂より速く飛び、砂が落ちきる前に消える**。
## 細い三角形として描く(円にすると砂粒と見分けが付かない)。
func _draw_break_shards(center: Vector2) -> void:
	if _break >= BREAK_SHARD_FADE:
		return
	var ratio := _break / BREAK_SHARD_FADE
	var fade: float = 1.0 - ratio
	for i in BREAK_SHARDS:
		# 上半分へ多く飛ばす。器が割れた破片は横と上へ散り、下は砂が占める。
		var angle := (
			PI * (1.15 + 0.7 * float(i) / float(BREAK_SHARDS - 1)) + sin(float(i) * 3.1) * 0.2
		)
		var direction := Vector2(cos(angle), sin(angle))
		var reach: float = BREAK_SHARD_REACH * ratio * (0.6 + 0.4 * absf(sin(float(i) * 2.2)))
		var at := center + direction * reach
		var along := direction * (5.0 + 4.0 * fade)
		var across := Vector2(-direction.y, direction.x) * (1.6 + 1.4 * fade)
		draw_colored_polygon(
			PackedVector2Array([at + along, at - along + across, at - along - across]),
			Color(GLASS_BLUE, 0.9 * fade)
		)


## こぼれた砂。粒が台座まで落ち、そこへ低い山として溜まってから消える。
func _draw_break_sand(center: Vector2, fade: float) -> void:
	var floor_y := CardView.PEDESTAL_CENTER_Y - 2.0
	for i in BREAK_SAND_GRAINS:
		# 粒ごとに落ち始めをずらし、ひとかたまりで落ちないようにする。
		var delay := float(i) / float(BREAK_SAND_GRAINS) * 0.35
		var t: float = clampf((_break - delay) / maxf(1.0 - delay, 0.01), 0.0, 1.0)
		if t <= 0.0:
			continue
		# **放物線を描いて落とす**(GameDesign.md 9章)。横へは一定の速さで流れ、
		# 縦は t の二乗で加速する。真下へ降ろすと器ではなく穴から漏れたように見える。
		var lane: float = float(i % 5) - 2.0
		var spread: float = lane * 11.0 + (float(i) - 8.0) * 0.9
		var x: float = center.x + spread * 0.4 + signf(lane) * BREAK_SAND_DRIFT * t
		var y: float = lerpf(center.y, floor_y, t * t)
		draw_circle(Vector2(x, y), 2.8 * (1.0 - t * 0.5), Color(SAND_AMBER, 0.95 - 0.35 * t))
	var pile: float = clampf((_break - 0.45) / 0.55, 0.0, 1.0)
	if pile <= 0.0:
		return
	UiPaint.fill_ellipse(
		get_canvas_item(),
		Vector2(center.x, floor_y),
		Vector2(CardView.PEDESTAL_RADIUS.x * 0.55 * pile, 5.0 * pile),
		Color(SAND_AMBER, 0.8 * fade),
		28
	)


## 硝子が割れた:膜が弾けて外へ広がり、破片が散る。
func _draw_glass() -> void:
	var center := _glass_rect.get_center()
	var fade := 1.0 - _glass
	var radius: float = _glass_rect.size.x * (0.2 + 0.34 * _glass)
	UiPaint.draw_ellipse_ring(
		get_canvas_item(), center, Vector2(radius, radius * 0.9), Color(GLASS_BLUE, fade), 2.0, 40
	)
	for i in GLASS_SHARDS:
		var angle := TAU * float(i) / float(GLASS_SHARDS)
		var direction := Vector2(cos(angle), sin(angle) * 0.9)
		draw_line(
			center + direction * radius * 0.75,
			center + direction * radius * 1.25,
			Color(GLASS_BLUE, fade * 0.9),
			2.0
		)
	if _glass < 0.3:
		var flash := 1.0 - _glass / 0.3
		UiPaint.fill_ellipse(
			get_canvas_item(), center, _glass_rect.size * 0.4, Color(1.0, 1.0, 1.0, 0.4 * flash), 28
		)
