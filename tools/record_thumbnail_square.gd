extends Control
## サムネ用の正方形GIF(512x512)の素材フレームを書き出す。
## 対局画面そのままではなく、目を引く動きだけを抜き出した抽象的な絵にする。
## 説明の文は載せない(サムネで読ませるものではないため)。ロゴと、砂が流れる・
## 反転する・殴りかかるという3つの動きだけで「対戦するゲーム」だと伝える。
##
## 実行(固定デルタで書き出すため --write-movie と --fixed-fps を必ず付ける):
##   godot --path . --write-movie scratchpad/sq/f.png
##     --fixed-fps 10 res://tools/record_thumbnail_square.tscn
##
## GIFへの変換(1280x720で書き出されるため中央を切り抜く):
##   magick -delay 10 -loop 0 scratchpad/sq/f0*.png -crop 512x512+384+104 +repage
##     -colors 96 -fuzz 3% -layers OptimizeFrame -layers OptimizeTransparency thumb512.gif
##
## 512KB以下に収めるため、背景は完全に静止させ、動くのは中央の駒と着弾の演出だけに
## とどめている。GIFはフレーム間の差分を持つ形式で、画面の広い範囲がわずかでも動くと
## そのコマを丸ごと持つことになり、容量が数倍に膨らむ。

const VIEW := Vector2(512.0, 512.0)
const FLOOR_Y := 400.0
const PIECE_HEIGHT := 180.0
const HERO_HEIGHT := 212.0

## 台本の時刻(秒)。
const FLIP_BEAM := 0.42
const FLIP_START := 0.76
const FLIP_SPAN := 0.46
const STRIKE_START := 1.44
const STRIKE_SPAN := 0.96
const END_TIME := 3.10

## 駒の並び。x座標と、元になる砂時計のid(色が散るように選ぶ)。
const SLOTS := [
	{"x": 96.0, "id": "shield", "height": PIECE_HEIGHT},
	{"x": 256.0, "id": "sand", "height": HERO_HEIGHT},
	{"x": 416.0, "id": "poison", "height": PIECE_HEIGHT},
]

var _t := 0.0
## id -> [state_full, state_falling, state_empty]
var _art: Dictionary = {}


func _ready() -> void:
	theme = load("res://resources/theme/main_theme.tres")
	# 書き出しは1280x720で行われる(--resolutionでは変えられない)。
	# 512x512の絵を画面の中央へ置いておき、変換時に切り抜く。
	anchor_right = 0.0
	anchor_bottom = 0.0
	size = VIEW
	position = ((Vector2(1280.0, 720.0) - VIEW) * 0.5).floor()
	for slot in SLOTS:
		var frames: Array[Texture2D] = []
		for state in ["state_full", "state_falling", "state_empty"]:
			frames.append(
				load("res://assets/hourglasses/processed/%s/%s.png" % [slot["id"], state])
			)
		_art[slot["id"]] = frames
	var logo := TitleLogo.new()
	logo.size = Vector2(760.0, 150.0)
	logo.scale = Vector2(0.63, 0.63)
	logo.position = Vector2((VIEW.x - 760.0 * 0.63) * 0.5, 12.0)
	add_child(logo)


func _process(delta: float) -> void:
	_t += delta
	if _t >= END_TIME:
		get_tree().quit()
		return
	queue_redraw()


# --- 台本の読み出し -------------------------------------------------------


## 0〜1で返す。範囲の外は0または1。
func _phase(start: float, span: float) -> float:
	return clampf((_t - start) / span, 0.0, 1.0)


## 反転が終わっているか。中央の駒の体力と攻撃力はここで入れ替わる。
func _flipped() -> bool:
	return _t >= FLIP_START + FLIP_SPAN * 0.5


func _hit() -> bool:
	return _t >= STRIKE_START + STRIKE_SPAN * 0.45


## 駒ごとの体力・攻撃力。反転と相打ちを反映する。
func _stats(index: int) -> Vector2i:
	match index:
		0:
			return Vector2i(1, 1) if _hit() else Vector2i(5, 1)
		1:
			var base := Vector2i(2, 4) if _flipped() else Vector2i(4, 2)
			return Vector2i(base.x - 1, base.y) if _hit() else base
		_:
			return Vector2i(3, 3)


func _texture(index: int) -> Texture2D:
	var stats := _stats(index)
	var frames: Array = _art[SLOTS[index]["id"]]
	if stats.y > stats.x:
		return frames[2]
	if stats.y == stats.x:
		return frames[1]
	return frames[0]


# --- 描画 -----------------------------------------------------------------


func _draw() -> void:
	_draw_background()
	_draw_beam()
	for i in range(SLOTS.size()):
		_draw_piece(i)
	_draw_impact()


func _draw_background() -> void:
	var ci := get_canvas_item()
	draw_rect(Rect2(Vector2.ZERO, VIEW), Color(0.07, 0.07, 0.09, 1.0))
	# 中央から広がる琥珀の光。反転と着弾の瞬間だけ強くして、絵全体を脈打たせる。
	# 駒の背後だけを弱く照らす。GIFは色数が少なく、広く強い階調を作ると
	# 縞(バンディング)になって安っぽく見えるため、halo は薄く小さくとどめる。
	for i in range(6, 0, -1):
		var t := float(i) / 6.0
		UiPaint.fill_ellipse(
			ci,
			Vector2(VIEW.x * 0.5, 300.0),
			Vector2(240.0 * t, 170.0 * t),
			Color(0.85, 0.62, 0.22, 0.02),
			44
		)
	# 卓。奥へ狭まる台形1枚だけで「盤面に並んでいる」ことを示す。
	var top := FLOOR_Y - 104.0
	var table := PackedVector2Array(
		[
			Vector2(150.0, top),
			Vector2(VIEW.x - 150.0, top),
			Vector2(VIEW.x - 4.0, FLOOR_Y + 40.0),
			Vector2(4.0, FLOOR_Y + 40.0),
		]
	)
	var stops := [[0.0, Color(0.13, 0.12, 0.14, 1.0)], [1.0, Color(0.27, 0.22, 0.19, 1.0)]]
	var table_rect := Rect2(0.0, top, VIEW.x, FLOOR_Y + 40.0 - top)
	UiPaint.fill_gradient_polygon(ci, table, table_rect, stops)
	draw_line(Vector2(150.0, top), Vector2(VIEW.x - 150.0, top), UiPalette.GLOW_AMBER, 2.0)
	draw_rect(Rect2(0.0, 0.0, VIEW.x, 4.0), UiPalette.GLOW_AMBER)
	draw_rect(Rect2(0.0, VIEW.y - 4.0, VIEW.x, 4.0), UiPalette.GLOW_AMBER)


## 反転の光の筋。卓の手前から中央の駒へ伸び、届いた瞬間に裏返る。
func _draw_beam() -> void:
	var beam := _phase(FLIP_BEAM, FLIP_START - FLIP_BEAM)
	if beam <= 0.0 or _t > FLIP_START + FLIP_SPAN * 0.6:
		return
	var fade := 1.0 if _t < FLIP_START else 1.0 - _phase(FLIP_START, FLIP_SPAN * 0.6)
	var from := Vector2(VIEW.x * 0.5, FLOOR_Y + 78.0)
	var to := from.lerp(Vector2(VIEW.x * 0.5, FLOOR_Y - HERO_HEIGHT * 0.5), beam)
	for i in range(3):
		var width := 26.0 - float(i) * 8.0
		var alpha := (0.10 + float(i) * 0.16) * fade
		draw_colored_polygon(
			PackedVector2Array(
				[
					from + Vector2(-width, 0.0),
					from + Vector2(width, 0.0),
					to + Vector2(width * 0.35, 0.0),
					to + Vector2(-width * 0.35, 0.0),
				]
			),
			Color(1.0, 0.84, 0.45, alpha)
		)


func _draw_piece(index: int) -> void:
	var slot: Dictionary = SLOTS[index]
	var height: float = slot["height"]
	var base := Vector2(slot["x"], FLOOR_Y)
	var offset := Vector2.ZERO
	var squash := 1.0

	if index == 1:
		var flip := _phase(FLIP_START, FLIP_SPAN)
		if flip > 0.0 and flip < 1.0:
			squash = maxf(absf(cos(flip * PI)), 0.05)
			offset.y -= sin(flip * PI) * 30.0
		var strike := _phase(STRIKE_START, STRIKE_SPAN)
		if strike > 0.0 and strike < 1.0:
			var reach: float = smoothstep(0.0, 0.45, strike) - smoothstep(0.5, 1.0, strike)
			offset += (_strike_target() - base) * reach
			offset.y -= sin(reach * PI) * 18.0
	elif index == 0 and _hit():
		# 殴られた側は押し返された反動で揺れる。
		var since := _t - (STRIKE_START + STRIKE_SPAN * 0.45)
		offset.x -= exp(-since * 7.0) * sin(since * 42.0) * 9.0

	var texture := _texture(index)
	var width := height * float(texture.get_width()) / float(texture.get_height())
	var top_left := base + offset - Vector2(width * 0.5, height * squash)
	# 台座の影。駒が浮くほど小さく薄くする。
	var lift := clampf(-offset.y / 40.0, 0.0, 1.0)
	UiPaint.fill_ellipse(
		get_canvas_item(),
		base + Vector2(offset.x, 0.0),
		Vector2(width * 0.42 * (1.0 - lift * 0.3), 12.0),
		Color(0.0, 0.0, 0.0, 0.45 - lift * 0.2),
		32
	)
	draw_texture_rect(texture, Rect2(top_left, Vector2(width, height * squash)), false)
	_draw_badges(index, base + offset, width, height * squash)


## 攻撃の的。左の駒の右斜め上へ渡っていき、上から叩く。真上に重ねると
## 殴られている側が完全に隠れてしまうため、右へずらしてどちらも見えるようにする。
func _strike_target() -> Vector2:
	return Vector2(float(SLOTS[0]["x"]) + 96.0, FLOOR_Y - 66.0)


## 当たった場所。殴られている駒の胴。
func _impact_point() -> Vector2:
	return Vector2(float(SLOTS[0]["x"]) + 34.0, FLOOR_Y - 96.0)


## 攻撃力と体力の数字。説明は載せないが、数字があることで
## 「殴り合うゲーム」だと一目で伝わる。
func _draw_badges(index: int, base: Vector2, width: float, height: float) -> void:
	var stats := _stats(index)
	var y := base.y - height * 0.06
	_draw_badge(Vector2(base.x - width * 0.36, y), stats.y, Color(0.86, 0.36, 0.22, 1.0))
	_draw_badge(Vector2(base.x + width * 0.36, y), stats.x, Color(0.34, 0.6, 0.86, 1.0))


func _draw_badge(at: Vector2, value: int, color: Color) -> void:
	var ci := get_canvas_item()
	UiPaint.fill_ellipse(ci, at, Vector2(17.0, 17.0), Color(0.06, 0.06, 0.08, 1.0), 24)
	UiPaint.fill_ellipse(ci, at, Vector2(14.0, 14.0), color, 24)
	UiPaint.draw_ellipse_ring(ci, at, Vector2(16.0, 16.0), UiPalette.BRASS_HIGHLIGHT, 2.0, 24)
	draw_string(
		_font(),
		Vector2(at.x - 20.0, at.y + 8.0),
		str(value),
		HORIZONTAL_ALIGNMENT_CENTER,
		40.0,
		22,
		UiPalette.TEXT_OFFWHITE
	)


## 反転が決まった瞬間と、攻撃が当たった瞬間の強さ(0〜1)。
func _flash_strength() -> float:
	var landed := FLIP_START + FLIP_SPAN * 0.5
	var hit := STRIKE_START + STRIKE_SPAN * 0.45
	var best := 0.0
	for moment in [landed, hit]:
		if _t >= moment:
			best = maxf(best, exp(-(_t - float(moment)) * 6.0))
	return best


## 着弾。閃光・広がる衝撃波・砕けて散る砂。サムネで一番目を引く瞬間のため、
## ここだけは他より派手に描く。
func _draw_impact() -> void:
	var hit := STRIKE_START + STRIKE_SPAN * 0.45
	if _t < hit or _t > hit + 0.6:
		return
	var k := (_t - hit) / 0.6
	var fade := 1.0 - k
	var ci := get_canvas_item()
	var at := _impact_point()
	UiPaint.fill_ellipse(
		ci, at, Vector2(54.0, 48.0) * (0.4 + k * 1.6), Color(1.0, 0.96, 0.82, fade), 32
	)
	for i in range(3):
		var ring := k * (1.0 + float(i) * 0.5)
		UiPaint.draw_ellipse_ring(
			ci,
			at,
			Vector2(46.0, 40.0) * (0.4 + ring * 2.4),
			Color(1.0, 0.82, 0.46, fade * 0.9),
			4.0 - float(i),
			32
		)
	# 足元へ広がる衝撃波。
	UiPaint.draw_ellipse_ring(
		ci,
		Vector2(float(SLOTS[0]["x"]) + 20.0, FLOOR_Y),
		Vector2(40.0 + k * 150.0, 10.0 + k * 34.0),
		Color(1.0, 0.78, 0.4, fade * 0.7),
		3.0,
		40
	)
	# 砕けて散る砂。
	for i in range(22):
		var angle := TAU * float(i) / 22.0 + 0.22
		var reach := 18.0 + k * (110.0 + fmod(float(i) * 37.0, 60.0))
		var point := at + Vector2(cos(angle), sin(angle) * 0.85) * reach
		point.y += k * k * 46.0
		UiPaint.fill_ellipse(ci, point, Vector2(4.0, 4.0) * fade, Color(0.99, 0.75, 0.36, fade), 8)


func _font() -> Font:
	var font := get_theme_font("font", "Label")
	return font if font != null else ThemeDB.fallback_font
