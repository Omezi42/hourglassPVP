class_name CardEffectData
extends Resource
## カード効果1件分のデータ(GameDesign.md 6章)。
## 「トリガー × ターゲット × エフェクト」の組み合わせで表現する。

@export var trigger: CardEnums.Trigger = CardEnums.Trigger.ON_PLAY
@export var target: CardEnums.EffectTarget = CardEnums.EffectTarget.OPPONENT_PLAYER
@export var effect_type: CardEnums.EffectType = CardEnums.EffectType.DAMAGE_PLAYER
@export var value: int = 0
## SUMMON で出す砂時計の id。他の効果では使わない。
@export var card_id: String = ""
## GRANT_KEYWORD で与えるキーワード。他の効果では使わない(-1 = なし)。
##
## **value を流用して「守護は0番」のように持たせない。**どの整数が何を指すかを
## 呼び出し側が覚えている前提のコードになり、.tres を読んでも意味が取れなくなるため。
@export var keyword: int = -1
