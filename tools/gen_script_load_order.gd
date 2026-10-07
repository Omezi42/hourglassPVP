extends SceneTree
## 起動時に裏で読み込むスクリプトの順番(`scripts/boot/script_load_order.gd`)を書き出す
## (Architecture.md 4.0.6節)。`scenes/main.tscn` から辿れるスクリプトを、参照される側から先に並べる。
## 先に読んだものはキャッシュに載るため、1本ずつ読めば1フレームで固まる量が小さくなる。
## 順番が古くても壊れはしない(漏れたものは `main.tscn` を読む時点でまとめてコンパイルされる)。
## `tools/check.sh` が毎回回す。
##
## 実行: godot --headless --path . --script res://tools/gen_script_load_order.gd

const ROOT_SCENE := "res://scenes/main.tscn"
const OUTPUT := "res://scripts/boot/script_load_order.gd"
const SCAN_DIRS := ["res://scripts", "res://scenes"]
## 起動シーンそのものと、この順番のファイルは並べない(並べる前に読み込み済み)。
const SKIP := ["res://scripts/boot/boot.gd", OUTPUT]

var _class_paths := {}
var _edges := {}
var _index := {}
var _low := {}
var _stack: Array[String] = []
var _on_stack := {}
var _counter := 0
var _order: Array[String] = []


func _initialize() -> void:
	var files: Array[String] = []
	for dir in SCAN_DIRS:
		_collect(dir, files)
	for f in files:
		if f.ends_with(".gd"):
			var m := RegEx.create_from_string("(?m)^class_name\\s+(\\w+)").search(_read(f))
			if m != null:
				_class_paths[m.get_string(1)] = f
	for f in files:
		_edges[f] = _references(f)
	_visit(ROOT_SCENE)
	var lines: Array[String] = [
		"## 生成物(`tools/gen_script_load_order.gd`)。手で編集しない。",
		"## 起動時に `Boot` が裏で読み込むスクリプトの順番(参照される側が先。Architecture.md 4.0.6節)。",
		"",
		"const PATHS: Array[String] = [",
	]
	for f in _order:
		if f.ends_with(".gd") and not SKIP.has(f):
			lines.append('\t"%s",' % f)
	lines.append("]")
	var out := FileAccess.open(OUTPUT, FileAccess.WRITE)
	out.store_string("\n".join(lines) + "\n")
	out.close()
	print("script load order: %d scripts" % (lines.size() - 5))
	quit()


func _collect(dir: String, out: Array[String]) -> void:
	for d in DirAccess.get_directories_at(dir):
		_collect(dir.path_join(d), out)
	for f in DirAccess.get_files_at(dir):
		if f.ends_with(".gd") or f.ends_with(".tscn"):
			out.append(dir.path_join(f))


func _read(path: String) -> String:
	return FileAccess.get_file_as_string(path)


## 参照先: 書かれている `res://` のパス(.gd / .tscn)と、使っている class_name。
func _references(path: String) -> Array[String]:
	var text := _read(path)
	var refs: Array[String] = []
	for m in RegEx.create_from_string('"(res://[^"]+\\.(?:gd|tscn))"').search_all(text):
		var target := m.get_string(1)
		if target != path and FileAccess.file_exists(target):
			refs.append(target)
	if path.ends_with(".gd"):
		var code := RegEx.create_from_string("#[^\\n]*").sub(text, "", true)
		code = RegEx.create_from_string('"(?:[^"\\\\\\n]|\\\\.)*"').sub(code, '""', true)
		var seen := {}
		for m in RegEx.create_from_string("\\b[A-Z]\\w+\\b").search_all(code):
			var word := m.get_string()
			if seen.has(word) or not _class_paths.has(word):
				continue
			seen[word] = true
			if _class_paths[word] != path:
				refs.append(_class_paths[word])
	return refs


## Tarjan の強連結成分分解。成分は参照される側から順に確定するため、確定した順に並べる。
func _visit(v: String) -> void:
	_index[v] = _counter
	_low[v] = _counter
	_counter += 1
	_stack.append(v)
	_on_stack[v] = true
	for w in _edges.get(v, []):
		if not _index.has(w):
			_visit(w)
			_low[v] = mini(_low[v], _low[w])
		elif _on_stack.has(w):
			_low[v] = mini(_low[v], _index[w])
	if _low[v] == _index[v]:
		while true:
			var w: String = _stack.pop_back()
			_on_stack.erase(w)
			_order.append(w)
			if w == v:
				break
