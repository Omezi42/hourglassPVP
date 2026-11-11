class_name StageRewardTokens
extends RefCounted
## 初回クリアの報酬の絵(砂金の硬貨・砂時計・アイコン)。リーサルパズル・ソロモードの
## 結果パネル(`CardChallengeResult`)が同じ絵で報酬を見せるため、ここへ集める。

const VISUAL_SIZE := Vector2(64, 88)
const ART_MAX := Vector2(60, 80)
const ICON_SIZE := 56.0
const COIN_RADIUS := 24.0
const POOL_RADIUS := Vector2(30, 7)
const POOL_ALPHA := 0.35


static func coin(visual_size: Vector2 = VISUAL_SIZE) -> Control:
	var visual := Control.new()
	visual.custom_minimum_size = visual_size
	visual.draw.connect(
		func() -> void:
			var ci := visual.get_canvas_item()
			var center := visual_size * 0.5
			UiKit.gem(ci, center, COIN_RADIUS, UiPalette.SAND_HI, UiPalette.SAND_DEEP)
	)
	return visual


## 手に入れるカード(砂時計を光だまりの上に立てる)・アイコンの絵。
static func art(texture: Texture2D, standing: bool, visual_size: Vector2 = VISUAL_SIZE) -> Control:
	var visual := Control.new()
	visual.custom_minimum_size = visual_size
	visual.draw.connect(
		func() -> void:
			if texture == null:
				return
			var box := visual_size
			if not standing:
				var side := minf(ICON_SIZE, minf(box.x, box.y))
				visual.draw_texture_rect(
					texture, Rect2((box - Vector2(side, side)) * 0.5, Vector2(side, side)), false
				)
				return
			var foot := Vector2(box.x * 0.5, box.y - POOL_RADIUS.y)
			UiPaint.fill_ellipse(
				visual.get_canvas_item(), foot, POOL_RADIUS, Color(UiPalette.SAND, POOL_ALPHA), 24
			)
			var tex_size := texture.get_size()
			var art_max := ART_MAX.min(box)
			var fit: float = minf(art_max.x / tex_size.x, art_max.y / tex_size.y)
			var draw_size := tex_size * fit
			visual.draw_texture_rect(
				texture,
				Rect2(Vector2(foot.x - draw_size.x * 0.5, foot.y + 2.0 - draw_size.y), draw_size),
				false
			)
	)
	return visual
