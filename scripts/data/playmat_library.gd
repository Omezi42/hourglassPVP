class_name PlaymatLibrary
extends RefCounted
## プレイマットの定義(GameDesign.md 9章・21章)。対局中の卓へ敷く布で、見た目だけを変える。
## `UserProfileLibrary` と同じく、Autoload を使わず static のみで持つ。
##
## **画像ではなくコード描画で作る**(UIクロームと同じ方針)。1件が持つのは
## 地の色・模様の種類・縁の色・箔の色だけで、**種類を足しても配布物が増えない**。
##
## **地は暗く、模様は薄く保つ。**砂時計の絵・台座の輪・数値のバッジのコントラストを
## 落とさないことが、見た目より優先する条件になる(GameDesign.md 9章)。

## 模様の種類。**描き方はこの enum の数だけ**にして、種類ごとに描画を書き起こさない。
enum Weave {
	## 砂紋。中央から広がる弧。
	RIPPLE,
	## 織り。斜めの格子。
	LATTICE,
	## 石畳。段ごとに半分ずらした矩形。
	MASONRY,
	## 星図。散らした点と、それを結ぶ細い線。
	STARS,
	## 唐草。左右対称に巻いた蔓。
	SCROLL,
}

const DEFAULT_ID := "sand_sea"
## CPU戦で相手側へ敷くマット。プレイヤーが買えるものとは別に持つ。
const CPU_ID := "workshop"

## 価格の段(GameDesign.md 21章)。**桁で分ける**。
const PRICE_STANDARD := 1500
const PRICE_DELUXE := 3000

## 1件 = 地 / 模様 / 縁 / 箔 / 隅飾りの有無。
## `price` が 0 のものは売り物ではない(既定のマットとCPU用)。
const MATS: Dictionary = {
	"sand_sea":
	{
		"name": "砂の海",
		"base": Color(0.115, 0.088, 0.062),
		"edge": Color(0.52, 0.40, 0.22),
		"weave": Weave.RIPPLE,
		"foil": Color(0.86, 0.68, 0.34),
		"corners": false,
		"price": 0,
	},
	"workshop":
	{
		"name": "工房の帆布",
		"base": Color(0.098, 0.082, 0.070),
		"edge": Color(0.40, 0.35, 0.26),
		"weave": Weave.LATTICE,
		"foil": Color(0.66, 0.58, 0.40),
		"corners": false,
		"price": 0,
	},
	"indigo":
	{
		"name": "藍染の織",
		"base": Color(0.062, 0.078, 0.125),
		"edge": Color(0.30, 0.42, 0.66),
		"weave": Weave.LATTICE,
		"foil": Color(0.56, 0.74, 0.98),
		"corners": false,
		"price": PRICE_STANDARD,
	},
	"stone":
	{
		"name": "石畳",
		"base": Color(0.088, 0.090, 0.094),
		"edge": Color(0.44, 0.44, 0.46),
		"weave": Weave.MASONRY,
		"foil": Color(0.78, 0.80, 0.84),
		"corners": false,
		"price": PRICE_STANDARD,
	},
	"moss":
	{
		"name": "苔庭",
		"base": Color(0.058, 0.086, 0.068),
		"edge": Color(0.32, 0.54, 0.36),
		"weave": Weave.RIPPLE,
		"foil": Color(0.62, 0.86, 0.62),
		"corners": false,
		"price": PRICE_STANDARD,
	},
	"star_chart":
	{
		"name": "星図の天鵞絨",
		"base": Color(0.048, 0.052, 0.098),
		"edge": Color(0.62, 0.58, 0.92),
		"weave": Weave.STARS,
		"foil": Color(0.90, 0.88, 1.0),
		"corners": true,
		"price": PRICE_DELUXE,
	},
	"royal":
	{
		"name": "王庭の唐草",
		"base": Color(0.098, 0.048, 0.062),
		"edge": Color(0.78, 0.58, 0.28),
		"weave": Weave.SCROLL,
		"foil": Color(1.0, 0.86, 0.52),
		"corners": true,
		"price": PRICE_DELUXE,
	},
}


static func get_mat(mat_id: String) -> Dictionary:
	return MATS.get(mat_id, MATS[DEFAULT_ID])


static func display_name(mat_id: String) -> String:
	return String(get_mat(mat_id)["name"])


static func price(mat_id: String) -> int:
	return int(get_mat(mat_id).get("price", 0))


static func has(mat_id: String) -> bool:
	return MATS.has(mat_id)


## ショップへ並ぶもの(GameDesign.md 21章)。**値の付いているものだけ**。
## 既定のマットとCPU用は初期解放/非売品なので、規則そのもので外れる。
static func purchasable_ids() -> Array[String]:
	var ids: Array[String] = []
	for mat_id in MATS:
		if int(MATS[mat_id].get("price", 0)) > 0:
			ids.append(String(mat_id))
	return ids
