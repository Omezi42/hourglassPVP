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

## 月末報酬(GameDesign.md 28章)。到達した最高段位の帯に応じた砂金
## (2026-09-15、ユーザー判断で確定)。
const SEASON_REWARDS := {
	"bronze": 100,
	"silver": 300,
	"gold": 800,
	"platinum": 3000,
}


## いま(JST基準)のシーズンキー("2026-09")。`at_unix_time`はテスト用(負値なら現在時刻)。
static func current_season_key(at_unix_time: float = -1.0) -> String:
	var unix_time := at_unix_time if at_unix_time >= 0.0 else Time.get_unix_time_from_system()
	var jst_time := unix_time + JST_OFFSET_HOURS * 3600.0
	var dict := Time.get_datetime_dict_from_unix_time(int(jst_time))
	return "%04d-%02d" % [int(dict.get("year", 0)), int(dict.get("month", 0))]


## いまのシーズンが終わるまでの日数(当日を1日と数える。JST基準)。ホームの札に出す(GameDesign.md 9章)。
static func days_left_in_season(at_unix_time: float = -1.0) -> int:
	var unix_time := at_unix_time if at_unix_time >= 0.0 else Time.get_unix_time_from_system()
	var jst_time := unix_time + JST_OFFSET_HOURS * 3600.0
	var today := Time.get_datetime_dict_from_unix_time(int(jst_time))
	var year := int(today["year"])
	var month := int(today["month"]) + 1
	if month > 12:
		month = 1
		year += 1
	var next_start := Time.get_unix_time_from_datetime_dict(
		{"year": year, "month": month, "day": 1, "hour": 0, "minute": 0, "second": 0}
	)
	return ceili((float(next_start) - jst_time) / 86400.0)


## ランクマッチへ入る直前・ランク画面を開いた直後に呼ぶ。シーズンが変わっていれば
## 旧シーズンの月末報酬(未受領なら)を付与してから、段位を初期化する。
##
## 戻り値は月初の表彰演出(GameDesign.md 28章)のための情報:
## `{"transitioned": bool, "peak_tier": String, "reward": int}`。**`transitioned`が
## trueになるのは、既にシーズンを経験したことがあるプレイヤーが次のシーズンへ
## 切り替わったときだけ**で、このゲームを初めて触る(前のシーズンが存在しない)
## プレイヤーへ「ブロンズに到達しました」のような空虚な表彰を出さないための区別。
static func ensure_current_season(
	client: FirestoreClient, uid: String, at_unix_time: float = -1.0
) -> Dictionary:
	var none := {"transitioned": false, "peak_tier": "", "reward": 0}
	if uid == "" or client == null:
		return none
	var current := current_season_key(at_unix_time)
	var previous := AccountService.rank_season()
	if previous == current:
		return none
	var is_first_season := previous.is_empty()
	var peak_tier := AccountService.rank_peak_tier()
	var reward := 0
	if not is_first_season and AccountService.rank_reward_claimed_season() != previous:
		reward = await _grant_season_reward(client, uid, previous, peak_tier)
	for _attempt in range(RETRY):
		var doc: Dictionary = await client.get_document_meta(AccountService.path(uid))
		var fields: Dictionary = doc.get("fields", {})
		if str(fields.get("rank_season", "")) == current:
			AccountService.apply_local_fields(fields)
			return {"transitioned": not is_first_season, "peak_tier": peak_tier, "reward": reward}
		var data := {
			"rank_season": current,
			"rank_tier": RankRules.INITIAL_TIER,
			"rank_stars": 0,
			"rank_rating": 0,
			"rank_peak_tier": RankRules.INITIAL_TIER,
			"rank_progress_score": RankRules.progress_score(RankRules.INITIAL_TIER, 0, 0),
			"rank_win_streak": 0,
			"updated_at": Time.get_unix_time_from_system(),
		}
		var ok: bool = await client.commit(
			[client.update_write(AccountService.path(uid), data, _precondition(doc))]
		)
		if ok:
			AccountService.apply_local_fields(data)
			return {"transitioned": not is_first_season, "peak_tier": peak_tier, "reward": reward}
	return none


## 対局の結果を段位へ反映する(GameDesign.md 28章)。10手未満の対局は数えない
## (15章「不正な稼ぎ方への線引き」と同じ不正対策)。`host`はunityroomランキングへの
## 送信(`UnityroomRankingClient`)がHTTPRequestをぶら下げるためのノード。
static func apply_result(
	client: FirestoreClient, host: Node, uid: String, won: bool, move_count: int
) -> void:
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
			data["rank_progress_score"] = RankRules.progress_score(tier, 0, rating)
		else:
			var stars: int = int(fields.get("rank_stars", 0))
			var streak: int = int(fields.get("rank_win_streak", 0))
			if won:
				streak += 1
				stars += RankRules.star_gain(streak)
			else:
				streak = 0
				stars = RankRules.retreat_stars(stars)
			var advanced := RankRules.advance_stars(tier, stars)
			var next_tier: String = advanced["tier"]
			data = {
				"rank_tier": next_tier,
				"rank_stars": advanced["stars"],
				"rank_win_streak": streak,
			}
			if next_tier == RankRules.PLATINUM_KEY:
				data["rank_rating"] = RankRules.PLATINUM_START_RATING
				data["rank_progress_score"] = RankRules.progress_score(
					next_tier, 0, RankRules.PLATINUM_START_RATING
				)
			else:
				data["rank_progress_score"] = RankRules.progress_score(
					next_tier, int(advanced["stars"]), 0
				)
			tier = next_tier
		if RankRules.compare_tier(tier, peak) > 0:
			data["rank_peak_tier"] = tier
		data["updated_at"] = Time.get_unix_time_from_system()
		var ok: bool = await client.commit(
			[client.update_write(AccountService.path(uid), data, _precondition(doc))]
		)
		if ok:
			AccountService.apply_local_fields(data)
			# プラチナのままレートが動いた/いまプラチナへ昇格したときだけ、
			# unityroomの公開ランキングへも送る(GameDesign.md 28章「要調査」への回答。
			# UnityroomRankingClientのクラス冒頭を参照)。
			if tier == RankRules.PLATINUM_KEY:
				UnityroomRankingClient.send_score(
					host,
					UnityroomRankingClient.RANK_SCOREBOARD_ID,
					float(data.get("rank_rating", AccountService.rank_rating()))
				)
			return


## 実際に加算できた額を返す(失敗・対象外なら0)。呼び出し側が表彰演出へ表示する額を
## 知るために使う。
static func _grant_season_reward(
	client: FirestoreClient, uid: String, old_season: String, peak_tier: String
) -> int:
	var amount := int(SEASON_REWARDS.get(RankRules.bracket_of(peak_tier), 0))
	if amount <= 0:
		return 0
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
			return amount
	return 0


static func _precondition(doc: Dictionary) -> Dictionary:
	if bool(doc.get("exists", false)) and str(doc.get("update_time", "")) != "":
		return {"updateTime": doc["update_time"]}
	return {}
