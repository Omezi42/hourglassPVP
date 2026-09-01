class_name OnlineResume
extends RefCounted
## 進行中のオンライン対戦を覚えておき、切断しても同じ対局へ戻れるようにする
## (GameDesign.md 11章)。`AccountStore` と同じ「Autoloadを使わずstaticで持つ」流儀。
##
## **局面そのものは保存しない。**対局の内容は `matches/{id}` に
## 「両者のデッキ・山札の種・指した手の並び」として残っており、そこから作り直せる
## (リプレイと同じ仕組み)。ここが持つのは、どの対局のどちら側だったかだけ。

const SAVE_PATH := "user://online_match.json"


## time_limit はルームマッチで切れる持ち時間の設定(GameDesign.md 5章)。復帰した対局が
## 途中から持ち時間ありに戻らないよう、側や種別と同じく覚えておく。
static func remember(
	match_id: String, my_side: int, is_room: bool, opponent_uid: String, time_limit: bool = true
) -> void:
	var file := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if file == null:
		return
	(
		file
		. store_string(
			(
				JSON
				. stringify(
					{
						"match_id": match_id,
						"side": my_side,
						"is_room": is_room,
						"opponent_uid": opponent_uid,
						"time_limit": time_limit,
					}
				)
			)
		)
	)
	file.close()


## 覚えている対局。無ければ空の Dictionary。
static func pending() -> Dictionary:
	if not FileAccess.file_exists(SAVE_PATH):
		return {}
	var file := FileAccess.open(SAVE_PATH, FileAccess.READ)
	if file == null:
		return {}
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	file.close()
	if not parsed is Dictionary:
		return {}
	var record: Dictionary = parsed
	return record if record.get("match_id", "") != "" else {}


## 覚えている対局を忘れる。**ファイルは消さず空の記録で上書きする**
## (`user://` のファイルを消す処理を増やさないため)。
static func clear() -> void:
	var file := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if file == null:
		return
	file.store_string(JSON.stringify({}))
	file.close()
