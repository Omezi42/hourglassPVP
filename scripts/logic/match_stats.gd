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
	var totals: Dictionary = bucket["kinds"]
	var key := str(kind)
	var entry: Dictionary = totals.get(key, {"games": 0, "wins": 0, "turns": 0})
	entry["games"] = int(entry["games"]) + 1
	entry["wins"] = int(entry["wins"]) + (1 if won else 0)
	entry["turns"] = int(entry["turns"]) + turns
	totals[key] = entry
	_record_cards(bucket["cards"], deck, won)
	_record_deck(bucket["decks"], deck, won)
	_save()


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


## 同じカードを2枚積んでいても1局は1局として数える(採用しているかどうかを見るため)。
static func _record_cards(source: Dictionary, deck: Array, won: bool) -> void:
	var seen: Dictionary = {}
	for card: CardData in deck:
		if seen.has(card.id):
			continue
		seen[card.id] = true
		var entry: Dictionary = source.get(card.id, {"games": 0, "wins": 0})
		entry["games"] = int(entry["games"]) + 1
		entry["wins"] = int(entry["wins"]) + (1 if won else 0)
		source[card.id] = entry


static func _record_deck(source: Dictionary, deck: Array, won: bool) -> void:
	if deck.is_empty():
		return
	var code := CardDeckCode.fingerprint(deck)
	var entry: Dictionary = source.get(code, {"games": 0, "wins": 0})
	entry["games"] = int(entry["games"]) + 1
	entry["wins"] = int(entry["wins"]) + (1 if won else 0)
	source[code] = entry
	if source.size() > DECK_LIMIT:
		_drop_smallest(source)


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
