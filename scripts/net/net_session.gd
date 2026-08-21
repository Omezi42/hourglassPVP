class_name NetSession
extends RefCounted

static var auth: FirebaseAuth
static var client: FirestoreClient
static var last_error: String = ""
static var _signed_in := false
static var _signing_in := false


static func ensure_ready(parent: Node) -> void:
	if auth != null:
		return
	var config: FirebaseConfig = load("res://data/firebase_config.tres")
	auth = FirebaseAuth.new(config)
	parent.add_child(auth)
	client = FirestoreClient.new(config, auth)
	parent.add_child(client)


## サインインが完了するまで待機し、成功したかどうかを返す。
## 失敗時はlast_errorにエラー内容が入る(失敗した場合、signed_inは発火しないため
## sign_in_failedも合わせて待ち受ける必要がある)。
## 複数の導線(マッチング・観戦・リプレイ一覧)から同時に呼ばれても匿名アカウントを
## 二重に作らないよう、進行中のサインインがあればその完了を待つ。
static func sign_in() -> bool:
	if _signed_in:
		return true
	if _signing_in:
		while _signing_in:
			await auth.get_tree().process_frame
		return _signed_in

	_signing_in = true
	var done := [false]
	var success := [false]
	var on_signed_in := func(_uid: String) -> void:
		done[0] = true
		success[0] = true
	var on_failed := func(error: String) -> void:
		done[0] = true
		success[0] = false
		last_error = error
	auth.signed_in.connect(on_signed_in, CONNECT_ONE_SHOT)
	auth.sign_in_failed.connect(on_failed, CONNECT_ONE_SHOT)
	auth.sign_in_anonymously()
	while not done[0]:
		await auth.get_tree().process_frame
	_signed_in = success[0]
	_signing_in = false
	return _signed_in
