extends SceneTree

## 書き出したpckに、入っていてはいけないものが混ざっていないか確かめる。
## 使い方: godot --headless --main-pack build/web/index.pck --script res://tools/verify_web_pck.gd
##
## エディタから書き出すと export_presets.cfg のフィルタが空へ戻る(実際に起きた)。
## 中身を見ずにサイズだけ眺めても気づけないため、名指しで確かめる。

const FORBIDDEN := ["res://assets/bgm/", "res://tools/balance/out/", "tools/discord/out/"]
const REQUIRED := ["res://data/discord_webhook.txt"]


func _walk(path: String, out: Array) -> void:
	var dir := DirAccess.open(path)
	if dir == null:
		return
	dir.list_dir_begin()
	var name := dir.get_next()
	while name != "":
		var full := path.path_join(name)
		if dir.current_is_dir():
			_walk(full, out)
		else:
			out.append(full)
		name = dir.get_next()


func _init() -> void:
	var files: Array = []
	_walk("res://", files)
	var problems: Array[String] = []
	for prefix in FORBIDDEN:
		for f in files:
			if String(f).begins_with(prefix) or String(f).find(prefix) != -1:
				problems.append("入ってはいけない: %s" % f)
	for required in REQUIRED:
		if not files.has(required):
			problems.append("入っているべき: %s" % required)
	if problems.is_empty():
		print("pck check passed (%d files)" % files.size())
		quit()
		return
	for p in problems:
		printerr("pck check FAILED  " + p)
	printerr("→ export_presets.cfg のフィルタが空へ戻っている可能性があります")
	quit(1)
