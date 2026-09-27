extends SceneTree

const USAGE := (
	"usage: godot ... --script godot_apply_patch.gd -- <PATCH_JSON_PATH>"
	+ " [--dry-run] [--allow-delete]"
)


func _init() -> void:
	var dry_run := false
	var allow_delete := false
	var patch_path := ""
	for a in OS.get_cmdline_user_args():
		if a == "--dry-run":
			dry_run = true
		elif a == "--allow-delete":
			allow_delete = true
		elif patch_path == "":
			patch_path = a

	if patch_path == "":
		_die(USAGE)
		return
	var patch := _load_patch(patch_path)
	if patch.is_empty():
		return
	var scene_path: String = patch["scene_path"]
	var root := _instantiate_scene(scene_path)
	if root == null:
		return

	var res: Dictionary = _apply_ops(root, patch["operations"], allow_delete)
	var applied: int = res["applied"]
	if res["err"] != OK:
		root.free()
		quit(1)
		return
	if dry_run:
		print("dry-run ok ops=", applied)
		root.free()
		quit(0)
		return

	var saved := _save_scene(root, scene_path)
	root.free()
	if saved:
		print("ok ops=", applied, " scene=", scene_path)
		quit(0)


func _die(msg: String, ctx: Variant = null) -> void:
	if ctx == null:
		printerr(msg)
	else:
		printerr(msg, ctx)
	quit(1)


func _is_abs_or_res(p: String) -> bool:
	return (
		p.begins_with("res://")
		or p.begins_with("/")
		or (
			p.length() >= 3
			and p.substr(1, 1) == ":"
			and (p.substr(2, 1) == "/" or p.substr(2, 1) == "\\")
		)
	)


func _read_json(path: String) -> Variant:
	var f := FileAccess.open(path, FileAccess.READ)
	if f == null:
		printerr("failed to open JSON: ", path)
		return null
	var v: Variant = JSON.parse_string(f.get_as_text())
	if v == null:
		printerr("failed to parse JSON: ", path)
	return v


# 失敗時は _die 済みで空の Dictionary を返す
func _load_patch(patch_path: String) -> Dictionary:
	if not _is_abs_or_res(patch_path):
		_die("patch path must be absolute or res:// (no relative paths): ", patch_path)
		return {}
	var patch_v: Variant = _read_json(patch_path)
	if patch_v == null or typeof(patch_v) != TYPE_DICTIONARY:
		_die("patch JSON must be an object: ", patch_path)
		return {}
	return _validate_patch(patch_v)


func _validate_patch(patch: Dictionary) -> Dictionary:
	var scene_path_v: Variant = patch.get("scene_path", "")
	if typeof(scene_path_v) != TYPE_STRING or str(scene_path_v) == "":
		_die("patch must include scene_path (string)")
		return {}
	var scene_path: String = scene_path_v
	if not _is_abs_or_res(scene_path):
		_die("scene_path must be absolute or res://: ", scene_path)
		return {}
	var ops_v: Variant = patch.get("operations", [])
	if typeof(ops_v) != TYPE_ARRAY:
		_die("operations must be an array")
		return {}
	return {"scene_path": scene_path, "operations": ops_v}


func _instantiate_scene(scene_path: String) -> Node:
	var packed := load(scene_path)
	if packed == null or not (packed is PackedScene):
		_die("failed to load PackedScene: ", scene_path)
		return null
	var root := (packed as PackedScene).instantiate()
	if root == null:
		_die("failed to instantiate scene: ", scene_path)
	return root


# 失敗時はバックアップから元のシーンを戻す
func _save_scene(root: Node, scene_path: String) -> bool:
	var bak: String = scene_path + ".bak"
	if _copy_file(scene_path, bak) != OK:
		_die("failed to create backup: ", bak)
		return false
	var out := PackedScene.new()
	if out.pack(root) != OK:
		_copy_file(bak, scene_path)
		_die("PackedScene.pack failed")
		return false
	if ResourceSaver.save(out, scene_path) != OK:
		_copy_file(bak, scene_path)
		_die("ResourceSaver.save failed: ", scene_path)
		return false
	return true


func _node_from(root: Node, p: String) -> Node:
	return root if (p == "" or p == ".") else root.get_node_or_null(NodePath(p))


func _fail(err: int, msg: String, ctx: Variant = null) -> int:
	if ctx == null:
		printerr(msg)
	else:
		printerr(msg, ctx)
	return err


func _apply_ops(root: Node, ops: Array, allow_delete: bool) -> Dictionary:
	var applied := 0
	for opv in ops:
		var err := _apply_op(root, opv, allow_delete)
		if err != OK:
			return {"err": err, "applied": applied}
		applied += 1
	return {"err": OK, "applied": applied}


func _apply_op(root: Node, opv: Variant, allow_delete: bool) -> int:
	if typeof(opv) != TYPE_DICTIONARY:
		return _fail(ERR_INVALID_DATA, "op must be an object: ", opv)
	var op := opv as Dictionary
	var kind := str(op.get("op", ""))
	var err: int
	match kind:
		"set_property":
			err = _op_set_property(root, op)
		"rename_node":
			err = _op_rename_node(root, op)
		"add_child_scene":
			err = _op_add_child_scene(root, op)
		"move_child":
			err = _op_move_child(root, op)
		"delete_node":
			err = _op_delete_node(root, op, allow_delete)
		_:
			err = _fail(ERR_INVALID_PARAMETER, "unknown op: ", kind)
	return err


func _op_set_property(root: Node, op: Dictionary) -> int:
	var n := _node_from(root, str(op.get("node", "")))
	if n == null:
		return _fail(ERR_DOES_NOT_EXIST, "node not found: ", op.get("node", ""))
	var prop := str(op.get("property", ""))
	if prop == "":
		return _fail(ERR_INVALID_PARAMETER, "property required")
	var value: Variant = op.get("value", null)
	if op.has("value_variant"):
		value = str_to_var(str(op.get("value_variant")))
	n.set(prop, value)
	return OK


func _op_rename_node(root: Node, op: Dictionary) -> int:
	var n := _node_from(root, str(op.get("node", "")))
	if n == null:
		return _fail(ERR_DOES_NOT_EXIST, "node not found: ", op.get("node", ""))
	var new_name := str(op.get("new_name", ""))
	if new_name == "":
		return _fail(ERR_INVALID_PARAMETER, "new_name required")
	n.name = new_name
	return OK


func _op_add_child_scene(root: Node, op: Dictionary) -> int:
	var parent := _node_from(root, str(op.get("parent", "")))
	if parent == null:
		return _fail(ERR_DOES_NOT_EXIST, "parent not found: ", op.get("parent", ""))
	var child_scene := str(op.get("child_scene", ""))
	if not _is_abs_or_res(child_scene):
		return _fail(ERR_INVALID_PARAMETER, "child_scene must be absolute or res://: ", child_scene)
	var child_packed := load(child_scene)
	if child_packed == null or not (child_packed is PackedScene):
		return _fail(ERR_CANT_OPEN, "failed to load child PackedScene: ", child_scene)
	var child := (child_packed as PackedScene).instantiate()
	if child == null:
		return _fail(ERR_CANT_CREATE, "failed to instantiate child: ", child_scene)
	var name_override := str(op.get("name", ""))
	if name_override != "":
		var existing := parent.get_node_or_null(NodePath(name_override))
		if existing != null:
			parent.remove_child(existing)
			existing.free()
		child.name = name_override
	parent.add_child(child)
	child.owner = root  # persist child while preserving nested instance ownership
	return OK


func _op_move_child(root: Node, op: Dictionary) -> int:
	var mv := _node_from(root, str(op.get("node", "")))
	if mv == null:
		return _fail(ERR_DOES_NOT_EXIST, "node not found: ", op.get("node", ""))
	var mv_parent := mv.get_parent()
	if mv_parent == null:
		return _fail(ERR_INVALID_PARAMETER, "cannot move the root node")
	mv_parent.move_child(mv, int(op.get("to_index", -1)))
	return OK


func _op_delete_node(root: Node, op: Dictionary, allow_delete: bool) -> int:
	if not allow_delete:
		return _fail(ERR_UNAUTHORIZED, "delete_node is disabled (pass --allow-delete)")
	var nd := _node_from(root, str(op.get("node", "")))
	if nd == null:
		return _fail(ERR_DOES_NOT_EXIST, "node not found: ", op.get("node", ""))
	if nd == root:
		return _fail(ERR_INVALID_PARAMETER, "refusing to delete root node")
	var pd := nd.get_parent()
	if pd != null:
		pd.remove_child(nd)
	nd.free()
	return OK


func _copy_file(src: String, dst: String) -> int:
	if FileAccess.file_exists(dst):
		var rm_err := DirAccess.remove_absolute(dst)
		if rm_err != OK:
			return rm_err
	return DirAccess.copy_absolute(src, dst)
