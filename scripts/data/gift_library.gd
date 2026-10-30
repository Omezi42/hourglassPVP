class_name GiftLibrary
extends RefCounted
## 配っているプレゼントの一覧(GameDesign.md 33章 / Architecture.md 10.22節)。
## 受け取ったかどうかは `players/{uid}.claimed_gifts`(`GiftService` が書く)を読む。

const GIFTS_DIR := "res://data/gifts"
const FIELD_CLAIMED := "claimed_gifts"

static var _cache: Array[GiftData] = []


static func all() -> Array[GiftData]:
	if not _cache.is_empty():
		return _cache
	var dir := DirAccess.open(GIFTS_DIR)
	if dir == null:
		return _cache
	var names := dir.get_files()
	names.sort()
	for name in names:
		# エクスポート後は "<name>.tres.remap" として格納される(Architecture.md 5章)。
		var base := name.trim_suffix(".remap")
		if not base.ends_with(".tres"):
			continue
		var gift: GiftData = load(GIFTS_DIR + "/" + base)
		if gift != null:
			_cache.append(gift)
	return _cache


static func is_claimed(gift: GiftData) -> bool:
	for entry in AccountService.profile_value(FIELD_CLAIMED, []):
		if str(entry) == gift.id:
			return true
	return false


## 画面に出すもの。受け取れるもの → 受け取り済みの順。期限を過ぎた未受け取りの品は出さない。
static func listed(today: String) -> Array[GiftData]:
	var open: Array[GiftData] = []
	var claimed: Array[GiftData] = []
	for gift in all():
		if is_claimed(gift):
			claimed.append(gift)
		elif not gift.expired(today):
			open.append(gift)
	return open + claimed


static func unclaimed_count(today: String) -> int:
	var count := 0
	for gift in listed(today):
		if not is_claimed(gift):
			count += 1
	return count
