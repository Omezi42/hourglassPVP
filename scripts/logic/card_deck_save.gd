class_name CardDeckSave
extends RefCounted
## v5.0のデッキ(30枚・同名2枚まで)の保存(Autoloadを使わずstaticで持つ流儀)。
##
## **デッキは何個でも保存できる**(GameDesign.md 9章)。対局で使うデッキは開始直前の
## 選択画面で毎回選ぶため、ここが持つ `selected` は**その選択画面の初期値**でしかない。
##
## アカウントへ同期する(GameDesign.md 14章「アカウントに紐づけるもの」/ Architecture.md 10.23節)。
## ファイルは「`owner` のアカウントのデッキ」の控えであり、`dirty` はまだ送れていない変更があることを示す。

const SAVE_PATH := "user://card_decks.json"
const COPY_LIMIT := 2
## デッキ名は表示上の都合で10文字程度までとする(GameDesign.md 9章)。
const NAME_LIMIT := 10
const DEFAULT_NAME := "デッキ"

## テストが差し替える(`user://` の実データに触らないため)。
static var save_path := SAVE_PATH


## 保存済みのデッキ一覧。1件は {"name": String, "cards": Array[CardData]}。
## 壊れている・カードが揃わない件は落とす(30枚に満たないデッキで対局へ入れないため)。
static func list_decks() -> Array:
	var decks: Array = []
	for entry in _load_raw().get("decks", []):
		if typeof(entry) != TYPE_DICTIONARY:
			continue
		var ids: Variant = (entry as Dictionary).get("ids", [])
		if typeof(ids) != TYPE_ARRAY:
			continue
		var cards := CardLibrary.deck_from_ids(ids)
		if cards.size() != MatchState.DECK_SIZE:
			continue
		decks.append(
			{"name": _sanitize_name(str((entry as Dictionary).get("name", ""))), "cards": cards}
		)
	return decks


static func save_decks(decks: Array) -> void:
	var raw: Array = []
	for deck in decks:
		(
			raw
			. append(
				{
					"name": _sanitize_name(str((deck as Dictionary).get("name", ""))),
					"ids": CardLibrary.ids_from_deck((deck as Dictionary).get("cards", [])),
				}
			)
		)
	var data := _load_raw()
	data["decks"] = raw
	data["selected"] = clampi(selected_index(), 0, maxi(raw.size() - 1, 0))
	_store_changed(data)


## 対局の開始前に選ぶ画面の初期値。範囲外なら先頭に落とす。
static func selected_index() -> int:
	var value: Variant = _load_raw().get("selected", 0)
	var index: int = int(value) if typeof(value) == TYPE_FLOAT or typeof(value) == TYPE_INT else 0
	return clampi(index, 0, maxi(list_decks().size() - 1, 0))


static func set_selected_index(index: int) -> void:
	var raw := _load_raw()
	raw["selected"] = index
	_store_changed(raw)


## いま選ばれているデッキ。1つも保存していないプレイヤーはプリセットの「基本」で
## 対局へ入る(GameDesign.md 18章)。
static func selected_deck() -> Array:
	var decks := list_decks()
	if decks.is_empty():
		return CardPresetDecks.basic()
	return decks[clampi(selected_index(), 0, decks.size() - 1)]["cards"]


## 1件を追加する。追加した位置を返す。
static func add_deck(deck_name: String, cards: Array) -> int:
	var decks := list_decks()
	decks.append({"name": deck_name, "cards": cards})
	save_decks(decks)
	return decks.size() - 1


static func update_deck(index: int, deck_name: String, cards: Array) -> void:
	var decks := list_decks()
	if index < 0 or index >= decks.size():
		add_deck(deck_name, cards)
		return
	decks[index] = {"name": deck_name, "cards": cards}
	save_decks(decks)


static func remove_deck(index: int) -> void:
	var decks := list_decks()
	if index < 0 or index >= decks.size():
		return
	decks.remove_at(index)
	save_decks(decks)


## 並び替えモード(GameDesign.md 9章)で1つ隣と入れ替える。
static func move_deck(index: int, offset: int) -> void:
	var decks := list_decks()
	var target := index + offset
	if index < 0 or index >= decks.size() or target < 0 or target >= decks.size():
		return
	var moved: Variant = decks[index]
	decks[index] = decks[target]
	decks[target] = moved
	save_decks(decks)


## 保存済みのデッキがまだ無いときに使う名前。「デッキ1」「デッキ2」…と続ける。
static func next_default_name() -> String:
	return _sanitize_name("%s%d" % [DEFAULT_NAME, list_decks().size() + 1])


## デッキがまだ無いときに使う既定のデッキ。マナカーブが偏らないよう、
## コストの安い順に15種を選んで2枚ずつ入れる。
static func default_deck() -> Array:
	var pool := CardLibrary.all_cards().duplicate()
	pool.sort_custom(func(a: CardData, b: CardData) -> bool: return a.cost < b.cost)
	var deck: Array = []
	for card in pool:
		if deck.size() >= MatchState.DECK_SIZE:
			break
		for i in COPY_LIMIT:
			deck.append(card)
	return deck


## 同期に使う控えの中身。`decks` は保存形式のまま(`{"name", "ids"}` の配列)。
static func sync_snapshot() -> Dictionary:
	var raw := _load_raw()
	return {
		"owner": str(raw.get("owner", "")),
		"dirty": bool(raw.get("dirty", false)),
		"revision": int(raw.get("revision", 0)),
		"decks": raw.get("decks", []),
		"selected": int(raw.get("selected", 0)),
	}


## アカウントの内容で控えを丸ごと置き換える(サインインの直後)。
static func replace_from_account(owner_uid: String, decks: Array, selected: int) -> void:
	_store(
		{
			"owner": owner_uid,
			"dirty": false,
			"revision": int(_load_raw().get("revision", 0)),
			"decks": decks,
			"selected": selected,
		}
	)


## 控えを `owner_uid` のものとして扱う(アカウントへまだ無いとき、手元のデッキを上げる前に呼ぶ)。
static func claim_owner(owner_uid: String) -> void:
	var raw := _load_raw()
	raw["owner"] = owner_uid
	_store(raw)


## 送れた時点で呼ぶ。送っている間に変更が入っていれば `dirty` を残す。
static func mark_synced(owner_uid: String, revision: int) -> void:
	var raw := _load_raw()
	if str(raw.get("owner", "")) != owner_uid or int(raw.get("revision", 0)) != revision:
		return
	raw["dirty"] = false
	_store(raw)


static func _sanitize_name(value: String) -> String:
	var trimmed := value.strip_edges()
	if trimmed == "":
		trimmed = DEFAULT_NAME
	# 表示名と同じく、同梱フォントが字形を持たない文字は豆腐になる(GameDesign.md 14章)。
	trimmed = TextGlyphs.sanitize(trimmed)
	if trimmed == "":
		trimmed = DEFAULT_NAME
	return trimmed.substr(0, NAME_LIMIT)


## 保存ファイルの中身。**旧形式(デッキ1つだけの `{"deck": [...]}`)もここで受ける**。
## 複数デッキを持つ前に保存したデッキが、更新した時点で消えることのないようにする。
static func _load_raw() -> Dictionary:
	if not FileAccess.file_exists(save_path):
		return {}
	var file := FileAccess.open(save_path, FileAccess.READ)
	if file == null:
		return {}
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	if typeof(parsed) != TYPE_DICTIONARY:
		return {}
	var raw := parsed as Dictionary
	if raw.has("decks"):
		return raw
	var ids: Variant = raw.get("deck", [])
	if typeof(ids) != TYPE_ARRAY or (ids as Array).is_empty():
		return {}
	return {"decks": [{"name": "%s1" % DEFAULT_NAME, "ids": ids}], "selected": 0}


## プレイヤーの操作による変更。送れていない印を付けて控え、アカウントへ送る。
static func _store_changed(raw: Dictionary) -> void:
	raw["dirty"] = true
	raw["revision"] = int(raw.get("revision", 0)) + 1
	_store(raw)
	AccountSyncService.push_decks()


static func _store(raw: Dictionary) -> void:
	var file := FileAccess.open(save_path, FileAccess.WRITE)
	if file == null:
		return
	file.store_string(JSON.stringify(raw))
