class_name CardInstance
extends RefCounted
## 場に出ている砂時計1体分の実行時状態(GameDesign.md 1章)。
## 静的データ(CardData)と可変状態(体力・攻撃力・行動済みか)を分離する。

var data: CardData
## 上の部屋に残っている砂。0になると破壊される。
var health: int = 0
## 下に落ちた砂。攻撃力そのもの。
var attack: int = 0
## この砂時計を出したターンかどうか(反転も攻撃もできない)。
var summoned_this_turn: bool = true
## このターンに反転したかどうか(1体につき1ターン1回)。
var flipped_this_turn: bool = false
## このターンに攻撃した回数(連撃なら2回まで)。
var attacks_this_turn: int = 0
## 硝子がまだ残っているか(最初の1回のダメージを無効にする)。
var glass_intact: bool = false


func _init(p_data: CardData) -> void:
	data = p_data
	health = p_data.total_sand
	attack = 0
	glass_intact = p_data.has_keyword(CardEnums.Keyword.GLASS)


## 体力と攻撃力の合計。ダメージを受けると減る。
func total_sand() -> int:
	return health + attack


func has_keyword(keyword: int) -> bool:
	return data.has_keyword(keyword)


## 反転せずに寿命を全うするまでに与える総ダメージ(GameDesign.md 1章)。
## CPUの評価関数の基礎になる。
func lifetime_damage() -> int:
	return health * attack + health * (health - 1) / 2


## このターンに攻撃できる回数の上限。
func max_attacks() -> int:
	return 2 if has_keyword(CardEnums.Keyword.DOUBLE_STRIKE) else 1


func can_attack() -> bool:
	return not summoned_this_turn and attack > 0 and attacks_this_turn < max_attacks()


func can_flip() -> bool:
	return not summoned_this_turn and not flipped_this_turn


## 反転:体力と攻撃力を入れ替える。
func flip() -> void:
	var previous := health
	health = attack
	attack = previous


## 砂を n 粒落とす(体力-n / 攻撃力+n)。総量は変わらない。
func drop_sand(amount: int) -> void:
	var moved: int = mini(amount, health)
	health -= moved
	attack += moved


## ターン終了時の1粒。
func tick() -> void:
	drop_sand(1)


## ダメージを受ける。受けた分の砂は消える(総量が減る)。
## 硝子で無効にした場合は0を返す。
func take_damage(amount: int) -> int:
	if amount <= 0:
		return 0
	if glass_intact:
		glass_intact = false
		return 0
	var dealt: int = mini(amount, health)
	health -= dealt
	return dealt


func is_dead() -> bool:
	return health <= 0


## 自分の手番が始まるときの状態リセット。
func begin_turn() -> void:
	summoned_this_turn = false
	flipped_this_turn = false
	attacks_this_turn = 0
