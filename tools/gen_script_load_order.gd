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
## `Main` がパスで読み、引き渡しの後に `Main.warm_up()` が1本ずつ読むもの(対局画面)。ここから辿れて
## 起動の順番に入らなかったスクリプトを `MATCH_PATHS` へ並べる。部品が `CardMatchScreen` を型・preload で
## 持って輪ができると、輪ごと1コマでコンパイルされるため失敗で終える(`check.sh` が落ちる)。
## パスの文字列での参照(`load()` で読む道)は辺に数えない。並べた起動のスクリプトがここへ型で届くと、
## 対局画面が起動の裏読み込みへ漏れるため、これも失敗で終える。
const DEFERRED := ["res://scripts/ui/card_match_screen.gd"]

var _class_paths := {}
var _edges := {}
var _index := {}
var _low := {}
var _stack: Array[String] = []
var _on_stack := {}
var _counter := 0
var _order: Array[String] = []
var _deferred_order: Array[String] = []
var _second_pass := false
var _cycles: Array[String] = []


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
		# この順番のファイルはパスを並べているだけで、読んでも並べた先は読まない。
		_edges[f] = [] if f == OUTPUT else _references(f)
	_visit(ROOT_SCENE)
	var leaks := DEFERRED.filter(func(d: String) -> bool: return _order.has(d))
	if not leaks.is_empty():
		printerr("deferred script leaks into the boot load order:\n  " + "\n  ".join(leaks))
		quit(1)
		return
	_second_pass = true
	for d in DEFERRED:
		_visit(d)
	if not _cycles.is_empty():
		printerr("deferred script is in a reference cycle:\n  " + "\n  ".join(_cycles))
		quit(1)
		return
	var lines: Array[String] = [
		"## 生成物(`tools/gen_script_load_order.gd`)。手で編集しない。",
		"## 起動時に `Boot` が裏で読み込むスクリプトの順番(参照される側が先。Architecture.md 4.0.6節)。",
		"",
		"const PATHS: Array[String] = [",
	]
	_append_paths(lines, _order)
	lines.append("]")
	lines.append("")
	lines.append("## 引き渡しの後に `Main.warm_up()` が1本ずつ読む対局画面まわり(参照される側が先)。")
	lines.append("const MATCH_PATHS: Array[String] = [")
	_append_paths(lines, _deferred_order)
	lines.append("]")
	var out := FileAccess.open(OUTPUT, FileAccess.WRITE)
	out.store_string("\n".join(lines) + "\n")
	out.close()
	print("script load order: %d + %d scripts" % [_order.size(), _deferred_order.size()])
	quit()


func _append_paths(lines: Array[String], paths: Array[String]) -> void:
	for f in paths:
		if f.ends_with(".gd") and not SKIP.has(f):
			lines.append('\t"%s",' % f)


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
		if target != path and FileAccess.file_exists(target) and not DEFERRED.has(target):
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
		var component: Array[String] = []
		while true:
			var w: String = _stack.pop_back()
			_on_stack.erase(w)
			component.append(w)
			if w == v:
				break
		if not _second_pass:
			_order.append_array(component)
			return
		if component.size() > 1 and component.any(func(f: String) -> bool: return DEFERRED.has(f)):
			_cycles.append_array(component)
		_deferred_order.append_array(component)
