class_name QueueNotifier
extends RefCounted
## 対戦相手の募集をDiscordへ知らせる(GameDesign.md 11章)。
##
## ランダムマッチは同時に遊んでいる人がいなければ成立しない。待機側になったことを
## コミュニティへ流し、いま遊べる人を呼べるようにする。
##
## **WebhookのURLはリポジトリへ置かない**(Architecture.md 6.3節)。
## `data/discord_webhook.txt` を .gitignore で管理外にしたうえで、エクスポートには
## 含める(Godotのエクスポートはgitではなくファイルシステムを見る)。GitHubは
## publicリポジトリに含まれるDiscordのWebhookを検出し、Discord側が自動的に
## 無効化するため、コミットするとこの機能は黙って壊れる。
##
## クライアントへ埋めてよいのはWebhookに限る。Botトークンは絶対に置かない
## (Webhookはそのチャンネルへ投稿する以外に何もできないが、Botトークンは
## サーバーの操作権限を持つため、pckから取り出された時点でサーバーごと失われる)。

const WEBHOOK_FILE := "res://data/discord_webhook.txt"
## 同じプレイヤーの連投だけをまとめる間隔。キャンセルして入り直した場合や
## 再読み込みした場合を想定したもので、全体の頻度を抑えるものではない
const REPEAT_GUARD_SECONDS := 120.0
const TIMEOUT_SECONDS := 8.0
## サーバーのカスタム絵文字(すなえる)。Webhookからは `<:名前:id>` の形でしか出せない
const SUNAERU_EMOJI := "<:sunaeru:1543231545706291312>"

static var _last_sent_at := -REPEAT_GUARD_SECONDS * 2.0


## 送れる状態かどうか(Webhookが設定済みで、連投の間隔も空いている)。
## 実際に送る前に画面へ知らせるため、消費せずに判定できる形で分けている。
static func can_send() -> bool:
	if _webhook_url() == "":
		return false
	return _now() - _last_sent_at >= REPEAT_GUARD_SECONDS


## 応答は待たなくてよい。失敗しても対局は通常どおり続ける(Discordが落ちていても
## ゲームは成立させる)。
static func notify_waiting(host: Node) -> bool:
	var url := _webhook_url()
	if url == "" or not can_send():
		return false
	_last_sent_at = _now()

	var body := (
		JSON
		. stringify(
			{
				"content": build_line(),
				# 誰にもメンションを飛ばさない。気づきたい人はDiscord側の
				# チャンネルごとの通知設定で受け取る(GameDesign.md 11章)
				"allowed_mentions": {"parse": []},
			}
		)
	)
	var result: Array = await HttpJson.request(
		host,
		url,
		HTTPClient.METHOD_POST,
		PackedStringArray(["Content-Type: application/json"]),
		body,
		TIMEOUT_SECONDS
	)
	var code := int(result[0])
	return code >= 200 and code < 300


## 1行だけの知らせ。すなえるが話しているように書く。
##
## 時刻を本文へ持たせているのは、Discordが同じ投稿者の連続したメッセージをまとめて
## しまい、2件目以降の時刻が画面に出ないため。プレイヤーを特定できる情報
## (表示名・ID)は載せない(GameDesign.md 11章)。
##
## 先頭はサーバーのカスタム絵文字。**Webhookからは `:sunaeru:` という書き方が解決
## されない**ため、`<:名前:id>` の形で書く必要がある。絵文字を消したり作り直したり
## するとidが変わり、その文字列がそのまま表示される。
static func build_line() -> String:
	var line := "%s だれかが対戦相手をさがしてるよ！ [ %s ]" % [SUNAERU_EMOJI, Time.get_time_string_from_system()]
	var version := str(ProjectSettings.get_setting("application/config/version", ""))
	if version != "":
		line += " ・ v%s" % version
	return line


static func _now() -> float:
	return Time.get_ticks_msec() / 1000.0


static func _webhook_url() -> String:
	if not FileAccess.file_exists(WEBHOOK_FILE):
		return ""
	var file := FileAccess.open(WEBHOOK_FILE, FileAccess.READ)
	if file == null:
		return ""
	return file.get_as_text().strip_edges()
