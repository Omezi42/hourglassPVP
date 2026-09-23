class_name TutorialSteps
extends RefCounted
## 誘導対局の8段(GameDesign.md 18章)の定義。`CardMatchTutorial` から切り出した
## データだけのクラス(Architecture.md 4.1.5節「8段へ増えると本体の処理と混ざって
## 読みにくくなるため」)。段の数だけ増減してもここだけ直せばよい。
##
## `event` が空文字の段(2:読むだけ)は、進行を待つ操作が無く「つぎへ」がすぐに押せる。
## `event` が "attack" の段は `target` (`"unit"` / `"face"`) で本体攻撃と駒攻撃を区別する
## (`MatchState.attack_performed` の `target_slot` が -1 かどうかで判定する)。
## `topic` は「説明を読んでいる間に光らせる数字」(GameDesign.md 18章「数字の光」)。

const STEPS: Array[Dictionary] = [
	{
		"event": "mulligan",
		"focus": "mulligan",
		"topic": "",
		"text": "こんにちは、ぼくすなえる! いらないカードは押すと引き直せるよ。決めたら下のボタンを押してね",
		"done": "そのまま始めてもぜんぜんいいんだよ。ここからが対局だよ!",
	},
	{
		"event": "play",
		"focus": "hand",
		"topic": "mana",
		"text": "手札の砂時計を、空いている台座へ出してみてね。左上の数字ぶんマナを使うよ",
		"done": "出したばかりの子はまだ動けないんだ。攻撃も反転も次のターンからだよ",
	},
	{
		"event": "",
		"focus": "",
		"topic": "stats",
		"text": "上に残った砂が体力、下に落ちた砂が攻撃力だよ。出した直後は攻撃力0で動けないんだ",
		"done": "",
	},
	{
		"event": "end_turn",
		"focus": "end_turn",
		"topic": "",
		"text": "つぎは画面右の「ターン終了」を押してみてね",
		"done": "ターンを終えるたびに、砂が1粒ずつ落ちていくんだ",
	},
	{
		"event": "attack",
		"target": "unit",
		"focus": "attack_unit",
		"topic": "",
		"text": "攻撃力がついたら、その子で相手の駒を殴ってみてね",
		"done": "攻撃はおたがいさま。殴った側も相手の攻撃力ぶん削れちゃうんだ",
	},
	{
		"event": "attack",
		"target": "face",
		"focus": "attack_face",
		"topic": "foe_hp",
		"text": "相手のHP帯を押せば、本体を殴れるよ。0にしたら勝ちだよ",
		"done": "相手のHPを削ったよ! 0になったら勝ちだよ",
	},
	{
		"event": "flip",
		"focus": "flip",
		"topic": "",
		"text": "攻撃力が体力を追い越した子がいたら、選んで「反転」を押してみてね",
		"done": "体力と攻撃力が入れ替わったよ。長生きするほど強くなるんだ",
	},
	{
		"event": "flip_right",
		"focus": "flip_right",
		"topic": "flip_right",
		"text": "反転権は相手の駒にも使えるよ。攻撃力の高い子を選んで弱めてみてね",
		"done": "反転権で相手を弱めたよ。残りの回数は少ないから、ここぞの場面で使ってね",
	},
]

## 出せる札が1枚も無いときに代わりに出す案内(GameDesign.md 18章)。
const STUCK_TEXT := "いまはマナが足りないみたい。「ターン終了」を押すと、つぎのターンはマナが1つ増えるよ"
## 攻撃・反転を求めているのに、この手番にはもうできる駒がいないときの案内。
## 前の段を終えた直後は、その駒が攻撃・反転を済ませていて何も押せないことが多い。
const STUCK_WAIT_TEXT := "いまはできる子がいないみたい。「ターン終了」を押して、つぎのターンで試してみてね"

## 締めのひと言(GameDesign.md 18章)。勝利条件の説明は5段目へ移ったため、ここは短く整える。
const OUTRO_TEXT := "あとは自由に遊んでみてね。駒を押せば効果も読めるよ!"

## 1度だけの補足(GameDesign.md 18章)。段階の途中でも締めの後でも、初めて起きた瞬間に出す。
const CALLOUT_OWN_UNIT_DIED_TO_SAND := "体力が0になると割れちゃう。返せば長生きするよ"
const CALLOUT_FOE_GUARD_PLAYED := "守護がいる間は、先にその子を倒さないと本体を殴れないよ"
