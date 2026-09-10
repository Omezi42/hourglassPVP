class_name MatchSides
extends RefCounted


## 対人戦の先手・後手を五分五分で振り分ける(GameDesign.md 11章)。
##
## **振るのは対局を成立させた側だけ**とし、結果は `matches/{id}` の
## `player_a`(先手)・`player_b`(後手)として1回のcommitで書き込む。両者は書かれた値を
## 読んで自分の側を決めるため、**双方が別々に振って食い違う経路が構造的に生まれない**。
## 先手勝率は五分ではない(GameDesign.md 7章)ので、先に待っていた側・部屋を作った側が
## 常に先手になる形は採らない。
static func assign(uid_x: String, uid_y: String) -> Dictionary:
	if randi() % 2 == 0:
		return {"player_a": uid_x, "player_b": uid_y}
	return {"player_a": uid_y, "player_b": uid_x}
