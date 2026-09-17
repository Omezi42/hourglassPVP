class_name UserProfileLibrary
extends RefCounted
## ユーザーのアイコン・称号の定義と取得(GameDesign.md 14章、Architecture.md 10.2)。
## `CardLibrary` と同じく、Autoloadを使わず static のみで持つ。

const DEFAULT_ICON_ID := "sand"
const DEFAULT_TITLE_ID := "novice"

const CPU_ICON_ID := "hour"
const CPU_TITLE_ID := "cpu_basic"

const ICONS: Dictionary = {
	"sand":
	{
		"name": "流砂",
		"path": "res://assets/hourglasses/emblems/sand.png",
	},
	"hour":
	{
		"name": "時計",
		"path": "res://assets/hourglasses/emblems/hour.png",
	},
	"crown":
	{
		"name": "王冠",
		"path": "res://assets/hourglasses/emblems/crown.png",
	},
	"shield":
	{
		"name": "大盾",
		"path": "res://assets/hourglasses/emblems/shield.png",
	},
	"sword":
	{
		"name": "宝剣",
		"path": "res://assets/hourglasses/emblems/sword.png",
	},
	"eye":
	{
		"name": "真眼",
		"path": "res://assets/hourglasses/emblems/eye.png",
	},
	"halo":
	{
		"name": "光輪",
		"path": "res://assets/hourglasses/emblems/halo.png",
	},
	"burst":
	{
		"name": "閃光",
		"path": "res://assets/hourglasses/emblems/burst.png",
	},
	"poison":
	{
		"name": "髑髏",
		"path": "res://assets/hourglasses/emblems/poison.png",
	},
	"wheel":
	{
		"name": "歯車",
		"path": "res://assets/hourglasses/emblems/wheel.png",
	},
	"gate":
	{
		"name": "鳥居",
		"path": "res://assets/hourglasses/emblems/gate.png",
	},
	"vamp":
	{
		"name": "蝙蝠",
		"path": "res://assets/hourglasses/emblems/vamp.png",
	},
	"glow":
	{
		"name": "陽光",
		"path": "res://assets/hourglasses/emblems/glow.png",
	},
	"anchor":
	{
		"name": "錨",
		"path": "res://assets/hourglasses/emblems/anchor.png",
	},
	"bloom":
	{
		"name": "大輪",
		"path": "res://assets/hourglasses/emblems/bloom.png",
	},
	"tower":
	{
		"name": "尖塔",
		"path": "res://assets/hourglasses/emblems/tower.png",
	},
	"mascot":
	{
		"name": "すなえる",
		"path": "res://assets/mascot/mascot_avatar.png",
	},
}

## 最初から持っているアイコン(GameDesign.md 14章)。ここに無いものはショップ(21章)で
## 解放する。**この並びから外したidが自動的に売り物になる**ため、アイコンを足すときに
## ショップ側へ書き足す作業は発生しない。
const INITIAL_ICON_IDS: Array[String] = [
	"sand",
	"hour",
	"crown",
	"shield",
	"sword",
	"eye",
	"halo",
	"burst",
]

const TITLES: Dictionary = {
	"none":
	{
		"name": "称号なし",
		"display": "",
	},
	"novice":
	{
		"name": "駆け出し決闘者",
		"display": "駆け出し決闘者",
	},
	"cpu_basic":
	{
		"name": "AI思考体",
		"display": "AI思考体",
	},
	"proposer":
	{
		"name": "発案者",
		"display": "発案者",
	},
	"hakoniwa_ou":
	{
		"name": "箱庭王",
		"display": "箱庭王",
	},
}

## 誰でも選べる称号(GameDesign.md 14章)。これ以外(「発案者」「箱庭王」)は
## `AccountService.owned_titles()` に含まれている人だけが選べる。
const INITIAL_TITLE_IDS: Array[String] = ["novice", "none"]

static var _textures: Dictionary = {}


## 定義されているアイコンすべて。所有しているものだけを出したい画面は
## `AccountService.owned_icon_ids()` を使う(所有はアカウント側の関心のため)。
static func get_available_icon_ids() -> Array:
	return ICONS.keys()


## 誰でも選べる称号だけを返す(初期の2つ)。所有を絞る称号
## (「発案者」「箱庭王」)は `AccountService.owned_titles()` と合わせて画面側が持つ
## (`owned_icon_ids()` が「初期解放 + 購入分」を返すのと同じ形)。
static func get_available_title_ids() -> Array:
	var list: Array = []
	for id in INITIAL_TITLE_IDS:
		list.append(id)
	return list


static func get_icon_name(icon_id: String) -> String:
	var entry: Dictionary = ICONS.get(icon_id, ICONS.get(DEFAULT_ICON_ID, {}))
	return str(entry.get("name", "流砂"))


static func get_icon_texture(icon_id: String) -> Texture2D:
	var resolved_id := icon_id if ICONS.has(icon_id) else DEFAULT_ICON_ID
	if _textures.has(resolved_id):
		return _textures[resolved_id]
	var entry: Dictionary = ICONS.get(resolved_id, {})
	var path: String = entry.get("path", "")
	if path.is_empty() or not ResourceLoader.exists(path):
		return null
	var tex := load(path) as Texture2D
	_textures[resolved_id] = tex
	return tex


static func get_title_name(title_id: String) -> String:
	var entry: Dictionary = TITLES.get(title_id, TITLES.get(DEFAULT_TITLE_ID, {}))
	return str(entry.get("name", "駆け出し決闘者"))


## 対局画面やプレートに表示する称号文字列(「称号なし」は空文字を返す)。
static func get_title_display(title_id: String) -> String:
	var entry: Dictionary = TITLES.get(title_id, TITLES.get(DEFAULT_TITLE_ID, {}))
	return str(entry.get("display", ""))
