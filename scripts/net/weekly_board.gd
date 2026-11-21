class_name WeeklyBoard
extends RefCounted
## 週替わりの遠征の順位表(GameDesign.md 27章「週替わりの遠征」、Architecture.md 10.15節)。
## `weekly_expedition/{week}/entries/{uid}` へ「勝った数・残りHP」を送り、上位を読む。
## 並びは 勝った数 → 残りHP → 先に記録した順(Firestoreのクエリが決める)。

const COLLECTION := "weekly_expedition"
const ENTRIES := "entries"
const LIMIT := 20

## 週ごとに読んだ上位の控え。自分が送ったらその週を捨てる。
static var _cache: Dictionary = {}


static func entry_path(week: String, uid: String) -> String:
	return "%s/%s/%s/%s" % [COLLECTION, week, ENTRIES, uid]


## 自分の記録を送る。サインインしていないときは何もしない。**await しない呼び出しを前提にしてある**
## (結果パネルの表示を通信で止めないため)。
static func submit(uid: String, week: String, wins: int, hp: int) -> void:
	if uid.is_empty() or week.is_empty():
		return
	var client := NetSession.client
	if client == null or client.auth == null or client.auth.uid != uid:
		return
	_cache.erase(week)
	await (
		client
		. set_document(
			entry_path(week, uid),
			{
				"wins": wins,
				"hp": hp,
				"name": AccountService.display_name(),
				"icon": AccountService.icon_id(),
				"updated_at": int(Time.get_unix_time_from_system()),
			}
		)
	)


## 上位20人 `[{"uid", "name", "icon", "wins", "hp"}]`。読めなかったときは null(0人とは分ける)。
static func load_top(week: String) -> Variant:
	if _cache.has(week):
		return _cache[week]
	var client := NetSession.client
	if client == null:
		return null
	var docs: Variant = await client.query_weekly_board(COLLECTION, week, LIMIT)
	if not (docs is Array):
		return null
	var rows: Array[Dictionary] = []
	for doc: Dictionary in docs:
		var fields: Dictionary = doc.get("fields", {})
		(
			rows
			. append(
				{
					"uid": str(doc.get("id", "")),
					"name": str(fields.get("name", "")),
					"icon": str(fields.get("icon", UserProfileLibrary.DEFAULT_ICON_ID)),
					"wins": int(fields.get("wins", 0)),
					"hp": int(fields.get("hp", 0)),
				}
			)
		)
	_cache[week] = rows
	return rows


## 読み込み済みの上位のうち自分の順位。読んでいない・入っていなければ0。
static func cached_rank(week: String, uid: String) -> int:
	return rank_in(_cache.get(week, []), uid)


## 上位の一覧の中の自分の順位(1始まり)。入っていなければ0。
static func rank_in(rows: Array, uid: String) -> int:
	if uid.is_empty():
		return 0
	for i in rows.size():
		if str((rows[i] as Dictionary).get("uid", "")) == uid:
			return i + 1
	return 0


static func has_cache(week: String) -> bool:
	return _cache.has(week)


static func clear_cache() -> void:
	_cache.clear()
