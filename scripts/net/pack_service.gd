class_name PackService
extends RefCounted
## パックの購入と生成(GameDesign.md 15章・21章 / Architecture.md 10.8.1節)。
## `AccountService.purchase()` と同じ流儀で、**`updateTime` を前提条件にした1回の `commit()`** で
## 残高・所持数・砂粒・天井を書く。残高を読んでから別に書くと、2つのタブで同時に開いたとき二重に引ける。
## 抽選は手元で行う(サーバーでは検証しない。GameDesign.md 11章)。未サインインでは使えない。

## 1回で開けられるパック数(1パック単位と10パック単位。値引きはしない)。
const BULK_COUNT := 10


## パックを開ける。`free` は1日1回の無料パック(砂金を引かず `free_pack_date` を更新する)。
## 戻り値: {"ok", "message", "packs": [{"cards": ids, "overflow": [bool]}], "dust_gained"}
static func open_packs(
	client: FirestoreClient,
	uid: String,
	pack_id: String,
	count: int,
	free: bool,
	rng: RandomNumberGenerator
) -> Dictionary:
	var pack := PackDefinition.load_pack(pack_id)
	if pack == null:
		return _fail("このパックは取り扱っていません。")
	if count != 1 and count != BULK_COUNT:
		return _fail("開けられるのは1パックか%dパックです。" % BULK_COUNT)
	if free and count != 1:
		return _fail("無料のパックは1日1パックです。")
	if uid == "" or client == null:
		return _fail("接続できないため開けられません。")
	var pools := PackDraw.pool_by_rarity(pack)
	var table := RarityTable.get_table()
	var today := DailyMissionService.today()
	var cost := 0 if free else pack.price * count

	for _attempt in range(AccountService.GRANT_RETRY):
		var doc: Dictionary = await client.get_document_meta(AccountService.path(uid))
		if not AccountService.read_succeeded(doc):
			break
		var fields: Dictionary = doc.get("fields", {})
		if free and str(fields.get("free_pack_date", "")) == today:
			return _fail("今日の無料パックはもう開けました。")
		var balance := int(fields.get("currency", 0))
		if balance < cost:
			AccountService.apply_local_fields({"currency": balance})
			return _fail("%sが足りません(あと%d)。" % [CurrencyRules.CURRENCY_NAME, cost - balance])
		var counts: Dictionary = (fields.get("card_counts", {}) as Dictionary).duplicate()
		var pity_map: Dictionary = (fields.get("pack_pity", {}) as Dictionary).duplicate()
		var pity := int(pity_map.get(pack_id, 0))
		var view := {"card_counts": counts, "owned_card_sets": fields.get("owned_card_sets", [])}
		var dust := int(fields.get("sand_dust", 0))
		var gained := 0
		var packs: Array = []
		for _i in count:
			var drawn := PackDraw.draw_pack(pack, pools, pity, rng)
			pity = int(drawn["pity"])
			var ids: Array[String] = []
			var overflow: Array[bool] = []
			for card: CardData in drawn["cards"]:
				var have := mini(CardOwnership.count_in(view, card), CardOwnership.cap(card))
				var over := have >= CardOwnership.cap(card)
				if over:
					gained += table.gain_of(card.rarity)
				else:
					counts[card.id] = have + 1
				ids.append(card.id)
				overflow.append(over)
			packs.append({"cards": ids, "overflow": overflow})
		pity_map[pack_id] = pity
		var data := {
			"currency": balance - cost,
			"card_counts": counts,
			"sand_dust": dust + gained,
			"pack_pity": pity_map,
			"updated_at": Time.get_unix_time_from_system(),
		}
		if free:
			data["free_pack_date"] = today
		if await _commit(client, uid, doc, data):
			return {"ok": true, "message": "", "packs": packs, "dust_gained": gained}
	return _fail("開けられませんでした。接続を確認してください。")


## 砂粒でカードを1枚生成する(GameDesign.md 15章)。未公開のカードと、上限まで持っているカードは生成できない。
static func craft(client: FirestoreClient, uid: String, card_id: String) -> Dictionary:
	var card := CardLibrary.find_by_id(card_id)
	if card == null or not _published(card):
		return _fail("このカードは生成できません。")
	if uid == "" or client == null:
		return _fail("接続できないため生成できません。")
	var cost := RarityTable.get_table().cost_of(card.rarity)

	for _attempt in range(AccountService.GRANT_RETRY):
		var doc: Dictionary = await client.get_document_meta(AccountService.path(uid))
		if not AccountService.read_succeeded(doc):
			break
		var fields: Dictionary = doc.get("fields", {})
		var have := CardOwnership.count_in(fields, card)
		if have >= CardOwnership.cap(card):
			return _fail("これ以上は持てません。")
		var dust := int(fields.get("sand_dust", 0))
		if dust < cost:
			AccountService.apply_local_fields({"sand_dust": dust})
			return _fail("砂粒が足りません(あと%d)。" % (cost - dust))
		var counts: Dictionary = (fields.get("card_counts", {}) as Dictionary).duplicate()
		counts[card_id] = have + 1
		var data := {
			"card_counts": counts,
			"sand_dust": dust - cost,
			"updated_at": Time.get_unix_time_from_system(),
		}
		if await _commit(client, uid, doc, data):
			return {"ok": true, "message": "%sを生成しました。" % card.display_name}
	return _fail("生成できませんでした。接続を確認してください。")


## いずれかのパックの公開済みカードか(未公開・パックに入らないカードは生成できない)。
static func _published(card: CardData) -> bool:
	for pack_id in PackDefinition.PACK_IDS:
		var pack := PackDefinition.load_pack(pack_id)
		if pack == null:
			continue
		for set_id in pack.set_ids:
			if CardSetLibrary.card_ids(set_id).has(card.id):
				return true
	return false


static func _commit(
	client: FirestoreClient, uid: String, doc: Dictionary, data: Dictionary
) -> bool:
	var precondition := {}
	if bool(doc.get("exists", false)) and str(doc.get("update_time", "")) != "":
		precondition = {"updateTime": doc["update_time"]}
	var path := AccountService.path(uid)
	var ok: bool = await client.commit([client.update_write(path, data, precondition)])
	if ok:
		AccountService.apply_local_fields(data)
	return ok


static func _fail(message: String) -> Dictionary:
	return {"ok": false, "message": message, "packs": [], "dust_gained": 0}
