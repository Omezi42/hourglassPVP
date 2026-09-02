class_name MatchRecordService
extends RefCounted
## 分析用の対局記録(GameDesign.md 22章 / Architecture.md 10.9節)。
##
## `matches/{id}` はリプレイのための置き場でアカウントごとに30件で消えるため
## (GameDesign.md 12章)、**分析のための記録は別のコレクションへ1件だけ書き、消さない**。
## 同じ場所へ「消える」と「消さない」という相反する要件を負わせられないための分離であり、
## 中身が重複することは承知のうえで採っている。
##
## 書き込みに失敗しても対局には何も起こさない。落ちて失われるのはサンプル1件だけである。

const COLLECTION := "match_records"
## 集計。**版で分けず通算で貯める**(版ごとに分けると、カードが毎日増える運用では
## 画面に出る数字が毎日0へ戻るため)。版ごとの分析は `tools/analyze_matches.py` が
## 記録そのものを読んで行う。
const STATS_PATH := "stats/global"
## 集計の更新が競合したときに読み直す回数。
const STATS_RETRIES := 4


## 1局ぶんを残す。**先着1件だけが通る**ため、両者が呼んでよい。
## 記録できた側だけが続けて集計を更新する(1局を2回数えないため)。
static func submit(client: FirestoreClient, match_id: String, kind: int, state: MatchState) -> bool:
	if client == null or match_id.is_empty() or state == null or state.winner < 0:
		return false
	var source: Dictionary = await client.get_document("matches/%s" % match_id)
	if source.is_empty():
		return false
	var record := _build(source, kind, state)
	if not await client.create_document("%s/%s" % [COLLECTION, match_id], record):
		return false
	await _bump_stats(client, record)
	return true


## 「みんなの戦績」が読む集計。取得できなければ空を返す。
static func fetch_stats(client: FirestoreClient) -> Dictionary:
	if client == null:
		return {}
	return await client.get_document(STATS_PATH)


## 決着の要因。集計のキーと分析の道具の両方が読むため、文字列で持つ
## (enum の整数のまま残すと、値を足したときに過去の記録の意味が変わる)。
static func end_reason_key(reason: int) -> String:
	match reason:
		MatchState.EndReason.SURRENDER:
			return "surrender"
		MatchState.EndReason.TIMEOUT:
			return "timeout"
		MatchState.EndReason.DRAW:
			return "draw"
	return "hp"


static func kind_key(kind: int) -> String:
	return "room" if kind == CurrencyRules.MatchKind.ROOM else "random"


static func _build(source: Dictionary, kind: int, state: MatchState) -> Dictionary:
	return {
		"build": GameVersion.build_id(),
		"version": GameVersion.version(),
		"kind": kind_key(kind),
		"finished_at": Time.get_unix_time_from_system(),
		"winner": "a" if state.winner == MatchState.Side.A else "b",
		"end_reason": end_reason_key(state.end_reason),
		"turns": state.turn_count,
		"hp_a": int(state.hp.get(MatchState.Side.A, 0)),
		"hp_b": int(state.hp.get(MatchState.Side.B, 0)),
		"deck_a": source.get("deck_a", []),
		"deck_b": source.get("deck_b", []),
		"seed": int(source.get("seed", 0)),
		"actions": source.get("actions", []),
		"player_a": source.get("player_a", ""),
		"player_b": source.get("player_b", ""),
	}


## 集計を増分で更新する。`AccountService.grant()` と同じく updateTime を前提条件にし、
## 競合したら読み直して再試行する(初回だけは exists:false で作る)。
static func _bump_stats(client: FirestoreClient, record: Dictionary) -> void:
	for _attempt in STATS_RETRIES:
		var meta: Dictionary = await client.get_document_meta(STATS_PATH)
		var fields: Dictionary = meta.get("fields", {})
		var precondition: Dictionary = (
			{"updateTime": meta["update_time"]} if meta.get("exists", false) else {"exists": false}
		)
		var updated := _merge(fields, record)
		if await client.commit([client.update_write(STATS_PATH, updated, precondition)]):
			return


## 1局ぶんを足した集計を返す。**カードは両者のデッキを1回ずつ数える**ため、
## `games` の2倍が `cards` の分母になる。
static func _merge(fields: Dictionary, record: Dictionary) -> Dictionary:
	var winner: String = record["winner"]
	var counts: Dictionary = _to_counts(fields.get("counts", {}))
	counts["games"] = int(counts.get("games", 0)) + 1
	counts["turns"] = int(counts.get("turns", 0)) + int(record["turns"])
	counts["first_wins"] = int(counts.get("first_wins", 0)) + (1 if winner == "a" else 0)
	var kind_key: String = "kind_%s" % record["kind"]
	counts[kind_key] = int(counts.get(kind_key, 0)) + 1
	var reason_key: String = "end_%s" % record["end_reason"]
	counts[reason_key] = int(counts.get(reason_key, 0)) + 1

	var cards: Dictionary = (fields.get("cards", {}) as Dictionary).duplicate(true)
	_count_deck(cards, record.get("deck_a", []), winner == "a")
	_count_deck(cards, record.get("deck_b", []), winner == "b")
	return {"counts": counts, "cards": cards, "updated_at": Time.get_unix_time_from_system()}


## 同じカードを2枚積んでいても1局は1局として数える(採用しているかどうかを見るため。
## `MatchStats` と同じ数え方に揃える)。
static func _count_deck(cards: Dictionary, ids: Array, won: bool) -> void:
	var seen: Dictionary = {}
	for id: Variant in ids:
		var key := str(id)
		if key.is_empty() or seen.has(key):
			continue
		seen[key] = true
		var entry: Dictionary = cards.get(key, {"g": 0, "w": 0})
		entry["g"] = int(entry.get("g", 0)) + 1
		entry["w"] = int(entry.get("w", 0)) + (1 if won else 0)
		cards[key] = entry


static func _to_counts(value: Variant) -> Dictionary:
	return (value as Dictionary).duplicate() if value is Dictionary else {}
