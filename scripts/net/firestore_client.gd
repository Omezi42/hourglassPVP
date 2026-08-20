class_name FirestoreClient
extends Node

var config: FirebaseConfig
var auth: FirebaseAuth


func _init(p_config: FirebaseConfig, p_auth: FirebaseAuth) -> void:
	config = p_config
	auth = p_auth


func get_document(path: String) -> Dictionary:
	var doc: Dictionary = await get_document_meta(path)
	return doc.get("fields", {})


## 存在有無・updateTime(楽観ロック用)まで含めて取得する
func get_document_meta(path: String) -> Dictionary:
	var result: Array = await _request(HTTPClient.METHOD_GET, path, {})
	var response_code: int = result[0]
	var parsed: Variant = result[1]
	if response_code != 200 or not (parsed is Dictionary):
		return {"exists": false, "fields": {}, "update_time": ""}
	return {
		"exists": true,
		"fields": FirestoreCodec.decode_fields(parsed),
		"update_time": parsed.get("updateTime", "")
	}


## data内のフィールドのみを更新する(他の既存フィールドは保持される)。
## Firestoreのupdate(PATCH)はupdateMaskを指定しない限りドキュメント全体を
## 置き換えてしまうため、常にdataのキーからupdateMaskを組み立てて渡す。
func set_document(path: String, data: Dictionary) -> bool:
	var body := FirestoreCodec.encode_fields(data)
	var result: Array = await _request(
		HTTPClient.METHOD_PATCH, path + _update_mask_query(data.keys()), body
	)
	var response_code: int = result[0]
	return response_code == 200


func delete_document(path: String) -> bool:
	var result: Array = await _request(HTTPClient.METHOD_DELETE, path, {})
	var response_code: int = result[0]
	return response_code == 200


## 指定パスにドキュメントが存在しない場合のみ作成する(既存なら失敗する)。
## ルームコードの偶発的な衝突などを安全に検出するために使う。
func create_document(path: String, data: Dictionary) -> bool:
	return await commit([update_write(path, data, {"exists": false})])


func full_name(path: String) -> String:
	return "projects/%s/databases/(default)/documents/%s" % [config.project_id, path]


## 複数書き込みをFirestoreのバッチコミットとして原子的に適用する。
## 各writeにcurrentDocumentの条件(exists/updateTime)を付けることで、
## 他クライアントによる競合更新があった場合は全体が失敗する(楽観ロック)。
func commit(writes: Array) -> bool:
	var result: Array = await _post_raw(_base_url() + ":commit", {"writes": writes})
	var response_code: int = result[0]
	return response_code == 200


## data内のフィールドのみを更新するWriteを組み立てる(他の既存フィールドは保持される)。
func update_write(path: String, data: Dictionary, precondition: Dictionary = {}) -> Dictionary:
	var write := {
		"update": {"name": full_name(path), "fields": FirestoreCodec.encode_fields(data)["fields"]},
		"updateMask": {"fieldPaths": data.keys()}
	}
	if not precondition.is_empty():
		write["currentDocument"] = precondition
	return write


func _update_mask_query(keys: Array) -> String:
	var params: Array[String] = []
	for key in keys:
		params.append("updateMask.fieldPaths=%s" % key)
	return "?" + "&".join(params)


func delete_write(path: String, precondition: Dictionary = {}) -> Dictionary:
	var write := {"delete": full_name(path)}
	if not precondition.is_empty():
		write["currentDocument"] = precondition
	return write


## collection直下でmatch_idが空文字のドキュメントをlimit件クエリする
## (マッチング待ち候補の検索用)。単一フィールドの等価フィルタのみとし、
## 複合インデックス作成をユーザーに要求せずに済むようにする。
func query_waiting(collection: String, limit: int) -> Array:
	return await _run_structured_query(
		{
			"from": [{"collectionId": collection}],
			"where":
			{
				"fieldFilter":
				{"field": {"fieldPath": "match_id"}, "op": "EQUAL", "value": {"stringValue": ""}}
			},
			"limit": limit
		}
	)


## collection直下でfield == valueのドキュメントをlimit件クエリする。
## 単一フィールドの等価フィルタのみとし、複合インデックスを要求しないようにする。
func query_field_equals(collection: String, field: String, value: Variant, limit: int) -> Array:
	return await _run_structured_query(
		{
			"from": [{"collectionId": collection}],
			"where":
			{
				"fieldFilter":
				{
					"field": {"fieldPath": field},
					"op": "EQUAL",
					"value": FirestoreCodec.encode_value(value)
				}
			},
			"limit": limit
		}
	)


## collection直下でfinished_at > 0のドキュメントを、finished_atの古い順にlimit件クエリする。
## フィルタとorderByが同一フィールドのため、複合インデックスなしで実行できる。
func query_finished_matches_oldest_first(collection: String, limit: int) -> Array:
	return await _run_structured_query(
		{
			"from": [{"collectionId": collection}],
			"where":
			{
				"fieldFilter":
				{
					"field": {"fieldPath": "finished_at"},
					"op": "GREATER_THAN",
					"value": {"integerValue": "0"}
				}
			},
			"orderBy": [{"field": {"fieldPath": "finished_at"}, "direction": "ASCENDING"}],
			"limit": limit
		}
	)


func _run_structured_query(structured_query: Dictionary) -> Array:
	var result: Array = await _post_raw(
		_base_url() + ":runQuery", {"structuredQuery": structured_query}
	)
	var response_code: int = result[0]
	var parsed: Variant = result[1]
	if response_code != 200 or not (parsed is Array):
		return []
	var docs := []
	for entry in parsed:
		if typeof(entry) != TYPE_DICTIONARY or not entry.has("document"):
			continue
		var doc: Dictionary = entry["document"]
		var doc_id: String = String(doc.get("name", "")).get_file()
		docs.append(
			{
				"id": doc_id,
				"fields": FirestoreCodec.decode_fields(doc),
				"update_time": doc.get("updateTime", "")
			}
		)
	return docs


func _base_url() -> String:
	return (
		"https://firestore.googleapis.com/v1/projects/%s/databases/(default)/documents"
		% config.project_id
	)


func _request(method: HTTPClient.Method, path: String, body: Dictionary) -> Array:
	var url := "%s/%s" % [_base_url(), path]
	var body_string := "" if body.is_empty() else JSON.stringify(body)
	return await _send(url, method, body_string)


func _post_raw(url: String, body: Dictionary) -> Array:
	return await _send(url, HTTPClient.METHOD_POST, JSON.stringify(body))


func _send(url: String, method: HTTPClient.Method, body_string: String) -> Array:
	var headers := ["Content-Type: application/json", "Authorization: Bearer %s" % auth.id_token]

	var request := HTTPRequest.new()
	add_child(request)
	request.request(url, headers, method, body_string)
	var result: Array = await request.request_completed
	request.queue_free()

	var response_code: int = result[1]
	var response_body: PackedByteArray = result[3]
	var parsed: Variant = JSON.parse_string(response_body.get_string_from_utf8())
	return [response_code, parsed]
