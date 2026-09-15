class_name RankProgress
extends RefCounted
## ランクマッチの段位・レートの読み書き(GameDesign.md 28章、Architecture.md 10.16節)。
## `players/{uid}` を直接触るstaticのみのクラスで、`AccountService`と同じ
## 「`updateTime`を前提条件にした`commit()`で競合したら読み直して再試行する」流儀を使う。
##
## シーズンの切り替えは「サーバー側の一括更新」を持たない(Architecture.md 10.16節)。
## 常駐サーバーを持たない方針のため、各プレイヤーのドキュメントは次に自分が
## 遊びに来た時点で自分自身を新シーズンへ切り替える(遅延リセット)。

const RETRY := 3
## 段位を動かさない対局の下限(GameDesign.md 15章「不正な稼ぎ方への線引き」と同じ線)。
const MIN_MOVES := 10
const JST_OFFSET_HOURS := 9

## 月末報酬(GameDesign.md 28章「具体的な額・品目は次のステップで決める」に対する暫定値)。
## 到達した最高段位の帯に応じた砂金。正式な額は別途検討する(docs/TODO.md 4.5節)。
const SEASON_REWARDS := {
	"bronze": 0,
	"silver": 100,
	"gold": 300,
	"platinum": 800,
}


## いま(JST基準)のシーズンキー("2026-09")。`at_unix_time`はテスト用(負値なら現在時刻)。
static func current_season_key(at_unix_time: float = -1.0) -> String:
	var unix_time := at_unix_time if at_unix_time >= 0.0 else Time.get_unix_time_from_system()
	var jst_time := unix_time + JST_OFFSET_HOURS * 3600.0
	var dict := Time.get_datetime_dict_from_unix_time(int(jst_time))
	return "%04d-%02d" % [int(dict.get("year", 0)), int(dict.get("month", 0))]


## ランクマッチへ入る直前・ランク画面を開いた直後に呼ぶ。シーズンが変わっていれば
## 旧シーズンの月末報酬(未受領なら)を付与してから、段位を初期化する。
static func ensure_current_season(
	client: FirestoreClient, uid: String, at_unix_time: float = -1.0
) -> void:
	if uid == "" or client == null:
		return
	var current := current_season_key(at_unix_time)
	var previous := AccountService.rank_season()
	if previous == current:
		return
	if previous != "" and AccountService.rank_reward_claimed_season() != previous:
		await _grant_season_reward(client, uid, previous, AccountService.rank_peak_tier())
	for _attempt in range(RETRY):
		var doc: Dictionary = await client.get_document_meta(AccountService.path(uid))
		var fields: Dictionary = doc.get("fields", {})
		if str(fields.get("rank_season", "")) == current:
			AccountService.apply_local_fields(fields)
			return
		var data := {
			"rank_season": current,
			"rank_tier": RankRules.INITIAL_TIER,
			"rank_stars": 0,
			"rank_rating": 0,
			"rank_peak_tier": RankRules.INITIAL_TIER,
			"updated_at": Time.get_unix_time_from_system(),
		}
		var ok: bool = await client.commit(
			[client.update_write(AccountService.path(uid), data, _precondition(doc))]
		)
		if ok:
			AccountService.apply_local_fields(data)
			return


## 対局の結果を段位へ反映する(GameDesign.md 28章)。10手未満の対局は数えない
## (15章「不正な稼ぎ方への線引き」と同じ不正対策)。
static func apply_result(client: FirestoreClient, uid: String, won: bool, move_count: int) -> void:
	if uid == "" or client == null or move_count < MIN_MOVES:
		return
	for _attempt in range(RETRY):
		var doc: Dictionary = await client.get_document_meta(AccountService.path(uid))
		var fields: Dictionary = doc.get("fields", {})
		var tier := str(fields.get("rank_tier", RankRules.INITIAL_TIER))
		if tier.is_empty():
			tier = RankRules.INITIAL_TIER
		var peak := str(fields.get("rank_peak_tier", tier))
		var data: Dictionary
		if tier == RankRules.PLATINUM_KEY:
			var rating: int = maxi(
				int(fields.get("rank_rating", 0)), RankRules.PLATINUM_START_RATING
			)
			rating += RankRules.rating_delta(rating, won)
			data = {"rank_rating": rating}
		else:
			var stars: int = int(fields.get("rank_stars", 0))
			stars = stars + 1 if won else RankRules.retreat_stars(stars)
			var advanced := RankRules.advance_stars(tier, stars)
			var next_tier: String = advanced["tier"]
			data = {"rank_tier": next_tier, "rank_stars": advanced["stars"]}
			if next_tier == RankRules.PLATINUM_KEY:
				data["rank_rating"] = RankRules.PLATINUM_START_RATING
			tier = next_tier
		if RankRules.compare_tier(tier, peak) > 0:
			data["rank_peak_tier"] = tier
		data["updated_at"] = Time.get_unix_time_from_system()
		var ok: bool = await client.commit(
			[client.update_write(AccountService.path(uid), data, _precondition(doc))]
		)
		if ok:
			AccountService.apply_local_fields(data)
			return


static func _grant_season_reward(
	client: FirestoreClient, uid: String, old_season: String, peak_tier: String
) -> void:
	var amount := int(SEASON_REWARDS.get(RankRules.bracket_of(peak_tier), 0))
	if amount <= 0:
		return
	for _attempt in range(RETRY):
		var doc: Dictionary = await client.get_document_meta(AccountService.path(uid))
		var fields: Dictionary = doc.get("fields", {})
		var data := {
			"currency": int(fields.get("currency", 0)) + amount,
			"rank_reward_claimed_season": old_season,
			"updated_at": Time.get_unix_time_from_system(),
		}
		var ok: bool = await client.commit(
			[client.update_write(AccountService.path(uid), data, _precondition(doc))]
		)
		if ok:
			AccountService.apply_local_fields(data)
			return


static func _precondition(doc: Dictionary) -> Dictionary:
	if bool(doc.get("exists", false)) and str(doc.get("update_time", "")) != "":
		return {"updateTime": doc["update_time"]}
	return {}
