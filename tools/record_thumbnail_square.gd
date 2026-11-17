extends Control
## unityroomのゲームアイコン用の正方形GIF(512x512・512KB以下)の素材フレームを書き出す。
## 一覧では100px前後まで縮むため、登場させるのは砂時計1つと、攻撃力・体力の丸2つだけにする。
## 「砂が落ちると体力が攻撃力へ移る」「ひっくり返すと入れ替わる」(GameDesign.md 1章)を
## 1つの砂時計で一巡させる。反転し終えた姿が最初の姿と同じなので、継ぎ目なくループする。
##
## 台本: 攻撃1・体力3 → 砂が落ちて 2・2 → もう1粒で 3・1(体力の丸が脈打つ)
## → 反転して 1・3 へ戻る。
##
## 実行(固定デルタで書き出すため --write-movie と --fixed-fps を必ず付ける):
##   godot --path . --write-movie scratchpad/sq/f.png
##     --fixed-fps 12 res://tools/record_thumbnail_square.tscn
## 絵の焼き付けを待つ間も空のコマが書き出されるため、使うのは末尾の END_TIME×12 コマだけ。
##
## GIFへの変換(1280x720で書き出されるため中央を切り抜く。全コマ共通の色表で量子化する):
##   magick <末尾のコマ> -crop 512x512+384+104 +repage +append -colors 128
##     -unique-colors scratchpad/sq/palette.png
##   magick -delay 8 -loop 0 <末尾のコマ> -crop 512x512+384+104 +repage
##     -dither None -remap scratchpad/sq/palette.png -fuzz 3% -layers OptimizeFrame
##     -layers OptimizeTransparency icon512.gif
##
## 512KB以下に収めるため、背景は完全に静止させる(GIFはコマ間の差分を持つ形式で、
## 広い範囲がわずかでも動くとそのコマを丸ごと持つことになる)。

const VIEW := Vector2(512.0, 512.0)
const WINDOW := Vector2(1280.0, 720.0)
const HERO_ID := "sand"

const CENTER_X := 256.0
const FLOOR_Y := 440.0
const GLASS_HEIGHT := 392.0
## 砂の落ち口(くびれ)の高さ。絵の高さに対する比。
const NECK_RATIO := 0.5
const STREAM_DROP_RATIO := 0.3

const GEM_RADIUS := 58.0
const GEM_Y := 424.0
const GEM_INSET := 84.0
const GEM_POP := 0.26
const GEM_POP_SPAN := 0.28

## 台本の時刻(秒)。
const TICK_STARTS: Array[float] = [0.5, 1.5]
const TICK_SPAN := 0.45
## 砂の絵を差し替える区間(砂が落ちる動きの中での割合)。短くして、広い面が変わるコマを減らす。
const BLEND_FROM := 0.3
const BLEND_TO := 0.75
const FLIP_START := 2.55
const FLIP_SPAN := 0.5
const LAND_SPAN := 0.5
const END_TIME := 3.8

## 砂が落ちるごとの (攻撃力, 体力)。
const STEPS: Array[Vector2i] = [Vector2i(1, 3), Vector2i(2, 2), Vector2i(3, 1)]

const FLIP_LIFT := 18.0
const FLIP_SHRINK := 0.12
const LAND_SQUASH := 0.08
## 沈むのは着地の直後だけ(砂時計の全面が変わるコマを増やさない)。
const SQUASH_SPAN := 0.17
const SWOOSH_RADIUS := 232.0
const SWOOSH_LENGTH := 1.1
const SWOOSH_WIDTH := 7.0
const NUMBER_ARC := 96.0
const DANGER_HZ := 2.5

const RAY_COUNT := 20
const RAY_REACH := 420.0
const RAY_COLOR := Color(0.96, 0.68, 0.24, 0.06)
## 砂時計の後ろの光。段のはっきりした円を重ねる(なだらかな光はGIFの色数で縞になる)。
const HALO_RADII: Array[float] = [236.0, 178.0, 120.0]
const HALO_COLOR := Color(0.96, 0.68, 0.24, 0.07)
const DAIS_RADIUS := Vector2(196.0, 36.0)
const DAIS_RIM := 7.0
const BURST_GRAINS := 18
const STREAM_GRAINS := 6

var _t := 0.0
## [state_full, state_falling, state_empty]
var _art: Array[Texture2D] = []
var _font: Font


func _ready() -> void:
	theme = load("res://resources/theme/main_theme.tres")
	# 書き出しは1280x720で行われる(--resolutionでは変えられない)。
	# 512x512の絵を画面の中央へ置いておき、変換時に切り抜く。
	anchor_right = 0.0
	anchor_bottom = 0.0
	size = VIEW
	position = ((WINDOW - VIEW) * 0.5).floor()
	clip_contents = true
	var label_font := get_theme_font("font", "Label")
	_font = label_font if label_font != null else ThemeDB.fallback_font
	for state in HourglassArt.State.values():
		_art.append(HourglassArt.texture(HERO_ID, state))


func _process(delta: float) -> void:
	if _art.is_empty():
		return
	_t += delta
	if _t >= END_TIME:
		get_tree().quit()
		return
	queue_redraw()


# --- 台本の読み出し -------------------------------------------------------


## 0〜1で返す。範囲の外は0または1。
func _phase(start: float, span: float) -> float:
	return clampf((_t - start) / span, 0.0, 1.0)


func _flip_phase() -> float:
	return _phase(FLIP_START, FLIP_SPAN)


func _flipping() -> bool:
	var k := _flip_phase()
	return k > 0.0 and k < 1.0


func _landed_at() -> float:
	return FLIP_START + FLIP_SPAN


## 数字が変わる時刻。砂が落ちる動きの半ばで変える。
func _tick_change_time(index: int) -> float:
	return TICK_STARTS[index] + TICK_SPAN * 0.5


func _stats() -> Vector2i:
	if _t >= _landed_at():
		return STEPS[0]
	var step := 0
	for i in TICK_STARTS.size():
		if _t >= _tick_change_time(i):
			step = i + 1
	return STEPS[step]


## 直近に数字が変わってからの秒数。変わっていなければ大きな値。
func _since_change() -> float:
	var best := INF
	var moments: Array[float] = [_landed_at()]
	for i in TICK_STARTS.size():
		moments.append(_tick_change_time(i))
	for moment in moments:
		if _t >= moment:
			best = minf(best, _t - moment)
	return best


func _pop() -> float:
	var since := _since_change()
	if since >= GEM_POP_SPAN:
		return 1.0
	return 1.0 + sin(since / GEM_POP_SPAN * PI) * GEM_POP


# --- 描画 -----------------------------------------------------------------


func _draw() -> void:
	if _art.is_empty():
		return
	_draw_background()
	_draw_dais()
	_draw_landing()
	_draw_glass()
	_draw_stream()
	_draw_swoosh()
	_draw_gems()


func _glass_center() -> Vector2:
	return Vector2(CENTER_X, FLOOR_Y - GLASS_HEIGHT * 0.5)


func _draw_background() -> void:
	var ci := get_canvas_item()
	var full := Rect2(Vector2.ZERO, VIEW)
	UiPaint.fill_gradient_polygon(
		ci,
		PackedVector2Array([Vector2.ZERO, Vector2(VIEW.x, 0.0), VIEW, Vector2(0.0, VIEW.y)]),
		full,
		[[0.0, UiPalette.INK_700], [1.0, UiPalette.INK_700]]
	)
	var center := _glass_center()
	for i in RAY_COUNT:
		if i % 2 == 1:
			continue
		var from := TAU * float(i) / float(RAY_COUNT)
		var to := TAU * float(i + 1) / float(RAY_COUNT)
		draw_colored_polygon(
			PackedVector2Array(
				[
					center,
					center + Vector2(cos(from), sin(from)) * RAY_REACH,
					center + Vector2(cos(to), sin(to)) * RAY_REACH,
				]
			),
			RAY_COLOR
		)
	for radius in HALO_RADII:
		UiKit.fill(ci, UiKit.ellipse(center, Vector2(radius, radius)), HALO_COLOR)


## 砂時計を載せる台座(場の砂時計は台座の上の物体として置く)。
func _draw_dais() -> void:
	var ci := get_canvas_item()
	var at := Vector2(CENTER_X, FLOOR_Y + 6.0)
	UiKit.fill(ci, UiKit.ellipse(at + Vector2(0.0, 12.0), DAIS_RADIUS * 1.06), Color(0, 0, 0, 0.5))
	UiKit.vgrad(
		ci,
		UiKit.ellipse(at + Vector2(0.0, DAIS_RIM), DAIS_RADIUS),
		[[0.0, UiPalette.BRASS], [1.0, UiPalette.BRASS_DEEP]],
		true
	)
	UiKit.vgrad(
		ci, UiKit.ellipse(at, DAIS_RADIUS), [[0.0, UiPalette.GOLD], [1.0, UiPalette.BRASS]], true
	)
	UiKit.vgrad(
		ci,
		UiKit.ellipse(at, DAIS_RADIUS - Vector2(DAIS_RIM, DAIS_RIM * 0.5)),
		[[0.0, UiPalette.INK_800], [1.0, UiPalette.INK_600]],
		true
	)
	var lift := sin(_flip_phase() * PI)
	UiKit.fill(
		ci,
		UiKit.ellipse(at, Vector2(132.0, 20.0) * (1.0 - lift * 0.25)),
		Color(0, 0, 0, 0.4 - lift * 0.15)
	)


## 絵を底辺の中央で揃える矩形。`bottom` は原点から底辺までの距離。
## 3つの状態の絵は画素数が違っても縦横比が同じなので、同じ矩形へ描けば枠が重なる。
func _glass_rect(bottom: float) -> Rect2:
	var width := GLASS_HEIGHT * float(_art[0].get_width()) / float(_art[0].get_height())
	return Rect2(Vector2(-width * 0.5, bottom - GLASS_HEIGHT), Vector2(width, GLASS_HEIGHT))


func _draw_glass() -> void:
	if _flipping():
		var k := _flip_phase()
		var eased := k * k * (3.0 - 2.0 * k)
		var arc := sin(k * PI)
		var center := _glass_center() - Vector2(0.0, arc * FLIP_LIFT)
		var shrink := 1.0 - arc * FLIP_SHRINK
		draw_set_transform(center, eased * PI, Vector2(shrink, shrink))
		draw_texture_rect(_art[2], _glass_rect(GLASS_HEIGHT * 0.5), false)
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
		return
	# 着地の直後だけ、底辺を支点に一度沈ませる。
	var land := _t - _landed_at()
	var squash := 0.0
	if land >= 0.0 and land < SQUASH_SPAN:
		squash = sin(land / SQUASH_SPAN * PI) * LAND_SQUASH
	draw_set_transform(Vector2(CENTER_X, FLOOR_Y), 0.0, Vector2(1.0 + squash * 0.6, 1.0 - squash))
	var from := 0
	var blend := 0.0
	if _t < _landed_at():
		for i in TICK_STARTS.size():
			var k := _phase(TICK_STARTS[i], TICK_SPAN)
			if k > 0.0:
				from = i
				blend = smoothstep(BLEND_FROM, BLEND_TO, k)
	draw_texture_rect(_art[from], _glass_rect(0.0), false)
	if blend > 0.0:
		draw_texture_rect(_art[from + 1], _glass_rect(0.0), false, Color(1, 1, 1, blend))
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


## くびれから落ちる砂粒。
func _draw_stream() -> void:
	var ci := get_canvas_item()
	var neck := Vector2(CENTER_X, FLOOR_Y - GLASS_HEIGHT * NECK_RATIO)
	for start in TICK_STARTS:
		var k := _phase(start, TICK_SPAN)
		if k <= 0.0 or k >= 1.0:
			continue
		var alpha := sin(k * PI)
		for i in STREAM_GRAINS:
			var fall := fposmod(k * 1.6 + float(i) / float(STREAM_GRAINS), 1.0)
			var at := neck + Vector2(0.0, fall * fall * GLASS_HEIGHT * STREAM_DROP_RATIO)
			at.x += (float(i % 3) - 1.0) * 3.0
			UiKit.fill(ci, UiKit.ellipse(at, Vector2(4.5, 5.5)), Color(UiPalette.SAND_HI, alpha))


## 反転の間、回る向きへ流れる2本の光の弧。
func _draw_swoosh() -> void:
	if not _flipping():
		return
	var k := _flip_phase()
	var arc := sin(k * PI)
	var head := k * k * (3.0 - 2.0 * k) * PI - PI * 0.5
	var color := Color(UiPalette.GOLD_HI, arc * 0.85)
	for side in 2:
		var at := head + PI * float(side)
		draw_arc(
			_glass_center(),
			SWOOSH_RADIUS,
			at - SWOOSH_LENGTH * arc,
			at,
			24,
			color,
			SWOOSH_WIDTH * arc,
			true
		)


## 着地の光と、台座から跳ねる砂。
func _draw_landing() -> void:
	var since := _t - _landed_at()
	if since < 0.0 or since >= LAND_SPAN:
		return
	var k := since / LAND_SPAN
	var fade := 1.0 - k
	var ci := get_canvas_item()
	var base := Vector2(CENTER_X, FLOOR_Y + 6.0)
	UiPaint.draw_ellipse_ring(
		ci,
		base,
		DAIS_RADIUS * (0.7 + k * 0.75),
		Color(UiPalette.GOLD_HI, fade),
		2.0 + fade * 6.0,
		48
	)
	for i in BURST_GRAINS:
		var side := -1.0 if i % 2 == 0 else 1.0
		var spread := 0.35 + fposmod(float(i) * 0.37, 0.65)
		var at := base + Vector2(side * (90.0 + k * 150.0 * spread), 0.0)
		at.y -= sin(k * PI) * (30.0 + 90.0 * fposmod(float(i) * 0.61, 1.0))
		var grain := 8.0 - k * 4.0
		UiKit.fill(ci, UiKit.ellipse(at, Vector2(grain, grain)), Color(UiPalette.SAND_HI, fade))


## 攻撃力(左・橙)と体力(右・赤)。反転の間は数字が弧を描いて左右を入れ替わる。
func _draw_gems() -> void:
	var ci := get_canvas_item()
	var left := Vector2(GEM_INSET, GEM_Y)
	var right := Vector2(VIEW.x - GEM_INSET, GEM_Y)
	var stats := _stats()
	if stats.y == 1 and not _flipping():
		var pulse := 0.5 + 0.5 * sin(_t * TAU * DANGER_HZ)
		var reach := GEM_RADIUS * (1.5 + pulse * 0.3)
		UiKit.glow(ci, right, Vector2(reach, reach), Color(UiPalette.HEALTH, 0.45 + pulse * 0.5))
	var pop := _pop()
	var radius := GEM_RADIUS * pop
	UiKit.gem(ci, left, radius, UiPalette.ATTACK, UiPalette.ATTACK_DEEP)
	UiKit.gem(ci, right, radius, UiPalette.HEALTH, UiPalette.HEALTH_DEEP)
	if not _flipping():
		UiKit.gem_text(ci, _font, left, radius, str(stats.x))
		UiKit.gem_text(ci, _font, right, radius, str(stats.y))
		return
	var k := _flip_phase()
	var swap := smoothstep(0.1, 0.9, k)
	var arc := sin(swap * PI)
	var lift := Vector2(0.0, -arc * NUMBER_ARC)
	var grown := GEM_RADIUS * (1.0 + arc * 0.35)
	UiKit.gem_text(ci, _font, left.lerp(right, swap) + lift, grown, str(stats.x))
	UiKit.gem_text(ci, _font, right.lerp(left, swap) + lift * 0.45, grown, str(stats.y))
