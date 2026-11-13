class_name RankedWaitLine
extends RefCounted
## ランクマッチの待機中の時計と、待機画面の見出しの下の1行(GameDesign.md 11章)。
## 帯(`RankedWaitBanner`)と待機画面が同じ書式で数える。

const SECONDS_PER_MINUTE := 60
const MSEC_PER_SECOND := 1000
const OTHERS_TEXT := "%s ・ ほかに %d人が待っています"


## 待機を始めた時刻(`Time.get_ticks_msec()`)からの経過秒。
static func elapsed_seconds(started_msec: int) -> int:
	return (Time.get_ticks_msec() - started_msec) / MSEC_PER_SECOND


static func clock(seconds: int) -> String:
	return "%d:%02d" % [seconds / SECONDS_PER_MINUTE, seconds % SECONDS_PER_MINUTE]


## `others` は自分を除く待機人数。0人・読めていない(負)ときは時間だけにする。
static func line(seconds: int, others: int) -> String:
	if others <= 0:
		return clock(seconds)
	return OTHERS_TEXT % [clock(seconds), others]
