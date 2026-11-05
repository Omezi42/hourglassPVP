class_name DeckIntroService
extends RefCounted
## みんなのデッキ(GameDesign.md 26章 / Architecture.md 10.14節)。#デッキ紹介 に流れた紹介を読む。
## 紹介を置くのは Cloud Functions だけで、ゲームは読むだけ。

const COLLECTION := "deck_intros"
## 新しいものからこの件数まで出す(それより古い紹介は出さない)。
const LIMIT := 50


## 新しい順の紹介。1件は {name, author_name, comment, created_at, cards: Array[CardData]}。
## 読めなかったときは null(0件の空配列と分けるため)。
static func fetch_recent(client: FirestoreClient) -> Variant:
	if client == null:
		return null
	var docs: Variant = await client.query_recent_or_null(COLLECTION, "created_at", LIMIT)
	if not (docs is Array):
		return null
	var intros: Array = []
	for doc in docs:
		var intro := from_fields(doc["fields"])
		if not intro.is_empty():
			intros.append(intro)
	return intros


## 30枚にならない紹介(カードが消えた等)は空の辞書を返し、一覧へ出さない。
static func from_fields(fields: Dictionary) -> Dictionary:
	var cards := CardDeckCode.from_text(String(fields.get("cards", "")))
	if cards.size() != MatchState.DECK_SIZE:
		return {}
	var deck_name := String(fields.get("name", "")).strip_edges()
	return {
		"name": deck_name if not deck_name.is_empty() else CardDeckSave.DEFAULT_NAME,
		"author_name": TextGlyphs.replace_unsupported(String(fields.get("author_name", ""))),
		"comment": TextGlyphs.replace_unsupported(String(fields.get("comment", ""))),
		"created_at": int(fields.get("created_at", 0)),
		"cards": cards,
	}
