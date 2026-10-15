class_name CardMatchFastForward
extends RefCounted
## 向きが変わったとき、再生中の演出を打ち切って結果だけを残す(GameDesign.md 9章「縦画面」/ Architecture.md 4.7節)。
## 盤面の状態は先に確定しているため、演出の Tween を終わりまで一度に進め、終わった後の値(位置・色・消える演出の片付け)
## だけを残す。そのうえで `CardMatchArrange` が新しい向きの座標へ置き直す。
##
## 演出の続きが Tween の `finished` を待って次の Tween を作る(攻撃の往復など)ため、何度か繰り返して進め切る。
## ずっと繰り返す Tween(手番の脈など)は終わりが無いので進めない。

## 1回に進める秒数。どの演出よりも長ければよい。
const SKIP_SECONDS := 3600.0
## 演出が次の演出を呼ぶ連鎖を進め切るまでの上限。
const MAX_PASSES := 12


static func run(screen: Control) -> void:
	if not screen.is_inside_tree() or not screen.is_visible_in_tree():
		return
	for i in MAX_PASSES:
		var stepped := false
		for tween in screen.get_tree().get_processed_tweens():
			if not tween.is_valid() or not tween.is_running() or tween.get_loops_left() < 0:
				continue
			tween.custom_step(SKIP_SECONDS)
			stepped = true
		if not stepped:
			return
