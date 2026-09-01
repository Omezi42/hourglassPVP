class_name DeckCodeService
extends RefCounted
## デッキコード(8桁の数字)の発行と読み込み(GameDesign.md 9章)。
## `AccountService` と同じ「static のみ・FirestoreClient を受け取る」流儀にし、
## UI が Firestore を直接叩かないようにする。
##
## **番号は中身を持たない。**`deckcodes/{コード}` へ「id*枚数」のテキストを預け、
## 渡すのは番号だけにする。20枚の組み合わせは1億通りをはるかに超えるため、
## 中身を持ったまま8桁へ収めることはできない。

const COLLECTION := "deckcodes"
const CODE_LENGTH := 8
## 番号が埋まっていたときに引き直す回数。
const ISSUE_RETRY_COUNT := 5

## 指紋 → 発行済みのコード。同じ構築を続けて発行しても同じ番号を返すために持つ
## (押すたびに預けると、使われないドキュメントが際限なく増える)。
static var _issued: Dictionary = {}


## デッキを預けて番号を返す。失敗したら空文字を返す。
static func publish(client: FirestoreClient, deck: Array) -> String:
	var fingerprint := CardDeckCode.fingerprint(deck)
	if _issued.has(fingerprint):
		return String(_issued[fingerprint])
	var text := CardDeckCode.to_text(deck)
	if text.is_empty():
		return ""
	for _attempt in range(ISSUE_RETRY_COUNT):
		var code := random_code()
		var created: bool = await client.create_document(
			_doc_path(code), {"cards": text, "created_at": Time.get_unix_time_from_system()}
		)
		if created:
			_issued[fingerprint] = code
			return code
	return ""


## 番号からデッキを組む。読めない場合は空の配列を返す。
static func fetch(client: FirestoreClient, code: String) -> Array:
	var normalized := normalize(code)
	if normalized == "":
		return []
	var doc: Dictionary = await client.get_document(_doc_path(normalized))
	var text: String = doc.get("cards", "")
	if text.is_empty():
		return []
	return CardDeckCode.from_text(text)


## 入力された文字列をコードとして扱えるかどうか。扱えない場合は空文字を返す。
static func normalize(code: String) -> String:
	var body := code.strip_edges()
	if body.length() != CODE_LENGTH:
		return ""
	for i in body.length():
		if body[i] < "0" or body[i] > "9":
			return ""
	return body


static func random_code() -> String:
	var code := ""
	for _i in range(CODE_LENGTH):
		code += str(randi() % 10)
	return code


static func _doc_path(code: String) -> String:
	return "%s/%s" % [COLLECTION, code]
