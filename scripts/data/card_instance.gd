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
## 効果で後から与えられたキーワード。**CardData.keywords は書き換えない**。
## .tres は load() が同じインスタンスを返すため、書き換えるとその版の全対局
## (リプレイ・シミュレーションを含む)へ残ってしまう。
var granted_keywords: Array[int] = []
## 効果を消されたか。true の間はキーワードも効果も持たないものとして扱う。
var silenced: bool = false


func _init(p_data: CardData) -> void:
	data = p_data
	health = p_data.total_sand
	attack = 0
	glass_intact = p_data.has_keyword(CardEnums.Keyword.GLASS)


## 体力と攻撃力の合計。ダメージを受けると減る。
func total_sand() -> int:
	return health + attack


## **キーワードの問い合わせは必ずここを通す。**CardData を直接見ると、
## 後から与えられたキーワードと、消された状態を取りこぼす。
## **コンボ系カード(GameDesign.md 6章)の条件付きキーワードもここで解決する**:
## `data.conditional_keyword` が一致し、いまの総量が `conditional_keyword_total`
## と等しい間だけ、そのキーワードを持つとみなす。
func has_keyword(keyword: int) -> bool:
	if silenced:
		return false
	if data.has_keyword(keyword) or granted_keywords.has(keyword):
		return true
	if data.conditional_keyword < 0 or data.conditional_keyword != keyword:
		return false
	return total_sand() == data.conditional_keyword_total


## この砂時計が持っているキーワードすべて(表示用)。
func keywords() -> Array:
	if silenced:
		return []
	var found: Array = []
	for keyword in data.keywords:
		found.append(keyword)
	for keyword in granted_keywords:
		if not found.has(keyword):
			found.append(keyword)
	var conditional := data.conditional_keyword
	if conditional >= 0 and not found.has(conditional) and has_keyword(conditional):
		found.append(conditional)
	return found


## trigger で発動する効果。消されている砂時計は何も返さない。
func effects_for(trigger: int) -> Array[CardEffectData]:
	var none: Array[CardEffectData] = []
	if silenced:
		return none
	return data.effects_for(trigger)


## キーワードを1つ与える。既に持っているものは重ねない。
func grant_keyword(keyword: int) -> void:
	if silenced or has_keyword(keyword):
		return
	granted_keywords.append(keyword)
	if keyword == CardEnums.Keyword.GLASS:
		glass_intact = true


## キーワードと効果をすべて消す。硝子の膜も剥がれる。
func silence() -> void:
	silenced = true
	granted_keywords.clear()
	glass_intact = false


## 反転せずに寿命を全うするまでに与える総ダメージ(GameDesign.md 1章)。
## CPUの評価関数の基礎になる。
func lifetime_damage() -> int:
	return health * attack + health * (health - 1) / 2


## このターンに攻撃できる回数の上限。
func max_attacks() -> int:
	return 2 if has_keyword(CardEnums.Keyword.DOUBLE_STRIKE) else 1


func can_attack() -> bool:
	if data.cannot_attack:
		return false
	return not summoned_this_turn and attack > 0 and attacks_this_turn < max_attacks()


## 反転できない駒(`CardData.cannot_flip`)は通常の反転も反転権も受け付けない
## (GameDesign.md 6章)。反転権の判定 `MatchState._can_use_flip_right()` も `flippable()` を見る。
func can_flip() -> bool:
	return flippable() and not summoned_this_turn and not flipped_this_turn


func flippable() -> bool:
	return not data.cannot_flip


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


## 砂を n 粒上へ戻す(攻撃力-n / 体力+n)。落砂の逆向きで、戻せるのは攻撃力まで。
## 総量は変わらない(GameDesign.md 6章)。**`drop_sand()` へ負の値を渡す形にはしない**——
## 砂の移動は名前で区別する(Architecture.md 2.4節)。戻した量を返す。
func raise_sand(amount: int) -> int:
	var moved: int = mini(amount, attack)
	attack -= moved
	health += moved
	return moved


## ターン終了時の1粒。**ソロモード(GameDesign.md 27章)の特殊ルールでは
## `MatchState.sand_drop_count`により1粒より多いことがある**。
## 静止(GameDesign.md 6章)を持つ駒は落ちない。実際に落ちた量を返す。
func tick(amount: int = 1) -> int:
	if has_keyword(CardEnums.Keyword.STILL):
		return 0
	var before := attack
	drop_sand(amount)
	return attack - before


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
