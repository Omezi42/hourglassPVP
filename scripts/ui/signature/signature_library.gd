class_name SignatureLibrary
extends RefCounted
## カードの演出の表(GameDesign.md 9章)。カード id → `SignatureMove` を継いだスクリプト。
## **カードに演出を付けるときは `moves/` へ1ファイル置き、ここへ1行足すだけ**にする。
## 表に無いカードは紋章の型(`EmblemStrikeFx`)と通常の着地のまま。

## 場に出たときの登場。
const ENTRANCES := {
	"chronos": preload("res://scripts/ui/signature/moves/chronos_entrance.gd"),
	"freeze": preload("res://scripts/ui/signature/moves/freeze_entrance.gd"),
	"relic": preload("res://scripts/ui/signature/moves/relic_entrance.gd"),
}

## 効果が対象へ届くまで(設置・落砂・砂術など、紋章が飛ぶ場面の代わり)。
const EFFECTS := {
	"clocktower": preload("res://scripts/ui/signature/moves/clocktower_effect.gd"),
	"tempest": preload("res://scripts/ui/signature/moves/tempest_effect.gd"),
	"stasis": preload("res://scripts/ui/signature/moves/stasis_effect.gd"),
	"verdict": preload("res://scripts/ui/signature/moves/verdict_effect.gd"),
	"oasis": preload("res://scripts/ui/signature/moves/oasis_effect.gd"),
	"spring": preload("res://scripts/ui/signature/moves/spring_effect.gd"),
	"anvil": preload("res://scripts/ui/signature/moves/anvil_effect.gd"),
	"rewind": preload("res://scripts/ui/signature/moves/rewind_effect.gd"),
	"drift": preload("res://scripts/ui/signature/moves/drift_effect.gd"),
	"moss": preload("res://scripts/ui/signature/moves/moss_effect.gd"),
	"vigil": preload("res://scripts/ui/signature/moves/vigil_effect.gd"),
	"cairn": preload("res://scripts/ui/signature/moves/cairn_effect.gd"),
	"burial": preload("res://scripts/ui/signature/moves/burial_effect.gd"),
	"awaken": preload("res://scripts/ui/signature/moves/awaken_effect.gd"),
	"reverb": preload("res://scripts/ui/signature/moves/reverb_effect.gd"),
	"delay": preload("res://scripts/ui/signature/moves/delay_effect.gd"),
	"resonance": preload("res://scripts/ui/signature/moves/resonance_effect.gd"),
	"canon": preload("res://scripts/ui/signature/moves/canon_effect.gd"),
	"repeat": preload("res://scripts/ui/signature/moves/repeat_effect.gd"),
	"encore": preload("res://scripts/ui/signature/moves/encore_effect.gd"),
	"chorus": preload("res://scripts/ui/signature/moves/chorus_effect.gd"),
	"crescendo": preload("res://scripts/ui/signature/moves/crescendo_effect.gd"),
}


static func entrance(card: CardData) -> SignatureMove:
	return _make(ENTRANCES, card)


static func effect(card: CardData) -> SignatureMove:
	return _make(EFFECTS, card)


static func _make(table: Dictionary, card: CardData) -> SignatureMove:
	if card == null or not table.has(card.id):
		return null
	return table[card.id].new()
