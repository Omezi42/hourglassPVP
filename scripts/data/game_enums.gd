class_name GameEnums
extends RefCounted

enum HourglassState { UPRIGHT, FALLING, FALLEN }

enum Trigger { ON_FLIP, WHILE_FALLING, ON_FALLEN, WHILE_FALLEN }

enum Target {
	SELF,
	ADJACENT_LEFT,
	ADJACENT_RIGHT,
	OPPONENT_PLAYER,
	OWN_PLAYER,
	RANDOM_ALLY,
	OPPONENT_MIRROR,
}

enum EffectType {
	DAMAGE,
	DAMAGE_REDUCTION,
	LOCK,
	FORCE_ADVANCE,
	RECOVER,
	COUNTER,
	SYNC_STATE,
	## 以下2つはスキル専用(GameDesign.md 7章)。受動効果としては使わない。
	SWAP_BENCH,
	SWAP_POSITION,
}
