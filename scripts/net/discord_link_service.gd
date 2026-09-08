class_name DiscordLinkService
extends RefCounted
## Discordアカウントとゲーム内アカウントを結びつけるための連携コード(GameDesign.md 26章)。
## `DeckCodeService` と同じ「8桁の数字を引換券として預ける」方式。
##
## 実際の紐付け(`discord_links` への書き込み)は Discord Bot 側(`/link` コマンド)が
## 行うため、ここが持つのは発行だけでよい。

const COLLECTION := "discord_link_codes"
const CODE_LENGTH := 8
## 番号が埋まっていたときに引き直す回数(DeckCodeServiceと同じ)。
const ISSUE_RETRY_COUNT := 5


## 自分のuidを預けて連携コードを返す。失敗したら空文字を返す。
static func publish_code(client: FirestoreClient, uid: String) -> String:
	if uid.is_empty():
		return ""
	for _attempt in range(ISSUE_RETRY_COUNT):
		var code := _random_code()
		var created: bool = await client.create_document(
			_doc_path(code), {"uid": uid, "created_at": Time.get_unix_time_from_system()}
		)
		if created:
			return code
	return ""


static func _random_code() -> String:
	var code := ""
	for _i in range(CODE_LENGTH):
		code += str(randi() % 10)
	return code


static func _doc_path(code: String) -> String:
	return "%s/%s" % [COLLECTION, code]
