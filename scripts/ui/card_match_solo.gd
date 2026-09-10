class_name CardMatchSolo
extends RefCounted
## ソロモードの進行(GameDesign.md 27章)。
##
## パズル型は既存の`CardMatchPuzzle`(`_screen.puzzle`)をそのまま使う。ここが扱うのは
## 残り4種(CPU対戦型・特殊ルール型・連戦型・縛り型)で、いずれも「固定デッキ・上級CPU・
## 特殊ルールを適用した対局」という共通の骨格を持つ。`card_match_screen.gd`が1000行の
## 上限に近いため、`CardMatchPuzzle`と同じ`_screen`参照を持つ切り出しにしている
## (Architecture.md 4.0節・10.15節)。

signal finished(cleared: bool)

var _screen: CardMatchScreen
var _panel: CardSoloResult
var _stage: SoloStageData = null
var _config: SoloMatchConfig = null
## 連戦型(GAUNTLET)でいま何戦目か(0始まり)。
var _gauntlet_index := 0
## 連戦型で次の対局へ持ち越すHP。-1なら未設定(初戦)。
var _carried_hp := -1
var _settled := false
var _cleared := false


func _init(screen: CardMatchScreen) -> void:
	_screen = screen
	_panel = CardSoloResult.new()
	_panel.retry_pressed.connect(func() -> void: start(_stage))
	_panel.quit_pressed.connect(func() -> void: finished.emit(_settled and _cleared))
	screen.add_child(_panel)


## いま挑戦中か。終局の受け口が結果パネルを出し分けるのに使う。
func active() -> bool:
	return _stage != null


func stage() -> SoloStageData:
	return _stage


## 1ステージを始める(パズル型以外)。連戦型は複数戦をまたいで内部で回す。
func start(target: SoloStageData) -> void:
	if target == null or target.match_config == null:
		return
	_stage = target
	_config = target.match_config
	_gauntlet_index = 0
	_carried_hp = -1
	_settled = false
	_panel.visible = false
	_begin_battle()


func close() -> void:
	_stage = null
	_config = null
	_settled = false
	_panel.visible = false


## 相手のHPが0になった等、`MatchState.match_ended` から呼ばれる。
func on_match_ended() -> void:
	if _stage == null or _settled:
		return
	var state: MatchState = _screen.state
	var won: bool = state != null and state.winner == _screen.my_side
	if won and _stage.stage_type == SoloStageData.Kind.GAUNTLET:
		_gauntlet_index += 1
		if _gauntlet_index < _config.opponent_count:
			_carried_hp = int(state.hp[_screen.my_side])
			_begin_battle()
			return
	_settle(won)


## 対局を1戦ぶん作る。中身はCPU戦と同じ経路(`_begin_state()`)で、固定デッキ・
## 上級CPU・特殊ルールをそのあとで重ねる(GameDesign.md 27章)。
func _begin_battle() -> void:
	# **`_reset_for_new_match()` は画面の後始末として `close()` を呼び、`_stage`/`_config`
	# を消す。**先に控えて、戻してから使う(`CardMatchPuzzle` が `_begin_state()` のあとで
	# 問題を覚えているのと同じ穴。Architecture.md 10.12節)。
	var stage_kept := _stage
	var config_kept := _config
	_screen._reset_for_new_match()
	_stage = stage_kept
	_config = config_kept
	_screen._cpu = CardCpuStrategy.new()
	_screen._cpu.difficulty = CardCpuStrategy.Difficulty.EXPERT
	_screen._interactive = true
	_screen._match_kind = CurrencyRules.MatchKind.NONE
	_screen.my_side = MatchState.Side.A
	_screen.bar_for(MatchState.Side.A).display_name = AccountService.display_name()
	_screen.bar_for(MatchState.Side.A).icon_id = AccountService.icon_id()
	_screen.bar_for(MatchState.Side.A).title_id = AccountService.title_id()
	_screen.foe_bar.display_name = "CPU"
	_screen.foe_bar.icon_id = UserProfileLibrary.CPU_ICON_ID
	_screen.foe_bar.title_id = UserProfileLibrary.CPU_TITLE_ID
	_screen._set_playmats(AccountService.playmat_id(), PlaymatLibrary.CPU_ID)
	var rng := RandomNumberGenerator.new()
	rng.randomize()
	_screen._begin_state(
		_deck_of(_config.player_deck_ids),
		_deck_of(_config.opponent_deck_ids),
		rng.randi_range(1, 1 << 30)
	)
	_apply_config()
	# `_begin_state()` は自分の呼び出しの中で一度 `refresh()` しているが、その後の
	# `_apply_config()` がHP・盤面を上書きするため、これが無いと差し替え後の
	# 局面(HPの上書き・連戦の持ち越し・初期配置)が次の操作まで画面へ反映されない
	# (`CardMatchPuzzle.start()` が `_apply()` の後で `refresh()` するのと同じ理由)。
	_screen.refresh()


func _deck_of(ids: Array[String]) -> Array:
	var cards: Array = []
	for id in ids:
		var card := CardLibrary.find_by_id(id)
		if card != null:
			cards.append(card)
	return cards


## 対局設定を反映する。**HP・盤面の上書きは新しいAPIを作らず、ルール画面
## (Architecture.md 4.2節)と同じ「差し替え」で行う。**
func _apply_config() -> void:
	var state: MatchState = _screen.state
	var mine: int = _screen.my_side
	var foe: int = MatchState.other_side(mine)
	state.sand_drop_count = _config.sand_drop_count
	state.flip_disabled = _config.flip_disabled
	state.clash_damage_multiplier = _config.clash_damage_multiplier
	state.mana_frozen = _config.mana_frozen
	# **凍結は「常に1のまま」を意味する**(GameDesign.md 27章)。この設定は最初の手番が
	# 始まったあとに掛かるため、まだ手番の来ていない側は最大マナ0のまま凍りつく。
	# 両者へ1を保証して、片側だけ何も出せない対局にならないようにする。
	if _config.mana_frozen:
		for target_side in [mine, foe]:
			state.max_mana[target_side] = maxi(int(state.max_mana[target_side]), 1)
			state.mana[target_side] = int(state.max_mana[target_side])
			state.mana_changed.emit(
				target_side, state.mana[target_side], state.max_mana[target_side]
			)
	if _config.hp_override > 0:
		state.hp[mine] = _config.hp_override
		state.hp[foe] = _config.hp_override
	# 連戦型(GAUNTLET)はHPだけを次の対局へ持ち越す(GameDesign.md 27章)。
	if _carried_hp >= 0:
		state.hp[mine] = _carried_hp
	_place(state, mine, _config.own_board_units)
	_place(state, foe, _config.foe_board_units)
	# **`hp_changed` は出さない。**`_screen.refresh()`(呼び出し元 `_begin_battle()`)が
	# `state.hp` を直接読んで情報帯を更新するため不要な上、`CardMatchSound`/`CardMatchLog`
	# がこの信号を「初期HP24 → 上書き後のHP」の被弾/回復として解釈し、開始直後に
	# 誤った演出とログを出す(連戦型の持ち越しでは実際のHP変化のためなおさら誤読を招く)。
	state.board_changed.emit(mine)
	state.board_changed.emit(foe)
	match _config.win_condition:
		SoloMatchConfig.WinCondition.SURVIVE_TURNS:
			state.turn_started.connect(_on_turn_started_for_survival)
		SoloMatchConfig.WinCondition.DESTROY_ALL_ENEMY_UNITS:
			state.unit_destroyed.connect(_on_unit_destroyed_for_wipe)


## 盤面の初期配置。`PuzzleStageData`と同じ`"id:体力:攻撃力"`の表現を読む。
func _place(state: MatchState, side: int, rows: Array[String]) -> void:
	if rows.is_empty():
		return
	var slots: Array = state.board[side]
	for i in rows.size():
		if i >= MatchState.BOARD_SIZE:
			break
		var parsed := PuzzleStageData.parse_unit(rows[i])
		if parsed.is_empty():
			continue
		var unit := CardInstance.new(parsed["card"])
		unit.health = int(parsed["health"])
		unit.attack = int(parsed["attack"])
		unit.summoned_this_turn = false
		slots[i] = unit


## 指定ターン数を生き残った(GameDesign.md 27章)。**通常のHP0での敗北判定は
## そのまま生かしておく**——生き残る前に自分が倒されたら、既存の経路で普通に負ける。
func _on_turn_started_for_survival(side: int) -> void:
	var state: MatchState = _screen.state
	if state == null or state.is_match_over() or side != _screen.my_side:
		return
	if state.turn_count > _config.survive_turns:
		state.surrender(MatchState.other_side(_screen.my_side))


## 相手の場の砂時計をすべて破壊した(GameDesign.md 27章)。
func _on_unit_destroyed_for_wipe(side: int, _slot: int, _card: CardData) -> void:
	var state: MatchState = _screen.state
	if state == null or state.is_match_over() or side == _screen.my_side:
		return
	if state.units(side).is_empty():
		state.surrender(side)


func _settle(cleared: bool) -> void:
	_settled = true
	_cleared = cleared
	var reward := ""
	if cleared:
		reward = _grant()
	_panel.show_for(cleared, _stage, reward)


## 初回クリアだけ報酬を出す(GameDesign.md 27章)。**通信は待たない**——結果の表示を
## 通信で止めない扱いは、対局の砂金(`CardMatchOutcome`)・パズルの砂金と同じ。
func _grant() -> String:
	return grant_stage_rewards(_stage)


## ステージの報酬を渡す。**パズル型のステージも同じ経路を通す**——パズル型は進行が
## `CardMatchPuzzle` 側にあるが、進捗を `SoloProgress` へ書かないと次のステージが
## 永久に開かない(Architecture.md 10.15節)。そのため static にして両者で共有する。
static func grant_stage_rewards(target: SoloStageData) -> String:
	var uid := ""
	if NetSession.client != null and NetSession.client.auth != null:
		uid = NetSession.client.auth.uid
	if not SoloProgress.mark_cleared(uid, target.id):
		return "このステージはクリア済みです"
	var parts: Array[String] = []
	if target.reward_gold > 0:
		if NetSession.client == null or uid.is_empty():
			AccountStore.add_pending_currency(target.reward_gold)
			parts.append("+%d 砂金(次に接続できたときに反映)" % target.reward_gold)
		else:
			AccountService.grant(NetSession.client, uid, target.reward_gold, false)
			parts.append("+%d 砂金" % target.reward_gold)
	if not target.reward_icon_id.is_empty():
		AccountService.unlock_icon(NetSession.client, uid, target.reward_icon_id)
		parts.append("アイコン「%s」を手に入れました" % UserProfileLibrary.get_icon_name(target.reward_icon_id))
	if not target.reward_card_set_id.is_empty():
		AccountService.unlock_card_set(NetSession.client, uid, target.reward_card_set_id)
		parts.append("%sを手に入れました" % CardSetLibrary.display_name(target.reward_card_set_id))
	return "\n".join(parts)
