class_name FirebaseAuth
extends Node

signal signed_in(uid: String)
signal sign_in_failed(error: String)

const SIGN_UP_URL := "https://identitytoolkit.googleapis.com/v1/accounts:signUp?key=%s"
const SIGN_IN_URL := "https://identitytoolkit.googleapis.com/v1/accounts:signInWithPassword?key=%s"
const REFRESH_URL := "https://securetoken.googleapis.com/v1/token?key=%s"
## 有効期限のこれだけ手前になったら更新する(トークンの寿命は通常3600秒)。
const REFRESH_MARGIN_SECONDS := 300.0
const DEFAULT_EXPIRES_IN := 3600.0

## ユーザーが決めたIDを、Firebaseの「メール/パスワード」プロバイダへ渡すための合成
## アドレスのドメイン(Architecture.md 10.1)。実在しないドメインを使うのは、メール
## アドレスを取得しない方針(GameDesign.md 14章)のため。この方式によりIDの一意性は
## Firebase側が保証してくれる(重複時はEMAIL_EXISTSが返る)。
const SYNTHETIC_EMAIL_DOMAIN := "hourglass-arena.local"
## IDに許す文字。合成アドレスとして成立しない文字を送信前に弾く。
const ID_PATTERN := "^[a-z0-9_-]+$"
const ID_MIN_LENGTH := 3
const ID_MAX_LENGTH := 20
const PASSWORD_MIN_LENGTH := 6

var config: FirebaseConfig
var uid: String = ""
var id_token: String = ""
## 登録済みならログインに使ったID。匿名のままなら空文字。
var login_id: String = ""
var _refresh_token: String = ""
var _expires_at: float = 0.0
var _refreshing := false


func _init(p_config: FirebaseConfig) -> void:
	config = p_config


func sign_in_anonymously() -> void:
	var body := JSON.stringify({"returnSecureToken": true})
	var result: Array = await _post(SIGN_UP_URL, body)
	var parsed: Variant = result[1]
	if result[0] == 200 and parsed is Dictionary and parsed.has("idToken"):
		login_id = ""
		_adopt(parsed)
		signed_in.emit(uid)
		return
	sign_in_failed.emit(str(result[2]))


## 保存済みの更新用トークンでサインインし直す(Architecture.md 10.1)。
## これが無いと起動のたびに新しい匿名アカウントが発行され、uidで引いているオンライン
## 対戦のリプレイが一覧から消える。成功したかどうかを返し、失敗した場合は呼び出し側が
## 新しい匿名サインインへ落とす。
func restore_session() -> bool:
	var session := AccountStore.load_session()
	var token: String = session["refresh_token"]
	if token == "":
		return false
	_refresh_token = token
	await _refresh()
	if not is_signed_in():
		_refresh_token = ""
		return false
	if uid == "":
		uid = session["uid"]
	login_id = session["login_id"]
	_persist()
	signed_in.emit(uid)
	return true


## 匿名で遊んでいたアカウントへIDとパスワードを結びつける(GameDesign.md 14章)。
##
## リンクは `accounts:signUp` へ現在のIDトークンを添えて行う。idTokenを付けると
## 「新しいアカウントを作る」ではなく「そのトークンのユーザーへ認証情報を結びつける」
## 意味になり、**uidが変わらない**ためリプレイと砂金の残高がそのまま引き継がれる。
##
## `accounts:update`(setAccountInfo)は使えない。2023年9月15日以降に作られた
## プロジェクトではメール列挙保護が既定で有効で、その状態ではメールアドレスの
## 追加・変更が「先に新しいアドレスを検証せよ」と拒否される。ここで使うのは
## 実在しない合成ドメインのアドレスのため検証メールは永久に届かず、詰んでしまう。
##
## 戻り値は空文字なら成功、そうでなければ表示用のエラー文言。
func register(p_login_id: String, password: String) -> String:
	var invalid := validate_credentials(p_login_id, password)
	if invalid != "":
		return invalid
	if not is_signed_in():
		return "サインインしていません。通信環境を確認してください。"

	var payload := {
		"idToken": id_token,
		"email": _to_email(p_login_id),
		"password": password,
		"returnSecureToken": true,
	}
	var result: Array = await _post(SIGN_UP_URL, JSON.stringify(payload))
	var parsed: Variant = result[1]
	if result[0] == 200 and parsed is Dictionary:
		login_id = _normalize_id(p_login_id)
		_adopt(parsed)
		return ""
	return _error_message(parsed, result[2])


## 登録済みのIDとパスワードでログインする。成功すると、それまで遊んでいた匿名
## アカウントからは切り離される(匿名側の記録は引き継がれない)。
## 戻り値は空文字なら成功、そうでなければ表示用のエラー文言。
func log_in(p_login_id: String, password: String) -> String:
	var invalid := validate_credentials(p_login_id, password)
	if invalid != "":
		return invalid

	var payload := {
		"email": _to_email(p_login_id),
		"password": password,
		"returnSecureToken": true,
	}
	var result: Array = await _post(SIGN_IN_URL, JSON.stringify(payload))
	var parsed: Variant = result[1]
	if result[0] == 200 and parsed is Dictionary and parsed.has("idToken"):
		login_id = _normalize_id(p_login_id)
		_adopt(parsed)
		signed_in.emit(uid)
		return ""
	return _error_message(parsed, result[2])


## 保存済みのセッションを捨てる。呼び出し側が続けて新しい匿名サインインを行う。
func log_out() -> void:
	uid = ""
	id_token = ""
	login_id = ""
	_refresh_token = ""
	_expires_at = 0.0
	AccountStore.clear_session()


func is_signed_in() -> bool:
	return id_token != ""


## IDとパスワードを結びつけ済みかどうか。匿名のままならfalse。
func is_registered() -> bool:
	return login_id != ""


## 送信前の入力検証。妥当なら空文字、そうでなければ表示用のエラー文言を返す。
## Firebaseのエラーコードをそのまま見せないよう、明らかな不備はここで弾く。
static func validate_credentials(p_login_id: String, password: String) -> String:
	var normalized := _normalize_id(p_login_id)
	if normalized.length() < ID_MIN_LENGTH or normalized.length() > ID_MAX_LENGTH:
		return "IDは%d〜%d文字で入力してください。" % [ID_MIN_LENGTH, ID_MAX_LENGTH]
	var regex := RegEx.new()
	regex.compile(ID_PATTERN)
	if regex.search(normalized) == null:
		return "IDに使えるのは英数字・ハイフン・アンダースコアだけです。"
	if password.length() < PASSWORD_MIN_LENGTH:
		return "パスワードは%d文字以上で入力してください。" % PASSWORD_MIN_LENGTH
	return ""


static func _normalize_id(p_login_id: String) -> String:
	return p_login_id.strip_edges().to_lower()


static func _to_email(p_login_id: String) -> String:
	return "%s@%s" % [_normalize_id(p_login_id), SYNTHETIC_EMAIL_DOMAIN]


## Firebaseのエラーコードを日本語の文言へ置き換える。
static func _error_message(parsed: Variant, fallback: Variant) -> String:
	var code := ""
	if parsed is Dictionary and parsed.has("error"):
		var error_body: Dictionary = parsed["error"]
		code = str(error_body.get("message", ""))
	if code.begins_with("EMAIL_EXISTS"):
		return "このIDは既に使われています。別のIDにしてください。"
	if (
		code.begins_with("EMAIL_NOT_FOUND")
		or code.begins_with("INVALID_LOGIN_CREDENTIALS")
		or code.begins_with("INVALID_PASSWORD")
	):
		return "IDまたはパスワードが違います。"
	if code.begins_with("WEAK_PASSWORD"):
		return "パスワードは%d文字以上で入力してください。" % PASSWORD_MIN_LENGTH
	if code.begins_with("TOO_MANY_ATTEMPTS_TRY_LATER"):
		return "試行が多すぎます。しばらく待ってからやり直してください。"
	if code.begins_with("CREDENTIAL_TOO_OLD_LOGIN_AGAIN") or code.begins_with("TOKEN_EXPIRED"):
		return "セッションの有効期限が切れました。もう一度お試しください。"
	# 同じOPERATION_NOT_ALLOWEDでも原因が2つあり、対処が異なるため文面を分ける。
	# 列挙保護の場合はコードの末尾に「verify the new email」が付く。
	# どちらも設定を直さない限り必ず失敗するため、生のコードも添えて切り分け可能にする
	# (文言だけに丸めた結果、原因を取り違えて誤った案内をしたことがある)。
	if code.contains("verify the new email"):
		return "サーバー側の設定(メール列挙保護)により登録できません。(%s)" % code
	if code.begins_with("OPERATION_NOT_ALLOWED") or code.begins_with("PASSWORD_LOGIN_DISABLED"):
		# Firebaseコンソールで「メール/パスワード」プロバイダが有効になっていない
		return "サーバー側でID登録が有効になっていません。(%s)" % code
	if code == "":
		return "通信に失敗しました。接続を確認してください。(%s)" % str(fallback)
	return "登録・ログインに失敗しました。(%s)" % code


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
	if parsed.has("user_id"):
		uid = str(parsed["user_id"])
	_store_token(parsed["id_token"], parsed.get("refresh_token", ""), parsed.get("expires_in", ""))


func _post(url_template: String, body: String) -> Array:
	var headers := PackedStringArray(["Content-Type: application/json"])
	return await HttpJson.request_with_retry(
		self, url_template % config.api_key, HTTPClient.METHOD_POST, headers, body
	)


## 認証エンドポイントの応答からuidとトークン類を取り込み、次回起動用に永続化する。
func _adopt(parsed: Dictionary) -> void:
	if parsed.has("localId"):
		uid = str(parsed["localId"])
	_store_token(
		str(parsed.get("idToken", id_token)),
		parsed.get("refreshToken", ""),
		parsed.get("expiresIn", "")
	)


func _store_token(token: String, refresh_token: String, expires_in: Variant) -> void:
	id_token = token
	if str(refresh_token) != "":
		_refresh_token = str(refresh_token)
	var lifetime := float(str(expires_in))
	if lifetime <= 0.0:
		lifetime = DEFAULT_EXPIRES_IN
	_expires_at = Time.get_unix_time_from_system() + lifetime
	_persist()


func _persist() -> void:
	if uid == "":
		return
	AccountStore.save_session(uid, _refresh_token, login_id)
