class_name SundayEventRules
extends RefCounted
## 日曜イベント(GameDesign.md 15章・25章)の判定。毎週日曜日(JST)のあいだ、
## ランダムマッチの砂金獲得量が2倍になる。サーバー側で正当性検証を行わない
## 既存方針(GameDesign.md 11章)に揃え、クライアントのローカル時刻をそのまま信頼する。

const REWARD_MULTIPLIER := 2
const JST_OFFSET_HOURS := 9
## Time.get_datetime_dict_from_system() の "weekday" は日曜=0。
const SUNDAY_WEEKDAY := 0


## いま(UTC基準のシステム時刻を日本時間へ換算して)日曜日かどうか。
## `at_unix_time` を渡すとその時刻で判定する(テスト用。負値なら現在時刻を使う)。
static func is_active(at_unix_time: float = -1.0) -> bool:
	var unix_time := at_unix_time if at_unix_time >= 0.0 else Time.get_unix_time_from_system()
	var jst_time := unix_time + JST_OFFSET_HOURS * 3600.0
	var dict := Time.get_datetime_dict_from_unix_time(int(jst_time))
	return int(dict.get("weekday", -1)) == SUNDAY_WEEKDAY


## 日本語の1行表示。イベント中でなければ空文字を返す。
static func banner_text(at_unix_time: float = -1.0) -> String:
	if is_active(at_unix_time):
		return "日曜イベント中:ランダムマッチの砂金が%d倍" % REWARD_MULTIPLIER
	return ""
