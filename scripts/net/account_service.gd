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
## 他プレイヤーのプロフィールキャッシュ(uid -> {display_name, icon_id, title_id})。
static var _profile_cache: Dictionary = {}


## ログアウト・ログインでアカウントが変わったときに呼ぶ。
static func reset() -> void:
	_profile = _empty_profile()
	_profile_cache.clear()


static func display_name() -> String:
	return str(_profile.get("display_name", ""))


## 表示名。未設定なら「ゲスト」を返す(GameDesign.md 14章)。
static func display_name_or_default() -> String:
	var name := display_name()
	return name if name != "" else "ゲスト"


static func icon_id() -> String:
	var id := str(_profile.get("icon_id", ""))
	if id.is_empty():
		id = str(AccountStore.load_local_customization().get("icon_id", ""))
	return id if not id.is_empty() else UserProfileLibrary.DEFAULT_ICON_ID


static func title_id() -> String:
	var id := str(_profile.get("title_id", ""))
	if id.is_empty():
		id = str(AccountStore.load_local_customization().get("title_id", ""))
	return id if not id.is_empty() else UserProfileLibrary.DEFAULT_TITLE_ID


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
	if _profile.get("icon_id", "") != "" or _profile.get("title_id", "") != "":
		AccountStore.save_local_customization(icon_id(), title_id())


static func save_display_name(client: FirestoreClient, uid: String, name: String) -> bool:
	return await save_profile(client, uid, name, icon_id(), title_id())


static func save_profile(
	client: FirestoreClient, uid: String, name: String, p_icon_id: String, p_title_id: String
) -> bool:
	var trimmed := TextGlyphs.sanitize(name.strip_edges())
	if trimmed.length() > DISPLAY_NAME_MAX_LENGTH:
		trimmed = trimmed.substr(0, DISPLAY_NAME_MAX_LENGTH)
	AccountStore.save_local_customization(p_icon_id, p_title_id)
	_profile["icon_id"] = p_icon_id
	_profile["title_id"] = p_title_id
	if uid == "":
		_profile["display_name"] = trimmed
		return true
	var ok: bool = await client.set_document(
		_path(uid),
		{
			"display_name": trimmed,
			"icon_id": p_icon_id,
			"title_id": p_title_id,
			"updated_at": Time.get_unix_time_from_system()
		}
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


## 他プレイヤーのプロフィールを引く(GameDesign.md 14章)。未設定・取得失敗なら既定値を返す。
## 同じuidは2度読まない。
static func fetch_profile(client: FirestoreClient, uid: String) -> Dictionary:
	if uid == "":
		return {
			"display_name": "",
			"icon_id": UserProfileLibrary.DEFAULT_ICON_ID,
			"title_id": UserProfileLibrary.DEFAULT_TITLE_ID,
		}
	if uid == _current_uid():
		return {
			"display_name": display_name(),
			"icon_id": icon_id(),
			"title_id": title_id(),
		}
	if _profile_cache.has(uid):
		return _profile_cache[uid]
	var fields: Dictionary = await client.get_document(_path(uid))
	var name := TextGlyphs.replace_unsupported(str(fields.get("display_name", "")))
	var p_icon := str(fields.get("icon_id", ""))
	if p_icon.is_empty():
		p_icon = UserProfileLibrary.DEFAULT_ICON_ID
	var p_title := str(fields.get("title_id", ""))
	if p_title.is_empty():
		p_title = UserProfileLibrary.DEFAULT_TITLE_ID
	var profile := {
		"display_name": name,
		"icon_id": p_icon,
		"title_id": p_title,
	}
	_profile_cache[uid] = profile
	return profile


## 他プレイヤーの表示名を引く(GameDesign.md 14章)。後方互換用。
static func fetch_display_name(client: FirestoreClient, uid: String) -> String:
	var profile := await fetch_profile(client, uid)
	return str(profile.get("display_name", ""))


static func _current_uid() -> String:
	return NetSession.auth.uid if NetSession.auth != null else ""


static func _path(uid: String) -> String:
	return "%s/%s" % [COLLECTION, uid]


static func _today() -> String:
	return Time.get_date_string_from_system()


static func _empty_profile() -> Dictionary:
	return {
		"display_name": "",
		"login_id": "",
		"icon_id": "",
		"title_id": "",
		"currency": 0,
		"cpu_reward_date": "",
		"cpu_reward_count": 0,
	}
