class_name HttpJson
extends RefCounted
## HTTPRequestの生成・タイムアウト・一時的失敗のリトライ・JSONのパースをまとめた薄いヘルパー。
## FirebaseAuthとFirestoreClientの両方がこれを経由する(Architecture.md 6.1節)。
##
## HTTPRequest.timeoutの既定値は0(無制限)で、応答が返らない場合は
## `await request_completed`が永久に解決しない。オンライン対戦はサインイン・マッチング・
## 手の送信のすべてがこのawaitの上に乗っているため、タイムアウトを必ず設定する。

const DEFAULT_TIMEOUT := 15.0
const RETRY_COUNT := 3
const RETRY_BASE_DELAY := 0.6


## 1回だけ送信する。戻り値は [code, parsed, text]。
## codeが0以下のときは応答自体が得られなかったこと(送信失敗・タイムアウト・切断)を表す。
static func request(
	host: Node,
	url: String,
	method: HTTPClient.Method,
	headers: PackedStringArray,
	body: String,
	timeout: float = DEFAULT_TIMEOUT
) -> Array:
	var http := HTTPRequest.new()
	http.timeout = timeout
	# Web書き出しでは、ブラウザが Content-Encoding を透過的に展開してから
	# Godotへ渡す。それにも関わらずHTTPRequestは応答ヘッダを見て自前でもう一度
	# 展開しようとするため、stream_peer_gzip.cppで失敗し RESULT_SUCCESS にならない。
	# 画面上は「接続できませんでした」としか見えないため原因を追いにくい。
	# やり取りするJSONはいずれも小さく、圧縮しなくても実害がないので常に無効にする。
	http.accept_gzip = false
	host.add_child(http)
	var send_error := http.request(url, headers, method, body)
	if send_error != OK:
		http.queue_free()
		return [0, null, "request_failed:%d" % send_error]

	var result: Array = await http.request_completed
	http.queue_free()

	var transport: int = result[0]
	var code: int = result[1]
	var text: String = (result[3] as PackedByteArray).get_string_from_utf8()
	if transport != HTTPRequest.RESULT_SUCCESS:
		return [0, null, "transport_error:%d" % transport]
	return [code, JSON.parse_string(text), text]


## 一時的な失敗(応答なし・429・5xx)だけをリトライする。400番台は呼び出し側の判断が
## 要る(認証切れ・前提条件エラー等)ため、ここでは再試行しない。
static func request_with_retry(
	host: Node,
	url: String,
	method: HTTPClient.Method,
	headers: PackedStringArray,
	body: String,
	timeout: float = DEFAULT_TIMEOUT,
	retries: int = RETRY_COUNT
) -> Array:
	var result: Array = [0, null, "not_sent"]
	for attempt in range(retries + 1):
		result = await request(host, url, method, headers, body, timeout)
		if not is_transient(result[0]):
			return result
		if attempt < retries:
			await host.get_tree().create_timer(RETRY_BASE_DELAY * (attempt + 1)).timeout
	return result


## そのステータスコードが「時間を置けば直るかもしれない失敗」かどうか。
static func is_transient(code: int) -> bool:
	return code <= 0 or code == 429 or code >= 500
