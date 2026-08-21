extends FirestoreClient
## OnlineMatchの送受信ロジックを実通信なしで検証するための差し替え用クライアント。
## get_document_meta / commit_detailed / update_write だけを上書きし、Firestoreの
## 「updateTimeを前提条件にした条件付き書き込み」をメモリ上で再現する。
##
## 書き込みは実物と同じく原子的に扱う(全writeの前提条件を検証してから適用する)。

## path -> {"fields": Dictionary, "update_time": String}
var store: Dictionary = {}
var revision: int = 0
## この回数だけcommitを失敗させる(送信のリトライを検証するため)。
var fail_commits: int = 0
var commit_count: int = 0
var read_count: int = 0


func _init(p_auth: FirebaseAuth) -> void:
	super(null, p_auth)


func get_document_meta(path: String) -> Dictionary:
	await Engine.get_main_loop().process_frame
	read_count += 1
	if not store.has(path):
		return {"exists": false, "fields": {}, "update_time": ""}
	var entry: Dictionary = store[path]
	return {
		"exists": true,
		"fields": (entry["fields"] as Dictionary).duplicate(true),
		"update_time": entry["update_time"]
	}


## 本物はFirestoreのWrite表現を組み立てるが、ここでは検証しやすい素の形で持つ。
func update_write(path: String, data: Dictionary, precondition: Dictionary = {}) -> Dictionary:
	return {"path": path, "data": data, "precondition": precondition}


func commit_detailed(writes: Array) -> Dictionary:
	await Engine.get_main_loop().process_frame
	commit_count += 1
	if fail_commits > 0:
		fail_commits -= 1
		return {"ok": false, "code": 0}
	for write in writes:
		var failure := _check_precondition(write)
		if failure != 0:
			return {"ok": false, "code": failure}
	for write in writes:
		_apply(write)
	return {"ok": true, "code": 200}


func get_document(path: String) -> Dictionary:
	var meta: Dictionary = await get_document_meta(path)
	return meta["fields"]


func set_document(path: String, data: Dictionary) -> bool:
	var result: Dictionary = await commit_detailed([update_write(path, data)])
	return result["ok"]


## テストから相手の手を差し込むための入り口(相手クライアントの書き込みを模す)。
func append_action(path: String, action: Dictionary) -> void:
	var entry: Dictionary = store[path]
	var actions: Array = (entry["fields"] as Dictionary).get("actions", [])
	actions.append(action)
	entry["fields"]["actions"] = actions
	revision += 1
	entry["update_time"] = str(revision)


func actions_at(path: String) -> Array:
	if not store.has(path):
		return []
	return (store[path]["fields"] as Dictionary).get("actions", [])


func _check_precondition(write: Dictionary) -> int:
	var precondition: Dictionary = write.get("precondition", {})
	var path: String = write["path"]
	var exists: bool = store.has(path)
	if precondition.has("exists") and bool(precondition["exists"]) != exists:
		return 400
	if precondition.has("updateTime"):
		var current: String = store[path]["update_time"] if exists else ""
		if current != str(precondition["updateTime"]):
			return 409
	return 0


func _apply(write: Dictionary) -> void:
	var path: String = write["path"]
	if not store.has(path):
		store[path] = {"fields": {}, "update_time": ""}
	var fields: Dictionary = store[path]["fields"]
	for key in (write["data"] as Dictionary).keys():
		fields[key] = write["data"][key]
	revision += 1
	store[path]["update_time"] = str(revision)
