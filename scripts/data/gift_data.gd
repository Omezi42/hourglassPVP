class_name GiftData
extends Resource
## 運営から全員へ配るプレゼント1件(GameDesign.md 33章)。`data/gifts/{id}.tres`。
## 1件足すのは `.tres` を1個置くだけで済む。

enum Kind { CARD_SET, CURRENCY }
## 届く人。enum は末尾にだけ足す(保存済みの `.tres` が整数で持つ)。
enum Audience { EVERYONE, SKIN_BUYERS }

@export var id: String = ""
@export var title: String = ""
## 説明1行。`{count}` は `SKIN_BUYERS` の枚数に差し込まれる(`GiftLibrary.description_for()`)。
@export var description: String = ""
@export var kind: Kind = Kind.CARD_SET
## `CARD_SET` のとき、渡すカードセット(`CardSetLibrary` の価格0のセット)。
@export var set_id: String = ""
## `CURRENCY` のとき、渡す砂金。
@export var amount: int = 0
## 日本時間の「YYYY-MM-DD」。その日まで受け取れる。空なら期限なし。
@export var expires: String = ""
## `SKIN_BUYERS` は廃止したカードスキンを持つアカウントだけに出し、`amount` は1枚あたりになる。
@export var audience: Audience = Audience.EVERYONE


func expired(today: String) -> bool:
	return not expires.is_empty() and today > expires
