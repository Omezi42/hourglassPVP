extends Control
## YouTubeのPV用サムネイル(1280x720の静止画)を書き出す。
## 左にロゴと惹句、右に「ひっくり返して殴る」瞬間の砂時計を大きく置く。
## 一覧の小さな表示でも読めるよう、文字は2行だけにして太く縁取る。
##
## 実行(実際の描画結果を読むため --headless は付けない):
##   godot --path . res://tools/record_thumbnail_youtube.tscn -- <出力先.png>

const VIEW := Vector2(1280.0, 720.0)
const BACKGROUND := preload("res://assets/backgrounds/processed/battle/background.png")
const FLOOR_Y := 640.0
const HERO_ID := "sand"
const ENEMY_ID := "poison"
const HERO_CENTER := Vector2(840.0, 360.0)
const HERO_HEIGHT := 440.0
## 反転の途中を切り取った傾き。
const HERO_TILT := deg_to_rad(-28.0)
const ENEMY_BASE := Vector2(1150.0, FLOOR_Y)
const ENEMY_HEIGHT := 300.0
const HERO_STATS := Vector2i(1, 5)

const LOGO_SCALE := 0.9
const LOGO_POSITION := Vector2(20.0, 40.0)
const COPY_LEFT := 60.0
const COPY_WIDTH := 560.0
const COPY_LINE1 := "ひっくり返せば"
const COPY_LINE2 := "攻守逆転!"

const ATTACK_COLOR := Color(0.88, 0.34, 0.2, 1.0)
const HEALTH_COLOR := Color(0.3, 0.58, 0.9, 1.0)
const GOLD := Color(1.0, 0.84, 0.42, 1.0)
const INK := Color(0.06, 0.09, 0.19, 1.0)
## 描き終えてから読み出すまでに待つコマ数(ロゴの金箔が子ノードとして描かれるのを待つ)。
const SETTLE_FRAMES := 3

var _art: Dictionary = {}
var _display_font: Font


func _ready() -> void:
	theme = load("res://resources/theme/main_theme.tres")
	_display_font = UiFonts.display_font(_font())
	await HourglassArt.ensure_ready_and_wait(self)
	for id in [HERO_ID, ENEMY_ID]:
		var frames: Array[Texture2D] = []
		for state in HourglassArt.State.values():
			frames.append(HourglassArt.texture(id, state))
		_art[id] = frames
	var logo := TitleLogo.new()
	logo.size = Vector2(COPY_WIDTH / LOGO_SCALE + 120.0, 290.0)
	logo.scale = Vector2(LOGO_SCALE, LOGO_SCALE)
	logo.position = LOGO_POSITION
	add_child(logo)
	queue_redraw()
	for i in SETTLE_FRAMES:
		await RenderingServer.frame_post_draw
	var args := OS.get_cmdline_user_args()
	var out := args[0] if not args.is_empty() else "user://youtube_thumbnail.png"
	get_viewport().get_texture().get_image().save_png(out)
	print("SAVED=%s" % out)
	get_tree().quit()


func _draw() -> void:
	if _art.is_empty():
		return
	_draw_background()
	_draw_trail()
	_draw_enemy()
	_draw_impact()
	_draw_hero()
	_draw_damage()
	_draw_copy()


func _draw_background() -> void:
	var ci := get_canvas_item()
	var full := Rect2(Vector2.ZERO, VIEW)
	var tex_size := BACKGROUND.get_size()
	var cover := maxf(VIEW.x / tex_size.x, VIEW.y / tex_size.y)
	draw_texture_rect(BACKGROUND, Rect2((VIEW - tex_size * cover) * 0.5, tex_size * cover), false)
	var corners := PackedVector2Array(
		[Vector2.ZERO, Vector2(VIEW.x, 0.0), VIEW, Vector2(0.0, VIEW.y)]
	)
	# 文字を置く左側を深く沈め、右の駒へ向かって明けていく。
	(
		UiPaint
		. fill_gradient_polygon(
			ci,
			corners,
			full,
			[
				[0.0, Color(0.02, 0.02, 0.05, 0.92)],
				[0.45, Color(0.03, 0.03, 0.06, 0.72)],
				[1.0, Color(0.03, 0.02, 0.04, 0.45)],
			]
		)
	)
	# 駒の背後に灯す琥珀の光。
	for i in range(8, 0, -1):
		var t := float(i) / 8.0
		UiPaint.fill_ellipse(
			ci,
			HERO_CENTER + Vector2(60.0, 40.0),
			Vector2(520.0, 360.0) * t,
			Color(0.9, 0.6, 0.2, 0.045),
			64
		)
	draw_rect(Rect2(0.0, 0.0, VIEW.x, 8.0), UiPalette.GLOW_AMBER)
	draw_rect(Rect2(0.0, VIEW.y - 8.0, VIEW.x, 8.0), UiPalette.GLOW_AMBER)


## 反転の軌跡。駒の周りを弧を描いて回る金の砂粒。
func _draw_trail() -> void:
	var ci := get_canvas_item()
	var radius := Vector2(250.0, 250.0)
	var steps := 40
	for i in steps:
		var k := float(i) / float(steps - 1)
		var angle := lerpf(PI * 0.95, PI * 1.75, k)
		var point := HERO_CENTER + Vector2(cos(angle), sin(angle)) * radius
		var grain := lerpf(3.0, 11.0, k)
		UiPaint.fill_ellipse(ci, point, Vector2(grain, grain), Color(GOLD, lerpf(0.1, 0.95, k)), 12)
	for i in 24:
		var angle := PI * (0.95 + 0.8 * fmod(float(i) * 0.37, 1.0))
		var reach := 250.0 + fmod(float(i) * 23.0, 40.0) - 20.0
		var point := HERO_CENTER + Vector2(cos(angle), sin(angle)) * reach
		UiPaint.fill_ellipse(ci, point, Vector2(3.0, 3.0), Color(GOLD, 0.55), 8)


func _draw_hero() -> void:
	var texture := _texture(HERO_ID, HERO_STATS)
	var width := HERO_HEIGHT * float(texture.get_width()) / float(texture.get_height())
	var rect := Rect2(-Vector2(width, HERO_HEIGHT) * 0.5, Vector2(width, HERO_HEIGHT))
	draw_set_transform(HERO_CENTER + Vector2(0.0, 10.0), HERO_TILT, Vector2.ONE)
	draw_texture_rect(texture, rect, false, Color(0.0, 0.0, 0.0, 0.5))
	draw_set_transform(HERO_CENTER, HERO_TILT, Vector2.ONE)
	draw_texture_rect(texture, rect, false)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	var badge_y := HERO_CENTER.y + HERO_HEIGHT * 0.42
	_draw_badge(
		Vector2(HERO_CENTER.x - width * 0.55, badge_y), str(HERO_STATS.y), ATTACK_COLOR, 1.6
	)
	_draw_badge(
		Vector2(HERO_CENTER.x + width * 0.35, badge_y + 30.0), str(HERO_STATS.x), HEALTH_COLOR, 1.2
	)


func _draw_enemy() -> void:
	var texture := _texture(ENEMY_ID, Vector2i(4, 0))
	var width := ENEMY_HEIGHT * float(texture.get_width()) / float(texture.get_height())
	var center := ENEMY_BASE - Vector2(0.0, ENEMY_HEIGHT * 0.5)
	# 殴られて後ろへ傾いだところ。
	draw_set_transform(center, deg_to_rad(12.0), Vector2.ONE)
	draw_texture_rect(
		texture,
		Rect2(-Vector2(width, ENEMY_HEIGHT) * 0.5, Vector2(width, ENEMY_HEIGHT)),
		false,
		Color(1.0, 0.85, 0.8, 1.0)
	)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


func _draw_impact() -> void:
	var ci := get_canvas_item()
	var at := ENEMY_BASE + Vector2(-70.0, -ENEMY_HEIGHT * 0.55)
	for i in 14:
		var angle := TAU * float(i) / 14.0 + 0.2
		var length := 150.0 + fmod(float(i) * 41.0, 90.0)
		var tip := at + Vector2(cos(angle), sin(angle)) * length
		var side := Vector2(-sin(angle), cos(angle)) * 9.0
		draw_colored_polygon(
			PackedVector2Array([at + side, tip, at - side]), Color(1.0, 0.88, 0.55, 0.55)
		)
	UiPaint.fill_ellipse(ci, at, Vector2(95.0, 85.0), Color(1.0, 0.96, 0.82, 0.55), 40)
	UiPaint.fill_ellipse(ci, at, Vector2(55.0, 50.0), Color(1.0, 0.98, 0.9, 0.9), 40)
	UiPaint.draw_ellipse_ring(ci, at, Vector2(140.0, 125.0), Color(1.0, 0.82, 0.46, 0.8), 5.0, 48)
	for i in 30:
		var angle := TAU * float(i) / 30.0 + 0.3
		var reach := 110.0 + fmod(float(i) * 37.0, 120.0)
		var grain := 6.0 + fmod(float(i) * 13.0, 4.0)
		UiPaint.fill_ellipse(
			ci,
			at + Vector2(cos(angle), sin(angle) * 0.9) * reach,
			Vector2(grain, grain),
			Color(0.99, 0.75, 0.36, 0.9),
			8
		)


func _draw_damage() -> void:
	var baseline := Vector2(ENEMY_BASE.x - 200.0, 200.0)
	_draw_outlined(baseline, "-%d" % HERO_STATS.y, 300.0, 120, 18, Color(1.0, 0.42, 0.3, 1.0))


func _draw_copy() -> void:
	var left := Vector2(COPY_LEFT, 0.0)
	_draw_outlined(
		left + Vector2(0.0, 440.0), COPY_LINE1, COPY_WIDTH, 72, 16, UiPalette.TEXT_OFFWHITE
	)
	_draw_outlined(left + Vector2(0.0, 590.0), COPY_LINE2, COPY_WIDTH, 124, 22, GOLD)


func _draw_outlined(
	baseline: Vector2, text: String, width: float, font_size: int, outline: int, color: Color
) -> void:
	draw_string_outline(
		_display_font,
		baseline + Vector2(0.0, 6.0),
		text,
		HORIZONTAL_ALIGNMENT_CENTER,
		width,
		font_size,
		outline + 6,
		Color(0.0, 0.0, 0.0, 0.5)
	)
	draw_string_outline(
		_display_font, baseline, text, HORIZONTAL_ALIGNMENT_CENTER, width, font_size, outline, INK
	)
	draw_string(_display_font, baseline, text, HORIZONTAL_ALIGNMENT_CENTER, width, font_size, color)


func _draw_badge(at: Vector2, value: String, color: Color, scale_by: float) -> void:
	var ci := get_canvas_item()
	var radius := 25.0 * scale_by
	UiPaint.fill_ellipse(ci, at, Vector2(radius + 5.0, radius + 5.0), INK, 32)
	UiPaint.fill_ellipse(ci, at, Vector2(radius, radius), color, 32)
	UiPaint.fill_ellipse(
		ci,
		at - Vector2(0.0, radius * 0.35),
		Vector2(radius * 0.7, radius * 0.45),
		Color(1.0, 1.0, 1.0, 0.18),
		24
	)
	UiPaint.draw_ellipse_ring(ci, at, Vector2(radius + 2.5, radius + 2.5), GOLD, 3.0, 32)
	var font_size := int(34.0 * scale_by)
	_draw_outlined(
		Vector2(at.x - 60.0, at.y + font_size * 0.36),
		value,
		120.0,
		font_size,
		8,
		UiPalette.TEXT_OFFWHITE
	)


func _texture(id: String, stats: Vector2i) -> Texture2D:
	var frames: Array = _art[id]
	if stats.y > stats.x:
		return frames[2]
	if stats.y == stats.x:
		return frames[1]
	return frames[0]


func _font() -> Font:
	var font := get_theme_font("font", "Label")
	return font if font != null else ThemeDB.fallback_font
