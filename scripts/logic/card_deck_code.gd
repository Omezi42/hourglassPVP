class_name CardDeckCode
extends RefCounted
## デッキを短い文字列にして受け渡す(GameDesign.md 9章)。
## `CardDeckSave` と同じ「Autoloadを使わずstaticで持つ」流儀。
##
## **中身はカードのidと枚数**であり、カード一覧の並び順の番号ではない。
## 番号で表すと、カードを1枚足した時点で過去のコードがすべて別のデッキになる。
## 毎日カードが増える運用(GameDesign.md 1章)とは両立しない。
##
## 形式: `HG1-` + 「id*枚数」を`,`で連ねた文字列をdeflateで縮めてBase64にしたもの。

const PREFIX := "HG1-"
const SEPARATOR := ","
const COUNT_MARK := "*"


## デッキ(CardData の配列)をコードにする。
static func encode(deck: Array) -> String:
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
	var raw := SEPARATOR.join(parts).to_utf8_buffer()
	var packed := raw.compress(FileAccess.COMPRESSION_DEFLATE)
	# 展開に元の長さが要るため、先頭2バイトへ入れておく(デッキ1つぶんなので65535で足りる)。
	var head := PackedByteArray([raw.size() & 0xFF, (raw.size() >> 8) & 0xFF])
	return PREFIX + Marshalls.raw_to_base64(head + packed)


## コードからデッキを組む。読めない場合は空の配列を返す。
static func decode(code: String) -> Array:
	var body := code.strip_edges()
	if not body.begins_with(PREFIX):
		return []
	var payload := body.substr(PREFIX.length())
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
	return _build(raw.get_string_from_utf8())


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


static func _build(text: String) -> Array:
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
