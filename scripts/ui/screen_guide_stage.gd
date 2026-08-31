class_name ScreenGuideStage
extends RuleStage
## 「画面の見かた」(GameDesign.md 20章)で見せる1枚の盤面。
##
## **専用の説明図は作らない**(20章)。`RuleStage` が持つ組み立て(情報帯・卓・12枠)を
## そのまま使い、ここでは手札・行動の列・駒の状態(守護 / 硝子 / 出したターン /
## 攻撃済み / まだ動ける / 攻撃の予測)を足すだけにする。対局画面と食い違った時点で
## 誤った予習になるため、絵はすべて `CardView` / `PlayerInfoBar` / `BoardTable` に描かせる。
##
## 項目を選んだときに光らせる場所は、組み立てながら `_regions` へ控える。
## 座標を表として別に持つと、配置を変えたときに黙ってずれる。

## 行動の列。対局画面(`CardMatchScreen`)と同じ並びにする。
const ACTION_GAP := 24.0
const ACTION_SIZE := Vector2(148, 48)
const ACTION_LABELS: Array[String] = ["コイン", "ターン終了", "ログ", "投了"]
const ACTION_STEP := 60.0
const FLIP_SIZE := Vector2(104, 30)
## 手札。対局画面と同じく盤面の真下へ中央で置く。
const HAND_GAP_X := 8.0
const HAND_TOP_GAP := 14.0

## 相手の場。**左の3枚は同じカードで、砂の比だけを変えてある**(絵の3状態を見せるため)。
const FOE_UNITS: Array = [
	{"id": "sand", "health": 5, "attack": 0},
	{"id": "sand", "health": 3, "attack": 2},
	{"id": "sand", "health": 1, "attack": 4},
	{"id": "glass", "health": 4, "attack": 2},
]
## 自分の場。守護・攻撃済み・出したターン・まだ動けるを1体ずつ並べる。
const SELF_UNITS: Array = [
	{"id": "shield", "health": 3, "attack": 1},
	{"id": "drill", "health": 4, "attack": 3},
	{"id": "grain", "health": 3, "attack": 0},
	{"id": "sword", "health": 4, "attack": 2},
]
## 手札に並べるカード。**3枚目はマナが足りない例**として暗く出す。
const HAND_CARDS: Array[String] = ["sand", "dash", "wall"]

var _regions: Dictionary = {}


## 盤面を組み立てる。`RuleStage.show_page()` は使わない(紙芝居のページではないため)。
func build() -> void:
	_rebuild_content()
	var board := _compose_board(SELF_UNITS, FOE_UNITS)
	var natural: Vector2 = board["size"]
	_decorate(board)
	natural.y += HAND_TOP_GAP + CardView.HAND_SIZE_PX.y
	_add_hand(natural)
	natural.x += ACTION_GAP + ACTION_SIZE.x
	_add_actions(board, natural)
	_fit(natural)


## 項目に対応する光らせる場所。`_content` の座標を、拡縮したあとの位置へ移して返す。
func region(key: String) -> Array:
	var found: Array = _regions.get(key, [])
	var mapped: Array = []
	for rect: Rect2 in found:
		mapped.append(
			Rect2(
				_content.position + rect.position * _content.scale.x, rect.size * _content.scale.x
			)
		)
	return mapped


## `RuleStage._rebuild()` はページの指定を要求するため、中身の器だけを作り直す。
func _rebuild_content() -> void:
	if _content != null:
		_content.queue_free()
	_regions.clear()
	_content = Control.new()
	_content.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_content)


func _mark(key: String, rect: Rect2) -> void:
	if not _regions.has(key):
		_regions[key] = []
	_regions[key].append(rect)


func _view_rect(view: CardView) -> Rect2:
	return Rect2(view.position, view.size)


## 駒の状態を仕込む。**対局画面と同じフラグを立てるだけ**にして、見え方の再現はしない。
func _decorate(board: Dictionary) -> void:
	var own: Array = board["rows"][MatchState.Side.A]
	var foe: Array = board["rows"][MatchState.Side.B]
	own[1].exhausted = true
	own[2].unit.summoned_this_turn = true
	own[3].ready_mark = true
	# 攻撃の予測は「この攻撃の後どうなるか」を双方へ出す(GameDesign.md 9章)。
	own[3].preview_health = 2
	foe[0].preview_health = 0
	foe[0].preview_dead = true
	for view: CardView in own + foe:
		view.queue_redraw()

	for side in [MatchState.Side.A, MatchState.Side.B]:
		var bar: PlayerInfoBar = board["bars"][side]
		_mark("bars", Rect2(bar.position, bar.size))
	_mark("board", board["table"])
	_mark("unit", _view_rect(own[3]))
	for i in 3:
		_mark("art", _view_rect(foe[i]))
	_mark("keywords", _view_rect(own[0]))
	_mark("keywords", _view_rect(foe[3]))
	for i in [1, 2, 3]:
		_mark("states", _view_rect(own[i]))
	_mark("preview", _view_rect(own[3]))
	_mark("preview", _view_rect(foe[0]))


## 手札。**場の砂時計とは別の見た目**(枠を持ち、コスト=左上 / 総量=右下)。
func _add_hand(natural: Vector2) -> void:
	var step: float = CardView.HAND_SIZE_PX.x + HAND_GAP_X
	var width: float = step * HAND_CARDS.size() - HAND_GAP_X
	var left: float = (natural.x - width) * 0.5
	var top: float = natural.y - CardView.HAND_SIZE_PX.y
	for i in HAND_CARDS.size():
		var data := CardLibrary.find_by_id(HAND_CARDS[i])
		if data == null:
			continue
		var view := CardView.new()
		view.mode = CardView.Mode.HAND
		_content.add_child(view)
		view.mouse_filter = Control.MOUSE_FILTER_IGNORE
		view.position = Vector2(left + step * i, top)
		view.size = CardView.HAND_SIZE_PX
		# 3枚目だけマナが足りない例にする。
		view.show_card(data, i < HAND_CARDS.size() - 1)
	_mark("hand", Rect2(Vector2(left, top), Vector2(width, CardView.HAND_SIZE_PX.y)))


## 行動の列と、選んだ駒のすぐ下に出る「反転」(GameDesign.md 9章)。
func _add_actions(board: Dictionary, natural: Vector2) -> void:
	var left: float = natural.x - ACTION_SIZE.x
	var top: float = board["table"].position.y
	for i in ACTION_LABELS.size():
		var at := Vector2(left, top + ACTION_STEP * i)
		_add_button(ACTION_LABELS[i], at, ACTION_SIZE)
	_mark(
		"actions",
		Rect2(
			Vector2(left, top),
			Vector2(ACTION_SIZE.x, ACTION_STEP * (ACTION_LABELS.size() - 1) + ACTION_SIZE.y)
		)
	)
	var own: Array = board["rows"][MatchState.Side.A]
	var target: CardView = own[3]
	var flip_at := Vector2(
		target.position.x + (target.size.x - FLIP_SIZE.x) * 0.5,
		target.position.y + target.size.y - 14.0
	)
	_add_button("反転", flip_at, FLIP_SIZE)
	_mark("actions", Rect2(flip_at, FLIP_SIZE))


func _add_button(label: String, at: Vector2, button_size: Vector2) -> void:
	var button := CodedButton.make(label, button_size)
	button.position = at
	# 押せないことを見た目で示す必要はない(盤面ごとクリックを受け付けないため)。
	button.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_content.add_child(button)
