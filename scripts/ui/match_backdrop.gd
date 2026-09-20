class_name MatchBackdrop
extends Control
## 対局画面専用の下地(GameDesign.md 9章「光と影」の検証用モック)。
## `ScreenBackdrop.PLAIN` の代わりに使い、「1つの光源で照らされた卓」という質感を足す。
##
## 描くのは背面から順に、床 → 卓の中心の光だまり → 卓・手札・情報帯への落ち影 →
## 四辺のビネット。`CardMatchScreen` の座標は**関数の中で実行時に読む**
## (Architecture.md 11章「class_nameを持つ2つのスクリプトが、互いのconstを
## constから参照してはいけない」)。

## 床の縦グラデーション。`ScreenBackdrop.STOPS` よりやや暖色寄り・やや暗め。
const FLOOR_STOPS := [
	[0.0, Color(0.11, 0.09, 0.10, 1.0)],
	[0.45, Color(0.19, 0.15, 0.15, 1.0)],
	[1.0, Color(0.07, 0.05, 0.06, 1.0)],
]
const FLOOR_GRAIN_ALPHA := 0.05

## 卓の中心に置く光だまり。同心の楕円を外へ向かって透明にしながら重ねる。
const GLOW_PEAK_ALPHA := 0.20
const GLOW_WIDTH_RATIO := 1.8
const GLOW_HEIGHT_RATIO := 1.5

## 四辺のビネット。`ScreenBackdrop._draw_vignette()` と同じ書き方(半透明の帯を
## 段階的に重ねる)を、上下左右の4辺すべてへ広げる。
const VIGNETTE_STEPS := 6
const VIGNETTE_WIDTH_RATIO := 0.18
const VIGNETTE_ALPHA := 0.45

## 落ち影。光源は上・中央にあるものとして、影は真下へわずかにずらす。
const SHADOW_OFFSET := Vector2(0.0, 8.0)
const SHADOW_STEPS := 5
const SHADOW_GROW_MIN := 4.0
const SHADOW_GROW_MAX := 12.0
const SHADOW_ALPHA_MIN := 0.03
const SHADOW_ALPHA_MAX := 0.32
const SHADOW_CORNER_RADIUS := 18.0
const SHADOW_CORNER_SEGMENTS := 8
## 卓の影だけは、盤面が1つの卓であることを強調するためもう少し濃く広くする。
const TABLE_SHADOW_STEPS := 6
const TABLE_SHADOW_GROW_MAX := 26.0
const TABLE_SHADOW_ALPHA_MAX := 0.42

static var _glow_cache: GradientTexture2D


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	anchor_right = 1.0
	anchor_bottom = 1.0


func _draw() -> void:
	var ci := get_canvas_item()
	var rect := Rect2(Vector2.ZERO, size)
	_draw_floor(ci, rect)
	_draw_glow_pool(ci)
	_draw_drop_shadows(ci)
	_draw_vignette()


func _draw_floor(ci: RID, rect: Rect2) -> void:
	var points := PackedVector2Array(
		[rect.position, Vector2(rect.end.x, 0.0), rect.end, Vector2(0.0, rect.end.y)]
	)
	UiPaint.fill_gradient_polygon(ci, points, rect, FLOOR_STOPS)
	UiPaint.apply_grain(ci, rect, FLOOR_GRAIN_ALPHA)


## 卓の後ろに広がる淡い光。`BoardGlow`(卓の額の外周だけを光らせる)とは別に、
## より広い範囲の空気そのものを暖色で持ち上げる。
func _draw_glow_pool(_ci: RID) -> void:
	var center: Vector2 = CardMatchScreen.TABLE_RECT.get_center()
	var half := Vector2(
		CardMatchScreen.TABLE_RECT.size.x * GLOW_WIDTH_RATIO * 0.5,
		CardMatchScreen.TABLE_RECT.size.y * GLOW_HEIGHT_RATIO * 0.5
	)
	# 同心の楕円を重ねると段が見えるため、放射状のグラデーションを1枚で敷く。
	draw_texture_rect(_glow_texture(), Rect2(center - half, half * 2.0), false)


static func _glow_texture() -> GradientTexture2D:
	if _glow_cache != null:
		return _glow_cache
	var gradient := Gradient.new()
	var amber := UiPalette.GLOW_AMBER
	gradient.set_color(0, Color(amber.r, amber.g, amber.b, GLOW_PEAK_ALPHA))
	gradient.set_color(1, Color(amber.r, amber.g, amber.b, 0.0))
	gradient.add_point(0.45, Color(amber.r, amber.g, amber.b, GLOW_PEAK_ALPHA * 0.45))
	var texture := GradientTexture2D.new()
	texture.gradient = gradient
	texture.fill = GradientTexture2D.FILL_RADIAL
	texture.fill_from = Vector2(0.5, 0.5)
	texture.fill_to = Vector2(1.0, 0.5)
	texture.width = 256
	texture.height = 256
	_glow_cache = texture
	return texture


## 卓・手札・情報帯それぞれの下へ落ち影を敷く。
func _draw_drop_shadows(ci: RID) -> void:
	var bar_size := Vector2(CardMatchScreen.BAR_WIDTH, PlayerInfoBar.BAR_HEIGHT)
	var foe_bar_rect := Rect2(
		Vector2(CardMatchScreen.MARGIN, CardMatchScreen.FOE_BAR_TOP), bar_size
	)
	var own_bar_rect := Rect2(
		Vector2(CardMatchScreen.MARGIN, CardMatchScreen.OWN_BAR_TOP), bar_size
	)
	_draw_shadow_layers(
		ci,
		CardMatchScreen.TABLE_RECT,
		TABLE_SHADOW_STEPS,
		SHADOW_GROW_MIN,
		TABLE_SHADOW_GROW_MAX,
		SHADOW_ALPHA_MIN,
		TABLE_SHADOW_ALPHA_MAX
	)
	_draw_shadow_layers(
		ci,
		CardMatchScreen.HAND_AREA,
		SHADOW_STEPS,
		SHADOW_GROW_MIN,
		SHADOW_GROW_MAX,
		SHADOW_ALPHA_MIN,
		SHADOW_ALPHA_MAX
	)
	_draw_shadow_layers(
		ci,
		foe_bar_rect,
		SHADOW_STEPS,
		SHADOW_GROW_MIN,
		SHADOW_GROW_MAX,
		SHADOW_ALPHA_MIN,
		SHADOW_ALPHA_MAX
	)
	_draw_shadow_layers(
		ci,
		own_bar_rect,
		SHADOW_STEPS,
		SHADOW_GROW_MIN,
		SHADOW_GROW_MAX,
		SHADOW_ALPHA_MIN,
		SHADOW_ALPHA_MAX
	)


## 1つの矩形ぶんの落ち影。大きく薄い層から小さく濃い層へ順に重ね、輪郭を柔らかくする。
func _draw_shadow_layers(
	ci: RID,
	rect: Rect2,
	steps: int,
	grow_min: float,
	grow_max: float,
	alpha_min: float,
	alpha_max: float
) -> void:
	var base_rect := Rect2(rect.position + SHADOW_OFFSET, rect.size)
	for i in steps:
		var t: float = float(i) / float(steps - 1) if steps > 1 else 1.0
		var grow := lerpf(grow_max, grow_min, t)
		var alpha := lerpf(alpha_min, alpha_max, t)
		var layer_rect := base_rect.grow(grow)
		var radius := SHADOW_CORNER_RADIUS + grow
		var points := UiPaint.rounded_rect_points_uniform(
			layer_rect, radius, SHADOW_CORNER_SEGMENTS
		)
		var color := Color(0.0, 0.0, 0.0, alpha)
		UiPaint.fill_gradient_polygon(ci, points, layer_rect, [[0.0, color], [1.0, color]])


## 端の落ち込み。`ScreenBackdrop._draw_vignette()` と同じ書き方を四辺すべてへ広げる。
func _draw_vignette() -> void:
	var band_x := size.x * VIGNETTE_WIDTH_RATIO / float(VIGNETTE_STEPS)
	var band_y := size.y * VIGNETTE_WIDTH_RATIO / float(VIGNETTE_STEPS)
	for i in VIGNETTE_STEPS:
		var alpha := VIGNETTE_ALPHA * float(VIGNETTE_STEPS - i) / float(VIGNETTE_STEPS)
		var shade := Color(0.0, 0.0, 0.0, alpha)
		draw_rect(Rect2(float(i) * band_x, 0.0, band_x, size.y), shade)
		draw_rect(Rect2(size.x - float(i + 1) * band_x, 0.0, band_x, size.y), shade)
		draw_rect(Rect2(0.0, float(i) * band_y, size.x, band_y), shade)
		draw_rect(Rect2(0.0, size.y - float(i + 1) * band_y, size.x, band_y), shade)
