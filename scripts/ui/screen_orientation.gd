class_name ScreenOrientation
extends RefCounted
## 画面の向き(GameDesign.md 9章「縦画面」/ Architecture.md 4.7節)。
## 判定はウィンドウの縦横比だけで行い、配信先を見ない。

## 縦の配置を止めるときだけ false にする(縦長のウィンドウでも横の配置を黒帯つきで出す)。
const ENABLED := true
const LANDSCAPE_SIZE := Vector2i(1280, 720)
const PORTRAIT_SIZE := Vector2i(720, 1280)

static var _window_portrait := false
static var _forced := false


## いま縦の配置で出すか。
static func is_portrait() -> bool:
	return _forced or (ENABLED and _window_portrait)


## ウィンドウの大きさを受けて向きを決め直す。縦か横かが変わったら true を返す。
static func update(window_size: Vector2) -> bool:
	var before := is_portrait()
	_window_portrait = window_size.y > window_size.x
	return is_portrait() != before


## いまの向きの基準解像度。
static func base_size() -> Vector2i:
	return PORTRAIT_SIZE if is_portrait() else LANDSCAPE_SIZE


## テストとモックから縦の配置を確かめるためだけに使う(`ENABLED` によらず縦にする)。
static func force_portrait_for_test(on: bool = true) -> void:
	_forced = on
