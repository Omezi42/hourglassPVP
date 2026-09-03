class_name PuzzleStageData
extends Resource
## リーサルパズル1問ぶんの初期配置(GameDesign.md 24章)。
##
## カードと同じくデータ駆動で持ち、問題を1問足すのは `.tres` を1個作るだけで済ませる。
## **盤面の駒は「id:体力:攻撃力」の文字列**として持つ。Inspector から1行で読めて、
## 総量から導けない値(あらかじめ砂が落ちている状態)をそのまま書けるため。

## 一覧と保存に使う一意の識別子。
@export var id: String = ""
## 一覧に出す題。
@export var title: String = ""
## 問題の狙いを1行で。何を覚えるための問題かを示す。
@export var hint: String = ""
## 一覧の並び。小さいほど前(易しい順)。
@export var order: int = 0
## 相手のHP。これを0にできればクリア。
@export var foe_hp: int = 10
## 自分のHP。表示のためだけに持つ。
@export var own_hp: int = 30
## そのターンに使えるマナ。
@export var mana: int = 0
## 手札のカードid。並べた順に手札へ入る。
@export var hand_ids: Array[String] = []
## 自陣の駒。`"sand:4:1"` = サンドが体力4・攻撃力1。空きは飛ばして詰めて置く。
@export var own_units: Array[String] = []
## 敵陣の駒。書き方は自陣と同じ。
@export var foe_units: Array[String] = []


## `"id:体力:攻撃力"` を分解する。読めない行は空の Dictionary を返す。
static func parse_unit(text: String) -> Dictionary:
	var parts := text.split(":")
	if parts.size() < 3:
		return {}
	var card := CardLibrary.find_by_id(parts[0])
	if card == null:
		return {}
	return {"card": card, "health": int(parts[1]), "attack": int(parts[2])}
