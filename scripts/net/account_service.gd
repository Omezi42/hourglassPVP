class_name AccountService
extends RefCounted
## `players/{uid}` の読み書きを1箇所へ集約する(Architecture.md 10.2)。
## `ReplayService` と同じくstaticのみのクラスで、各画面が `FirestoreClient` を
## 直接叩かないようにするために置く。
##
## 直近に読んだ値はキャッシュしておき、ホーム画面が残高を出すたびに通信しない。

const COLLECTION := "players"
## 残高の加算が他のタブと競合したときに読み直して再試行する回数。
const GRANT_RETRY := 3
const DISPLAY_NAME_MAX_LENGTH := 10

## 直近に読み込んだプロフィール。キーは `players/{uid}` のフィールドと同じ。
static var _profile: Dictionary = _empty_profile()


## ログアウト・ログインでアカウントが変わったときに呼ぶ。
static func reset() -> void:
	_profile = _empty_profile()


static func display_name() -> String:
	return str(_profile.get("display_name", ""))


## 表示名。未設定なら「ゲスト」を返す(GameDesign.md 14章)。
static func display_name_or_default() -> String:
	var name := display_name()
	return name if name != "" else "ゲスト"


static func currency() -> int:
	return int(_profile.get("currency", 0))


static func cpu_reward_count_today() -> int:
	if str(_profile.get("cpu_reward_date", "")) != _today():
		return 0
	return int(_profile.get("cpu_reward_count", 0))


## サインイン直後に1度呼ぶ。ドキュメントが無ければ空のプロフィールのまま扱い、
## 最初の書き込み(表示名の設定・砂金の獲得)で作られる。
static func load_profile(client: FirestoreClient, uid: String) -> void:
	if uid == "":
		return
	var fields: Dictionary = await client.get_document(_path(uid))
	_profile = _empty_profile()
	for key in fields:
		_profile[key] = fields[key]


static func save_display_name(client: FirestoreClient, uid: String, name: String) -> bool:
	var trimmed := name.strip_edges()
	if trimmed.length() > DISPLAY_NAME_MAX_LENGTH:
		trimmed = trimmed.substr(0, DISPLAY_NAME_MAX_LENGTH)
	var ok: bool = await client.set_document(
		_path(uid), {"display_name": trimmed, "updated_at": Time.get_unix_time_from_system()}
	)
	if ok:
		_profile["display_name"] = trimmed
	return ok


## 表示用にログインIDを控える(認証そのものはFirebase側が持っている)。
static func save_login_id(client: FirestoreClient, uid: String, login_id: String) -> bool:
	var ok: bool = await client.set_document(
		_path(uid), {"login_id": login_id, "updated_at": Time.get_unix_time_from_system()}
	)
	if ok:
		_profile["login_id"] = login_id
	return ok


## 砂金を加算する(GameDesign.md 15章)。加算後の残高を返す。
##
## 残高は read-modify-write のため、同じアカウントを2つのタブで開くと加算が
## 消えうる。`updateTime` を前提条件にした `commit()` で競合を検出し、
## 競合したら読み直して再試行する(`OnlineMatch` の手の送信と同じ流儀)。
##
## 通信に失敗した場合は加算分を `AccountStore` へ退避し、次回の成功時に
## まとめて足し込む。CPU戦はオフラインでも成立するため、この経路が無いと
## 獲得が消える。
static func grant(client: FirestoreClient, uid: String, amount: int, is_cpu: bool) -> int:
	var pending := AccountStore.get_pending_currency()
	var total := amount + pending
	if uid == "" or total <= 0:
		return currency()

	for _attempt in range(GRANT_RETRY):
		var doc: Dictionary = await client.get_document_meta(_path(uid))
		var fields: Dictionary = doc.get("fields", {})
		var data := {
			"currency": int(fields.get("currency", 0)) + total,
			"updated_at": Time.get_unix_time_from_system(),
		}
		if is_cpu:
			var same_day: bool = str(fields.get("cpu_reward_date", "")) == _today()
			data["cpu_reward_date"] = _today()
			data["cpu_reward_count"] = (
				(int(fields.get("cpu_reward_count", 0)) + 1) if same_day else 1
			)

		var precondition := {}
		if bool(doc.get("exists", false)) and str(doc.get("update_time", "")) != "":
			precondition = {"updateTime": doc["update_time"]}
		var ok: bool = await client.commit([client.update_write(_path(uid), data, precondition)])
		if ok:
			for key in data:
				_profile[key] = data[key]
			AccountStore.clear_pending_currency()
			return currency()

	# 競合が続いた・通信に失敗した。獲得分は手元に残して次回へ回す
	AccountStore.add_pending_currency(amount)
	return currency()


static func _path(uid: String) -> String:
	return "%s/%s" % [COLLECTION, uid]


static func _today() -> String:
	return Time.get_date_string_from_system()


static func _empty_profile() -> Dictionary:
	return {
		"display_name": "",
		"login_id": "",
		"currency": 0,
		"cpu_reward_date": "",
		"cpu_reward_count": 0,
	}
