extends Control
## unityroomのゲームアイコン用の正方形GIF(512x512・512KB以下)の素材フレームを書き出す。
## 一覧で小さく表示されても伝わるよう、登場させるのは味方と相手の砂時計2つだけにする。
## 「上の砂が体力・下の砂が攻撃力」「ひっくり返すと入れ替わる」「入れ替えて殴る」の
## 3つを、大きな数字と動きで一巡させてループする。
##
## 台本: 味方(体力5・攻撃1)が反転して体力1・攻撃5になる → 相手(体力4・攻撃0)を殴って
## 砕く → 新しい相手が落ちてくる → 味方が反転して戻る → 最初の絵へ戻る。
## 相手は出たばかりで攻撃力0のため相打ちは起きない(GameDesign.md 1章・4章)。
##
## 実行(固定デルタで書き出すため --write-movie と --fixed-fps を必ず付ける):
##   godot --path . --write-movie scratchpad/sq/f.png
##     --fixed-fps 12 res://tools/record_thumbnail_square.tscn
## 絵の焼き付けを待つ間も空のコマが書き出されるため、使うのは末尾の END_TIME×12 コマだけ。
##
## GIFへの変換(1280x720で書き出されるため中央を切り抜く。全コマ共通の色表で量子化し、
## 静止している背景をコマ間の差分に含めない):
##   magick scratchpad/sq/f0*.png -crop 512x512+384+104 +repage +append -colors 96
##     -unique-colors scratchpad/sq/palette.png
##   magick -delay 8 -loop 0 scratchpad/sq/f0*.png -crop 512x512+384+104 +repage
##     -dither None -remap scratchpad/sq/palette.png -layers OptimizeFrame
##     -layers OptimizeTransparency icon512.gif
##
## 512KB以下に収めるため、背景は完全に静止させる。GIFはコマ間の差分を持つ形式で、
## 画面の広い範囲がわずかでも動くとそのコマを丸ごと持つことになる。

const VIEW := Vector2(512.0, 512.0)
const BACKGROUND := preload("res://assets/backgrounds/processed/battle/background.png")
const FLOOR_Y := 452.0
const HERO_X := 150.0
const ENEMY_X := 382.0
const HERO_HEIGHT := 236.0
const ENEMY_HEIGHT := 196.0
const HERO_ID := "sand"
const ENEMY_ID := "poison"
const LOGO_SCALE := 0.56
## 背景をこの大きさまで縮めてから引き伸ばし、ぼかす。駒が浮き立ち、GIFの差分も軽くなる
## (細かい模様の上を駒が動くと、動いた範囲の圧縮が効かず容量が膨らむ)。
const BACKGROUND_BLUR_SIZE := 48

const ATTACK_COLOR := Color(0.88, 0.34, 0.2, 1.0)
const HEALTH_COLOR := Color(0.3, 0.58, 0.9, 1.0)
const GOLD := Color(1.0, 0.84, 0.42, 1.0)
const INK := Color(0.06, 0.09, 0.19, 1.0)

## 台本の時刻(秒)。
const FLIP_START := 0.4
const FLIP_SPAN := 0.55
const STRIKE_START := 1.35
const STRIKE_SPAN := 0.7
const SHATTER_SPAN := 0.6
const DROP_START := 2.85
const DROP_SPAN := 0.4
const FLIP_BACK_START := 3.55
const FLIP_BACK_SPAN := 0.45
const END_TIME := 4.4

const HERO_BEFORE := Vector2i(5, 1)
const HERO_AFTER := Vector2i(1, 5)
const ENEMY_STATS := Vector2i(4, 0)

var _t := 0.0
## id -> [state_full, state_falling, state_empty]
var _art: Dictionary = {}
var _display_font: Font
var _background: Texture2D


func _ready() -> void:
	theme = load("res://resources/theme/main_theme.tres")
	# 書き出しは1280x720で行われる(--resolutionでは変えられない)。
	# 512x512の絵を画面の中央へ置いておき、変換時に切り抜く。
	anchor_right = 0.0
	anchor_bottom = 0.0
	size = VIEW
	position = ((Vector2(1280.0, 720.0) - VIEW) * 0.5).floor()
	clip_contents = true
	_display_font = UiFonts.display_font(_font())
	_background = _blurred_background()
	var logo := TitleLogo.new()
	logo.size = Vector2(VIEW.x / LOGO_SCALE, 290.0)
	logo.scale = Vector2(LOGO_SCALE, LOGO_SCALE)
	logo.position = Vector2(0.0, -2.0)
	add_child(logo)
	# 色違いの絵は起動後に焼き付けるため、焼き上がるまで台本を進めない。
	await HourglassArt.ensure_ready_and_wait(self)
	for id in [HERO_ID, ENEMY_ID]:
		var frames: Array[Texture2D] = []
		for state in HourglassArt.State.values():
			frames.append(HourglassArt.texture(id, state))
		_art[id] = frames
	# 焼き付けを待つ間に書き出されたコマは、変換時にこの番号より前を捨てる。
	print("FIRST_FRAME=%d" % Engine.get_frames_drawn())


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


func _hit_time() -> float:
	return STRIKE_START + STRIKE_SPAN * 0.45


func _hero_stats() -> Vector2i:
	if _t >= FLIP_BACK_START + FLIP_BACK_SPAN * 0.5:
		return HERO_BEFORE
	if _t >= FLIP_START + FLIP_SPAN * 0.5:
		return HERO_AFTER
	return HERO_BEFORE


## 砕けている間とまだ落ちてきていない間は相手がいない。
func _enemy_present() -> bool:
	return _t < _hit_time() or _t >= DROP_START


func _enemy_stats() -> Vector2i:
	if _t >= _hit_time() and _t < DROP_START:
		return Vector2i(0, ENEMY_STATS.y)
	return ENEMY_STATS


## 体力と攻撃力の比から、砂の溜まり方の絵を選ぶ。
func _texture(id: String, stats: Vector2i) -> Texture2D:
	var frames: Array = _art[id]
	if stats.y > stats.x:
		return frames[2]
	if stats.y == stats.x:
		return frames[1]
	return frames[0]


## 反転の回転角(0〜PI)と浮き上がり。回り終わった瞬間に絵を正位置の反対側の状態へ差し替える。
func _hero_flip() -> Vector2:
	for span in [[FLIP_START, FLIP_SPAN], [FLIP_BACK_START, FLIP_BACK_SPAN]]:
		var k := _phase(span[0], span[1])
		if k > 0.0 and k < 1.0:
			var eased := smoothstep(0.0, 1.0, k)
			return Vector2(eased * PI, sin(k * PI) * 46.0)
	return Vector2.ZERO


# --- 描画 -----------------------------------------------------------------


func _draw() -> void:
	if _art.is_empty():
		return
	_draw_background()
	_draw_enemy()
	_draw_hero()
	_draw_impact()
	_draw_flip_word()
	_draw_damage_number()


func _draw_background() -> void:
	var ci := get_canvas_item()
	draw_texture_rect(_background, Rect2(Vector2.ZERO, VIEW), false)
	# 絵の上へ暗い幕を掛け、駒と数字を浮かせる。上端はロゴのためにさらに沈める。
	var shade := [
		[0.0, Color(0.02, 0.02, 0.05, 0.86)],
		[0.34, Color(0.03, 0.03, 0.06, 0.55)],
		[1.0, Color(0.03, 0.02, 0.04, 0.7)],
	]
	var full := Rect2(Vector2.ZERO, VIEW)
	UiPaint.fill_gradient_polygon(
		ci,
		PackedVector2Array([Vector2.ZERO, Vector2(VIEW.x, 0.0), VIEW, Vector2(0.0, VIEW.y)]),
		full,
		shade
	)
	# 駒の足元を照らす琥珀の光だまり。
	for i in range(5, 0, -1):
		var t := float(i) / 5.0
		UiPaint.fill_ellipse(
			ci,
			Vector2(VIEW.x * 0.5, FLOOR_Y - 10.0),
			Vector2(260.0 * t, 60.0 * t),
			Color(0.85, 0.62, 0.22, 0.05),
			48
		)
	draw_rect(Rect2(0.0, 0.0, VIEW.x, 5.0), UiPalette.GLOW_AMBER)
	draw_rect(Rect2(0.0, VIEW.y - 5.0, VIEW.x, 5.0), UiPalette.GLOW_AMBER)


## 背景の絵の中央を正方形に切り出し、小さく縮めたもの。
func _blurred_background() -> Texture2D:
	var image := BACKGROUND.get_image()
	var side := mini(image.get_width(), image.get_height())
	image = image.get_region(
		Rect2i((image.get_width() - side) / 2, (image.get_height() - side) / 2, side, side)
	)
	image.resize(BACKGROUND_BLUR_SIZE, BACKGROUND_BLUR_SIZE, Image.INTERPOLATE_LANCZOS)
	return ImageTexture.create_from_image(image)


func _draw_hero() -> void:
	var base := Vector2(HERO_X, FLOOR_Y)
	var offset := Vector2.ZERO
	var flip := _hero_flip()
	offset.y -= flip.y
	var strike := _phase(STRIKE_START, STRIKE_SPAN)
	if strike > 0.0 and strike < 1.0:
		var reach: float = smoothstep(0.0, 0.45, strike) - smoothstep(0.5, 1.0, strike)
		offset += (Vector2(ENEMY_X - 96.0, FLOOR_Y - 20.0) - base) * reach
		offset.y -= sin(reach * PI) * 30.0

	var stats := _hero_stats()
	var texture := _texture(HERO_ID, stats)
	if flip.x > 0.0:
		# 回転中は回り始める前の絵を回す。180度で差し替え先の絵とほぼ重なる。
		var before := HERO_AFTER if _t >= FLIP_BACK_START else HERO_BEFORE
		texture = _texture(HERO_ID, before)
	var width := HERO_HEIGHT * float(texture.get_width()) / float(texture.get_height())
	_draw_shadow(base + Vector2(offset.x, 0.0), width, clampf(-offset.y / 60.0, 0.0, 1.0))
	var center := base + offset - Vector2(0.0, HERO_HEIGHT * 0.5)
	draw_set_transform(center, flip.x, Vector2.ONE)
	draw_texture_rect(
		texture, Rect2(-Vector2(width, HERO_HEIGHT) * 0.5, Vector2(width, HERO_HEIGHT)), false
	)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	_draw_hero_badges(base + offset, width)


func _draw_enemy() -> void:
	if not _enemy_present():
		_draw_shatter()
		return
	var base := Vector2(ENEMY_X, FLOOR_Y)
	var offset := Vector2.ZERO
	if _t >= DROP_START:
		var k := _phase(DROP_START, DROP_SPAN)
		# 落ちてきて1度だけ弾む。
		var fall := 1.0 - k * k if k < 0.75 else absf(sin((k - 0.75) / 0.25 * PI)) * 0.08
		offset.y -= fall * 240.0
	elif _t < _hit_time() and _t > _hit_time() - 0.05:
		offset.x += 4.0
	var texture := _texture(ENEMY_ID, ENEMY_STATS)
	var width := ENEMY_HEIGHT * float(texture.get_width()) / float(texture.get_height())
	_draw_shadow(base, width, clampf(-offset.y / 200.0, 0.0, 1.0))
	var top_left := base + offset - Vector2(width * 0.5, ENEMY_HEIGHT)
	draw_texture_rect(texture, Rect2(top_left, Vector2(width, ENEMY_HEIGHT)), false)
	var stats := _enemy_stats()
	var y := base.y + offset.y - ENEMY_HEIGHT * 0.07
	_draw_badge(Vector2(base.x - width * 0.38, y), str(stats.y), ATTACK_COLOR, 1.0)
	_draw_badge(Vector2(base.x + width * 0.38, y), str(stats.x), HEALTH_COLOR, 1.0)


func _draw_shadow(at: Vector2, width: float, lift: float) -> void:
	UiPaint.fill_ellipse(
		get_canvas_item(),
		at,
		Vector2(width * 0.42 * (1.0 - lift * 0.4), 13.0),
		Color(0.0, 0.0, 0.0, 0.5 - lift * 0.25),
		32
	)


## 味方の攻撃力(左・赤)と体力(右・青)。反転の間は数字が弧を描いて左右を入れ替わる。
func _draw_hero_badges(base: Vector2, width: float) -> void:
	var y := base.y - HERO_HEIGHT * 0.07
	var left := Vector2(base.x - width * 0.38, y)
	var right := Vector2(base.x + width * 0.38, y)
	var swap := 0.0
	var from := HERO_BEFORE
	for span in [[FLIP_START, FLIP_SPAN], [FLIP_BACK_START, FLIP_BACK_SPAN]]:
		var k := _phase(span[0], span[1])
		if k > 0.0 and k < 1.0:
			swap = smoothstep(0.1, 0.9, k)
			from = HERO_AFTER if span[0] == FLIP_BACK_START else HERO_BEFORE
	if swap <= 0.0:
		var stats := _hero_stats()
		var pop := _pop_scale()
		_draw_badge(left, str(stats.y), ATTACK_COLOR, pop)
		_draw_badge(right, str(stats.x), HEALTH_COLOR, pop)
		return
	_draw_badge(left, "", ATTACK_COLOR, 1.0)
	_draw_badge(right, "", HEALTH_COLOR, 1.0)
	var lift := Vector2(0.0, -sin(swap * PI) * 70.0)
	_draw_number(left.lerp(right, swap) + lift, str(from.y), 1.0 + sin(swap * PI) * 0.5)
	_draw_number(right.lerp(left, swap) - lift * 0.6, str(from.x), 1.0 + sin(swap * PI) * 0.5)


## 反転し終えた直後に数字をひと跳ねさせる。
func _pop_scale() -> float:
	var best := 1.0
	for moment in [FLIP_START + FLIP_SPAN, FLIP_BACK_START + FLIP_BACK_SPAN]:
		var since := _t - float(moment)
		if since >= 0.0 and since < 0.3:
			best = maxf(best, 1.0 + sin(since / 0.3 * PI) * 0.35)
	return best


func _draw_badge(at: Vector2, value: String, color: Color, pop: float) -> void:
	var ci := get_canvas_item()
	var radius := 25.0 * pop
	UiPaint.fill_ellipse(ci, at, Vector2(radius + 4.0, radius + 4.0), INK, 28)
	UiPaint.fill_ellipse(ci, at, Vector2(radius, radius), color, 28)
	UiPaint.fill_ellipse(
		ci,
		at - Vector2(0.0, radius * 0.35),
		Vector2(radius * 0.7, radius * 0.45),
		Color(1.0, 1.0, 1.0, 0.18),
		20
	)
	UiPaint.draw_ellipse_ring(ci, at, Vector2(radius + 2.0, radius + 2.0), GOLD, 2.5, 28)
	if value != "":
		_draw_number(at, value, pop)


func _draw_number(at: Vector2, value: String, scale_by: float) -> void:
	var font_size := int(34.0 * scale_by)
	var baseline := Vector2(at.x - 40.0, at.y + font_size * 0.36)
	draw_string_outline(
		_display_font, baseline, value, HORIZONTAL_ALIGNMENT_CENTER, 80.0, font_size, 7, INK
	)
	draw_string(
		_display_font,
		baseline,
		value,
		HORIZONTAL_ALIGNMENT_CENTER,
		80.0,
		font_size,
		UiPalette.TEXT_OFFWHITE
	)


## 「反転!」の文字。一覧の小さな表示でも読めるよう、大きく縁取って味方の頭上へ出す。
func _draw_flip_word() -> void:
	var since := _t - FLIP_START
	if since < 0.0 or since > 1.0:
		return
	var grow := minf(since / 0.15, 1.0)
	var font_size := int(lerpf(30.0, 64.0, grow) + sin(minf(since / 0.3, 1.0) * PI) * 10.0)
	var alpha := 1.0 - _phase(FLIP_START + 0.75, 0.25)
	var baseline := Vector2(VIEW.x * 0.5 - 120.0, 226.0)
	var text := "反転!"
	draw_string_outline(
		_display_font,
		baseline + Vector2(0.0, 4.0),
		text,
		HORIZONTAL_ALIGNMENT_CENTER,
		240.0,
		font_size,
		16,
		Color(0.0, 0.0, 0.0, 0.5 * alpha)
	)
	draw_string_outline(
		_display_font,
		baseline,
		text,
		HORIZONTAL_ALIGNMENT_CENTER,
		240.0,
		font_size,
		12,
		Color(INK, alpha)
	)
	draw_string(
		_display_font,
		baseline,
		text,
		HORIZONTAL_ALIGNMENT_CENTER,
		240.0,
		font_size,
		Color(GOLD, alpha)
	)


## 与えたダメージ。相手のいた場所から浮き上がって消える。
func _draw_damage_number() -> void:
	var since := _t - _hit_time()
	if since < 0.0 or since > 1.0:
		return
	var font_size := int(72.0 + sin(minf(since / 0.2, 1.0) * PI) * 18.0)
	var alpha := 1.0 - _phase(_hit_time() + 0.7, 0.3)
	var baseline := Vector2(ENEMY_X - 110.0, 250.0 - since * 40.0)
	var text := "-%d" % HERO_AFTER.y
	draw_string_outline(
		_display_font,
		baseline,
		text,
		HORIZONTAL_ALIGNMENT_CENTER,
		220.0,
		font_size,
		12,
		Color(INK, alpha)
	)
	draw_string(
		_display_font,
		baseline,
		text,
		HORIZONTAL_ALIGNMENT_CENTER,
		220.0,
		font_size,
		Color(1.0, 0.42, 0.3, alpha)
	)


## 着弾の閃光と衝撃の輪。
func _draw_impact() -> void:
	var hit := _hit_time()
	if _t < hit or _t > hit + 0.5:
		return
	var k := (_t - hit) / 0.5
	var fade := 1.0 - k
	var ci := get_canvas_item()
	var at := Vector2(ENEMY_X - 20.0, FLOOR_Y - 110.0)
	UiPaint.fill_ellipse(
		ci, at, Vector2(70.0, 62.0) * (0.4 + k * 1.4), Color(1.0, 0.96, 0.82, fade), 32
	)
	for i in range(3):
		var ring := k * (1.0 + float(i) * 0.5)
		UiPaint.draw_ellipse_ring(
			ci,
			at,
			Vector2(50.0, 44.0) * (0.4 + ring * 2.6),
			Color(1.0, 0.82, 0.46, fade * 0.9),
			5.0 - float(i),
			32
		)


## 砕けた相手の砂が飛び散って床へ落ちる。
func _draw_shatter() -> void:
	var since := _t - _hit_time()
	if since < 0.0 or since > SHATTER_SPAN:
		return
	var k := since / SHATTER_SPAN
	var fade := 1.0 - k
	var ci := get_canvas_item()
	var at := Vector2(ENEMY_X, FLOOR_Y - ENEMY_HEIGHT * 0.5)
	for i in range(28):
		var angle := TAU * float(i) / 28.0 + 0.3
		var reach := 10.0 + k * (90.0 + fmod(float(i) * 37.0, 70.0))
		var point := at + Vector2(cos(angle), sin(angle) * 0.9) * reach
		point.y += k * k * 120.0
		var grain := 5.0 + fmod(float(i) * 13.0, 3.0)
		UiPaint.fill_ellipse(
			ci, point, Vector2(grain, grain) * (1.0 - k * 0.5), Color(0.99, 0.75, 0.36, fade), 8
		)


func _font() -> Font:
	var font := get_theme_font("font", "Label")
	return font if font != null else ThemeDB.fallback_font
