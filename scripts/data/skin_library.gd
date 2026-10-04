class_name SkinLibrary
extends RefCounted
## カードスキンの定義(GameDesign.md 31章、Architecture.md 10.19節)。`PlaymatLibrary` と同じく、
## Autoload を使わず static のみで持つ。
##
## スキンは**そのカード1枚だけの固有の絵**であり、色違いでは作らない(31章)。
## 絵は `ART_DIR/{skin_id}/` に3状態を置き、**読む口はこの `texture()` だけに閉じる**——
## 枚数が増えて実行時に取りに行く方式へ移すとき、出どころを1箇所で切り替えられるようにするため。

const ART_DIR := "res://assets/hourglasses/skins"
## `HourglassArt.State` の並びに対応するファイル名。
const STATE_FILES: Array[String] = ["state_upright", "state_falling", "state_fallen"]
## 1枚あたりの価格の目安(GameDesign.md 31章)。アイコン・エモートより高く、マットより安い。
const PRICE_STANDARD := 500

## 1件 = 対象のカードid / 表示名 / 手札の窓の光だまりの色 / 価格。
const SKINS: Dictionary = {
	"sword_holy":
	{
		"card_id": "sword",
		"name": "聖剣",
		"accent": Color(0.98, 0.86, 0.52),
		"price": PRICE_STANDARD,
	},
}

static var _textures: Dictionary = {}
static var _available: Array[String] = []
static var _available_ready := false


## 売り物として並ぶスキン。**3状態の絵が揃っているものだけ**——定義だけ先に入って絵が
## まだ届いていないスキンを、空の見本のまま売らないため。配布物の中身は起動中に変わらないので1度だけ調べる。
static func all() -> Array[String]:
	if not _available_ready:
		_available_ready = true
		for skin_id in SKINS:
			if has_art(String(skin_id)):
				_available.append(String(skin_id))
	return _available


static func has(skin_id: String) -> bool:
	return SKINS.has(skin_id)


static func card_id(skin_id: String) -> String:
	return String(SKINS.get(skin_id, {}).get("card_id", ""))


static func display_name(skin_id: String) -> String:
	return String(SKINS.get(skin_id, {}).get("name", ""))


static func price(skin_id: String) -> int:
	return int(SKINS.get(skin_id, {}).get("price", 0))


static func accent_color(skin_id: String) -> Color:
	return SKINS.get(skin_id, {}).get("accent", HourglassArt.MASTER_SAND)


## そのカードを対象にするスキン。1枚のカードに複数のスキンは持たせない(図鑑のON/OFFが1つで済む)。
static func skin_for_card(p_card_id: String) -> String:
	for skin_id in all():
		if card_id(skin_id) == p_card_id:
			return skin_id
	return ""


static func has_art(skin_id: String) -> bool:
	for state in STATE_FILES.size():
		if not ResourceLoader.exists(_path(skin_id, state)):
			return false
	return true


## スキンの絵の1状態。**所有・ON/OFFを見ない**(ショップの見本はここを直に読む)。
static func texture(skin_id: String, state: int) -> Texture2D:
	var key := "%s|%d" % [skin_id, state]
	if _textures.has(key):
		return _textures[key]
	var path := _path(skin_id, state)
	var found: Texture2D = load(path) if ResourceLoader.exists(path) else null
	_textures[key] = found
	return found


static func _path(skin_id: String, state: int) -> String:
	return "%s/%s/%s.png" % [ART_DIR, skin_id, STATE_FILES[state]]
