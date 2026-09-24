class_name UnityroomRankingClient
extends RefCounted
## unityroomのランキング機能との連携(GameDesign.md 28章「unityroomランキング連携は
## 要調査」への回答)。
##
## **技術調査の結論**:unityroomのランキングAPIは「そのボードへ今回のスコアを送る」
## だけの一方向のAPIで、読み出し(ランキングを取得する)口は公開されていない。
## したがってこのゲーム内の `CardRankScreen` をunityroom側の値で置き換えることは
## できず、**ゲーム内ランキングを主とし、unityroom側は「そのゲームページへ来た人が
## 見る、公開された副次的なランキング」として追加で送る**運用にする(10.16節の
## 「連携できない場合はゲーム内ランキングのみで運用する」の中間案にあたる)。
##
## **月をまたいで推移する「いまのレート」をそのまま見せるには、unityroom側の
## ゲーム管理画面でそのボードの記録方式を「常に記録」に設定しておく必要がある。**
## 「ハイスコア(降順)」のままだと、シーズンが変わってレートが下がったときに
## 古い最高値が残り続け、実際の段位と食い違う。この設定はこのプロジェクトの
## コードからは変更できず、unityroom側の管理画面で行う。
##
## 署名の手順(HMAC-SHA256・エンドポイント・ヘッダーの組み立て)は、Godot用の
## 非公式unityroom SDK(https://github.com/seisei0809/unityroom-godot-ranking、
## MITライセンス)が公開している実装をそのまま踏襲している。**このクラスでは
## その実装をこのプロジェクトの流儀(鍵をInspectorではなく`data/`のファイルから読む、
## 送信の再試行は`HttpJson`を再利用する)に合わせて書き直している。**
##
## 鍵の置き場所・扱いは `QueueNotifier`(GameDesign.md 11章の募集通知)と同じ:
## `data/unityroom_hmac_key.txt` を `.gitignore` で管理外にし、エクスポートには
## 含める(Web書き出しの時点でクライアントに埋め込まれる以上、この鍵は元々
## 秘匿できないが、公開リポジトリへコミットする理由も無いため同じ扱いにする)。

const KEY_FILE := "res://data/unityroom_hmac_key.txt"
const FALLBACK_ORIGIN := "https://unityroom.com"
const SCORE_PATH := "/gameplay_api/v1/scoreboards/%d/scores"
const TIMEOUT_SECONDS := 8.0
const RETRY_COUNT := 3

## ランクマッチのレートを送るボードNo(GameDesign.md 28章)。unityroomのゲーム管理
## 画面で作成したボードの番号に合わせる。**既定の1のまま使う場合は、そのボードの
## 記録方式を「常に記録」にしておくこと**(クラス冒頭の注記のとおり)。
const RANK_SCOREBOARD_ID := 1


## 送れる状態かどうか(鍵が設定済み・Web書き出しかどうか)。`QueueNotifier.can_send()`
## と同じ形。Web書き出し以外では署名の仕組みそのものが意味を持たないため送らない。
## unityroom以外の配信先では送り先が成立しないため送らない(Architecture.md 4.6節)。
static func can_send() -> bool:
	return OS.has_feature("web") and _hmac_key() != "" and not PortalInfo.is_portal()


## スコアを送る。**応答は待たなくてよい**(失敗しても段位の更新そのものは通常どおり
## 進む。GameDesign.md 11章の募集通知と同じ「裏方の処理」としての扱い)。
static func send_score(
	host: Node, scoreboard_id: int, score: float, on_done: Callable = Callable()
) -> bool:
	if not can_send() or scoreboard_id <= 0:
		if on_done.is_valid():
			on_done.call(false)
		return false

	var path := SCORE_PATH % scoreboard_id
	var unix_time := str(int(Time.get_unix_time_from_system()))
	var score_text := str(score)
	var signature := _sign(_hmac_key(), "POST\n%s\n%s\n%s" % [path, unix_time, score_text])
	if signature == "":
		if on_done.is_valid():
			on_done.call(false)
		return false

	var headers := PackedStringArray(
		[
			"Content-Type: application/x-www-form-urlencoded",
			"X-Unityroom-Signature: %s" % signature,
			"X-Unityroom-Timestamp: %s" % unix_time,
		]
	)
	var body := "score=%s" % score_text.uri_encode()
	var result: Array = await HttpJson.request_with_retry(
		host.get_tree().root,
		_origin() + path,
		HTTPClient.METHOD_POST,
		headers,
		body,
		TIMEOUT_SECONDS,
		RETRY_COUNT
	)
	var ok: bool = int(result[0]) >= 200 and int(result[0]) < 300
	if on_done.is_valid():
		on_done.call(ok)
	return ok


## unityroomはゲームを自分のドメイン配下で配信するため、送り先は「いま開いている
## ページのホスト名」になる(`window.location.hostname`)。取得できない場合だけ
## 既定のドメインへ落ちる。
static func _origin() -> String:
	var hostname := str(JavaScriptBridge.eval("window.location.hostname"))
	if not hostname.is_empty():
		return "https://" + hostname
	return FALLBACK_ORIGIN


## HMAC-SHA256の署名を16進文字列で返す。鍵はbase64、Godot組み込みの`HMACContext`
## だけで計算でき外部ライブラリを要らない。
static func _sign(key_text: String, source: String) -> String:
	var key_bytes := Marshalls.base64_to_raw(key_text)
	if key_bytes.is_empty():
		return ""
	var hmac := HMACContext.new()
	if hmac.start(HashingContext.HASH_SHA256, key_bytes) != OK:
		return ""
	if hmac.update(source.to_utf8_buffer()) != OK:
		return ""
	return hmac.finish().hex_encode()


static func _hmac_key() -> String:
	if not FileAccess.file_exists(KEY_FILE):
		return ""
	var file := FileAccess.open(KEY_FILE, FileAccess.READ)
	if file == null:
		return ""
	return file.get_as_text().strip_edges()
