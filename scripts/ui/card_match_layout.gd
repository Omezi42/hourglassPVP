class_name CardMatchLayout
extends RefCounted
## 対局画面の座標の組(GameDesign.md 9章「対局画面」「縦の対局画面」/ Architecture.md 4.7節)。
## 横(1280x720)と縦(720x1280)の2組を持ち、`CardMatchArrange` がいまの組で部品を置き直す。
## 対局画面への参照を持たない描画部品(下地・吊りランプ・行動の列の地・固有演出)は `current()` を読む。

const CARD_GAP := 12.0
const HAND_GAP := 8.0
## 相手の場6枠だけをわずかに縮小して奥行きを出す。
const FOE_ROW_SCALE := 0.92
## 反転ボタンは選んだ駒のすぐ下へ出す(GameDesign.md 9章)。
const FLIP_BUTTON_SIZE := Vector2(104, 34)
const FLIP_BUTTON_OVERLAP := 3.0

const PORTRAIT_SIDE := 10.0
## 縦の文字は720幅の基準で本文24px・小さい見出し20pxを目安にする(GameDesign.md 9章「縦画面」)。
## 部品ごとの倍率はその目安から決めている。
const PORTRAIT_BAR_SCALE := 1.5
const PORTRAIT_PIECE_SCALE := 0.88
const PORTRAIT_STAT_SCALE := 1.4
const PORTRAIT_HISTORY_SCALE := 1.3
const PORTRAIT_HISTORY_TILES := 3
const PORTRAIT_HAND_HEIGHT := 262.0
## 手札の札は重ねた扇にして大きく見せる。
const PORTRAIT_HAND_SCALE := 1.35
const PORTRAIT_DETAIL_SCALE := 1.6
## 駒の下の名前とキーワード。
const PORTRAIT_LABEL_SCALE := 1.65
## 丸いボタン(反転権・コイン・メニュー)と残り回数の粒。
const PORTRAIT_BUTTON_SCALE := 1.4
## 盤面へ重ねる文字の部品(反転ボタン・対象選択の案内・実況・エモート・墓地の一覧・誘導対局の帯)。
const PORTRAIT_TEXT_SCALE := 1.5
## 選んだ手札の札を飛び出させる量。
const PORTRAIT_HAND_SELECT_LIFT := 40.0
const PORTRAIT_TUTORIAL_SCALE := 1.4
const PORTRAIT_TUTORIAL_BAND_HEIGHT := 100.0
## 駒の列を各陣地の中央からレールと反対側へ寄せる量。レールの右端の時計とターン終了に駒のバッジが掛からないように。
const PORTRAIT_ROW_SPREAD := 45.0
## 相手の列はさらに上へ寄せる(レールの右端の時計に駒の下の文字が掛からないように)。
const PORTRAIT_FOE_ROW_SPREAD := 60.0
const PORTRAIT_GAP := 8.0
const PORTRAIT_LOG_FONT_SIZE := 24
const PORTRAIT_LOG_TITLE_FONT_SIZE := 30

static var _landscape: CardMatchLayout
static var _portrait: CardMatchLayout
static var _current: CardMatchLayout

var portrait := false
var screen_size := Vector2.ZERO
## 12枠を載せる卓上。
var table_rect := Rect2()
## 手札の革の面。
var hand_area := Rect2()
## 手札の札の上端。
var hand_top := 0.0
## 手札を両端の下がった扇に並べるか(縦)。
var hand_fan := false
## 情報帯。`bar_scale` を掛ける前の大きさで持つ。
var foe_bar_position := Vector2.ZERO
var own_bar_position := Vector2.ZERO
var bar_size := Vector2.ZERO
var bar_scale := 1.0
var bar_stacked := false
## 盤面の6枠。駒の大きさは `CardView.BOARD_SIZE_PX` のまま、`piece_scale` を中心から掛ける。
var slot_left := 0.0
var slot_pitch := 0.0
var foe_row_top := 0.0
var own_row_top := 0.0
var piece_scale := 1.0
var stat_scale := 1.0
var label_scale := 1.0
## 手札の札と詳細パネルの縮尺。
var hand_scale := 1.0
var detail_scale := 1.0
var button_scale := 1.0
var text_scale := 1.0
var hand_select_lift := 0.0
## 誘導対局の帯(画面座標の位置と、縮尺を掛ける前の大きさ)と縮尺。
var tutorial_band_position := Vector2.ZERO
var tutorial_band_size := Vector2.ZERO
var tutorial_scale := 1.0
## 直前の手の列。
var history_position := Vector2.ZERO
var history_horizontal := false
var history_scale := 1.0
var history_tiles := 0
## 行動のボタンの中心。横では行動の列、縦では卓と自分の情報帯の脇。
var flip_right_center := Vector2.ZERO
var flip_gauge_position := Vector2.ZERO
var coin_center := Vector2.ZERO
var clock_center := Vector2.ZERO
var turn_end_center := Vector2.ZERO
var back_center := Vector2.ZERO
## 横だけ: 行動の列の板・ログ・エモート・投了。縦だけ: メニューのボタン。
var action_panel_rect := Rect2()
var log_center := Vector2.ZERO
var emote_center := Vector2.ZERO
var surrender_center := Vector2.ZERO
var menu_center := Vector2.ZERO
## 縦だけ: 再生の操作の中心(行動の列の代わり)。
var replay_center := Vector2.ZERO
## 詳細パネルを収める範囲の右端(行動の列の手前)。
var play_right := 0.0
## 対象選択の案内・通信待ちの札・バージョンの表示。
var prompt_rect := Rect2()
var waiting_center := Vector2.ZERO
var version_position := Vector2.ZERO
## マリガンの一群(見出し〜確定ボタン)の上端と、札の間隔。
var mulligan_top := 0.0
var mulligan_card_gap := 0.0
## ログのパネルと文字の大きさ(0ならテーマの既定)。
var log_panel_size := Vector2.ZERO
var log_font_size := 0
var log_title_font_size := 0


static func current() -> CardMatchLayout:
	if _current == null:
		_current = landscape()
	return _current


static func choose(is_portrait: bool) -> CardMatchLayout:
	_current = portrait_set() if is_portrait else landscape()
	return _current


static func landscape() -> CardMatchLayout:
	if _landscape == null:
		_landscape = _make_landscape()
	return _landscape


static func portrait_set() -> CardMatchLayout:
	if _portrait == null:
		_portrait = _make_portrait()
	return _portrait


## 盤面の1枠の左上(縮める前の大きさ基準)。
func slot_position(opponent: bool, slot: int) -> Vector2:
	return Vector2(slot_left + slot * slot_pitch, foe_row_top if opponent else own_row_top)


## 卓の中央のレールの高さ。
func rail_y() -> float:
	return table_rect.get_center().y


static func _make_landscape() -> CardMatchLayout:
	var l := CardMatchLayout.new()
	l.screen_size = Vector2(ScreenOrientation.LANDSCAPE_SIZE)
	l.table_rect = Rect2(190, 74, 900, 372)
	l.hand_area = Rect2(190, 520, 900, 166)
	l.hand_top = 528.0
	var margin := 24.0
	var column_x := 1108.0
	var column_center := column_x + 80.0
	l.foe_bar_position = Vector2(margin, 8.0)
	l.own_bar_position = Vector2(margin, 456.0)
	l.bar_size = Vector2(column_x - margin - 24.0, PlayerInfoBar.BAR_HEIGHT)
	var row_width := MatchState.BOARD_SIZE * CardView.BOARD_SIZE_PX.x
	row_width += (MatchState.BOARD_SIZE - 1) * CARD_GAP
	l.slot_left = l.table_rect.position.x + (l.table_rect.size.x - row_width) * 0.5
	l.slot_pitch = CardView.BOARD_SIZE_PX.x + CARD_GAP
	l.foe_row_top = 92.0
	l.own_row_top = 268.0
	l.history_position = Vector2(18.0, 96.0)
	l.history_tiles = CardMatchActionHistory.MAX_TILES
	l.tutorial_band_position = CardMatchTutorial.BAND_RECT.position
	l.tutorial_band_size = CardMatchTutorial.BAND_RECT.size
	l.flip_right_center = Vector2(column_center, ActionColumnLayout.FLIP_RIGHT_Y)
	l.flip_gauge_position = Vector2(
		column_center - FlipRightGauge.GAUGE_SIZE.x * 0.5, ActionColumnLayout.FLIP_GAUGE_TOP
	)
	l.coin_center = Vector2(column_center, ActionColumnLayout.COIN_Y)
	l.clock_center = Vector2(column_center, ActionColumnLayout.CLOCK_Y)
	l.turn_end_center = Vector2(column_center, ActionColumnLayout.TURN_END_Y)
	l.back_center = l.flip_right_center
	l.log_center = Vector2(column_center, ActionColumnLayout.LOG_Y)
	l.emote_center = Vector2(column_center, ActionColumnLayout.EMOTE_Y)
	l.surrender_center = Vector2(column_center, ActionColumnLayout.SURRENDER_Y)
	l.action_panel_rect = Rect2(column_x + 6.0, 10.0, l.screen_size.x - column_x - 22.0, 700.0)
	l.play_right = column_x
	l.prompt_rect = Rect2(column_x, 240, 148, 52)
	l.waiting_center = Vector2(640, 260)
	l.version_position = Vector2(24, 700)
	l.mulligan_top = 110.0
	l.mulligan_card_gap = CardMatchMulligan.CARD_GAP
	l.log_panel_size = CardMatchLog.PANEL_SIZE
	return l


## 上から 相手の情報帯(2段)/ 直前の手(横1列)+メニュー / 卓 / 自分の情報帯(2段)/ 手札(扇)。
static func _make_portrait() -> CardMatchLayout:
	var l := CardMatchLayout.new()
	l.portrait = true
	l.screen_size = Vector2(ScreenOrientation.PORTRAIT_SIZE)
	var side := PORTRAIT_SIDE
	var width := l.screen_size.x - side * 2.0
	l.bar_stacked = true
	l.bar_scale = PORTRAIT_BAR_SCALE
	l.bar_size = Vector2(PlayerInfoBar.STACKED_WIDTH, PlayerInfoBar.STACKED_HEIGHT)
	var bar_height := PlayerInfoBar.STACKED_HEIGHT * PORTRAIT_BAR_SCALE
	l.foe_bar_position = Vector2(side, PORTRAIT_GAP)
	l.history_horizontal = true
	l.history_scale = PORTRAIT_HISTORY_SCALE
	l.history_tiles = PORTRAIT_HISTORY_TILES
	l.history_position = Vector2(side + 2.0, l.foe_bar_position.y + bar_height + 6.0)
	var history_height := CardMatchActionHistory.TILE_SIZE.y * PORTRAIT_HISTORY_SCALE
	var menu_radius := ActionColumnLayout.SMALL_DIAMETER * 0.5
	l.menu_center = Vector2(
		l.screen_size.x - side - menu_radius, l.history_position.y + history_height * 0.5
	)
	l.back_center = l.menu_center
	l.hand_fan = true
	l.hand_area = Rect2(
		side, l.screen_size.y - PORTRAIT_HAND_HEIGHT - side, width, PORTRAIT_HAND_HEIGHT
	)
	l.hand_top = l.hand_area.position.y + 16.0
	l.own_bar_position = Vector2(side, l.hand_area.position.y - PORTRAIT_GAP - bar_height)
	var table_top := l.history_position.y + history_height + side
	l.table_rect = Rect2(side, table_top, width, l.own_bar_position.y - PORTRAIT_GAP - table_top)
	l.piece_scale = PORTRAIT_PIECE_SCALE
	l.stat_scale = PORTRAIT_STAT_SCALE
	l.label_scale = PORTRAIT_LABEL_SCALE
	l.hand_scale = PORTRAIT_HAND_SCALE
	l.detail_scale = PORTRAIT_DETAIL_SCALE
	l.button_scale = PORTRAIT_BUTTON_SCALE
	l.text_scale = PORTRAIT_TEXT_SCALE
	l.hand_select_lift = PORTRAIT_HAND_SELECT_LIFT
	l.tutorial_scale = PORTRAIT_TUTORIAL_SCALE
	l.tutorial_band_position = Vector2(side, l.table_rect.position.y)
	l.tutorial_band_size = Vector2(width / PORTRAIT_TUTORIAL_SCALE, PORTRAIT_TUTORIAL_BAND_HEIGHT)
	l.slot_pitch = (width - side * 2.0) / float(MatchState.BOARD_SIZE)
	var half_piece := CardView.BOARD_SIZE_PX * 0.5
	l.slot_left = side * 2.0 + l.slot_pitch * 0.5 - half_piece.x
	var quarter := l.table_rect.size.y * 0.25
	l.foe_row_top = l.table_rect.position.y + quarter - PORTRAIT_FOE_ROW_SPREAD - half_piece.y
	l.own_row_top = l.table_rect.end.y - quarter + PORTRAIT_ROW_SPREAD - half_piece.y
	var rail := l.rail_y()
	var end_radius := ActionColumnLayout.TURN_END_DIAMETER * 0.5
	l.turn_end_center = Vector2(l.screen_size.x - 2.0 - end_radius, rail)
	l.clock_center = Vector2(
		l.turn_end_center.x, rail - end_radius - ActionColumnLayout.CLOCK_DIAMETER * 0.5
	)
	# 反転権(+残り回数の粒)とコインはレールの左端。右端のターン終了と対にする。
	var flip_radius := ActionColumnLayout.FLIP_RIGHT_DIAMETER * 0.5 * PORTRAIT_BUTTON_SCALE
	l.flip_right_center = Vector2(l.table_rect.position.x + PORTRAIT_GAP + flip_radius, rail)
	var gauge_height := FlipRightGauge.GAUGE_SIZE.y * PORTRAIT_BUTTON_SCALE
	l.flip_gauge_position = Vector2(
		l.flip_right_center.x + flip_radius + PORTRAIT_GAP, rail - gauge_height * 0.5
	)
	var coin_radius := ActionColumnLayout.COIN_DIAMETER * 0.5 * PORTRAIT_BUTTON_SCALE
	l.coin_center = Vector2(
		l.flip_right_center.x + flip_radius + PORTRAIT_GAP + coin_radius,
		rail - gauge_height * 0.5 - PORTRAIT_GAP - coin_radius
	)
	l.play_right = l.screen_size.x
	var gauge_right := l.flip_gauge_position.x + FlipRightGauge.GAUGE_SIZE.x * PORTRAIT_BUTTON_SCALE
	l.replay_center = Vector2((gauge_right + l.turn_end_center.x - end_radius) * 0.5, rail)
	var prompt_size := Vector2(148, 52) * PORTRAIT_TEXT_SCALE
	l.prompt_rect = Rect2(Vector2(l.screen_size.x * 0.5, rail) - prompt_size * 0.5, prompt_size)
	l.waiting_center = l.table_rect.get_center()
	l.version_position = Vector2(side + 6.0, l.screen_size.y - 6.0)
	# 縦は一群を画面のちょうど中央へ。札は最大4枚を1.35倍のまま横1列に収めるため間隔を詰める。
	l.mulligan_top = (l.screen_size.y - CardMatchMulligan.CONTENT_HEIGHT) * 0.5
	l.mulligan_card_gap = 14.0
	l.log_panel_size = Vector2(width - side * 2.0, l.screen_size.y - side * 10.0)
	l.log_font_size = PORTRAIT_LOG_FONT_SIZE
	l.log_title_font_size = PORTRAIT_LOG_TITLE_FONT_SIZE
	return l
