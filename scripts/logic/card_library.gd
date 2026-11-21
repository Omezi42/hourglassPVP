class_name CardLibrary
extends RefCounted
## data/cards/ を走査してカード定義を列挙する(Autoloadを使わずstaticで持つ流儀)。

const CARDS_DIR := "res://data/cards"

## `load_step()` に予算を区切らせないときの値(一度に全部読む)。
const LOAD_ALL_AT_ONCE := 1 << 30

static var _cache: Array[CardData] = []
static var _files := PackedStringArray()
static var _scanned := false
## `load_step()` が読み終えるまで溜めておく(読み終えてから `_cache` へ移す)。
static var _loaded: Array[Resource] = []


## 集められるカード。id順に並ぶ。**トークンは含まない**(GameDesign.md 6章)。
## デッキ編集・砂時計一覧・CPUのデッキ生成は、いずれもこちらを使う。
static func all_cards() -> Array[CardData]:
	var found: Array[CardData] = []
	for card in _load_all():
		if not card.is_token:
			found.append(card)
	return found


## トークンを含む定義のすべて。**効果から id で引くときだけ使う**
## (SUMMON の出す先はトークンであり、all_cards() には出てこない)。
static func _load_all() -> Array[CardData]:
	if _cache.is_empty():
		load_step(LOAD_ALL_AT_ONCE)
	return _cache


## カードを1コマ `budget_msec` ずつ読み、読み終えたら true を返す。全種を一度に読むと1コマが
## 約0.6秒止まるため、起動の裏読み込み(`Boot`)がスクリプトの後に呼ぶ(Architecture.md 4.0.6節)。
static func load_step(budget_msec: int) -> bool:
	if not _cache.is_empty():
		return true
	if not _scanned:
		_files = _card_files()
		_scanned = true
	var started := Time.get_ticks_msec()
	while _loaded.size() < _files.size() and Time.get_ticks_msec() - started < budget_msec:
		_loaded.append(load(CARDS_DIR + "/" + _files[_loaded.size()]))
	if _loaded.size() < _files.size():
		return false
	for card: CardData in _loaded:
		if card != null:
			_cache.append(card)
	_loaded.clear()
	return true


static func _card_files() -> PackedStringArray:
	var files := PackedStringArray()
	var dir := DirAccess.open(CARDS_DIR)
	if dir == null:
		return files
	var names := dir.get_files()
	names.sort()
	for name in names:
		# エクスポート後は "<name>.tres.remap" として格納されるため、除いた名前で判定する。
		var base := name.trim_suffix(".remap")
		if base.ends_with(".tres"):
			files.append(base)
	return files


## コスト順の比較(GameDesign.md 9章)。**カードを並べる画面はすべてこれを使う。**
## 画面ごとに比較関数を書くと、同じ「コスト順」が場所によって食い違う
## (実際にデッキ編集と墓地の一覧は総量を見ておらず、砂術が先へ出ていた)。
##
## 同コストのときは **砂時計が先・砂術が後**。砂術は総量を持たないため、
## 総量の小さい順で並べると必ず先頭へ来てしまうが、
## **このゲームの中心は砂時計**であり、砂術はそれを助けるものとして後ろへ置く。
static func compare_by_cost(a: CardData, b: CardData) -> bool:
	if a.cost != b.cost:
		return a.cost < b.cost
	if a.is_spell != b.is_spell:
		return b.is_spell
	if a.total_sand != b.total_sand:
		return a.total_sand < b.total_sand
	return a.id < b.id


## コスト順(同コストは砂時計が先 → 総量の小さい順 → id順)。一覧の既定の並び。
static func sorted_by_cost() -> Array[CardData]:
	var cards := all_cards().duplicate()
	cards.sort_custom(compare_by_cost)
	return cards


## プールへ加えられた順。番号は CardData.pool_index が持つ。
static func sorted_by_pool_index() -> Array[CardData]:
	var cards := all_cards().duplicate()
	cards.sort_custom(
		func(a: CardData, b: CardData) -> bool:
			if a.pool_index != b.pool_index:
				return a.pool_index < b.pool_index
			return a.id < b.id
	)
	return cards


## **トークンも引ける**。効果が id で参照するため、集められるカードだけに絞らない。
static func find_by_id(id: String) -> CardData:
	for card in _load_all():
		if card.id == id:
			return card
	return null


## id の配列からデッキ(CardData の配列)を復元する。
static func deck_from_ids(ids: Array) -> Array:
	var cards: Array = []
	for id in ids:
		var card := find_by_id(str(id))
		if card != null:
			cards.append(card)
	return cards


## **戻り値は `Array[String]` にすること。**`OnlineSetup.push_setup()` が
## `Array[String]` を受け取るため、untyped の `Array` を返すと実行時に型が合わず
## 関数ごと呼ばれない(対局のデッキが相手へ届かず、両者が待ち続ける)。
static func ids_from_deck(cards: Array) -> Array[String]:
	var ids: Array[String] = []
	for card in cards:
		ids.append(card.id)
	return ids
