class_name CardDeckCode
extends RefCounted
## デッキと「id*枚数」のテキストを行き来する(GameDesign.md 9章)。
## `CardDeckSave` と同じ「Autoloadを使わずstaticで持つ」流儀。
##
## **画面へ出すデッキコードは8桁の数字**であり、その中身はここで作ったテキストを
## サーバーへ預けたものになる(`DeckCodeService`)。20枚の組み合わせは1億通りを
## はるかに超えるため、**中身を持ったまま8桁へ収めることは原理的にできない**。
##
## `fingerprint()` は画面へ出さない内部の識別子で、戦績がデッキ別の勝率を数えるのに
## 使う(記録のたびに通信させるわけにいかないため、こちらはローカルで完結する)。

const SEPARATOR := ","
const COUNT_MARK := "*"
## 指紋の形式。`HG1-` + 上記テキストを deflate で縮めて Base64 にしたもの。
const FINGERPRINT_PREFIX := "HG1-"


## デッキ(CardData の配列)を「id*枚数」のテキストにする。
static func to_text(deck: Array) -> String:
	var counts: Dictionary = {}
	var order: Array[String] = []
	for card: CardData in deck:
		if not counts.has(card.id):
			counts[card.id] = 0
			order.append(card.id)
		counts[card.id] += 1
	order.sort()
	var parts: PackedStringArray = []
	for id in order:
		parts.append("%s%s%d" % [id, COUNT_MARK, int(counts[id])])
	return SEPARATOR.join(parts)


## テキストからデッキを組む。読めない場合は空の配列を返す
## (プールから消えたカードを含む場合もここで空になる)。
static func from_text(text: String) -> Array:
	var deck: Array = []
	for part in text.split(SEPARATOR, false):
		var pair := part.split(COUNT_MARK, true, 1)
		if pair.size() != 2 or not pair[1].is_valid_int():
			return []
		var card := CardLibrary.find_by_id(pair[0])
		if card == null:
			return []
		var count := int(pair[1])
		if count < 1 or count > CardDeckSave.COPY_LIMIT:
			return []
		for i in count:
			deck.append(card)
	if deck.size() != MatchState.DECK_SIZE:
		return []
	return deck


## 構築を突き合わせるための内部の識別子(戦績・発行済みコードのキャッシュに使う)。
static func fingerprint(deck: Array) -> String:
	var raw := to_text(deck).to_utf8_buffer()
	var packed := raw.compress(FileAccess.COMPRESSION_DEFLATE)
	# 展開に元の長さが要るため、先頭2バイトへ入れておく(デッキ1つぶんなので65535で足りる)。
	var head := PackedByteArray([raw.size() & 0xFF, (raw.size() >> 8) & 0xFF])
	return FINGERPRINT_PREFIX + Marshalls.raw_to_base64(head + packed)


## 指紋からデッキを戻す。読めない場合は空の配列を返す。
static func deck_from_fingerprint(code: String) -> Array:
	var body := code.strip_edges()
	if not body.begins_with(FINGERPRINT_PREFIX):
		return []
	var payload := body.substr(FINGERPRINT_PREFIX.length())
	# Base64 として成立しない文字列を渡すとエンジン側がエラーを出すため、先に弾く。
	if not _is_base64(payload):
		return []
	var blob := Marshalls.base64_to_raw(payload)
	if blob.size() < 3:
		return []
	var length: int = blob[0] | (blob[1] << 8)
	var raw := blob.slice(2).decompress(length, FileAccess.COMPRESSION_DEFLATE)
	if raw.is_empty():
		return []
	return from_text(raw.get_string_from_utf8())


static func _is_base64(text: String) -> bool:
	if text.is_empty() or text.length() % 4 != 0:
		return false
	for i in text.length():
		var c := text[i]
		var ok := (
			(c >= "A" and c <= "Z")
			or (c >= "a" and c <= "z")
			or (c >= "0" and c <= "9")
			or c == "+"
			or c == "/"
			or c == "="
		)
		if not ok:
			return false
	return true
