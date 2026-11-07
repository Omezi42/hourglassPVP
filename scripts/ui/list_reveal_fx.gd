class_name ListRevealFx
extends RefCounted
## 一覧系の画面(デッキ一覧・リプレイ一覧・戦績・パズル選択)が、横2列グリッドを
## 組み終えた直後に呼ぶ共通の登場演出(GameDesign.md 9章「一覧系」)。
##
## 上から順に短くずれて現れることで「並んだ」感を出す。件数が多い画面で
## 待たされないよう、上限より後ろは遅延0で同時に現れる。

## 1件ごとの遅延の刻み(秒)。
const STEP := 0.03
## この件数までだけ遅延をずらす。それ以降は同時に現れる。
const MAX_STAGGERED := 8
const DURATION := 0.18
## フェードインと同時に、この量だけ下からせり上がる。
const RISE := 10.0


## `items` は `GridContainer.get_children()` 等、そのまま渡せる。
## Control でない要素(モーダル等が紛れた場合)は無視する。
static func stagger(items: Array, step: float = STEP, max_staggered: int = MAX_STAGGERED) -> void:
	for i in items.size():
		var item: Control = items[i] as Control
		if item == null:
			continue
		var delay: float = step * float(mini(i, max_staggered))
		item.modulate.a = 0.0
		# グリッドはこのフレームの終わりに子を並べ直すため、目標のy座標は
		# 並び終わってから読む(先に読むと0,0のままを掴む)。
		# 弱参照で持つ(同じフレームで組み直されて先に解放された札を、ラムダが掴んだままにしない)。
		var ref: WeakRef = weakref(item)
		var reveal := func() -> void:
			var alive: Control = ref.get_ref()
			if alive == null:
				return
			var target_y := alive.position.y
			alive.position.y = target_y + RISE
			var tween := alive.create_tween()
			tween.set_parallel(true)
			tween.tween_property(alive, "modulate:a", 1.0, DURATION).set_delay(delay)
			tween.tween_property(alive, "position:y", target_y, DURATION).set_delay(delay)
		reveal.call_deferred()
