class_name CardMatchSound
extends RefCounted
## 対局中の効果音(GameDesign.md 9章)。「カードを出す」「反転」「攻撃(相打ち)」
## 「被弾」「決着」の5種を、`MatchState` のシグナルだけを見て鳴らす。
##
## **画面側の操作ではなく盤面の変化を起点にする。**自分の操作・CPUの手・オンラインで
## 届いた手・リプレイの再生はいずれも `MatchAction.apply()` を通って同じシグナルを出すため、
## ここ1箇所に置けば経路ごとに鳴らし忘れる余地が消える。
##
## **攻撃の演出中は、当たる瞬間まで音を持ち越す**(`CardMatchStrike` が砂の飛散を
## 持ち越すのと同じ理由)。解決と同時に鳴らすと、駒がまだ渡っている最中に
## 衝突音だけが先に鳴り、因果が逆に聞こえる。

var _screen: CardMatchScreen
## 攻撃の演出中に預かった音。当たった瞬間にまとめて鳴らす。
var _held: Array[SoundBank.Sfx] = []
## 直前のHP。`hp_changed` は新しい値しか渡さないため、減ったかどうかをここで見る。
var _hp: Dictionary = {}


func _init(screen: CardMatchScreen) -> void:
	_screen = screen


## `start_match()` の**後**に張る。配り始めの初期化までは鳴らさない。
func watch(state: MatchState) -> void:
	_hp = {
		MatchState.Side.A: int(state.hp[MatchState.Side.A]),
		MatchState.Side.B: int(state.hp[MatchState.Side.B]),
	}
	state.unit_played.connect(_on_unit_played)
	state.spell_cast.connect(_on_spell_cast)
	state.unit_flipped.connect(_on_unit_flipped)
	state.attack_performed.connect(_on_attack_performed)
	state.hp_changed.connect(_on_hp_changed)
	state.match_ended.connect(_on_match_ended)


## 攻撃が当たった瞬間。`CardMatchStrike` から呼ぶ。
func flush() -> void:
	for sfx in _held:
		SoundBank.play(sfx)
	_held.clear()


func _play(sfx: SoundBank.Sfx) -> void:
	if _screen.strike_busy():
		if not _held.has(sfx):
			_held.append(sfx)
		return
	SoundBank.play(sfx)


func _on_unit_played(_side: int, _slot: int) -> void:
	_play(SoundBank.Sfx.MOVE)


## 砂術も「カードを使った」音を鳴らす。盤面へ置く音と分けるほどの違いが無く、
## 効果そのものの音(被弾・破壊)は効果の側から鳴るため。
func _on_spell_cast(_side: int, _card: CardData) -> void:
	_play(SoundBank.Sfx.MOVE)


func _on_unit_flipped(_side: int, _slot: int) -> void:
	_play(SoundBank.Sfx.FLIP)


## 砂時計どうしの攻撃だけを「相打ち」の音にする。本体を殴った場合は
## 被弾(HPの減り)の側で鳴るため、ここでは鳴らさない。
func _on_attack_performed(_side: int, _slot: int, target_slot: int) -> void:
	if target_slot >= 0:
		_play(SoundBank.Sfx.SWAP)


func _on_hp_changed(side: int, new_hp: int) -> void:
	var previous: int = int(_hp.get(side, new_hp))
	_hp[side] = new_hp
	if new_hp < previous:
		_play(SoundBank.Sfx.DAMAGE)


## 決着では**BGMを止めて短いジングルへ切り替える**(GameDesign.md 9章)。
## 結果パネルは数秒しか出ないため、数分あるクラシックを流し続けても冒頭しか聞かれない。
## 再生モードは結果パネルを出さないため、曲も止めない。
func _on_match_ended(winner: int) -> void:
	flush()
	if not _screen.interactive:
		return
	MusicPlayer.stop()
	var won: bool = winner == _screen.my_side
	SoundBank.play(SoundBank.Sfx.RESULT_WIN if won else SoundBank.Sfx.RESULT_LOSE)
