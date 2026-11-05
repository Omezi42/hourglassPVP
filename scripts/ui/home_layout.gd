class_name HomeLayout
extends RefCounted
## ホームの札の位置(GameDesign.md 9章)。上段 = 左ミッション / 中央「対戦する」/ 右ソロモード、
## 下段 = デッキ編集・砂時計図鑑・ショップの横長の札3つ。ヘッダーの左右の端もここで決める。
## **位置はここ1か所で決める。**`HomeScreen`(ヘッダー・ミッション)・`BattleTab`(対戦・ソロ)・
## `DeckTab`(下段)が別々に持つと、片方だけ直したときに幅や端が食い違う。

const LEFT := 40.0
const WIDTH := 1200.0
## ヘッダー(アカウント帯)の下端から少し空けた位置。
const TOP := 128.0
const GAP := 20.0
const SIDE_WIDTH := 300.0
const UPPER_HEIGHT := 412.0
const LOWER_HEIGHT := 108.0
const COLLECT_COUNT := 3
## 札の下に通信待ち・デッキ不足の文言を出す行(9章)。
const STATUS_HEIGHT := 36.0
## ヘッダーの部品(名札・残高・ルールブック・メニュー)の上端と背丈。すべて同じ背丈に揃える。
const HEADER_TOP := 18.0
const HEADER_HEIGHT := 72.0

## 中央「対戦する」の中の3段(上から 台座の砂時計 / 段位の帯 / ボタン)。
const BATTLE_BUTTON_SIZE := Vector2(380, 84)
const RANK_PLATE_SIZE := Vector2(500, 64)
const CENTER_GAP := 10.0
const PORTRAIT_BATTLE_BUTTON_SIZE := Vector2(460, 100)
const PORTRAIT_RANK_PLATE_SIZE := Vector2(640, 76)

## 縦画面。ヘッダーとその下の日曜の知らせの行を避ける。
const PORTRAIT_LEFT := 24.0
const PORTRAIT_WIDTH := 672.0
const PORTRAIT_TOP := 152.0
const PORTRAIT_GAP := 16.0
const PORTRAIT_BATTLE_HEIGHT := 440.0
const PORTRAIT_MIDDLE_HEIGHT := 420.0
const PORTRAIT_COLLECT_HEIGHT := 184.0
const PORTRAIT_STATUS_HEIGHT := 36.0
const PORTRAIT_HEADER_HEIGHT := 84.0


static func header_margin(portrait: bool) -> float:
	return PORTRAIT_LEFT if portrait else LEFT


static func header_height(portrait: bool) -> float:
	return PORTRAIT_HEADER_HEIGHT if portrait else HEADER_HEIGHT


static func battle_rect(portrait: bool) -> Rect2:
	if portrait:
		return Rect2(PORTRAIT_LEFT, PORTRAIT_TOP, PORTRAIT_WIDTH, PORTRAIT_BATTLE_HEIGHT)
	var center_width := WIDTH - (SIDE_WIDTH + GAP) * 2.0
	return Rect2(LEFT + SIDE_WIDTH + GAP, TOP, center_width, UPPER_HEIGHT)


static func battle_button_rect(portrait: bool) -> Rect2:
	var area := battle_rect(portrait)
	var button := PORTRAIT_BATTLE_BUTTON_SIZE if portrait else BATTLE_BUTTON_SIZE
	return Rect2(Vector2(area.get_center().x - button.x * 0.5, area.end.y - button.y), button)


static func rank_plate_rect(portrait: bool) -> Rect2:
	var plate := PORTRAIT_RANK_PLATE_SIZE if portrait else RANK_PLATE_SIZE
	var bottom := battle_button_rect(portrait).position.y - CENTER_GAP
	return Rect2(
		Vector2(battle_rect(portrait).get_center().x - plate.x * 0.5, bottom - plate.y), plate
	)


static func hourglass_stand_rect(portrait: bool) -> Rect2:
	var area := battle_rect(portrait)
	var bottom := rank_plate_rect(portrait).position.y - CENTER_GAP
	return Rect2(area.position, Vector2(area.size.x, bottom - area.position.y))


static func mission_rect(portrait: bool) -> Rect2:
	if portrait:
		return _portrait_middle_rect(0)
	return Rect2(LEFT, TOP, SIDE_WIDTH, UPPER_HEIGHT)


static func solo_rect(portrait: bool) -> Rect2:
	if portrait:
		return _portrait_middle_rect(1)
	return Rect2(LEFT + WIDTH - SIDE_WIDTH, TOP, SIDE_WIDTH, UPPER_HEIGHT)


## 下段の横長の札(縦画面でも横1列)。
static func collect_rect(index: int, portrait: bool) -> Rect2:
	var left := PORTRAIT_LEFT if portrait else LEFT
	var total := PORTRAIT_WIDTH if portrait else WIDTH
	var gap := PORTRAIT_GAP if portrait else GAP
	var top := _portrait_middle_rect(0).end.y + gap if portrait else TOP + UPPER_HEIGHT + gap
	var width := (total - gap * float(COLLECT_COUNT - 1)) / float(COLLECT_COUNT)
	var height := PORTRAIT_COLLECT_HEIGHT if portrait else LOWER_HEIGHT
	return Rect2(left + (width + gap) * float(index), top, width, height)


static func status_rect(portrait: bool) -> Rect2:
	var gap := PORTRAIT_GAP if portrait else GAP
	var top := collect_rect(0, portrait).end.y + gap * 0.25
	if portrait:
		return Rect2(PORTRAIT_LEFT, top, PORTRAIT_WIDTH, PORTRAIT_STATUS_HEIGHT)
	return Rect2(LEFT, top, WIDTH, STATUS_HEIGHT)


## 縦の中段(ミッションとソロモードを左右に)。
static func _portrait_middle_rect(index: int) -> Rect2:
	var top := PORTRAIT_TOP + PORTRAIT_BATTLE_HEIGHT + PORTRAIT_GAP
	var width := (PORTRAIT_WIDTH - PORTRAIT_GAP) * 0.5
	return Rect2(
		PORTRAIT_LEFT + (width + PORTRAIT_GAP) * float(index), top, width, PORTRAIT_MIDDLE_HEIGHT
	)
