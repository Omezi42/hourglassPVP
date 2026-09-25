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


func is_empty() -> bool:
	return gold <= 0 and card_set_id.is_empty() and icon_id.is_empty()


## 報酬の札に絵として出すカード。1枚セット(GameDesign.md 27章)の先頭を使う。
func card() -> CardData:
	if card_set_id.is_empty():
		return null
	var ids := CardSetLibrary.card_ids(card_set_id)
	return null if ids.is_empty() else CardLibrary.find_by_id(ids[0])


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
