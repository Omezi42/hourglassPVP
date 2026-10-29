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
	"middle": preload("res://scripts/ui/signature/moves/middle_entrance.gd"),
	"phase": preload("res://scripts/ui/signature/moves/phase_entrance.gd"),
	"grain": preload("res://scripts/ui/signature/moves/grain_entrance.gd"),
	"dash": preload("res://scripts/ui/signature/moves/dash_entrance.gd"),
	"shield": preload("res://scripts/ui/signature/moves/shield_entrance.gd"),
	"sand": preload("res://scripts/ui/signature/moves/sand_entrance.gd"),
	"watcher": preload("res://scripts/ui/signature/moves/watcher_entrance.gd"),
	"glass": preload("res://scripts/ui/signature/moves/glass_entrance.gd"),
	"vamp": preload("res://scripts/ui/signature/moves/vamp_entrance.gd"),
	"drill": preload("res://scripts/ui/signature/moves/drill_entrance.gd"),
	"lance": preload("res://scripts/ui/signature/moves/lance_entrance.gd"),
	"twin": preload("res://scripts/ui/signature/moves/twin_entrance.gd"),
	"lock": preload("res://scripts/ui/signature/moves/lock_entrance.gd"),
	"gate": preload("res://scripts/ui/signature/moves/gate_entrance.gd"),
	"poison": preload("res://scripts/ui/signature/moves/poison_entrance.gd"),
	"guard": preload("res://scripts/ui/signature/moves/guard_entrance.gd"),
	"mirror": preload("res://scripts/ui/signature/moves/mirror_entrance.gd"),
	"wall": preload("res://scripts/ui/signature/moves/wall_entrance.gd"),
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
	"sling": preload("res://scripts/ui/signature/moves/sling_effect.gd"),
	"pelt": preload("res://scripts/ui/signature/moves/pelt_effect.gd"),
	"bola": preload("res://scripts/ui/signature/moves/bola_effect.gd"),
	"nibble": preload("res://scripts/ui/signature/moves/nibble_effect.gd"),
	"block": preload("res://scripts/ui/signature/moves/block_effect.gd"),
	"vault": preload("res://scripts/ui/signature/moves/vault_effect.gd"),
	"hive": preload("res://scripts/ui/signature/moves/hive_effect.gd"),
	"relief": preload("res://scripts/ui/signature/moves/relief_effect.gd"),
	"collapse": preload("res://scripts/ui/signature/moves/collapse_effect.gd"),
	"march": preload("res://scripts/ui/signature/moves/march_effect.gd"),
	"key": preload("res://scripts/ui/signature/moves/key_effect.gd"),
	"cycle": preload("res://scripts/ui/signature/moves/cycle_effect.gd"),
	"crest": preload("res://scripts/ui/signature/moves/crest_effect.gd"),
	"shot": preload("res://scripts/ui/signature/moves/shot_effect.gd"),
	"shatter": preload("res://scripts/ui/signature/moves/shatter_effect.gd"),
	"recall": preload("res://scripts/ui/signature/moves/recall_effect.gd"),
	"refill": preload("res://scripts/ui/signature/moves/refill_effect.gd"),
	"call": preload("res://scripts/ui/signature/moves/call_effect.gd"),
	"reverse": preload("res://scripts/ui/signature/moves/reverse_effect.gd"),
	"turn": preload("res://scripts/ui/signature/moves/turn_effect.gd"),
	"gust": preload("res://scripts/ui/signature/moves/gust_effect.gd"),
	"seal": preload("res://scripts/ui/signature/moves/seal_effect.gd"),
	"goad": preload("res://scripts/ui/signature/moves/goad_effect.gd"),
	"pinch": preload("res://scripts/ui/signature/moves/pinch_effect.gd"),
	"bulwark": preload("res://scripts/ui/signature/moves/bulwark_effect.gd"),
	"wand": preload("res://scripts/ui/signature/moves/wand_effect.gd"),
	"seed": preload("res://scripts/ui/signature/moves/seed_effect.gd"),
	"glim": preload("res://scripts/ui/signature/moves/glim_effect.gd"),
	"husk": preload("res://scripts/ui/signature/moves/husk_effect.gd"),
	"pebble": preload("res://scripts/ui/signature/moves/pebble_effect.gd"),
	"salt": preload("res://scripts/ui/signature/moves/salt_effect.gd"),
	"tick": preload("res://scripts/ui/signature/moves/tick_effect.gd"),
	"rattle": preload("res://scripts/ui/signature/moves/rattle_effect.gd"),
	"dust": preload("res://scripts/ui/signature/moves/dust_effect.gd"),
	"flask": preload("res://scripts/ui/signature/moves/flask_effect.gd"),
	"forge": preload("res://scripts/ui/signature/moves/forge_effect.gd"),
	"temper": preload("res://scripts/ui/signature/moves/temper_effect.gd"),
	"balm": preload("res://scripts/ui/signature/moves/balm_effect.gd"),
	"hour": preload("res://scripts/ui/signature/moves/hour_effect.gd"),
	"spike": preload("res://scripts/ui/signature/moves/spike_effect.gd"),
	"blank": preload("res://scripts/ui/signature/moves/blank_effect.gd"),
	"crown": preload("res://scripts/ui/signature/moves/crown_effect.gd"),
	"eye": preload("res://scripts/ui/signature/moves/eye_effect.gd"),
	"pivot": preload("res://scripts/ui/signature/moves/pivot_effect.gd"),
	"sword": preload("res://scripts/ui/signature/moves/sword_effect.gd"),
	"sprout": preload("res://scripts/ui/signature/moves/sprout_effect.gd"),
	"hammer": preload("res://scripts/ui/signature/moves/hammer_effect.gd"),
	"well": preload("res://scripts/ui/signature/moves/well_effect.gd"),
	"burst": preload("res://scripts/ui/signature/moves/burst_effect.gd"),
	"halo": preload("res://scripts/ui/signature/moves/halo_effect.gd"),
	"legacy": preload("res://scripts/ui/signature/moves/legacy_effect.gd"),
	"shell": preload("res://scripts/ui/signature/moves/shell_effect.gd"),
	"swarm": preload("res://scripts/ui/signature/moves/swarm_effect.gd"),
	"wheel": preload("res://scripts/ui/signature/moves/wheel_effect.gd"),
	"barb": preload("res://scripts/ui/signature/moves/barb_effect.gd"),
	"pike": preload("res://scripts/ui/signature/moves/pike_effect.gd"),
	"drip": preload("res://scripts/ui/signature/moves/drip_effect.gd"),
	"glow": preload("res://scripts/ui/signature/moves/glow_effect.gd"),
	"bloom": preload("res://scripts/ui/signature/moves/bloom_effect.gd"),
	"obelisk": preload("res://scripts/ui/signature/moves/obelisk_effect.gd"),
	"sweep": preload("res://scripts/ui/signature/moves/sweep_effect.gd"),
	"tower": preload("res://scripts/ui/signature/moves/tower_effect.gd"),
	"anchor": preload("res://scripts/ui/signature/moves/anchor_effect.gd"),
	"ward": preload("res://scripts/ui/signature/moves/ward_effect.gd"),
	"echo": preload("res://scripts/ui/signature/moves/echo_effect.gd"),
	"crack": preload("res://scripts/ui/signature/moves/crack_effect.gd"),
	"memory": preload("res://scripts/ui/signature/moves/memory_effect.gd"),
	"page": preload("res://scripts/ui/signature/moves/page_effect.gd"),
	"chime": preload("res://scripts/ui/signature/moves/chime_effect.gd"),
}


static func entrance(card: CardData) -> SignatureMove:
	return _make(ENTRANCES, card)


static func effect(card: CardData) -> SignatureMove:
	return _make(EFFECTS, card)


static func _make(table: Dictionary, card: CardData) -> SignatureMove:
	if card == null or not table.has(card.id):
		return null
	return table[card.id].new()
