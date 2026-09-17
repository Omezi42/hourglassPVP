class_name LabModeration
extends RefCounted
## 掲示板〈ラボ〉への投稿の自動チェック(GameDesign.md 29章)。
##
## **自動チェックと開発側の目視確認の2段構え。**ここで弾けるのは単純な禁止語の
## 部分一致だけで、商標・既存カードとの酷似・趣旨のズレのような判定は
## `tools/lab_admin/` の管理ツールで開発側が目視で行う(Architecture.md 10.17節)。

const NAME_MAX_LENGTH := 20
const DESCRIPTION_MAX_LENGTH := 200

## 最低限の語数で始め、運用しながら増やす(GameDesign.md 29章「NGワードの禁止語
## リストを用意する」)。大文字・小文字を区別しない部分一致で見る。
const BANNED_WORDS: Array[String] = [
	"殺す",
	"死ね",
	"レイプ",
	"きんたま",
	"ちんこ",
	"まんこ",
	"fuck",
	"shit",
	"nigger",
]


## 投稿できるかどうかを判定する。通らなければ理由を1行で返す(空文字なら通過)。
static func quick_check(card_name: String, description: String) -> String:
	var name := card_name.strip_edges()
	var desc := description.strip_edges()
	if name.is_empty():
		return "カード名を入力してください。"
	if name.length() > NAME_MAX_LENGTH:
		return "カード名は%d文字までにしてください。" % NAME_MAX_LENGTH
	if desc.is_empty():
		return "モチーフ・効果の説明を入力してください。"
	if desc.length() > DESCRIPTION_MAX_LENGTH:
		return "説明は%d文字までにしてください。" % DESCRIPTION_MAX_LENGTH
	var haystack := (name + "\n" + desc).to_lower()
	for word in BANNED_WORDS:
		if haystack.contains(word.to_lower()):
			return "使用できない語が含まれています。"
	return ""
