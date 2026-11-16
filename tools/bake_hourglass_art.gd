extends SceneTree
## コード描画の砂時計の止めた絵を、ビルド前に焼く(Architecture.md 10.19節)。
##
## `resources/shaders/hourglasses/{art_key}.gdshader` ごとに3状態へ、止めた層(back・frame)と
## 完成形(state)を `assets/hourglasses/overrides/{art_key}/` へ書く。ウィンドウありで回す
## (headless は描画しない)。シェーダー・共通の部品・表の色や質感を変えたら回し直す。
##
##   Godot --path . --script res://tools/bake_hourglass_art.gd [-- art_key ...]

const OUTPUT_DIR := "res://assets/hourglasses/overrides"
const STATE_NAMES: Array[String] = ["state_full", "state_falling", "state_empty"]
## 何から焼いたかの控え(`art_key` → ハッシュ)。`tools/check_hourglass_bake.py` が同じ規則で求めて照合する。
const MANIFEST_PATH := "res://tools/hourglass_bake_manifest.json"
## 焼いた絵の元になるファイル(カードのシェーダーのほかに、全カードの絵へ効くもの)。
const COMMON_SOURCES: Array[String] = [
	"res://resources/shaders/hourglass/hourglass_lib.gdshaderinc",
	"res://resources/shaders/hourglass/hourglass_glass.gdshaderinc",
	"res://resources/shaders/hourglass/frame_parts.gdshaderinc",
	"res://resources/shaders/hourglass/art_main.gdshaderinc",
]
## 焼いた絵の取り込み設定。非可逆のWebP(0.85)。可逆で持つと3倍近くになる(Architecture.md 4.1節)。
const IMPORT_SETTINGS := (
	'[remap]\n\nimporter="texture"\ntype="CompressedTexture2D"\n\n'
	+ "[params]\n\ncompress/mode=1\ncompress/lossy_quality=0.85\n"
)

var _viewport: SubViewport
var _rect: ColorRect


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	_viewport = SubViewport.new()
	_viewport.size = HourglassLive.CANVAS
	_viewport.transparent_bg = true
	_viewport.disable_3d = true
	_viewport.render_target_update_mode = SubViewport.UPDATE_DISABLED
	_rect = ColorRect.new()
	_rect.anchor_right = 1.0
	_rect.anchor_bottom = 1.0
	_viewport.add_child(_rect)
	root.add_child(_viewport)
	await process_frame
	var only := OS.get_cmdline_user_args()
	for art_key in art_keys():
		if only.is_empty() or only.has(art_key):
			await bake(art_key)
	quit()


## 絵のシェーダーを持つカードのid。
static func art_keys() -> Array[String]:
	var keys: Array[String] = []
	for file in DirAccess.get_files_at(HourglassLive.ART_SHADER_DIR):
		if file.ends_with(".gdshader"):
			keys.append(file.get_basename())
	keys.sort()
	return keys


## 書いたPNGが可逆のまま取り込まれないよう、取り込み設定が無ければ非可逆の設定を置く。
func _save(image: Image, path: String) -> void:
	image.save_png(path)
	var import_path := path + ".import"
	if not FileAccess.file_exists(import_path):
		var file := FileAccess.open(import_path, FileAccess.WRITE)
		file.store_string(IMPORT_SETTINGS)


func bake(art_key: String) -> void:
	var dir := ProjectSettings.globalize_path("%s/%s" % [OUTPUT_DIR, art_key])
	DirAccess.make_dir_recursive_absolute(dir)
	for state in STATE_NAMES.size():
		var layers: Array[Image] = []
		for layer in 2:
			layers.append(await _render_static(art_key, state, layer))
		var back_path := "%s/back_%s.png" % [dir, HourglassLive.LAYER_STATES[state]]
		var no_back := _is_empty(layers[0])
		if no_back:
			if FileAccess.file_exists(back_path):
				DirAccess.remove_absolute(back_path)
		else:
			_save(layers[0], back_path)
		_save(layers[1], "%s/frame_%s.png" % [dir, HourglassLive.LAYER_STATES[state]])
		var back_tex: Texture2D = null if no_back else ImageTexture.create_from_image(layers[0])
		var frame_tex := ImageTexture.create_from_image(layers[1])
		var full := await _render_stack(art_key, state, back_tex, frame_tex)
		_save(full, "%s/%s.png" % [dir, STATE_NAMES[state]])
	_write_manifest(art_key)
	print("baked ", art_key)


## 層(0=後ろ / 1=枠)。
func _render_static(art_key: String, state: int, layer: int) -> Image:
	var material := HourglassLive.sand_material(art_key, state)
	material.shader = load(HourglassLive.art_shader_path(art_key))
	material.set_shader_parameter("layer", layer)
	_rect.material = material
	return await _draw()


## 3層を重ねた完成形(clock = 0)を1枚撮る。動く絵と同じ組み立て。
func _render_stack(art_key: String, state: int, back_tex: Texture2D, frame_tex: Texture2D) -> Image:
	var stack := HourglassLive.make_stack(art_key, state, back_tex, frame_tex, HourglassLive.CANVAS)
	stack.viewport.render_target_update_mode = SubViewport.UPDATE_ONCE
	root.add_child(stack.viewport)
	await RenderingServer.frame_post_draw
	var image := stack.viewport.get_texture().get_image()
	stack.viewport.queue_free()
	return image


func _draw() -> Image:
	_viewport.render_target_update_mode = SubViewport.UPDATE_ONCE
	await RenderingServer.frame_post_draw
	return _viewport.get_texture().get_image()


static func _is_empty(image: Image) -> bool:
	var data := image.get_data()
	for i in range(3, data.size(), 4):
		if data[i] != 0:
			return false
	return true


## 焼いた絵の元(共通の部品・そのカードのシェーダー・共通のガラス・表のそのカードの行)のハッシュ。改行コードは揃える。
static func source_hash(art_key: String) -> String:
	var paths: Array[String] = COMMON_SOURCES.duplicate()
	paths.append(HourglassLive.art_shader_path(art_key))
	paths.append(HourglassLive.glass_shader_path(art_key))
	var context := HashingContext.new()
	context.start(HashingContext.HASH_SHA256)
	for path in paths:
		context.update(
			FileAccess.get_file_as_string(path).replace(String.chr(13), "").to_utf8_buffer()
		)
	context.update(table_row(art_key).to_utf8_buffer())
	return context.finish().hex_encode()


## 表(`data/hourglass_tints.tres`)のそのカードの行。
static func table_row(art_key: String) -> String:
	var prefix := '"%s": {' % art_key
	for line in FileAccess.get_file_as_string(HourglassArt.TABLE_PATH).split("\n"):
		if line.begins_with(prefix):
			return line.strip_edges()
	return ""


func _write_manifest(art_key: String) -> void:
	var manifest: Dictionary = {}
	if FileAccess.file_exists(MANIFEST_PATH):
		manifest = JSON.parse_string(FileAccess.get_file_as_string(MANIFEST_PATH))
	manifest[art_key] = source_hash(art_key)
	var file := FileAccess.open(MANIFEST_PATH, FileAccess.WRITE)
	file.store_string(JSON.stringify(manifest, "\t", true) + "\n")
