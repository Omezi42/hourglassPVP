class_name ActionColumnLayout
extends RefCounted
## 行動の列(GameDesign.md 9章「対局画面の見た目」)の縦の並び。
## 性格ごとに3つの群へまとめ、**間隔は群の中の `GAP_TIGHT` と群の間の `GAP_GROUP` の2種類だけ**にする。
##   手番の外の資源: 反転権(+残り回数の札)/ コイン
##   手番: 持ち時間の時計 / ターン終了
##   対局の外: ログ / エモート / 投了(ターン終了から最も遠い下端)
## 値はいずれも画面座標の中心y。他のクラスは関数の中から読む(const から参照しない)。

const GAP_TIGHT := 10.0
const GAP_GROUP := 32.0
## 操作盤の上端の飾り板の下端 + 余白。
const CONTENT_TOP := 42.0

const FLIP_RIGHT_DIAMETER := 72.0
const FLIP_GAUGE_HEIGHT := 44.0
const COIN_DIAMETER := 48.0
const CLOCK_DIAMETER := 56.0
const TURN_END_DIAMETER := 110.0
## ターン終了を囲む彫り込みの輪の、ボタン半径からの余白。群の中の間隔は輪から測る。
const TURN_END_RING_MARGIN := 12.0
const SMALL_DIAMETER := 56.0

const FLIP_RIGHT_Y := CONTENT_TOP + FLIP_RIGHT_DIAMETER * 0.5
const FLIP_GAUGE_TOP := CONTENT_TOP + FLIP_RIGHT_DIAMETER + GAP_TIGHT
const COIN_Y := FLIP_GAUGE_TOP + FLIP_GAUGE_HEIGHT + GAP_TIGHT + COIN_DIAMETER * 0.5
const TURN_GROUP_TOP := COIN_Y + COIN_DIAMETER * 0.5 + GAP_GROUP
const CLOCK_Y := TURN_GROUP_TOP + CLOCK_DIAMETER * 0.5
const TURN_END_Y := (
	TURN_GROUP_TOP + CLOCK_DIAMETER + GAP_TIGHT + TURN_END_RING_MARGIN + TURN_END_DIAMETER * 0.5
)
const META_GROUP_TOP := TURN_END_Y + TURN_END_DIAMETER * 0.5 + TURN_END_RING_MARGIN + GAP_GROUP
const LOG_Y := META_GROUP_TOP + SMALL_DIAMETER * 0.5
const EMOTE_Y := LOG_Y + SMALL_DIAMETER + GAP_TIGHT
const SURRENDER_Y := EMOTE_Y + SMALL_DIAMETER + GAP_TIGHT
## 群の間の区切り線(群の間の余白の中央)。
const DIVIDER_YS := [TURN_GROUP_TOP - GAP_GROUP * 0.5, META_GROUP_TOP - GAP_GROUP * 0.5]
