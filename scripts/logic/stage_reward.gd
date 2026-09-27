class_name StageReward
extends RefCounted
## リーサルパズル・ソロモードの初回クリアで渡したもの(GameDesign.md 24章・27章)。
## 結果パネルが砂金・カード・アイコンを1つずつ札にして並べるため、文ではなく中身で返す。

var gold := 0
## 通信できず手元へ控えた(次に接続できたときに反映する)。
var gold_pending := false
var card_set_id := ""
var icon_id := ""
## 解き直しで、報酬を渡さなかった。
var already_cleared := false
## 同時に複数の節目が届いたとき(ソロモード・27章)、すべてを並べるための一覧。
## `card_set_id` / `icon_id` は先頭と同じ値を持つ(単数しか読まない呼び出し元との互換用)。
var card_set_ids: Array[String] = []
var icon_ids: Array[String] = []


func is_empty() -> bool:
	return (
		gold <= 0
		and card_set_id.is_empty()
		and icon_id.is_empty()
		and card_set_ids.is_empty()
		and icon_ids.is_empty()
	)


## 報酬の札に絵として出すカードたち。1枚セット(GameDesign.md 27章)の先頭をそれぞれ使う。
func cards() -> Array[CardData]:
	var ids := card_set_ids if not card_set_ids.is_empty() else _single(card_set_id)
	var result: Array[CardData] = []
	for set_id in ids:
		var found := CardSetLibrary.card_ids(set_id)
		if found.is_empty():
			continue
		var card := CardLibrary.find_by_id(found[0])
		if card != null:
			result.append(card)
	return result


## 報酬のアイコンのidたち。
func icons() -> Array[String]:
	return icon_ids if not icon_ids.is_empty() else _single(icon_id)


static func _single(value: String) -> Array[String]:
	var result: Array[String] = []
	if not value.is_empty():
		result.append(value)
	return result


## 砂金を渡す。通信できないときは手元へ控え、次に加算が通ったときにまとめて足す
## (対局の砂金と同じ扱い。Architecture.md 10.2節)。**通信は待たない。**
func grant_gold(uid: String, amount: int) -> void:
	if amount <= 0:
		return
	gold = amount
	if NetSession.client == null or uid.is_empty():
		AccountStore.add_pending_currency(amount)
		gold_pending = true
	else:
		AccountService.grant(NetSession.client, uid, amount, false)


static func current_uid() -> String:
	if NetSession.client != null and NetSession.client.auth != null:
		return NetSession.client.auth.uid
	return ""
