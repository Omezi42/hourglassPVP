class_name AccountStore
extends RefCounted
## アカウントの復帰情報を`user://`へ保存する(Architecture.md 10.1)。
## `DeckSave`と同じく、Autoloadを使わずstaticのみで持つ。
##
## **パスワードは一切保存しない**。保存するのは認証サービスが発行した更新用トークンと、
## 次回の入力を省くための最後に使ったIDだけ。トークンが失効しても、パスワードが
## 手元に残っていない以上、再ログインはユーザーの入力を必要とする。

const SAVE_PATH := "user://account.json"


## 起動時の自動ログインに使う情報を保存する。refresh_tokenが空なら保存自体を行わず、
## 既存の保存も消す(ログアウトと同じ扱い)。
static func save_session(uid: String, refresh_token: String, login_id: String) -> void:
	if refresh_token == "":
		clear_session()
		return
	var data := _load()
	data["uid"] = uid
	data["refresh_token"] = refresh_token
	data["login_id"] = login_id
	_store(data)


## 保存済みのセッションを返す。無ければ全て空・0の辞書を返す。
static func load_session() -> Dictionary:
	var data := _load()
	return {
		"uid": str(data.get("uid", "")),
		"refresh_token": str(data.get("refresh_token", "")),
		"login_id": str(data.get("login_id", "")),
	}


## ログアウト時に呼ぶ。未反映の砂金は次のアカウントのものではないため一緒に捨てる。
static func clear_session() -> void:
	_store({})


## 通信に失敗して残高へ反映できなかった砂金を積む(GameDesign.md 15章)。
## CPU戦はオフラインでも成立するため、この退避が無いと獲得が消える。
static func add_pending_currency(amount: int) -> void:
	if amount <= 0:
		return
	var data := _load()
	data["pending_currency"] = int(data.get("pending_currency", 0)) + amount
	_store(data)


static func get_pending_currency() -> int:
	return int(_load().get("pending_currency", 0))


## 退避分を残高へ反映できた時点で呼ぶ。
static func clear_pending_currency() -> void:
	var data := _load()
	data["pending_currency"] = 0
	_store(data)


## ローカルにアイコンと称号を保存する(オフライン復帰用)。
static func save_local_customization(icon_id: String, title_id: String, playmat_id := "") -> void:
	var data := _load()
	data["icon_id"] = icon_id
	data["title_id"] = title_id
	if not playmat_id.is_empty():
		data["playmat_id"] = playmat_id
	_store(data)


## ショップで解放したものと、エモートの枠をローカルにも控える(オフライン復帰用)。
## 買う操作そのものは通信を要する(GameDesign.md 21章)が、買った結果は
## 次に開いたときへ持ち越せないと、オフラインの間だけアイコンが選べなくなる。
static func save_local_unlocks(
	owned_icons: Array, owned_emotes: Array, emote_slots: Array, owned_playmats := []
) -> void:
	var data := _load()
	data["owned_icons"] = owned_icons
	data["owned_emotes"] = owned_emotes
	data["emote_slots"] = emote_slots
	data["owned_playmats"] = owned_playmats
	_store(data)


static func load_local_unlocks() -> Dictionary:
	var data := _load()
	return {
		"owned_icons": data.get("owned_icons", []),
		"owned_emotes": data.get("owned_emotes", []),
		"emote_slots": data.get("emote_slots", []),
		"owned_playmats": data.get("owned_playmats", []),
	}


static func load_local_customization() -> Dictionary:
	var data := _load()
	return {
		"icon_id": str(data.get("icon_id", "")),
		"title_id": str(data.get("title_id", "")),
		"playmat_id": str(data.get("playmat_id", "")),
	}


static func _load() -> Dictionary:
	if not FileAccess.file_exists(SAVE_PATH):
		return {}
	var file := FileAccess.open(SAVE_PATH, FileAccess.READ)
	if file == null:
		return {}
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	if typeof(parsed) != TYPE_DICTIONARY:
		return {}
	return parsed


static func _store(data: Dictionary) -> void:
	var file := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if file == null:
		return
	file.store_string(JSON.stringify(data))
