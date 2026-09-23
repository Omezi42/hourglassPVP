extends SceneTree
## 誘導対局の通し確認(GameDesign.md 18章)。対局画面・帯・台本用のCPUを実際に動かし、帯の指示どおりに
## 指し続けて勝ちまで届くかを見る。`tutorial_script_tests.gd` は台本の手を `MatchState` へ直接当てるため、
## 帯の説明を読んでいる間のCPUの待ちのような、進行役どうしの噛み合わせはここでしか拾えない。
## `scripts/ui/` を読むため `run_tests.gd` とは別に `tools/check.sh` から起動する。

const POLL_SECONDS := 0.1
const MAX_POLLS := 600


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var s := CardMatchScreen.new()
	s.size = Vector2(1280, 720)
	root.add_child(s)
	await create_timer(0.3).timeout
	s.start_tutorial_match()
	var t: CardMatchTutorial = s._tutorial
	var st: MatchState = s.state
	for i in MAX_POLLS:
		await create_timer(POLL_SECONDS).timeout
		if st.is_match_over():
			print("tutorial flow passed" if st.hp[s.my_side] > 0 else "tutorial flow FAILED: lost")
			quit()
			return
		if t._showing_done or not t._callout_active.is_empty():
			t._on_next_pressed()
		elif st.mulligan_pending:
			s._mulligan._on_confirm_pressed()
		elif st.current_turn == s.my_side and str(t._current_step().get("side", "")) == "a":
			var a := t._cpu_action_for(st, s.my_side, t._current_step())
			if a.is_empty():
				continue
			s._perform(a)
	print("tutorial flow FAILED: stuck at step ", t._index, " ", t._current_step())
	quit(1)
