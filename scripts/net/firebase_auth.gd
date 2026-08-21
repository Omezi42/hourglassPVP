class_name FirebaseAuth
extends Node

signal signed_in(uid: String)
signal sign_in_failed(error: String)

const SIGN_UP_URL := "https://identitytoolkit.googleapis.com/v1/accounts:signUp?key=%s"
const REFRESH_URL := "https://securetoken.googleapis.com/v1/token?key=%s"
## 有効期限のこれだけ手前になったら更新する(トークンの寿命は通常3600秒)。
const REFRESH_MARGIN_SECONDS := 300.0
const DEFAULT_EXPIRES_IN := 3600.0

var config: FirebaseConfig
var uid: String = ""
var id_token: String = ""
var _refresh_token: String = ""
var _expires_at: float = 0.0
var _refreshing := false


func _init(p_config: FirebaseConfig) -> void:
	config = p_config


func sign_in_anonymously() -> void:
	var headers := PackedStringArray(["Content-Type: application/json"])
	var body := JSON.stringify({"returnSecureToken": true})
	var result: Array = await HttpJson.request_with_retry(
		self, SIGN_UP_URL % config.api_key, HTTPClient.METHOD_POST, headers, body
	)
	var parsed: Variant = result[1]
	if result[0] == 200 and parsed is Dictionary and parsed.has("idToken"):
		uid = parsed["localId"]
		_store_token(parsed["idToken"], parsed.get("refreshToken", ""), parsed.get("expiresIn", ""))
		signed_in.emit(uid)
		return
	sign_in_failed.emit(str(result[2]))


func is_signed_in() -> bool:
	return id_token != ""


## 有効期限が近ければIDトークンを更新する。FirestoreClientが全リクエストの前に呼ぶ。
## 匿名サインインのトークンは1時間で失効するため、これが無いと長く遊んだセッションで
## 以降の通信がすべて401になり、画面上は「相手が指してこない」ようにしか見えなくなる。
func ensure_fresh_token() -> void:
	if not is_signed_in() or _refresh_token == "":
		return
	if Time.get_unix_time_from_system() < _expires_at - REFRESH_MARGIN_SECONDS:
		return
	await force_refresh()


## 期限に関わらず更新する。クライアント時刻がずれていると期限の判定を当てにできないため、
## 実際に401が返った場合はFirestoreClientがこちらを呼ぶ。
func force_refresh() -> void:
	if _refresh_token == "":
		return
	if _refreshing:
		# 同時に複数のリクエストが更新を要求しても、実際の更新は1回で足りる
		while _refreshing:
			await get_tree().process_frame
		return
	_refreshing = true
	await _refresh()
	_refreshing = false


func _refresh() -> void:
	var headers := PackedStringArray(["Content-Type: application/x-www-form-urlencoded"])
	var body := "grant_type=refresh_token&refresh_token=%s" % _refresh_token.uri_encode()
	var result: Array = await HttpJson.request_with_retry(
		self, REFRESH_URL % config.api_key, HTTPClient.METHOD_POST, headers, body
	)
	var parsed: Variant = result[1]
	if result[0] != 200 or not (parsed is Dictionary) or not parsed.has("id_token"):
		return
	_store_token(parsed["id_token"], parsed.get("refresh_token", ""), parsed.get("expires_in", ""))


func _store_token(token: String, refresh_token: String, expires_in: Variant) -> void:
	id_token = token
	if str(refresh_token) != "":
		_refresh_token = str(refresh_token)
	var lifetime := float(str(expires_in))
	if lifetime <= 0.0:
		lifetime = DEFAULT_EXPIRES_IN
	_expires_at = Time.get_unix_time_from_system() + lifetime
