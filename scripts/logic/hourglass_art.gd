class_name HourglassArt
extends RefCounted
## 砂時計の絵を、原本1組(サンドの3状態)から色変換で作って配る(Architecture.md 4.1節)。
##
## 全58種は同じ絵の色違いであり、色違いを焼いた画像を配ると pck の7割を1枚の絵が占める。
## ここが1組だけを持つことで、**カードを何種増やしても配布物は大きくならない**。
##
## `SoundBank` と同じ「Autoloadを使わずstaticで持つ」流儀。
## 配るのは `ImageTexture` で、焼き上がるまでは原本の中身を入れておき、
## 焼けた時点で同じオブジェクトの中身を差し替える(受け取った側は何も知らなくてよい)。

enum State { UPRIGHT, FALLING, FALLEN }

const STATE_FILES: Array[String] = ["state_full", "state_falling", "state_empty"]
const MASTER_ID := "sand"
const MASTER_DIR := "res://assets/hourglasses/master"
const OVERRIDE_DIR := "res://assets/hourglasses/overrides"
const TABLE_PATH := "res://data/hourglass_tints.tres"
const SHADER_PATH := "res://resources/shaders/hourglass_tint.gdshader"

static var _table: HourglassTintTable = null
static var _published: Dictionary = {}
static var _baked: Dictionary = {}
static var _overrides: Dictionary = {}
static var _viewport: SubViewport = null
static var _rect: ColorRect = null
static var _baking := false


## 起動時に1度だけ呼ぶ(Main._ready())。焼き付けはフレームをまたぐため、
## 呼んだ側は待たなくてよい。タイトル画面には砂時計の絵が1枚も無い。
static func ensure_ready(parent: Node) -> void:
	if _viewport != null:
		return
	_load_table()
	_viewport = SubViewport.new()
	_viewport.transparent_bg = true
	_viewport.disable_3d = true
	_viewport.render_target_update_mode = SubViewport.UPDATE_DISABLED
	_rect = ColorRect.new()
	_rect.anchor_right = 1.0
	_rect.anchor_bottom = 1.0
	var material := ShaderMaterial.new()
	material.shader = load(SHADER_PATH)
	_rect.material = material
	_viewport.add_child(_rect)
	parent.add_child(_viewport)
	_bake_all()


## その絵の1状態を返す。焼き上がっていなければ原本の中身が入った器を返し、
## 焼けた時点で中身だけが入れ替わる。
static func texture(art_id: String, state: int) -> Texture2D:
	var override := _override(art_id, state)
	if override != null:
		return override
	var key := "%s|%d" % [art_id, state]
	if _published.has(key):
		return _published[key]
	var image := _master_image(state)
	var made: ImageTexture = null
	if image != null:
		made = ImageTexture.create_from_image(image)
	_published[key] = made
	return made


## 固有の絵(色違いでは足りないカード)。あればそれをそのまま使う。
static func _override(art_id: String, state: int) -> Texture2D:
	var key := "%s|%d" % [art_id, state]
	if _overrides.has(key):
		return _overrides[key]
	var path := "%s/%s/%s.png" % [OVERRIDE_DIR, art_id, STATE_FILES[state]]
	var found: Texture2D = load(path) if ResourceLoader.exists(path) else null
	_overrides[key] = found
	return found


static func _load_table() -> void:
	if _table == null:
		_table = load(TABLE_PATH)


static func _master_image(state: int) -> Image:
	var key := "%s|%d" % [MASTER_ID, state]
	if _baked.has(key):
		return _baked[key]
	var path := "%s/%s.png" % [MASTER_DIR, STATE_FILES[state]]
	var texture: Texture2D = load(path) if ResourceLoader.exists(path) else null
	if texture == null:
		push_error("砂時計の原本が見つかりません: " + path)
		return null
	var image := texture.get_image()
	_baked[key] = image
	return image


## 親が先に焼き上がるよう、原本からの段数の浅い順に並べて焼く。
static func _bake_all() -> void:
	if _table == null or _baking:
		return
	_baking = true
	var ordered := _ordered_ids()
	for art_id in ordered:
		for state in STATE_FILES.size():
			await _bake(art_id, state)
	_baking = false


static func _ordered_ids() -> Array[String]:
	var ranked: Array = []
	for art_id in _table.entries.keys():
		if String(art_id) == MASTER_ID:
			continue
		ranked.append([_table.chain(String(art_id)).size(), String(art_id)])
	ranked.sort_custom(func(a, b): return a[0] < b[0])
	var ids: Array[String] = []
	for row in ranked:
		ids.append(row[1])
	return ids


static func _bake(art_id: String, state: int) -> void:
	if _override(art_id, state) != null:
		return
	var source_id := _table.source_of(art_id)
	var source: Image = _baked.get("%s|%d" % [source_id, state], null)
	if source == null:
		source = _master_image(state)
	if source == null:
		return
	var step: Dictionary = _table.entries[art_id]
	_rect.material.set_shader_parameter("hue_shift", float(step.get("hue", 0.0)))
	_rect.material.set_shader_parameter("saturation", float(step.get("sat", 1.0)))
	_rect.material.set_shader_parameter("saturation_bias", float(step.get("sat_bias", 0.0)))
	_rect.material.set_shader_parameter("saturation_floor", float(step.get("floor", 0.0)))
	_rect.material.set_shader_parameter("value_scale", float(step.get("value", 1.0)))
	_rect.material.set_shader_parameter("value_bias", float(step.get("value_bias", 0.0)))
	_rect.material.set_shader_parameter("threshold", float(step.get("threshold", 0.0)))
	_rect.material.set_shader_parameter("source_art", ImageTexture.create_from_image(source))
	_viewport.size = source.get_size()
	_viewport.render_target_update_mode = SubViewport.UPDATE_ONCE
	await RenderingServer.frame_post_draw
	var baked := _viewport.get_texture().get_image()
	_baked["%s|%d" % [art_id, state]] = baked
	var key := "%s|%d" % [art_id, state]
	if _published.has(key) and _published[key] != null:
		(_published[key] as ImageTexture).set_image(baked)
	else:
		_published[key] = ImageTexture.create_from_image(baked)
