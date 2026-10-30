class_name GiftService
extends RefCounted
## プレゼントの受け取り(GameDesign.md 33章 / Architecture.md 10.22節)。
## 受け取りの印(`claimed_gifts`)と品を1回の `commit()` で書く(`WelcomeDays.claim()` と同じ形)。
## 未サインイン・通信失敗のときは退避しない(押せなくしておけば失うものが無いため)。

const OWNED_SETS := "owned_card_sets"


## 受け取れたら true。既に受け取っていた(別のタブで受け取った)ときは、印を読み直して false を返す。
static func claim(client: FirestoreClient, uid: String, gift: GiftData) -> bool:
	if client == null or uid.is_empty() or gift == null:
		return false
	var path := AccountService.path(uid)
	for _attempt in range(AccountService.GRANT_RETRY):
		var doc: Dictionary = await client.get_document_meta(path)
		if not AccountService.read_succeeded(doc):
			return false
		var fields: Dictionary = doc.get("fields", {})
		var claimed: Array = fields.get(GiftLibrary.FIELD_CLAIMED, [])
		if claimed.has(gift.id):
			AccountService.apply_local_fields({GiftLibrary.FIELD_CLAIMED: claimed})
			return false
		var next_claimed := claimed.duplicate()
		next_claimed.append(gift.id)
		var data := {
			GiftLibrary.FIELD_CLAIMED: next_claimed,
			"updated_at": Time.get_unix_time_from_system(),
		}
		match gift.kind:
			GiftData.Kind.CARD_SET:
				var owned: Array = fields.get(OWNED_SETS, [])
				if not owned.has(gift.set_id):
					var next_owned := owned.duplicate()
					next_owned.append(gift.set_id)
					data[OWNED_SETS] = next_owned
			GiftData.Kind.CURRENCY:
				data["currency"] = int(fields.get("currency", 0)) + gift.amount
		var precondition := {}
		if bool(doc.get("exists", false)) and str(doc.get("update_time", "")) != "":
			precondition = {"updateTime": doc["update_time"]}
		if await client.commit([client.update_write(path, data, precondition)]):
			AccountService.apply_local_fields(data)
			if data.has(OWNED_SETS):
				AccountService.save_unlocks_locally()
			return true
	return false
