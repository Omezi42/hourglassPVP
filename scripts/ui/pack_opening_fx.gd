class_name PackOpeningFx
extends Control
## 開封の粒と光(GameDesign.md 21章「開封」)。時刻で決まる絵だけを持ち、段取りは `PackOpeningOverlay` が持つ。
## 2枚重ねて使う: `BACK` はレジェンドの札の後ろ(暗幕・文字盤・光の筋・後ろの大きな砂時計)、
## `FRONT` は札の手前(弾ける砂粒・輪・欠片・砂粒の飛行・閃光・見出し)。
## 粒は種つきの乱数で毎コマ同じ位置を計算し直す(状態を持たない)。矩形だけで描くため描き直しが軽い。

enum Layer { BACK, FRONT }

const STAGE := Vector2(1280, 720)
const GRAIN := 3.0
const DRAG := 3.0
const SHARD_COUNT := 40
## レジェンドの段取り(開始からの秒)。`PackOpeningOverlay.LEGEND_*` と揃える。
const L_DIM := 0.35
const L_STOP := Vector2(0.65, 0.95)
const L_REWIND := Vector2(1.15, 1.95)
const L_FLASH := 2.0
const L_FIELD := 300
const L_DIAL := 210.0
const L_TICKS := 12
const L_RAYS := 16
const L_HEADING := "レジェンド"
const L_HEADING_DROP := 238.0
const L_HEADING_LINE := 150.0
const L_BIG_VESSEL := 1.7

var layer: Layer = Layer.FRONT
## 暗幕の濃さ(BACK。レジェンドの間に下げる)。
var dim := 0.0:
	set(value):
		dim = value
		queue_redraw()

var _t := 0.0
var _bursts: Array[Dictionary] = []
var _rings: Array[Dictionary] = []
var _shards: Array[Dictionary] = []
var _flights: Array[Dictionary] = []
var _glows: Array[Dictionary] = []
var _legend_at := -1.0
var _legend_center := Vector2.ZERO
var _font: Font


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	size = STAGE
	_font = get_theme_default_font()


func _process(delta: float) -> void:
	if not is_visible_in_tree():
		return
	_t += delta
	_prune()
	queue_redraw()


func now() -> float:
	return _t


## 砂粒が弾ける。`colors` から順に色を取る。
func burst(
	at: Vector2, colors: Array, count := 60, speed := 320.0, life := 0.9, gravity := 260.0
) -> void:
	_bursts.append(
		{
			"at": at,
			"t0": _t,
			"count": count,
			"speed": speed,
			"life": life,
			"gravity": gravity,
			"colors": colors,
			"seed": randi()
		}
	)


## 色の輪が広がる。
func ring(at: Vector2, color: Color, radius := 150.0, life := 0.6) -> void:
	_rings.append({"at": at, "t0": _t, "color": color, "radius": radius, "life": life})


## ガラスの欠片(割れたガラス・エピックの結晶)。
func shards(at: Vector2, color: Color, spread: Vector2, count := SHARD_COUNT, life := 1.0) -> void:
	_shards.append(
		{
			"at": at,
			"t0": _t,
			"color": color,
			"spread": spread,
			"count": count,
			"life": life,
			"seed": randi()
		}
	)


## 光だまり(エピックの後ろに溜まる紫・割れる瞬間の閃光)。
func glow(at: Vector2, radii: Vector2, color: Color, rise: float, life: float) -> void:
	_glows.append({"at": at, "t0": _t, "radii": radii, "color": color, "rise": rise, "life": life})


## 砂粒が弧を描いて飛ぶ(上限を超えた札 → 砂粒の残高)。
func flight(from: Vector2, to: Vector2, color: Color, life := 0.9, count := 70) -> void:
	_flights.append(
		{
			"from": from,
			"to": to,
			"t0": _t,
			"color": color,
			"life": life,
			"count": count,
			"seed": randi()
		}
	)


## レジェンドの段取りを始める。`center` は札が上がる先。
func start_legend(center: Vector2) -> void:
	_legend_at = _t
	_legend_center = center


func end_legend() -> void:
	_legend_at = -1.0


func _prune() -> void:
	for list: Array[Dictionary] in [_bursts, _rings, _shards, _flights, _glows]:
		for i in range(list.size() - 1, -1, -1):
			if _t - float(list[i]["t0"]) > float(list[i]["life"]) + 0.05:
				list.remove_at(i)


static func seg(t: float, from: float, to: float) -> float:
	return clampf((t - from) / maxf(to - from, 0.0001), 0.0, 1.0)


static func ease_out(x: float) -> float:
	return 1.0 - pow(1.0 - x, 3.0)


func _draw() -> void:
	var ci := get_canvas_item()
	if layer == Layer.BACK:
		if dim > 0.0:
			RenderingServer.canvas_item_add_rect(
				ci, Rect2(Vector2.ZERO, STAGE), Color(UiPalette.INK_950, 0.78 * dim)
			)
		if _legend_at >= 0.0:
			_legend_back(ci, _t - _legend_at)
		return
	for g in _glows:
		var k := (
			seg(_t, g["t0"], g["t0"] + g["rise"])
			* (1.0 - seg(_t, g["t0"] + g["rise"], g["t0"] + g["life"]))
		)
		UiKit.glow(ci, g["at"], g["radii"], Color(g["color"], g["color"].a * k))
	for r in _rings:
		var k := ease_out(seg(_t, r["t0"], r["t0"] + r["life"]))
		ShapePaint.circle(
			ci,
			r["at"],
			r["radius"] * k,
			Color(r["color"], 1.0 - k),
			false,
			3.0 * (1.0 - k) + 1.0,
			true
		)
	for b in _bursts:
		_draw_burst(ci, b)
	for s in _shards:
		_draw_shards(ci, s)
	for f in _flights:
		_draw_flight(ci, f)
	if _legend_at >= 0.0:
		_legend_front(ci, _t - _legend_at)


func _draw_burst(ci: RID, b: Dictionary) -> void:
	var age := _t - float(b["t0"])
	var life: float = b["life"]
	if age < 0.0:
		return
	var rng := RandomNumberGenerator.new()
	rng.seed = b["seed"]
	var colors: Array = b["colors"]
	var drag := (1.0 - exp(-age * DRAG)) / DRAG
	for i in int(b["count"]):
		var a := rng.randf() * TAU
		var v := rng.randf_range(0.3, 1.0) * float(b["speed"])
		var size_px := rng.randf_range(1.6, GRAIN + 1.0)
		var fade := 1.0 - seg(age, life * rng.randf_range(0.5, 0.9), life)
		var pos: Vector2 = (
			b["at"]
			+ Vector2(cos(a), sin(a)) * v * drag
			+ Vector2(0, float(b["gravity"]) * age * age)
		)
		var col: Color = colors[i % colors.size()]
		RenderingServer.canvas_item_add_rect(
			ci, Rect2(pos, Vector2(size_px, size_px)), Color(col, fade)
		)


func _draw_shards(ci: RID, s: Dictionary) -> void:
	var age := _t - float(s["t0"])
	var k := 1.0 - seg(age, 0.0, s["life"])
	var rng := RandomNumberGenerator.new()
	rng.seed = s["seed"]
	var spread: Vector2 = s["spread"]
	var drag := (1.0 - exp(-age * DRAG)) / DRAG
	for i in int(s["count"]):
		var a := rng.randf() * TAU
		var v := rng.randf_range(200, 700)
		var from: Vector2 = (
			s["at"]
			+ Vector2(rng.randf_range(-spread.x, spread.x), rng.randf_range(-spread.y, spread.y))
		)
		var pos := from + Vector2(cos(a), sin(a)) * v * drag + Vector2(0, 300 * age * age)
		var r := rng.randf_range(6, 16)
		var spin := age * rng.randf_range(-10, 10)
		var pts := PackedVector2Array()
		for j in 3:
			var aa := spin + j * TAU / 3.0 + rng.randf_range(-0.4, 0.4)
			pts.append(pos + Vector2(cos(aa), sin(aa)) * r * (1.0 if j > 0 else 0.5))
		var col: Color = s["color"]
		UiKit.fill(ci, pts, Color(col, 0.35 * k))
		UiKit.stroke(ci, pts, Color(Color.WHITE, 0.6 * k), 1.0)


func _draw_flight(ci: RID, f: Dictionary) -> void:
	var age := _t - float(f["t0"])
	var life: float = f["life"]
	var rng := RandomNumberGenerator.new()
	rng.seed = f["seed"]
	var from: Vector2 = f["from"]
	var to: Vector2 = f["to"]
	var bend := (from + to) * 0.5 + Vector2(0, -minf(from.distance_to(to) * 0.45, 260.0))
	for i in int(f["count"]):
		var delay := rng.randf() * life * 0.45
		var jitter := Vector2(rng.randf_range(-40, 40), rng.randf_range(-50, 30))
		var p := seg(age, delay, delay + life * 0.55)
		if p <= 0.0 or p >= 1.0:
			continue
		var q := p * p
		var start := from + jitter
		var pos := start.lerp(bend, q).lerp(bend.lerp(to, q), q)
		RenderingServer.canvas_item_add_rect(
			ci, Rect2(pos, Vector2(GRAIN, GRAIN)), Color(f["color"], 1.0 - p * 0.3)
		)


## レジェンドの後ろ: 止まった砂・薄い青の膜・文字盤・後ろの大きな砂時計・回る光の筋。
func _legend_back(ci: RID, lt: float) -> void:
	var c := _legend_center
	var appear := seg(lt, L_STOP.x - 0.1, L_STOP.x)
	var stop := ease_out(seg(lt, L_STOP.x, L_STOP.y))
	var back := seg(lt, L_REWIND.x, L_REWIND.y)
	var flash := seg(lt, L_FLASH - 0.05, L_FLASH)
	var after := seg(lt, L_FLASH, L_FLASH + 0.4)
	if after > 0.0:
		for i in L_RAYS:
			var angle := TAU * i / L_RAYS + lt * 0.35
			var dir := Vector2(cos(angle), sin(angle))
			var side := Vector2(-dir.y, dir.x) * 34.0
			UiKit.fill(
				ci,
				PackedVector2Array(
					[
						c + dir * 140.0 - side * 0.3,
						c + dir * 900.0 - side,
						c + dir * 900.0 + side,
						c + dir * 140.0 + side * 0.3
					]
				),
				Color(UiPalette.RARITY_LEGEND, 0.16 * after)
			)
		UiKit.glow(ci, c, Vector2(420, 320), Color(UiPalette.RARITY_LEGEND, 0.35 * after))
	var dial := appear * (1.0 - after)
	if dial > 0.0:
		UiKit.glow(
			ci, c, Vector2(L_DIAL * 1.6, L_DIAL * 1.3), Color(UiPalette.STILL_FILM, 0.12 * dial)
		)
		ShapePaint.circle(ci, c, L_DIAL, Color(UiPalette.STILL_FILM, 0.55 * dial), false, 2.0, true)
		ShapePaint.circle(
			ci, c, L_DIAL * 0.92, Color(UiPalette.STILL_FILM, 0.25 * dial), false, 1.0, true
		)
		for i in L_TICKS:
			var a := TAU * i / L_TICKS
			var d := Vector2(cos(a), sin(a))
			ShapePaint.polyline(
				ci,
				PackedVector2Array([c + d * L_DIAL * 0.86, c + d * L_DIAL * 0.97]),
				Color(UiPalette.STILL_FILM, 0.7 * dial),
				2.0,
				true
			)
		var needle := -PI * 0.5 - TAU * 3.0 * back * back
		ShapePaint.polyline(
			ci,
			PackedVector2Array([c, c + Vector2(cos(needle), sin(needle)) * L_DIAL * 0.8]),
			Color(UiPalette.STILL_FILM, 0.9 * dial),
			3.0,
			true
		)
		var turn := PI * ease_out(back)
		PackVesselPaint.draw(
			ci,
			Transform2D(turn, Vector2.ONE * L_BIG_VESSEL, 0.0, c),
			1.0 - back,
			false,
			[],
			0.28 * dial
		)
	if appear > 0.0 and back < 1.0:
		_frozen_sand(ci, c, stop, back, appear)
	var veil := stop * (1.0 - seg(lt, L_REWIND.y - 0.2, L_REWIND.y))
	if veil > 0.0:
		RenderingServer.canvas_item_add_rect(
			ci, Rect2(Vector2.ZERO, STAGE), Color(UiPalette.STILL_FILM, 0.07 * veil)
		)
	if flash > 0.0 and after < 1.0:
		UiKit.glow(ci, c, Vector2(520, 420), Color(Color.WHITE, 0.6 * (1.0 - after)))


func _frozen_sand(ci: RID, c: Vector2, stop: float, back: float, appear: float) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 31
	var sand := [UiPalette.SAND_HI, UiPalette.SAND, UiPalette.RARITY_LEGEND, UiPalette.GOLD_HI]
	var q := back * back
	for i in L_FIELD:
		var a0 := rng.randf() * TAU
		var r0 := rng.randf_range(170.0, 560.0)
		var base := c + Vector2(cos(a0) * r0 * 1.15, sin(a0) * r0 * 0.75)
		var fall := Vector2(0, -70.0 * (1.0 - stop))
		var a := a0 - 3.0 * q
		var r := r0 * (1.0 - q)
		var swirl := c + Vector2(cos(a) * r * 1.15, sin(a) * r * 0.75)
		var pos := (base + fall).lerp(swirl, minf(back * 4.0, 1.0))
		var col: Color = sand[i % sand.size()]
		col = col.lerp(UiPalette.STILL_FILM, 0.45 * stop * (1.0 - back))
		var sz := rng.randf_range(1.5, 3.2)
		var alpha := appear * (1.0 - seg(back, 0.85, 1.0))
		if stop < 1.0:
			var tail := 14.0 * (1.0 - stop)
			RenderingServer.canvas_item_add_rect(
				ci, Rect2(pos - Vector2(0, tail), Vector2(sz * 0.6, tail)), Color(col, 0.35 * alpha)
			)
		RenderingServer.canvas_item_add_rect(
			ci, Rect2(pos, Vector2(sz, sz)), Color(col, 0.95 * alpha)
		)


## レジェンドの手前: 表になった後の見出しと飾り線。
func _legend_front(ci: RID, lt: float) -> void:
	var k := ease_out(seg(lt, L_FLASH + 0.1, L_FLASH + 0.5))
	if k <= 0.0 or _font == null:
		return
	var y := _legend_center.y - L_HEADING_DROP
	var px := UiPalette.T_TITLE
	var color := Color(UiPalette.RARITY_LEGEND.lerp(UiPalette.GOLD_HI, 0.3), k)
	UiKit.text_in(ci, _font, L_HEADING, Rect2(0, y - px, STAGE.x, px * 2), px, color, 2)
	var half := _font.get_string_size(L_HEADING, HORIZONTAL_ALIGNMENT_LEFT, -1, px).x * 0.5 + 18.0
	for side in [-1.0, 1.0]:
		var from := Vector2(_legend_center.x + side * half, y)
		var to := from + Vector2(side * L_HEADING_LINE * k, 0)
		ShapePaint.polyline(ci, PackedVector2Array([from, to]), color, 1.6, true)
		UiKit.fill(ci, RarityPaint.diamond(to, 5.0), color)
