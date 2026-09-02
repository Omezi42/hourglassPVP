class_name CardEffectDemoEnemy
extends RefCounted
## 「相手の砂時計へ効く効果」の実演の中身(GameDesign.md 9章)。
##
## `CardEffectPreview` が1000行の上限に達したため切り出した。純粋な static だけを持ち、
## 渡された駒の Dictionary をその場の見た目へ書き換えるところまでが責務。


static func apply(foe: Dictionary, demo: int, value: int, landed: float) -> void:
	match demo:
		CardEffectPreview.Demo.FX_DESTROY_UNIT:
			foe["shatter"] = landed
		CardEffectPreview.Demo.FX_SWAP_STATS:
			foe["flip"] = landed if landed < 1.0 else -1.0
			if landed >= 0.5:
				var health: int = foe["h"]
				foe["h"] = foe["a"]
				foe["a"] = health
		CardEffectPreview.Demo.FX_DROP_SAND:
			foe["h"] = maxi(foe["h"] - value, 0)
			foe["a"] = foe["a"] + value
		CardEffectPreview.Demo.FX_RETURN_TO_HAND:
			# 砕けるのではなく盤面から消える。**破壊との違いはここでしか見せられない。**
			foe["fade"] = 1.0 - landed
		_:
			var left: int = foe["h"] - value
			foe["total"] = maxi(foe["total"] - value, foe["a"])
			foe["h"] = maxi(left, 0)
			if left <= 0:
				foe["shatter"] = landed


static func note(demo: int, value: int, all: bool) -> String:
	var scope := "相手の砂時計すべて" if all else "相手の砂時計1体"
	match demo:
		CardEffectPreview.Demo.FX_DESTROY_UNIT:
			return "%sを破壊する" % scope
		CardEffectPreview.Demo.FX_SWAP_STATS:
			return "%sの体力と攻撃力を入れ替える" % scope
		CardEffectPreview.Demo.FX_DROP_SAND:
			return "%sの砂が%d粒落ちる" % [scope, value]
		CardEffectPreview.Demo.FX_RETURN_TO_HAND:
			return "%sを持ち主の手札へ戻す" % scope
	return "%sへ%dダメージ(砂は消える)" % [scope, value]
