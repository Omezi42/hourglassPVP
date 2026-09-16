class_name MatchStats
extends RefCounted
## 対局の戦績(GameDesign.md 19章)。`CardDeckSave` と同じ
## 「Autoloadを使わずstaticで持つ」流儀で `user://match_stats.json` へ貯める。
##
## **リプレイから集計しない。**リプレイは直近30件しか残らず(GameDesign.md 12章)、
## 古い対局が消えるたびに通算の勝率が変わってしまう。終局のたびに1件足すだけの
## 積み上げ方式にして、リプレイの保持件数と切り離す。
##
## **アカウントごとに数える**(`LocalReplayService` と同じ理由)。ログアウトして
## 別のアカウントで遊んだぶんが混ざらないようにする。
##
## **このファイル自体はFirestoreを一切知らない。**同期(押す・引く)は
## `MatchStatsService`(net層)が担当し、ここは「1局ぶんの増分を計算し、
## 任意のバケット(Dictionary)へ適用する」計算と、ローカルの読み書きだけを持つ。
## `apply_delta()` をローカル保存とFirestore同期の両方が共有することで、
## 「どちらが正しい増分か」がズレる余地を無くしてある。

const SAVE_PATH := "user://match_stats.json"
## デッキ別に覚えておく上限。多すぎると読み込みが重くなるだけで、
## 構築の傾向を見るには十分な件数。
const DECK_LIMIT := 20

static var _loaded := false
## テスト中だけ true。`user://` の実データを書き換えないための保険。
static var _muted := false
static var _data: Dictionary = {}


## 1局ぶんを足す。kind は `CurrencyRules.MatchKind`。
static func record(owner_uid: String, kind: int, won: bool, turns: int, deck: Array) -> void:
	_ensure_loaded()
	var bucket := _bucket(owner_uid)
	apply_delta(bucket, kind, won, turns, unique_card_ids(deck), deck_code_for(deck))
	_save()


## デッキ(`Array[CardData]`)から、戦績が数える単位(重複しないid・指紋)を作る。
## Firestoreへ送る増分も同じものを使うため、ここを唯一の作り方にする。
static func unique_card_ids(deck: Array) -> Array[String]:
	var seen: Dictionary = {}
	var ids: Array[String] = []
	for card: CardData in deck:
		if seen.has(card.id):
			continue
		seen[card.id] = true
		ids.append(card.id)
	return ids


static func deck_code_for(deck: Array) -> String:
	return CardDeckCode.fingerprint(deck) if not deck.is_empty() else ""


## 1局ぶんの増分を任意のバケット(`{"kinds":, "cards":, "decks":}`)へ適用する。
## ローカルの `record()` と `MatchStatsService` のFirestore同期が、同じ計算を
## 共有するための唯一の入口。
static func apply_delta(
	bucket: Dictionary, kind: int, won: bool, turns: int, card_ids: Array, deck_code: String
) -> void:
	for field in ["kinds", "cards", "decks"]:
		if not bucket.has(field):
			bucket[field] = {}
	var totals: Dictionary = bucket["kinds"]
	var key := str(kind)
	var entry: Dictionary = totals.get(key, {"games": 0, "wins": 0, "turns": 0})
	entry["games"] = int(entry["games"]) + 1
	entry["wins"] = int(entry["wins"]) + (1 if won else 0)
	entry["turns"] = int(entry["turns"]) + turns
	totals[key] = entry
	var cards: Dictionary = bucket["cards"]
	for id: String in card_ids:
		var c: Dictionary = cards.get(id, {"games": 0, "wins": 0})
		c["games"] = int(c["games"]) + 1
		c["wins"] = int(c["wins"]) + (1 if won else 0)
		cards[id] = c
	if deck_code.is_empty():
		return
	var decks: Dictionary = bucket["decks"]
	var d: Dictionary = decks.get(deck_code, {"games": 0, "wins": 0})
	d["games"] = int(d["games"]) + 1
	d["wins"] = int(d["wins"]) + (1 if won else 0)
	decks[deck_code] = d
	if decks.size() > DECK_LIMIT:
		_drop_smallest(decks)


## Firestoreから読んだ値でローカルのバケットを丸ごと差し替える
## (`MatchStatsService` が別端末の分を取り込むときに使う)。
static func replace_bucket(
	owner_uid: String, kinds: Dictionary, cards: Dictionary, decks: Dictionary
) -> void:
	_ensure_loaded()
	var key := owner_uid if not owner_uid.is_empty() else "local"
	_data[key] = {"kinds": kinds, "cards": cards, "decks": decks}
	_save()


## いまローカルに持っているバケットをそのまま返す(Firestoreへの初回書き込み用)。
static func bucket_snapshot(owner_uid: String) -> Dictionary:
	_ensure_loaded()
	return _bucket(owner_uid).duplicate(true)


## 集計。kind が負なら全種別の合計を返す。
static func totals(owner_uid: String, kind: int = -1) -> Dictionary:
	_ensure_loaded()
	var bucket := _bucket(owner_uid)
	var games := 0
	var wins := 0
	var turns := 0
	for key: String in bucket["kinds"]:
		if kind >= 0 and key != str(kind):
			continue
		var entry: Dictionary = bucket["kinds"][key]
		games += int(entry["games"])
		wins += int(entry["wins"])
		turns += int(entry["turns"])
	return {"games": games, "wins": wins, "turns": turns}


## カード別の成績。`{"id":, "games":, "wins":}` を採用数の多い順で返す。
static func cards(owner_uid: String) -> Array:
	_ensure_loaded()
	return _sorted_rows(_bucket(owner_uid)["cards"], "id")


## デッキ別の成績。`{"code":, "games":, "wins":}` を対局数の多い順で返す。
static func decks(owner_uid: String) -> Array:
	_ensure_loaded()
	return _sorted_rows(_bucket(owner_uid)["decks"], "code")


static func _sorted_rows(source: Dictionary, key_name: String) -> Array:
	var rows: Array = []
	for key: String in source:
		var entry: Dictionary = source[key]
		rows.append({key_name: key, "games": int(entry["games"]), "wins": int(entry["wins"])})
	rows.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return a["games"] > b["games"])
	return rows


## 上限を超えたら、いちばん対局数の少ない構築を落とす。
static func _drop_smallest(source: Dictionary) -> void:
	var smallest := ""
	var fewest := -1
	for key: String in source:
		var games: int = int(source[key]["games"])
		if fewest < 0 or games < fewest:
			fewest = games
			smallest = key
	if not smallest.is_empty():
		source.erase(smallest)


static func _bucket(owner_uid: String) -> Dictionary:
	var key := owner_uid if not owner_uid.is_empty() else "local"
	if not _data.has(key):
		_data[key] = {"kinds": {}, "cards": {}, "decks": {}}
	var bucket: Dictionary = _data[key]
	for field in ["kinds", "cards", "decks"]:
		if not bucket.has(field):
			bucket[field] = {}
	return bucket


static func _ensure_loaded() -> void:
	if _loaded:
		return
	_loaded = true
	var file := FileAccess.open(SAVE_PATH, FileAccess.READ)
	if file == null:
		return
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	file.close()
	if parsed is Dictionary:
		_data = parsed


static func _save() -> void:
	if _muted:
		return
	var file := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if file == null:
		return
	file.store_string(JSON.stringify(_data))
	file.close()


## テストが `user://` を汚さずに検証するために使う。保存は行わなくなる。
static func reset_for_test(data: Dictionary) -> void:
	_loaded = true
	_muted = true
	_data = data
