class_name CardMatchReset
extends RefCounted
## 前の対局の名残を落としてから新しい対局へ入る(Architecture.md 4.0節)。結果パネル・ログ・選択・
## タイマー・通信・棋譜はいずれも画面が使い回されるため対局をまたいで残り、
## 片付けないと2局目が「対戦終了の表示のまま遊べない」状態になる。
##
## `card_match_screen.gd` が1000行の上限に近いため、ここへ切り出している。
## 切り出した他の進行役と同じく、画面の私設メンバを直に触る。


static func run(screen: CardMatchScreen) -> void:
	# **リプレイと観戦は既定のマット**(棋譜はマットを記録しない。GameDesign.md 9章)。
	# 対局へ入る側がこの後で敷き替える。
	screen._set_playmats(PlaymatLibrary.DEFAULT_ID, PlaymatLibrary.DEFAULT_ID)
	screen._result.visible = false
	screen._log.set_open(false)
	screen._log.clear()
	if screen._history != null:
		screen._history.clear()
	if screen._hand_layout != null:
		screen._hand_layout.reset()
	screen._pile.visible = false
	screen._selection.clear()
	if screen._finale != null:
		screen._finale.reset()
	screen._cpu_timer.stop()
	screen._cpu = null
	screen._cpu_followup = false
	if screen._emote != null:
		screen._emote.close_popup()
	if screen._replay != null:
		screen._replay.stop()
	if screen._online != null:
		# 停止したノードは解放しない(Architecture.md 6.1節)。参照だけを落とす。
		screen._online.stop()
	screen._setup = null
	screen._client = null
	screen._match_id = ""
	screen._clocks.clear()
	if screen._alert != null:
		screen._alert.remaining_seconds = -1.0
		screen._alert.is_my_turn = false
	# 前の対局のHP・マナ・山札の枚数・持ち時間が情報帯に残らないようにする
	# (`reset()` が持ち時間も含めて未初期化の状態へ戻す)。
	screen._own_bar.reset()
	screen._foe_bar.reset()
	screen._cpu_record = {}
	if screen._puzzle != null:
		screen._puzzle.close()
	if screen._solo != null:
		screen._solo.close()
	screen._status.set_waiting("")
	screen._match_start_pending = true
	if screen._mulligan != null:
		screen._mulligan.close()
		screen._mulligan.picking_disabled = false
	if screen._tutorial != null:
		screen._tutorial.reset_for_new_match()
	screen.set_process(true)
	if screen.state != null and is_instance_valid(screen.state):
		screen.state.queue_free()
	screen.state = null
	# **前の対局の盤面をここで消す。**`refresh()` は `state == null` の間ずっと
	# 早期returnするため、これを怠るとオンライン対戦の山札・種の交換を待っている間
	# (数秒〜タイムアウトまで数分かかりうる)、前の対局の駒・手札がそのまま
	# 盤面に残り続ける。「対戦相手を待っています」の文言と実際に動く駒が同時に
	# 見えるという、対局が壊れているようにしか見えない状態になっていた。
	for view in screen._foe_slots + screen._own_slots:
		view.clear()
		view.selected = false
		view.exhausted = false
		view.ready_mark = false
		view.preview_health = -1
		view.preview_dead = false
	for view in screen._hand_views:
		view.clear()
		view.visible = false
	# 行動の列も、次の `refresh()`(`_begin_state()` の中)までは実体の無い
	# 状態を操作させないよう一旦隠す。**「戻る」だけは例外**——設定を待つ間に
	# 中断できる導線が無いと、通信が詰まったときに画面へ閉じ込められる
	# (GameDesign.md 11章「対局が始まる前はいつでも中断してホームへ戻れる」)。
	# ここでは表示させず、オンライン対戦の開始処理(`CardMatchOnline`)が
	# 待機に入る直前に明示的に出す。
	screen._end_turn_button.visible = false
	screen._coin_button.visible = false
	screen._log_button.visible = false
	screen._surrender_button.visible = false
	screen._flip_button.visible = false
	screen._back_button.visible = false
	# エモートボタン・打点アシストはいずれも既定で可視のまま作られ、通常は毎回の
	# `refresh()` が `state == null` を考慮して隠す。だが `refresh()` 自体が
	# `state == null` の間は早期returnするため、その経路を借りずここで直接呼ぶ。
	if screen._emote != null:
		screen._emote.refresh()
	if screen._damage_assist != null:
		screen._damage_assist.sync()
