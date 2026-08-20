class_name FirebaseAuth
extends Node

signal signed_in(uid: String)
signal sign_in_failed(error: String)

var config: FirebaseConfig
var uid: String = ""
var id_token: String = ""


func _init(p_config: FirebaseConfig) -> void:
	config = p_config


func sign_in_anonymously() -> void:
	var url := "https://identitytoolkit.googleapis.com/v1/accounts:signUp?key=%s" % config.api_key
	var headers := ["Content-Type: application/json"]
	var body := JSON.stringify({"returnSecureToken": true})

	var request := HTTPRequest.new()
	add_child(request)
	request.request(url, headers, HTTPClient.METHOD_POST, body)
	var result: Array = await request.request_completed
	request.queue_free()

	var response_code: int = result[1]
	var response_body: PackedByteArray = result[3]
	var parsed: Variant = JSON.parse_string(response_body.get_string_from_utf8())

	if response_code == 200 and parsed is Dictionary and parsed.has("idToken"):
		uid = parsed["localId"]
		id_token = parsed["idToken"]
		signed_in.emit(uid)
	else:
		sign_in_failed.emit(response_body.get_string_from_utf8())
