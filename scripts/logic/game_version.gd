class_name GameVersion
extends RefCounted
## バージョンとビルドIDを読む唯一の場所(GameDesign.md 11章・Architecture.md 6.4節)。
##
## `version` は人が読む日付方式(`2026.08.29`)で、Discordの募集通知と対局画面に出す。
## `build_id` は**マッチングの突き合わせに使う**もので、`tools/export_web.sh` が
## 書き出しの直前に `project.godot` へUTCの書き出し時刻(`20260829-143052`)を
## 書き込む。**手で更新する値を増やさない**ためにこの形にしている。
##
## ビルドIDは時刻順にそのまま文字列比較できる。「どちらが古いか」が分かるため、
## 弾いたときに「新しい版が公開されています」と「相手が古い版で待っています」を
## 書き分けられる(GameDesign.md 11章)。

const VERSION_SETTING := "application/config/version"
const BUILD_ID_SETTING := "application/config/build_id"
## 書き出しを一度も通していない状態。エディタ実行の初期値であり、
## 書き出した版とはマッチングしない。
const DEV_BUILD_ID := "dev"


## 日付方式のバージョン(`2026.08.29`)。
static func version() -> String:
	return str(ProjectSettings.get_setting(VERSION_SETTING, ""))


## マッチングの突き合わせに使うビルドID。
static func build_id() -> String:
	var id := str(ProjectSettings.get_setting(BUILD_ID_SETTING, DEV_BUILD_ID))
	return id if id != "" else DEV_BUILD_ID


## 同じ対局へ入ってよい相手かどうか。
##
## **空(この機能より前の版)は版違いとして扱う。**盤面が食い違いうるのはまさに
## その組み合わせであり、未設定を「何でも通す」側へ倒すと守りたいケースを素通りさせる。
static func matches_build(other_build_id: String) -> bool:
	return other_build_id != "" and other_build_id == build_id()


## 相手のほうが新しいか(自分が古いか)。ビルドIDは時刻順に比較できる。
##
## **`dev` と空は比較に混ぜない。**`dev` は書き出しを通していない手元の状態で
## 時刻ではなく、文字列として比べると `"d" > "9"` で必ず新しい側になってしまう。
## どちらが古いか分からない場合は false を返し、画面には「相手が古い」ではなく
## 版が違うことだけを伝える側へ倒す。
static func is_newer_than_mine(other_build_id: String) -> bool:
	var mine := build_id()
	if mine == DEV_BUILD_ID or other_build_id == DEV_BUILD_ID or other_build_id == "":
		return false
	return other_build_id > mine


## 画面に出す1行。
static func display() -> String:
	var text := "v%s" % version()
	var id := build_id()
	if id != DEV_BUILD_ID:
		text += " (%s)" % id
	return text
