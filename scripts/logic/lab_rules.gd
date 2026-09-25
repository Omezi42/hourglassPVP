class_name LabRules
extends RefCounted
## 掲示板〈ラボ〉の判定(GameDesign.md 29章、Architecture.md 10.17節)。
## 通信を持たず、回・案・投票用紙の辞書(Firestoreから読んだ形)だけを見る。

## 自分の投稿の状態。
enum Status { LISTED, HIDDEN, REVIEWING, ADOPTED, RESULT, TOURNAMENT }
## 投票できない理由。
enum VoteBlock { NONE, CLOSED, OWN, ALREADY, NO_VOTES_LEFT, HIDDEN }

const VOTES_PER_ROUND := 3
const JST_OFFSET := 9 * 3600
const SECONDS_PER_MINUTE := 60
const SECONDS_PER_HOUR := 3600
const SECONDS_PER_DAY := 86400


static func is_open(round: Dictionary, now: float) -> bool:
	return float(round.get("starts_at", 0)) <= now and now < float(round.get("ends_at", 0))


static func is_closed(round: Dictionary, now: float) -> bool:
	return now >= float(round.get("ends_at", 0))


## 開いている回。無ければ空の辞書。
static func current_round(rounds: Array, now: float) -> Dictionary:
	for round in rounds:
		if is_open(round, now):
			return round
	return {}


## 締め切った回を新しい順に。
static func closed_rounds(rounds: Array, now: float) -> Array:
	var rows := rounds.filter(func(round: Dictionary) -> bool: return is_closed(round, now))
	rows.sort_custom(
		func(a: Dictionary, b: Dictionary) -> bool:
			return float(a.get("ends_at", 0)) > float(b.get("ends_at", 0))
	)
	return rows


## 案と投票用紙のドキュメントID。1回1人1件・1枚をIDの一意性で担保する。
static func entry_id(round_id: String, uid: String) -> String:
	return "%s_%s" % [round_id, uid]


static func voted_ids(ballot: Dictionary) -> Array:
	return ballot.get("proposal_ids", [])


static func votes_left(ballot: Dictionary) -> int:
	return maxi(VOTES_PER_ROUND - voted_ids(ballot).size(), 0)


static func vote_block(
	proposal: Dictionary, ballot: Dictionary, uid: String, round: Dictionary, now: float
) -> VoteBlock:
	if not is_open(round, now):
		return VoteBlock.CLOSED
	if bool(proposal.get("hidden", false)):
		return VoteBlock.HIDDEN
	if str(proposal.get("author_uid", "")) == uid:
		return VoteBlock.OWN
	if voted_ids(ballot).has(str(proposal.get("id", ""))):
		return VoteBlock.ALREADY
	if votes_left(ballot) <= 0:
		return VoteBlock.NO_VOTES_LEFT
	return VoteBlock.NONE


static func visible_rows(rows: Array) -> Array:
	return rows.filter(func(row: Dictionary) -> bool: return not bool(row.get("hidden", false)))


## 募集中の並び。見る人ごとに違い、開き直しても変わらない。
static func viewer_order(rows: Array, uid: String) -> Array:
	var sorted := rows.duplicate()
	sorted.sort_custom(
		func(a: Dictionary, b: Dictionary) -> bool:
			return (uid + str(a.get("id", ""))).hash() < (uid + str(b.get("id", ""))).hash()
	)
	return sorted


## 締切後の並び。得票の多い順、同数なら先に出した順。
static func ranked(rows: Array) -> Array:
	var sorted := rows.duplicate()
	sorted.sort_custom(
		func(a: Dictionary, b: Dictionary) -> bool:
			var count_a := int(a.get("good_count", 0))
			var count_b := int(b.get("good_count", 0))
			if count_a != count_b:
				return count_a > count_b
			return float(a.get("created_at", 0)) < float(b.get("created_at", 0))
	)
	return sorted


## 自分の投稿の状態。`round` は投稿が属する回(大会の案は空)。
static func status_of(proposal: Dictionary, round: Dictionary, now: float) -> Status:
	if str(proposal.get("source", "")) == "tournament":
		return Status.TOURNAMENT
	if bool(proposal.get("hidden", false)):
		return Status.HIDDEN
	if round.is_empty() or not is_closed(round, now):
		return Status.LISTED
	if str(proposal.get("result", "")) == "adopted":
		return Status.ADOPTED
	if bool(round.get("results_fixed", false)):
		return Status.RESULT
	return Status.REVIEWING


## 締切までの残り。「あと5日 14時間」「あと3時間 20分」「あと12分」。
static func deadline_text(ends_at: float, now: float) -> String:
	var left := maxi(int(ends_at - now), 0)
	var days := left / SECONDS_PER_DAY
	var hours := (left % SECONDS_PER_DAY) / SECONDS_PER_HOUR
	var minutes := (left % SECONDS_PER_HOUR) / SECONDS_PER_MINUTE
	if days > 0:
		return "あと%d日 %d時間" % [days, hours]
	if hours > 0:
		return "あと%d時間 %d分" % [hours, minutes]
	return "あと%d分" % maxi(minutes, 1)


## 回の期間(JST)。「9/1〜9/14」。締切の瞬間は翌日0時のため1秒引いた日を出す。
static func period_text(round: Dictionary) -> String:
	var start := Time.get_datetime_dict_from_unix_time(
		int(float(round.get("starts_at", 0))) + JST_OFFSET
	)
	var end := Time.get_datetime_dict_from_unix_time(
		int(float(round.get("ends_at", 0))) + JST_OFFSET - 1
	)
	return "%d/%d〜%d/%d" % [start["month"], start["day"], end["month"], end["day"]]
