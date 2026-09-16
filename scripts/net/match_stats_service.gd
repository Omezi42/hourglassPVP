class_name MatchStatsService
extends RefCounted
## 戦績(`MatchStats`)をFirestoreへ同期し、別端末からログインしても
## 同じ記録を続けて見られるようにする(GameDesign.md 19章)。
##
## `players/{uid}` へ `stats_kinds` / `stats_cards` / `stats_decks` の3フィールドを
## 持たせ、`MatchStats.apply_delta()` と同じ増分計算をそのまま流用する。
##
## **押す(push)**: 対局を終えるたびに、`AccountService.grant()` と同じ
## 「`updateTime` を前提条件にした `commit()` で read-modify-write、競合したら
## 読み直して再試行」の流儀で1局ぶんを増分する。通信に失敗した場合は
## `AccountStore` へ退避し、次にサインインが成功した時点でまとめて送り直す。
##
## **引く(pull)**: サインインのたびに(`AccountService.load_profile()` から)
## Firestoreの値でローカルの `user://match_stats.json` を丸ごと差し替える。
## これが「別端末で記録した分」を取り込む唯一の経路であり、そのうえで
## まだ送れていないローカルの増分(退避分)を上へ重ねて適用し直す。

## 競合・通信失敗時に読み直して再試行する回数(`AccountService.GRANT_RETRY` と同じ)。
const RETRY := 3


## 1局ぶんをFirestoreへ送る。**await しない呼び出しを前提にしてある**
## (結果パネルの表示を通信で止めないため。砂金の付与と同じ扱い)。
static func push(
	client: FirestoreClient, uid: String, kind: int, won: bool, turns: int, deck: Array
) -> void:
	var entry := {
		"kind": kind,
		"won": won,
		"turns": turns,
		"card_ids": MatchStats.unique_card_ids(deck),
		"deck_code": MatchStats.deck_code_for(deck),
	}
	await _push_entry(client, uid, entry)


## サインインの直後、`AccountService.load_profile()` が読んだフィールドをそのまま渡す
## (二重に通信しないため)。ローカルを差し替えてから、退避してあった分を送り直す。
static func sync_after_sign_in(client: FirestoreClient, uid: String, fields: Dictionary) -> void:
	if uid.is_empty():
		return
	MatchStats.replace_bucket(
		uid,
		fields.get("stats_kinds", {}),
		fields.get("stats_cards", {}),
		fields.get("stats_decks", {})
	)
	var pending := AccountStore.get_pending_matches()
	if pending.is_empty():
		return
	AccountStore.clear_pending_matches()
	for raw in pending:
		var entry: Dictionary = raw
		# 差し替えた直後のローカルにも、まだ送れていない分を重ねて見せる
		# (置き換えでサーバーへ届いていない自分の対局が画面から消えないように)。
		var bucket := MatchStats.bucket_snapshot(uid)
		MatchStats.apply_delta(
			bucket,
			int(entry.get("kind", 0)),
			bool(entry.get("won", false)),
			int(entry.get("turns", 0)),
			entry.get("card_ids", []),
			str(entry.get("deck_code", ""))
		)
		MatchStats.replace_bucket(uid, bucket["kinds"], bucket["cards"], bucket["decks"])
		await _push_entry(client, uid, entry)


static func _push_entry(client: FirestoreClient, uid: String, entry: Dictionary) -> void:
	if uid.is_empty() or client == null:
		AccountStore.add_pending_match(entry)
		return
	var path := AccountService.path(uid)
	for _attempt in range(RETRY):
		var doc: Dictionary = await client.get_document_meta(path)
		var fields: Dictionary = doc.get("fields", {})
		var bucket := {
			"kinds": fields.get("stats_kinds", {}),
			"cards": fields.get("stats_cards", {}),
			"decks": fields.get("stats_decks", {}),
		}
		MatchStats.apply_delta(
			bucket,
			int(entry.get("kind", 0)),
			bool(entry.get("won", false)),
			int(entry.get("turns", 0)),
			entry.get("card_ids", []),
			str(entry.get("deck_code", ""))
		)
		var data := {
			"stats_kinds": bucket["kinds"],
			"stats_cards": bucket["cards"],
			"stats_decks": bucket["decks"],
			"updated_at": Time.get_unix_time_from_system(),
		}
		var precondition := {}
		if bool(doc.get("exists", false)) and str(doc.get("update_time", "")) != "":
			precondition = {"updateTime": doc["update_time"]}
		var ok: bool = await client.commit([client.update_write(path, data, precondition)])
		if ok:
			return

	AccountStore.add_pending_match(entry)
