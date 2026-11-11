class_name SkinRenderer
extends RefCounted
## カードスキンのシェーダーを絵にする(Architecture.md 10.19節)。窓口は `SkinLibrary`。
##
## 止めた絵は `HourglassArt` と同じく起動時に3状態ぶんを焼いて配る(焼き上がる前は空の器を配り、
## 焼けた時点で中身を差し替える)。動く絵はスキン×状態ごとに1つの `SubViewport` が描き続け、
## 同じスキン・同じ状態の駒で1枚を共有する。**直前のフレームで引かれなかったものは描き直さない**。

## シェーダーのキャンバス。基本の絵の落下中と同じ高さで、`CardView._art_reference()` が
## 3状態で最も高いキャンバスを基準に縮めるため、止めた絵はこの大きさで揃える。
const CANVAS := Vector2i(400, 532)
## Web版は止めた絵を半分の解像度で焼く(`HourglassArt.WEB_BAKE_SCALE` と同じ理由)。
const WEB_BAKE_SCALE := 0.5
## 動く絵の高さ。場の駒の表示(`CardView.BOARD_ART_SIDE` = 112)の2倍。Web版は1倍。
const LIVE_HEIGHT := 224
const WEB_LIVE_SCALE := 0.5
## 止めた絵を焼く時刻(秒)。
const STILL_CLOCK := 0.0
## 引かれなくなってから描き続ける猶予(フレーム)。呼ぶ側の再描画と1フレームずれても途切れないように。
const GRACE_FRAMES := 1
## 3状態の砂(`sand_top`, `sand_bottom`, `flow`)。`HourglassArt.State` の並び。
const STATE_SAND: Array[Vector3] = [
	Vector3(0.85, 0.0, 0.0),
	Vector3(0.45, 0.40, 1.0),
	Vector3(0.0, 0.85, 0.0),
]


## 動く絵1枚ぶん。
class Live:
	extends RefCounted
	var viewport: SubViewport
	var material: ShaderMaterial
	var texture: Texture2D
	var used_at := -100


## 動く絵の時計と視線を毎フレーム進める。
class Host:
	extends Node

	func _process(delta: float) -> void:
		SkinRenderer.tick(delta)


static var _host: Host = null
static var _bake_viewport: SubViewport = null
static var _bake_rect: ColorRect = null
static var _baking := false
static var _shaders: Dictionary = {}
static var _stills: Dictionary = {}
static var _lives: Dictionary = {}
static var _clock := 0.0
static var _look := Vector2.ZERO


## 起動時に1度だけ呼ぶ(`Main._ready()`)。焼き付けはフレームをまたぐため、呼んだ側は待たなくてよい。
static func ensure_ready(parent: Node) -> void:
	if _host != null and is_instance_valid(_host):
		return
	_host = Host.new()
	_bake_viewport = SubViewport.new()
	_bake_viewport.transparent_bg = true
	_bake_viewport.disable_3d = true
	_bake_viewport.render_target_update_mode = SubViewport.UPDATE_DISABLED
	_bake_rect = ColorRect.new()
	_bake_rect.anchor_right = 1.0
	_bake_rect.anchor_bottom = 1.0
	_bake_viewport.add_child(_bake_rect)
	_host.add_child(_bake_viewport)
	parent.add_child(_host)
	_bake_all()


static func has_shader(skin_id: String) -> bool:
	if not _shaders.has(skin_id):
		_shaders[skin_id] = ResourceLoader.exists(SkinLibrary.shader_path(skin_id))
	return _shaders[skin_id]


## 止めた絵の1状態。焼き上がっていなければ空の器が入っていて、焼けた時点で中身だけが入れ替わる。
static func still(skin_id: String, state: int) -> Texture2D:
	var key := _key(skin_id, state)
	if not _stills.has(key):
		var blank := Image.create_empty(_bake_size().x, _bake_size().y, false, Image.FORMAT_RGBA8)
		_stills[key] = ImageTexture.create_from_image(blank)
	return _stills[key]


## 動く絵の1状態。呼ばれたフレームを控え、呼ばれ続けている間だけ描き続ける。
## 準備前(ヘッドレスのテストなど)は止めた絵を返す。
static func live(skin_id: String, state: int) -> Texture2D:
	if _host == null or not is_instance_valid(_host):
		return still(skin_id, state)
	var key := _key(skin_id, state)
	var entry: Live = _lives.get(key, null)
	if entry == null:
		entry = _make_live(skin_id, state)
		_lives[key] = entry
	entry.used_at = Engine.get_process_frames()
	if entry.viewport.render_target_update_mode != SubViewport.UPDATE_ALWAYS:
		entry.viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	return entry.texture


## `Host._process()` から毎フレーム。時計と視線を渡し、引かれていない絵を止める。
static func tick(delta: float) -> void:
	_clock += delta
	_look = _mouse_look()
	var now := Engine.get_process_frames()
	for entry: Live in _lives.values():
		var active := now - entry.used_at <= GRACE_FRAMES
		var mode := SubViewport.UPDATE_ALWAYS if active else SubViewport.UPDATE_DISABLED
		if entry.viewport.render_target_update_mode != mode:
			entry.viewport.render_target_update_mode = mode
		if active:
			entry.material.set_shader_parameter("clock", _clock)
			entry.material.set_shader_parameter("look", _look)


static func _make_live(skin_id: String, state: int) -> Live:
	var entry := Live.new()
	entry.material = _material(skin_id, state, _clock, _look)
	entry.viewport = SubViewport.new()
	entry.viewport.size = _live_size()
	entry.viewport.transparent_bg = true
	entry.viewport.disable_3d = true
	entry.viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	var rect := ColorRect.new()
	rect.anchor_right = 1.0
	rect.anchor_bottom = 1.0
	rect.material = entry.material
	entry.viewport.add_child(rect)
	_host.add_child(entry.viewport)
	entry.texture = entry.viewport.get_texture()
	return entry


static func _material(skin_id: String, state: int, clock: float, look: Vector2) -> ShaderMaterial:
	var material := ShaderMaterial.new()
	material.shader = load(SkinLibrary.shader_path(skin_id))
	var sand := STATE_SAND[state]
	material.set_shader_parameter("sand_top", sand.x)
	material.set_shader_parameter("sand_bottom", sand.y)
	material.set_shader_parameter("flow", sand.z)
	material.set_shader_parameter("clock", clock)
	material.set_shader_parameter("look", look)
	return material


## 画面中央からマウスへの向き。各軸 -1〜1(上が正。シェーダーの座標に合わせる)。
static func _mouse_look() -> Vector2:
	var viewport := _host.get_viewport()
	var half := viewport.get_visible_rect().size * 0.5
	if half.x <= 0.0 or half.y <= 0.0:
		return Vector2.ZERO
	var offset := viewport.get_mouse_position() - half
	return Vector2(clampf(offset.x / half.x, -1.0, 1.0), clampf(-offset.y / half.y, -1.0, 1.0))


static func _bake_all() -> void:
	if _baking:
		return
	_baking = true
	for skin_id in SkinLibrary.all():
		if not has_shader(skin_id):
			continue
		for state in STATE_SAND.size():
			await _bake(skin_id, state)
	_baking = false


static func _bake(skin_id: String, state: int) -> void:
	_bake_rect.material = _material(skin_id, state, STILL_CLOCK, Vector2.ZERO)
	_bake_viewport.size = _bake_size()
	_bake_viewport.render_target_update_mode = SubViewport.UPDATE_ONCE
	await RenderingServer.frame_post_draw
	var image := _bake_viewport.get_texture().get_image()
	if image == null or image.get_size() != _bake_size():
		return
	(still(skin_id, state) as ImageTexture).set_image(image)


static func _bake_size() -> Vector2i:
	if not OS.has_feature("web"):
		return CANVAS
	return Vector2i((Vector2(CANVAS) * WEB_BAKE_SCALE).round())


static func _live_size() -> Vector2i:
	var height := LIVE_HEIGHT * (WEB_LIVE_SCALE if OS.has_feature("web") else 1.0)
	return Vector2i(roundi(height * CANVAS.x / float(CANVAS.y)), roundi(height))


static func _key(skin_id: String, state: int) -> String:
	return "%s|%d" % [skin_id, state]
