class_name HomeLayout
extends RefCounted
## ホームの3列の位置(GameDesign.md 9章)。左=ソロモード / 中央=バトル / 右=デッキ編集・図鑑・ショップ。
## **列の位置はここ1か所で決める。**`BattleTab`(左と中央)と `DeckTab`(右)が別々に
## 持つと、片方だけ直したときに列の幅や上端が食い違う。

const LEFT := 40.0
const WIDTH := 1200.0
## ヘッダー(アカウント帯)の下端から少し空けた位置。
const TOP := 128.0
const BOTTOM := 664.0
const GAP := 20.0
const COLUMN_COUNT := 3
## 3列の下に通信待ち・デッキ不足の文言を出す行(9章)。
const STATUS_TOP := 672.0
const STATUS_HEIGHT := 36.0

## 縦画面。ヘッダーとその下の日曜の知らせの行を避ける。
const PORTRAIT_LEFT := 24.0
const PORTRAIT_WIDTH := 672.0
const PORTRAIT_TOP := 152.0
const PORTRAIT_GAP := 16.0
const PORTRAIT_BATTLE_HEIGHT := 470.0
const PORTRAIT_SOLO_HEIGHT := 300.0
const PORTRAIT_COLLECT_HEIGHT := 220.0
const PORTRAIT_STATUS_HEIGHT := 40.0


static func column_width() -> float:
	return (WIDTH - GAP * float(COLUMN_COUNT - 1)) / float(COLUMN_COUNT)


static func column_rect(index: int) -> Rect2:
	var width := column_width()
	return Rect2(LEFT + (width + GAP) * float(index), TOP, width, BOTTOM - TOP)


## 右の列を縦3段に割った1段。
static func collect_rect(index: int, count: int) -> Rect2:
	var column := column_rect(COLUMN_COUNT - 1)
	var height := (column.size.y - GAP * float(count - 1)) / float(count)
	return Rect2(
		column.position.x, column.position.y + (height + GAP) * float(index), column.size.x, height
	)


static func status_rect() -> Rect2:
	return Rect2(LEFT, STATUS_TOP, WIDTH, STATUS_HEIGHT)


static func portrait_battle_rect() -> Rect2:
	return Rect2(PORTRAIT_LEFT, PORTRAIT_TOP, PORTRAIT_WIDTH, PORTRAIT_BATTLE_HEIGHT)


static func portrait_solo_rect() -> Rect2:
	var top := portrait_battle_rect().end.y + PORTRAIT_GAP
	return Rect2(PORTRAIT_LEFT, top, PORTRAIT_WIDTH, PORTRAIT_SOLO_HEIGHT)


## 縦では右の列の3つを横1列に並べる。
static func portrait_collect_rect(index: int, count: int) -> Rect2:
	var top := portrait_solo_rect().end.y + PORTRAIT_GAP
	var width := (PORTRAIT_WIDTH - PORTRAIT_GAP * float(count - 1)) / float(count)
	return Rect2(
		PORTRAIT_LEFT + (width + PORTRAIT_GAP) * float(index), top, width, PORTRAIT_COLLECT_HEIGHT
	)


static func portrait_status_rect() -> Rect2:
	var top := portrait_collect_rect(0, 1).end.y + PORTRAIT_GAP
	return Rect2(PORTRAIT_LEFT, top, PORTRAIT_WIDTH, PORTRAIT_STATUS_HEIGHT)
