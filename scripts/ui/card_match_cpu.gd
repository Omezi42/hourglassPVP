class_name CardMatchCpu
extends RefCounted
## CPU戦の進行(Architecture.md 4.0節)。始め方・棋譜の用意・マリガン・思考の間合い・1手の適用を持つ。
## 何を指すかは `CardCpuStrategy` が決め、ここは「いつ・どう指させるか」だけを持つ。
## 切り出した他の進行役と同じく、画面の私設メンバ(`_cpu` / `_cpu_timer` / `_cpu_record` /
## `_cpu_followup`)を直に触る。

var _screen: CardMatchScreen


func _init(screen: CardMatchScreen) -> void:
	_screen = screen


## `CardMatchScreen.start_cpu_match()` の中身。
func start(
	deck_self: Array,
	deck_foe: Array,
	difficulty: int,
	keep_deck_order: bool,
	tutorial_script: TutorialScriptData
) -> void:
	var s := _screen
	s._reset_for_new_match()
	s._own_deck = deck_self
	if tutorial_script != null:
		s._tutorial.load_script(tutorial_script)
		s._mulligan.picking_disabled = true
		s._cpu = TutorialCpuStrategy.new(s._tutorial)
	else:
		s._cpu = CardCpuStrategy.new()
		s._cpu.difficulty = CardCpuStrategy.resolve_difficulty(difficulty)
	s._interactive = true
	s._match_kind = CurrencyRules.MatchKind.CPU
	s.my_side = MatchState.Side.A
	s._own_bar.display_name = AccountService.display_name()
	s._own_bar.icon_id = AccountService.icon_id()
	s._own_bar.title_id = AccountService.title_id()
	s._foe_bar.display_name = "CPU"
	s._foe_bar.icon_id = UserProfileLibrary.CPU_ICON_ID
	s._foe_bar.title_id = UserProfileLibrary.CPU_TITLE_ID
	s._set_playmats(AccountService.playmat_id(), PlaymatLibrary.CPU_ID)
	# CPU戦もリプレイとして残すため、山札の種を決めてから始める(GameDesign.md 12章)。
	var rng := RandomNumberGenerator.new()
	rng.randomize()
	var seed_value := rng.randi_range(1, 1 << 30)
	s._cpu_record = {
		"deck_a": CardLibrary.ids_from_deck(deck_self),
		"deck_b": CardLibrary.ids_from_deck(deck_foe),
		"seed": seed_value,
		"actions": [],
		"source": "cpu",
	}
	s._keep_deck_order = keep_deck_order
	s._begin_state(deck_self, deck_foe, seed_value, true)
	_start_mulligan()


## CPUのマリガンは先に決めておく。適用の順序は `MatchState` が A → B に固定するため、
## どちらが先に確定しても同じ対局になる。
func _start_mulligan() -> void:
	var s := _screen
	if not s.state.mulligan_pending:
		return
	var foe := MatchState.other_side(s.my_side)
	s._perform(MatchAction.mulligan(foe, s._cpu.choose_mulligan(s.state, foe)))
	s._mulligan.show_hand(
		s.state.hand[s.my_side],
		s.state.first_side == s.my_side,
		s.state.coin_available.get(s.my_side, false)
	)


## 考える間を置いてから指させる。誘導対局では帯の予告文を読める長さまで延びる。
func schedule(delay_scale := 1.0) -> void:
	_screen._cpu_timer.start(
		_screen._tutorial.cpu_delay(CardMatchScreen.CPU_THINK_SECONDS * delay_scale)
	)


## 手番が回ってきた。CPUの番なら考え始める。`opening` は対局開始の幕を出した直後で、
## 幕の長さに合わせて誘導対局の延長をかけない。
func on_turn_started(side: int, opening := false) -> void:
	var s := _screen
	if s._cpu == null or side == s.my_side or s.state.is_match_over():
		return
	if opening:
		s._cpu_timer.start(CardMatchScreen.CPU_THINK_SECONDS)
	else:
		schedule()


## 1手の演出が終わった。同じ手番の続きがあれば短い間で次を指す。
func on_actions_settled() -> void:
	var s := _screen
	if not s._cpu_followup:
		return
	s._cpu_followup = false
	if s._cpu != null and not s.state.is_match_over():
		schedule(0.4)


func take_action() -> void:
	var s := _screen
	if s._cpu == null or s.state.is_match_over():
		return
	var side := s.state.current_turn
	if side == s.my_side:
		return
	var action := s._cpu.choose_action(s.state, side)
	if action.is_empty():
		return
	s._record(action)
	s._strike.capture(action)
	MatchAction.apply(s.state, action)
	# 続けて指すのは演出が終わってから。重ねると駒が2体同時に渡ってしまう。
	s._cpu_followup = action["type"] != "end_turn" and not s.state.is_match_over()
	s._finish_action()


## 同じデッキでもう1局(GameDesign.md 9章)。相手のデッキは13章のとおり毎回ランダムに組む。
func rematch() -> void:
	var rng := RandomNumberGenerator.new()
	rng.randomize()
	_screen.start_cpu_match(_screen._own_deck, CardDeckSave.random_deck(rng))
