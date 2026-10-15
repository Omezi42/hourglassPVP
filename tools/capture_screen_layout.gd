extends Control
## 画面を縦(720x1280)または横で撮る(Architecture.md 4.7節)。画面を SubViewport の中で作り、
## `ScreenOrientation.force_portrait_for_test()` のうえで `apply_orientation()` を呼んでから撮る。
## 縦画面の確認用。撮った絵の良し悪しは人が判断する(CLAUDE.md)。
##
## 実行(実際の描画結果を読むため --headless は付けない):
##   godot --path . res://tools/capture_screen_layout.tscn -- <出力先フォルダ> <portrait|landscape> <画面>...
## 画面は `class_name` か `.tscn` のパス。`|` で区切って開いた後に呼ぶ関数と引数を足せる
## (例: `CardListScreen|_select_tab|false`)。引数は `str_to_var()` で読む。

const SETTLE_SECONDS := 0.8
const SETTLE_FRAMES := 4
## 開くときに呼ぶ関数(`Main` が画面を出すときに呼ぶもの)。最初に見つかった1つだけを呼ぶ。
const OPEN_METHODS := ["open_manage", "open"]

var _stage: SubViewport


func _ready() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() < 3:
		push_error("usage: -- <out_dir> <portrait|landscape> <screen>...")
		get_tree().quit(1)
		return
	var out_dir := args[0]
	var portrait := args[1] == "portrait"
	DirAccess.make_dir_recursive_absolute(out_dir)
	ScreenOrientation.force_portrait_for_test(portrait)
	_stage = SubViewport.new()
	_stage.size = ScreenOrientation.base_size()
	_stage.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	add_child(_stage)
	var preview := TextureRect.new()
	preview.texture = _stage.get_texture()
	preview.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	preview.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	preview.anchor_right = 1.0
	preview.anchor_bottom = 1.0
	add_child(preview)
	for spec in args.slice(2):
		await _shoot(spec, portrait, out_dir)
	get_tree().quit()


func _shoot(spec: String, portrait: bool, out_dir: String) -> void:
	var parts := spec.split("|")
	var screen := _instantiate(parts[0])
	if screen == null:
		push_error("unknown screen: %s" % parts[0])
		return
	screen.anchor_right = 1.0
	screen.anchor_bottom = 1.0
	_stage.add_child(screen)
	if screen.has_method("apply_orientation"):
		screen.call("apply_orientation", portrait)
	for method in OPEN_METHODS:
		if screen.has_method(method):
			screen.call(method)
			break
	if parts.size() > 1:
		var call_args: Array = []
		for raw in parts.slice(2):
			call_args.append(str_to_var(raw))
		screen.callv(parts[1], call_args)
	screen.visible = true
	await get_tree().create_timer(SETTLE_SECONDS).timeout
	for i in SETTLE_FRAMES:
		await RenderingServer.frame_post_draw
	var name := spec.get_file().get_basename().replace("|", "_").replace(",", "_")
	var path := out_dir.path_join("%s_%s.png" % [name, "portrait" if portrait else "landscape"])
	_stage.get_texture().get_image().save_png(path)
	print("SAVED=%s" % path)
	screen.queue_free()
	await get_tree().process_frame


func _instantiate(id: String) -> Control:
	if id.ends_with(".tscn"):
		return (load(id) as PackedScene).instantiate() as Control
	for entry in ProjectSettings.get_global_class_list():
		if entry["class"] == id:
			return (load(entry["path"]) as GDScript).new() as Control
	return null
