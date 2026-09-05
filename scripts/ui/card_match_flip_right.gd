class_name CardMatchFlipRight
extends RefCounted
## 反転権(GameDesign.md 2章)。場に出ている砂時計を敵味方問わず反転できる特殊な
## 行動回数。通常の反転(1体1ターン1回・出したターンは不可)を無視し、マナも不要。
## 先手・後手で総回数が異なり、手番差の補正を狙う。
##
## `card_match_screen.gd` が1000行の上限に達しているため切り出した
## (`CardMatchSpell` 等と同じ流儀)。ボタンの生成・対象選択・適用をこの1箇所へ集める。

var _screen: CardMatchScreen
var _button: Button


func _init(screen: CardMatchScreen) -> void:
	_screen = screen
	# 「戻る」ボタンと同じ位置に置く。**両者は同時に見えない**——戻るボタンは
	# 再生・観戦(_interactive == false)だけに出て、反転権は対局中(_interactive == true)
	# だけに出るため、行動の列を再配置せずに済む。
	_button = CardMatchBuild.add_button(screen, "反転権", CardMatchScreen.ACTION_BUTTON_SIZE)
	_button.position = Vector2(CardMatchScreen.ACTION_COLUMN_X, CardMatchScreen.BACK_BUTTON_TOP)
	_button.visible = false
	_button.pressed.connect(_on_pressed)


func _on_pressed() -> void:
	if _screen.selection.is_flip_right():
		_screen.selection.clear()
		_screen.refresh()
		return
	if not _ready_to_use():
		return
	_screen.selection.begin_flip_right()
	_screen.refresh()


## 選ばれた1体へ反転権を使う。**押した枠に駒がいるかだけをここで見る**
## (`MatchState.use_flip_right()` が非公開の内部判定で最終確認する。公開メソッドの
## 数がgdlintの上限に達しているため、コインと同じく戻り値だけで成否を判断させる)。
## 使えない対象(空き枠など)を押した場合は取り消し扱いにする。
func use_at(target_side: int, slot: int) -> void:
	if _screen.state.board[target_side][slot] != null:
		_screen._perform(MatchAction.flip_right(_screen.my_side, target_side, slot))
	_screen.selection.clear()
	_screen._hide_detail()
	_screen.refresh()


func _ready_to_use() -> bool:
	var state: MatchState = _screen.state
	if state == null or state.is_match_over() or state.current_turn != _screen.my_side:
		return false
	return int(state.flip_right_remaining.get(_screen.my_side, 0)) > 0


func refresh() -> void:
	var state: MatchState = _screen.state
	if state == null or not _screen.is_interactive():
		_button.visible = false
		return
	_button.visible = true
	var remaining := int(state.flip_right_remaining.get(_screen.my_side, 0))
	_button.text = "反転権(%d)" % remaining
	_button.disabled = not _screen.selection.is_flip_right() and not _ready_to_use()
