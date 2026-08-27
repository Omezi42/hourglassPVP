class_name CardEffectData
extends Resource
## カード効果1件分のデータ(GameDesign.md 6章)。
## 「トリガー × ターゲット × エフェクト」の組み合わせで表現する。

@export var trigger: CardEnums.Trigger = CardEnums.Trigger.ON_PLAY
@export var target: CardEnums.EffectTarget = CardEnums.EffectTarget.OPPONENT_PLAYER
@export var effect_type: CardEnums.EffectType = CardEnums.EffectType.DAMAGE_PLAYER
@export var value: int = 0
