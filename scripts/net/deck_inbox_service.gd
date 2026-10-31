class_name DeckInboxService
extends RefCounted
## 攻略サイトの「ゲームに追加」で届いたデッキを受け取る(GameDesign.md 32章 / Architecture.md 10.21節)。
## サイトはデッキ一覧(`players/{uid}.decks`)を書き換えず、`players/{uid}/deck_inbox/` へ1件ずつ置く。
## 手元の未送信の変更が優先されて、サイトから足したデッキが上書きで消えるため。

const COLLECTION := "deck_inbox"

## 受け取ったが、まだ画面で知らせていないデッキ名。
static var _unannounced: Array[String] = []


## 届いているデッキを末尾へ足す。サインインのたびと、デッキ一覧を開いたときに呼ぶ。
static func receive(client: FirestoreClient, uid: String) -> void:
	if uid.is_empty() or client == null:
		return
	var inbox := "%s/%s" % [AccountService.path(uid), COLLECTION]
	for doc in await client.list_documents(inbox):
		var fields: Dictionary = doc["fields"]
		# 先に消す。消せないまま足すと、次に受け取ったとき同じデッキが2つになるため。
		if not await client.delete_document("%s/%s" % [inbox, doc["id"]]):
			continue
		var cards := CardDeckCode.from_text(String(fields.get("cards", "")))
		if cards.size() != MatchState.DECK_SIZE:
			continue
		var deck_name := String(fields.get("name", "")).strip_edges()
		if deck_name.is_empty():
			deck_name = CardDeckSave.DEFAULT_NAME
		CardDeckSave.add_deck(deck_name, cards)
		_unannounced.append(deck_name)


## 知らせる1行。知らせていないものが無ければ空文字。呼ぶと空に戻る。
static func take_announcement() -> String:
	if _unannounced.is_empty():
		return ""
	var text := "サイトから「%s」が届きました" % "」「".join(_unannounced)
	_unannounced.clear()
	return text


static func reset_for_test() -> void:
	_unannounced.clear()
