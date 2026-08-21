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
##
## 保存済みのセッションがあればそちらで復帰し、無い場合にだけ新しい匿名アカウントを
## 作る(Architecture.md 10.1)。これにより起動のたびにuidが変わることがなくなり、
## uidで引いているリプレイと砂金の残高が次回起動時も自分のものとして残る。
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
	var restored: bool = await auth.restore_session()
	if not restored:
		auth.sign_in_anonymously()
	while not done[0]:
		await auth.get_tree().process_frame
	_signed_in = success[0]
	_signing_in = false
	if _signed_in:
		await AccountService.load_profile(client, auth.uid)
	return _signed_in


## 匿名アカウントへIDとパスワードを結びつける(GameDesign.md 14章)。
## 成功すると空文字、失敗すると表示用のエラー文言を返す。
static func register(login_id: String, password: String) -> String:
	if not await sign_in():
		return "通信に失敗しました。接続を確認してください。"
	var error: String = await auth.register(login_id, password)
	if error != "":
		return error
	await AccountService.save_login_id(client, auth.uid, auth.login_id)
	return ""


## 登録済みのアカウントへログインし直す。成功すると空文字を返す。
static func log_in(login_id: String, password: String) -> String:
	# 匿名のままでも通信自体はできるため、サインイン済みかどうかは問わない
	var error: String = await auth.log_in(login_id, password)
	if error != "":
		return error
	_signed_in = true
	AccountService.reset()
	await AccountService.load_profile(client, auth.uid)
	return ""


## ログアウトし、新しい匿名アカウントで遊ぶ状態へ戻す。
static func log_out() -> void:
	auth.log_out()
	AccountService.reset()
	_signed_in = false
	await sign_in()
