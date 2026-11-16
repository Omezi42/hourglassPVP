class_name HourglassLive
extends RefCounted
## コード描画の砂時計の動く絵(Architecture.md 10.19節)。窓口は `live_texture()`。
##
## カード×状態ごとに1つの `SubViewport` へ、後ろ(backのPNG)・ガラスと砂(`glass_{kind}`。ここだけが動く)・
## 枠(frameのPNG)の3枚を重ねる。**同じカード・同じ状態の駒で1枚を共有し**、
## 直前のフレームで引かれなかったものは描き直さない。止めた絵は焼いた `HourglassArt.texture()`。

## シェーダーのキャンバス。基本の絵の落下中と同じ高さ。
const CANVAS := Vector2i(400, 532)
const ART_SHADER_DIR := "res://resources/shaders/hourglasses"
const GLASS_SHADER_DIR := "res://resources/shaders/hourglass"
## 動く絵の高さ。場の駒の表示(`CardView.BOARD_ART_SIDE` = 112)の2倍。Web版は1倍。
const LIVE_HEIGHT := 224
const WEB_LIVE_SCALE := 0.5
## 引かれなくなってから描き続ける猶予(フレーム)。呼ぶ側の再描画と1フレームずれても途切れないように。
const GRACE_FRAMES := 1
## 焼いた層のファイル名(`HourglassArt.STATE_FILES` の並びに対応する状態名)。
const LAYER_STATES: Array[String] = ["full", "falling", "empty"]
const LAYER_BACK := "back"
const LAYER_FRAME := "frame"
## 3状態の砂(`sand_top`, `sand_bottom`, `flow`)。`HourglassArt.State` の並び。
const STATE_SAND: Array[Vector3] = [
	Vector3(0.85, 0.0, 0.0),
	Vector3(0.45, 0.40, 1.0),
	Vector3(0.0, 0.85, 0.0),
]

static var _host: Host = null
static var _shaders: Dictionary = {}
static var _lives: Dictionary = {}
static var _clock := 0.0


## 動く絵1枚ぶん。3枚を重ねた `SubViewport` とその絵。
class Stack:
	extends RefCounted
	var viewport: SubViewport
	var glass: ShaderMaterial
	var texture: Texture2D
	var used_at := -100

	func set_time(clock: float) -> void:
		glass.set_shader_parameter("clock", clock)


## 砂の時計を毎フレーム進める。
class Host:
	extends Node

	func _process(delta: float) -> void:
		HourglassLive.tick(delta)


## 起動時に1度だけ呼ぶ(`Main._ready()`)。
static func ensure_ready(parent: Node) -> void:
	if _host != null and is_instance_valid(_host):
		return
	_host = Host.new()
	parent.add_child(_host)


## そのカードの絵がシェーダーで描かれるか(`resources/shaders/hourglasses/{art_key}.gdshader` がある)。
static func has_shader(art_key: String) -> bool:
	if not _shaders.has(art_key):
		_shaders[art_key] = ResourceLoader.exists(art_shader_path(art_key))
	return _shaders[art_key]


static func art_shader_path(art_key: String) -> String:
	return "%s/%s.gdshader" % [ART_SHADER_DIR, art_key]


## そのカードの砂の質感の共通のガラス。質感が無ければ「さらさら」。
static func glass_shader_path(art_key: String) -> String:
	var kind := HourglassArt.texture_name(art_key)
	return "%s/glass_%s.gdshader" % [GLASS_SHADER_DIR, kind if not kind.is_empty() else "sand"]


## 動く絵の1状態。呼ばれたフレームを控え、呼ばれ続けている間だけ描き続ける。
## 準備前(ヘッドレスのテストなど)・シェーダーの無いカードは止めた絵を返す。
static func live_texture(art_key: String, state: int) -> Texture2D:
	if _host == null or not is_instance_valid(_host) or not has_shader(art_key):
		return HourglassArt.texture(art_key, state)
	var key := "%s|%d" % [art_key, state]
	var entry: Stack = _lives.get(key, null)
	if entry == null:
		entry = make_stack(
			art_key,
			state,
			load_layer(art_key, state, LAYER_BACK),
			load_layer(art_key, state, LAYER_FRAME)
		)
		entry.set_time(_clock)
		_host.add_child(entry.viewport)
		_lives[key] = entry
	entry.used_at = Engine.get_process_frames()
	if entry.viewport.render_target_update_mode != SubViewport.UPDATE_ALWAYS:
		entry.viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	return entry.texture


## 共通のガラスを1度だけ描いてコンパイルを済ませる。対局画面を開くときに、自分のデッキの質感のぶんだけ呼ぶ。
static func warm_glass(art_keys: Array) -> void:
	if _host == null or not is_instance_valid(_host):
		return
	var done: Dictionary = {}
	for art_key in art_keys:
		var path := glass_shader_path(String(art_key))
		if done.has(path) or not ResourceLoader.exists(path):
			continue
		done[path] = true
		var warm := make_stack(
			String(art_key), HourglassArt.State.UPRIGHT, null, null, Vector2i(8, 8)
		)
		warm.viewport.render_target_update_mode = SubViewport.UPDATE_ONCE
		_host.add_child(warm.viewport)
		_free_after_draw(warm.viewport)


static func _free_after_draw(viewport: SubViewport) -> void:
	await RenderingServer.frame_post_draw
	if is_instance_valid(viewport):
		viewport.queue_free()


## 後ろ・ガラス・枠を重ねた `SubViewport` を作る(焼き付けの完成形も同じ組み立てを使う)。
## `back_tex` / `frame_tex` は焼いた層。無ければ空の絵を敷く。
static func make_stack(
	art_key: String,
	state: int,
	back_tex: Texture2D,
	frame_tex: Texture2D,
	size: Vector2i = Vector2i.ZERO
) -> Stack:
	var stack := Stack.new()
	stack.glass = _glass_material(art_key, state)
	stack.viewport = SubViewport.new()
	stack.viewport.size = size if size != Vector2i.ZERO else _live_size()
	stack.viewport.transparent_bg = true
	stack.viewport.disable_3d = true
	stack.viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	if back_tex != null:
		stack.viewport.add_child(_layer_rect(back_tex))
	var glass := ColorRect.new()
	glass.anchor_right = 1.0
	glass.anchor_bottom = 1.0
	glass.material = stack.glass
	stack.viewport.add_child(glass)
	if frame_tex != null:
		stack.viewport.add_child(_layer_rect(frame_tex))
	stack.texture = stack.viewport.get_texture()
	return stack


static func _layer_rect(texture: Texture2D) -> TextureRect:
	var rect := TextureRect.new()
	rect.anchor_right = 1.0
	rect.anchor_bottom = 1.0
	rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	rect.stretch_mode = TextureRect.STRETCH_SCALE
	rect.texture = texture
	return rect


## 焼いた層の画像。無ければ null(後ろが空のカードは back を持たない)。
static func load_layer(art_key: String, state: int, layer: String) -> Texture2D:
	var path := layer_path(art_key, state, layer)
	return load(path) if ResourceLoader.exists(path) else null


static func layer_path(art_key: String, state: int, layer: String) -> String:
	return "%s/%s/%s_%s.png" % [HourglassArt.OVERRIDE_DIR, art_key, layer, LAYER_STATES[state]]


## `Host._process()` から毎フレーム。時計を渡し、引かれていない絵を止める。
static func tick(delta: float) -> void:
	_clock += delta
	var now := Engine.get_process_frames()
	for entry: Stack in _lives.values():
		var active := now - entry.used_at <= GRACE_FRAMES
		var mode := SubViewport.UPDATE_ALWAYS if active else SubViewport.UPDATE_DISABLED
		if entry.viewport.render_target_update_mode != mode:
			entry.viewport.render_target_update_mode = mode
		if active:
			entry.set_time(_clock)


static func _glass_material(art_key: String, state: int) -> ShaderMaterial:
	var material := sand_material(art_key, state)
	material.shader = load(glass_shader_path(art_key))
	return material


## 3状態の砂と砂の色を入れたマテリアル(シェーダーは呼ぶ側が入れる。焼く道具も使う)。
static func sand_material(art_key: String, state: int) -> ShaderMaterial:
	var material := ShaderMaterial.new()
	var sand := STATE_SAND[state]
	material.set_shader_parameter("sand_top", sand.x)
	material.set_shader_parameter("sand_bottom", sand.y)
	material.set_shader_parameter("flow", sand.z)
	material.set_shader_parameter("clock", 0.0)
	material.set_shader_parameter("sand_color", HourglassArt.accent_color(art_key))
	return material


static func _live_size() -> Vector2i:
	var height := LIVE_HEIGHT * (WEB_LIVE_SCALE if OS.has_feature("web") else 1.0)
	return Vector2i(roundi(height * CANVAS.x / float(CANVAS.y)), roundi(height))
