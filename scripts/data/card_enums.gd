class_name CardEnums
extends RefCounted
## v5.0のカード(砂時計)が使う語彙。GameDesign.md 1章・6章に対応する。
## 旧ルール(位相制)のGameEnumsとは別物であり、混ぜて使わない。

## 常在の能力(GameDesign.md 6章)。1枚に複数持たせてよい。
##
## **このうち「語として見せる」のは、複数のカードに載っているものだけ**(NAMED を参照)。
## 1枚にしか無い能力を語にすると、その語を覚えても他で使い回せず、
## カードを読むたびに語の意味を思い出す手間だけが増えるため。
## 語にしないものは、カードに効果の文をそのまま書く。
enum Keyword {
	## 相手はこの砂時計を無視して他を攻撃できない。
	GUARD,
	## 最初に受けるダメージを1度だけ無効にする。
	GLASS,
	## 砂時計を攻撃したとき、超過分が相手プレイヤーへ抜ける。
	PIERCE,
	## この砂時計がダメージを与えた砂時計を破壊する。
	POISON,
	## 与えたダメージと同じだけ自分のHPを回復する。
	LIFESTEAL,
	## 1ターンに2回攻撃する。
	DOUBLE_STRIKE,
	## 場に出た瞬間に砂が2粒落ちる(すぐ攻撃できる)。
	QUICK,
	## 戦闘で与えるダメージが2倍になる。**語にしない**(コンボ系カードが
	## `CardData.conditional_keyword` 経由で条件付きに持たせるためだけの値で、
	## 常在の `keywords` 配列へ直接載るカードは無い)。
	DAMAGE_BOOST,
	## ターン終了時に砂が落ちない(老いない代わりに攻撃力も伸びない)。静止の刻。
	STILL,
}

## トリガーキーワード(GameDesign.md 6章)。
##
## **新しい値は必ず末尾へ足す**(EffectTarget と同じ理由)。
enum Trigger {
	## 設置:場に出したとき。
	ON_PLAY,
	## 反転:反転したとき。毎ターン行えるため常在効果として値付けする。
	ON_FLIP,
	## 余砂:破壊されたとき。
	ON_DEATH,
	## 落砂:自分のターン終了時(砂が1粒落ちる瞬間)。
	ON_TURN_END,
	## 被弾:ダメージを受けたとき。硝子で無効化された場合は発動しない。
	ON_DAMAGED,
	## 自分の他の砂時計が破壊されたとき(遺砂の刻)。**語にしない**——札には「常在」と出し、
	## 効果の文をそのまま書く(GameDesign.md 6章)。トークンの破壊にも反応する。
	ON_ALLY_DEATH,
	## 相手の砂時計が反転したとき(反響の刻)。ON_ALLY_DEATH と同じく語にせず「常在」と出す。
	## 起こし方(通常の反転・反転権・効果)を問わない。
	ON_ENEMY_FLIP,
	## 相手がカードを引いたとき(薙砂の刻)。引けた1枚ごとに発動し、手番の始めの1枚とマリガンは数えない。
	## ON_ALLY_DEATH と同じく語にせず「常在」と出す。
	ON_ENEMY_DRAW,
	## 自分が砂術を使ったとき(詠砂の刻)。砂術の効果を解決し終えた後に、場にいる自分の駒が反応する。
	## ON_ALLY_DEATH と同じく語にせず「常在」と出す。
	ON_OWN_SPELL,
	## この駒が攻撃したとき(スパーク。烈砂の刻)。戦闘を解決し終えた後、この駒が砕けていなければ働く。
	## 相手プレイヤーへの攻撃でも働く。ON_ALLY_DEATH と同じく語にせず「常在」と出す。
	ON_ATTACK,
	## 自分がHPを失ったとき(イグニス。烈砂の刻)。ダメージでも代償でも、1回の減少ごとに1回働く(減った量は問わない)。
	## ON_ALLY_DEATH と同じく語にせず「常在」と出す。
	ON_OWN_HP_LOST,
	## 自分が砂時計を出したとき(ファウンテン。注砂の刻)。手から出したときも効果で出したときも働き、その砂時計自身が出たときは働かない。
	## hint の entered_slot が出た砂時計の枠(EffectTarget.ENTERING_UNIT が読む)。ON_ALLY_DEATH と同じく語にせず「常在」と出す。
	ON_ALLY_ENTER,
	## この駒が戦闘で相手の砂時計へダメージを与えたとき(リーチ。汲砂の刻)。与えた量が hint の dealt に入る。
	## 攻撃したときも反撃したときも働く。ON_ALLY_DEATH と同じく語にせず「常在」と出す。
	ON_DEAL_DAMAGE,
	## 相手の砂時計の砂が上へ戻ったとき(アクイファー。汲砂の刻)。戻った駒1体ごとに1回働く(戻った量は問わない)。
	## ON_ALLY_DEATH と同じく語にせず「常在」と出す。
	ON_FOE_SAND_RAISED,
}

## エフェクトの対象。
##
## **新しい値は必ず末尾へ足す。**`.tres` は enum を整数で保存しているため、
## 途中へ挿入すると既存のカードの対象が丸ごとずれる(実際に一度やって、
## 全体除去が単体ドローになった)。並びの美しさより保存済みデータとの整合を取る。
enum EffectTarget {
	## この効果を持つ砂時計自身。
	SELF,
	## 相手の砂時計1体(選択。CPUは評価値で選ぶ)。
	ENEMY_UNIT,
	## 相手の砂時計すべて。
	ALL_ENEMY_UNITS,
	## 自分の砂時計すべて。
	ALL_ALLY_UNITS,
	## 相手プレイヤー。
	OPPONENT_PLAYER,
	## 自分プレイヤー。
	OWN_PLAYER,
	## 自分の砂時計1体(選択)。
	ALLY_UNIT,
	## 相手プレイヤーか相手の砂時計1体(選択。追砂の刻)。DAMAGE_UNIT と組み、本体を選べば本体へ与える。
	ENEMY_UNIT_OR_PLAYER,
	## この効果を持つ駒以外の、敵味方すべての砂時計(アイオーン)。自分の駒を左から、次に相手の駒を左から並べる。
	ALL_OTHER_UNITS,
	## 被弾で、戦闘でダメージを与えてきた相手の砂時計(パリィ)。砂術・設置などの効果によるダメージでは
	## 誰も指さず、攻撃した駒が既に砕けていれば不発。
	DAMAGING_FOE,
	## この効果を持つ駒以外の、自分の砂時計すべて(フレア)。左の枠から並べる。
	OTHER_ALLY_UNITS,
	## 自分の砂時計が出たときの、出た砂時計(ファウンテン)。ON_ALLY_ENTER の hint の entered_slot が指す駒で、いなければ不発。
	ENTERING_UNIT,
}

## エフェクトの種類。
##
## **新しい値は必ず末尾へ足す**(EffectTarget と同じ理由)。
enum EffectType {
	## プレイヤーへ value ダメージ。
	DAMAGE_PLAYER,
	## 砂時計へ value ダメージ(砂が消える=総量が減る)。
	DAMAGE_UNIT,
	## 砂時計を破壊する。
	DESTROY_UNIT,
	## 体力と攻撃力を入れ替える(強制反転)。
	SWAP_STATS,
	## 総量を value 増やす(体力へ加算する)。
	ADD_TOTAL,
	## 砂を value 粒落とす(体力-value / 攻撃力+value)。
	DROP_SAND,
	## カードを value 枚引く。
	DRAW,
	## 自分のHPを value 回復する。
	HEAL_PLAYER,
	## 相手の砂時計の数 × value ダメージを相手プレイヤーへ。
	DAMAGE_PLAYER_PER_ENEMY_UNIT,
	## 攻撃力を value 増やす(下の部屋へ砂を足す。体力は変わらない)。
	ADD_ATTACK,
	## 空き枠へ card_id の砂時計を1体出す。空きが無ければ何もしない。
	SUMMON,
	## 対象へ keyword のキーワードを与える。
	GRANT_KEYWORD,
	## 対象のキーワードと効果をすべて消す。
	SILENCE,
	## 対象の砂時計を持ち主の手札へ戻す(砂術。GameDesign.md 6章)。
	## **破壊ではないため余砂は発火しない**。戻るのは CardData であり、
	## 受けたダメージも与えられたキーワードも失われる。
	RETURN_TO_HAND,
	## 対象プレイヤーのHPを反転する(初期HP - 現在HP)。value は使わない。
	## 砂時計の反転(体力と攻撃力の入れ替え)を、プレイヤー自身へ持ち込んだもの。
	INVERT_PLAYER_HP,
	## 砂を value 粒上へ戻す(攻撃力-value / 体力+value)。DROP_SAND の逆向きで、
	## 戻せるのは攻撃力まで(0未満にはならない)。総量は変わらない(GameDesign.md 6章)。
	RAISE_SAND,
	## 自分の墓地の砂時計(トークンを含む。砂術は含まない)1体につき、総量を value 増やす(遺砂の刻)。
	ADD_TOTAL_PER_GRAVE,
	## 自分の墓地の砂時計1体を手札へ戻す。対象 SELF は余砂で砕けたそのカード自身、
	## それ以外はプレイヤーが墓地から選ぶ(hint の grave_index。トークンは選べない)。
	RECOVER_FROM_GRAVE,
	## 自分の墓地の砂時計1体を選んで空き枠へ出す(蘇生)。設置効果は解決しない。
	REVIVE_FROM_GRAVE,
	## このターンすでに反転した対象を、もう一度反転できるようにする(反響の刻)。
	## 外すのは「1体1ターン1回」だけで、出したターンの制限は残る。value は使わない。
	RESET_FLIP,
	## 対象プレイヤーの反転権の残り回数を value 増やす(反響の刻)。上限は無い。
	GAIN_FLIP_RIGHT,
	## 対象プレイヤーへ value + このターン自分の砂時計が反転した回数 のダメージ(反響の刻)。
	DAMAGE_PLAYER_PLUS_FLIPS,
	## 相手の砂時計の数 × value だけ自分のHPを回復する(追砂の刻)。
	HEAL_PLAYER_PER_ENEMY_UNIT,
	## card_id のカードを、target が指すプレイヤーの手札へ1枚加える(プレゼント)。山札は減らない。
	ADD_CARD_TO_HAND,
	## 対象プレイヤーへ、発動した砂時計のいまの攻撃力ぶんのダメージ(クロックタワー)。value は使わない。
	DAMAGE_PLAYER_BY_OWN_ATTACK,
	## 自分の山札からランダムな砂術を value 枚、手札へ加える(砂占い。詠砂の刻)。「引く」ではないため
	## 相手のドローに反応する効果は働かない。山札に砂術が無ければ何もしない。
	TUTOR_SPELL,
	## 自分の墓地の砂術1枚を選んで手札へ戻す(アーカイブ。詠砂の刻)。選び方は RECOVER_FROM_GRAVE と同じ。
	RECOVER_SPELL_FROM_GRAVE,
	## 自分の墓地でいちばん新しい砂術(この効果を持つものを除く)を、コストを払わずにもう一度撃つ
	## (写し詠み。詠砂の刻)。撃ち直しは「砂術を使う」に数えない。
	RECAST_SPELL,
	## 自分の墓地の砂術1枚につき、対象プレイヤーへ value ダメージ(グリモア。詠砂の刻)。
	DAMAGE_PLAYER_PER_GRAVE_SPELL,
	## 相手の砂時計が自分(この駒を含む)より多ければ、その差の数だけ相手の砂時計をランダムに破壊する(イコライザー)。
	DESTROY_RANDOM_BY_EXCESS,
	## 対象の総量を value にする(クインテット)。差は体力で埋め、体力が1未満になるぶんは攻撃力から引く。
	SET_TOTAL,
	## 対象の砂を体力が1になるまで落とす(ハリケーン)。ダメージではない。value は使わない。
	DROP_SAND_TO_ONE,
	## 対象の砂を残らず上へ戻す(ゼロアワー)。攻撃力が0になる。value は使わない。
	RAISE_ALL_SAND,
	## 空いている枠すべてに、自分の墓地からランダムな砂時計を出す(ネクロポリス)。設置効果は解決しない。
	REVIVE_RANDOM_ALL,
	## 自分のHPが相手より少ないとき、その差の半分(切り上げ)だけ対象プレイヤーのHPを回復する(リブラ)。value は使わない。
	HEAL_PLAYER_HALF_HP_GAP,
	## 自分のHPが相手より少ないぶんだけ、場にいる相手の砂時計をランダムに選んで1点ずつダメージを与える(ラストアワー)。
	## 同じ駒が続けて選ばれてよい。砕けた駒は選ばず、相手の砂時計がいなくなったら残りは捨てる。value は使わない。
	DAMAGE_RANDOM_UNITS_BY_HP_GAP,
	## 自分の手札からランダムなコスト condition_total 以下の砂時計を value 体まで、コストを払わず空き枠へ出し、
	## keyword を与える(スタンピード)。設置効果は解決する。条件に合う砂時計か空き枠が足りなければ出せる数だけ出す。
	PLAY_RANDOM_FROM_HAND,
	## 対象プレイヤーの最大マナを value 増やす(ベル。早鐘の刻)。上限(`MatchState.MAX_MANA`)を超えない。今の手番のマナは増えない。
	GAIN_MAX_MANA,
	## 対象プレイヤーの最大マナを上限まで上げ、上がったマナ1につき value だけ自分のHPを失う(ドーン)。今の手番のマナは増えない。
	RAISE_MAX_MANA_TO_CAP,
	## 対象プレイヤーの今の手番のマナを value 増やす(早回し・前借り)。コインと同じく今の手番だけで、上限を超えるぶんは捨てる。
	GAIN_MANA,
	## 対象プレイヤーの次の手番のマナを value 少なく始まるようにする(ボイラー・前借り・サンライズ)。
	## 重なれば足し、回復の後に引く。0未満にはならない。
	DELAY_MANA,
	## 対象の砂時計へ granted_effect を与える(導火線。導火の刻)。与えた効果は `CardInstance.granted_effects` が持ち、
	## 沈黙で消え、手札へ戻ると失われる。同じ効果を2回与えれば2回働く。
	GRANT_EFFECT,
	## 対象の砂時計の「出したターンは攻撃できない・反転できない」を外す(刻限)。出したターン以外の駒には何も起きない。value は使わない。
	LIFT_SUMMON_LIMIT,
	## 対象のすべての砂時計へ、発動した砂時計のいまの攻撃力ぶんのダメージ(ノヴァ)。value は使わない。
	DAMAGE_UNIT_BY_OWN_ATTACK,
	## 自分の山札の上から value 枚を墓地へ置く(シャフト。先触の刻)。「引く」ではないため相手のドローに反応する効果は働かない。
	## 山札が足りなければある分だけ置く。
	MILL_DECK,
	## 自分の山札の一番上を見て、そのままにするか墓地へ置く(スコープ)。選びは hint の peek_index(0なら墓地へ)。無ければそのまま。
	PEEK_KEEP_OR_MILL,
	## 自分の山札の上から value 枚を見て、1枚を手札に加え、残りを墓地へ置く(予兆)。選びは hint の peek_index(見た札の位置)。
	PEEK_PICK_TO_HAND,
	## 自分の山札の一番上を公開し、そのコストの数だけ対象の砂時計の砂を上へ戻す(ルーン)。公開した札は山札の一番上に残る。
	REVEAL_RAISE_SAND,
	## 自分の山札の一番上を公開する。コスト value 以下の砂時計なら場に出し(設置効果は働く。空き枠が無ければ手札へ)、それ以外は手札に加える(未来視)。
	REVEAL_PLAY_OR_HAND,
	## 自分の山札の上から value 枚を墓地へ置き、その中でコストがいちばん高い砂時計1枚を手札に加える(ディガー)。砂時計が無ければ何も加えない。
	MILL_TAKE_BEST_UNIT,
	## 自分の山札の一番上を墓地へ置く。それが砂術なら相手の砂時計1体(ランダム)に value ダメージ(ホロスコープ)。
	MILL_SPELL_DAMAGE,
	## 自分の山札の一番上を、コストを払わずに使う(予言)。砂時計なら空き枠へ出し、砂術なら撃つ。山札が0枚か使えないなら何もしない。
	PLAY_DECK_TOP,
	## 残りのマナ(コストを払った後)をすべて0にし、1につき対象の砂時計の総量を value 足す(キャスク・デリュージ。注砂の刻)。
	## 残りが0なら何も起きない。
	SPEND_MANA_ADD_TOTAL,
	## 残りのマナをすべて0にし、1につきランダムな相手の砂時計1体へ value ダメージ(溢れ砂)。
	## その時点で場にいる相手の砂時計から1点ずつ選び、相手の砂時計がいなくなったら残りは捨てる。
	SPEND_MANA_DAMAGE_RANDOM,
	## このターン使わずに残したマナ1につき、対象の砂時計1体の総量を value 足す(リザーバー。マナは使わない)。
	ADD_TOTAL_PER_UNUSED_MANA,
	## 対象の自分の砂時計1体の総量を value 減らし(ダメージではない。体力から引き、体力1未満のぶんは攻撃力から引く)、
	## 効果を持つ砂時計の総量を value 増やす(デカンタ)。対象がいなければ何も起きない。
	TRANSFER_TOTAL_TO_SELF,
	## 効果を持つ砂時計(砕けた時の)の攻撃力の数だけ、自分の他の砂時計へ左から順に1ずつ総量を足す(アンフォラ)。一周したら左から。
	DISTRIBUTE_TOTAL_BY_OWN_ATTACK,
	## 自分の山札が0枚なら、対局に勝つ(テルミヌス)。勝つのは効果を解決したその時点で、相手のHPは問わない。
	WIN_IF_DECK_EMPTY,
	## 対象の自分の砂時計1体を破壊し、その余砂(ON_DEATH。導火線で与えた余砂も含む)をもう一度発動する(爆心。導火の刻)。
	## 破壊で1回、もう一度で1回。余砂を持たない駒は選べない(ConditionScope.TARGET_HAS_DEATH_EFFECT)。
	DESTROY_AND_REPEAT_DEATH,
	## 対象の相手の砂時計の攻撃力を value 抜き(0未満にはならない)、抜けた数だけ自分の砂時計1体の体力を増やす(汲み上げ。汲砂の刻)。
	## 増やす駒は自分の駒から自動で選ぶ(`CardDrawSandEffects.ally_for_gain`)。
	DRAIN_ATTACK_TO_ALLY,
	## 対象の相手の砂時計の攻撃力をすべて抜き、抜けた数だけ自分のHPを回復する(砂盗み)。value は使わない。
	DRAIN_ATTACK_TO_HP,
	## 対象の相手の砂時計それぞれの攻撃力を value ずつ抜き、抜けた数の合計だけこの砂時計の体力を増やす(メイルストロム)。
	DRAIN_ATTACK_TO_SELF,
	## 対象の相手の砂時計の総量を value 減らし(ダメージではない。総量0で破壊)、減った数だけ自分の砂時計1体の総量を増やす(サイフォン・ドレイン)。
	TRANSFER_TOTAL_FROM_FOE,
	## 対象の相手の砂時計と自分の砂時計1体の総量を入れ替える(バーター)。体力と攻撃力の比は保ち、端数は体力へ。value は使わない。
	SWAP_TOTAL_WITH_ALLY,
	## この砂時計の砂を、戦闘で与えたダメージ(hint の dealt)の数だけ上へ戻す(リーチ)。value は使わない。
	RAISE_SAND_BY_DEALT,
	## 対象の相手の砂時計を自分の空き枠の左へ奪う(チャーム・ディフェクト・ルアー・パイパー。寝返りの刻)。
	## 全体(ALL_ENEMY_UNITS)なら空き枠の数まで攻撃力の高い順に奪う。空き枠が無ければ不発。value は使わない。
	SEIZE_UNIT,
	## 対象の相手の砂時計をこのターンだけ奪い、攻撃・反転できるようにする(誘い砂)。手番の終わりに元の持ち主へ返る。value は使わない。
	SEIZE_UNIT_FOR_TURN,
	## 対象の相手の砂時計に、相手の別の砂時計を攻撃させる(同士討ち・マリオネット)。value は使わない。
	## random_target なら攻撃させる駒もランダム(攻撃力1以上から)、そうでなければ攻撃力がいちばん高い別の駒。
	FORCE_FOE_ATTACK,
	## 対象の相手の砂時計と、この砂時計の持ち場を入れ替える(トレイター)。value は使わない。
	SWAP_SIDE_WITH_FOE,
}

## コンボ系カードの発動条件が確認する範囲(GameDesign.md 6章)。
## `CardEffectData.condition_scope` が使う。NONE なら常に発動する。
##
## **新しい値は必ず末尾へ足す**(EffectTarget と同じ理由)。
enum ConditionScope {
	## 条件なし。常に発動する。
	NONE,
	## この効果を持つ砂時計自身の、いまの総量(体力+攻撃力)を見る。
	SELF,
	## 選んだ対象の、いまの総量を見る。対象の絞り込みとして働く
	## (条件を満たさない相手・味方は選べない)。
	TARGET,
	## 自分の場に、いまの総量が条件と一致する砂時計が1体でもいるかを見る。
	## 選ぶ対象そのものの総量は問わない。
	ANY_ALLY,
	## 選んだ対象の攻撃力が体力より多いか(老いた駒・反転した駒)。TARGET と同じく
	## 対象の絞り込みとして働き、condition_total は使わない(静止の刻)。
	ATTACK_OVER_HEALTH,
	## 選んだ対象の体力が condition_total 以下か。TARGET と同じく対象の絞り込みとして働く(追砂の刻)。
	HEALTH_AT_MOST,
	## 選んだ対象の総量が condition_total 以上か。TARGET と同じく対象の絞り込みとして働く(追砂の刻)。
	TOTAL_AT_LEAST,
	## 相手の砂時計の数が、この駒を除いた自分の砂時計の数より多いか。condition_total は使わない(追砂の刻)。
	ENEMY_OUTNUMBERS,
	## 相手の砂時計の数が condition_total 以上か(薙砂の刻)。発動の可否を決める条件。
	ENEMY_COUNT_AT_LEAST,
	## 自分のHPが相手のHPより少ないか(背水の刻)。同じなら満たさない。発動の可否を決める条件で、
	## condition_total は使わない。
	OWN_HP_BELOW_FOE,
	## 自分のHPが condition_total 以下か(背水の刻。12は初期HPの半分)。発動の可否を決める条件。
	OWN_HP_AT_MOST,
	## 自分の最大マナが上限(`MatchState.MAX_MANA`)に届いているか(アラーム。早鐘の刻)。発動の可否を決める条件で、
	## condition_total は使わない。
	MAX_MANA_FULL,
	## 残りのマナ(コストを払った後)が condition_total 以上か(ラドル。注砂の刻)。発動の可否を決める条件。
	OWN_MANA_AT_LEAST,
	## 自分の墓地のカード(砂時計・砂術・トークンすべて)が condition_total 枚以上か(ヴィジョン。先触の刻)。発動の可否を決める条件。
	OWN_GRAVE_AT_LEAST,
	## 選んだ対象が余砂(ON_DEATH の効果。導火線で与えたものも含む)を持つか(爆心。導火の刻)。TARGET と同じく対象の絞り込みとして働く。
	TARGET_HAS_DEATH_EFFECT,
	## 選んだ対象の攻撃力が condition_total 以下か(チャーム。寝返りの刻)。TARGET と同じく対象の絞り込みとして働く。
	ATTACK_AT_MOST,
	## 選んだ対象の総量が condition_total 以下か(ルアー。寝返りの刻)。TARGET と同じく対象の絞り込みとして働く。
	TOTAL_AT_MOST,
	## 相手の砂時計の数が、この駒を含む自分の砂時計の数より condition_total 以上多いか(ディフェクト)。発動の可否を決める条件。
	ENEMY_LEADS_BY,
}

## 効果が対象へ届く演出の「型」(GameDesign.md 9章)。`MatchState.effect_struck` /
## `effect_struck_many` が運ぶ。全体に効く効果(対象が複数)は `effect_struck_many` が
## 対象の数だけ同時に紋章を飛ばすため、この型自体は単体・複数のどちらでも共通で使う。
##
## **新しい値は必ず末尾へ足す**(EffectTarget と同じ理由。信号の整数値は保存しないが、
## 他の enum と扱いを揃える)。
enum EffectVisualStyle {
	## 打撃。紋章が対象へ飛んで実際に当てる(ダメージ・破壊・確定の一撃)。
	STRIKE,
	## 恵与。紋章が対象へ舞い降りて馴染む(総量・攻撃力を足す、キーワードを与える)。
	DESCEND,
	## 払拭。紋章が対象に重なり、キーワード・効果の色が抜けて消える。
	DRAIN,
	## 反転。紋章が対象の周りを回ってから、体力と攻撃力が入れ替わる。
	SPIN,
	## 静止。対象を取らない効果(ドロー等)が、飛ばずにその場で光の輪を出して消える。
	PULSE,
	## 回収。紋章が対象を包み、駒が縮んで持ち主の手札へ吸い込まれる(砂へ還す)。
	RECALL,
}

## 紋章の出どころ(GameDesign.md 9章 2026-09-21・Architecture.md 4.0節)。
## `source_slot` だけでは、砂術(手札から撃つ)と余砂(駒が既に盤面から降りている)の
## 紋章をどこから飛ばせばよいか決まらないため、型で分けて持つ。
##
## | origin | 出どころ |
## |---|---|
## | UNIT | 盤面に残っている駒の中心 |
## | SPELL | 自分の情報帯の中心(浮き上がってから飛ぶ) |
## | DEATH | 砕けた台座の銘板(残ってから飛ぶ) |
##
## **新しい値は必ず末尾へ足す**(EffectTarget と同じ理由)。
enum EffectOrigin {
	UNIT,
	SPELL,
	DEATH,
}

## 弾のカードのレアリティ(GameDesign.md 8章)。`.tres` へ整数で保存するため、**新しい値は必ず末尾へ足す**。
enum Rarity {
	COMMON,
	RARE,
	EPIC,
	LEGENDARY,
}

## 語として見せるキーワード。**複数のカードに載っているものだけ**をここへ入れる。
## カードを追加してある能力が2枚目に載ったら、ここへ足して語へ昇格させる。
const NAMED: Array[Keyword] = [
	Keyword.GUARD, Keyword.GLASS, Keyword.PIERCE, Keyword.QUICK, Keyword.STILL
]


static func is_named(keyword: int) -> bool:
	return NAMED.has(keyword)


## 語にしない能力を、カードの狭い1行へ収める短い言い換え。
## **カードの面は左右の隅を数値バッジが占めるため、収まるのは4文字程度**しかない。
## 何をする能力かは keyword_description() が返す一文で読ませる。
static func keyword_short_text(keyword: int) -> String:
	match keyword:
		Keyword.POISON:
			return "破壊"
		Keyword.LIFESTEAL:
			return "回復"
		Keyword.DOUBLE_STRIKE:
			return "2回攻撃"
		Keyword.DAMAGE_BOOST:
			return "倍撃"
	return keyword_name(keyword)


## キーワードの表示名(GameDesign.md 6章の語)。
static func keyword_name(keyword: int) -> String:
	match keyword:
		Keyword.GUARD:
			return "守護"
		Keyword.GLASS:
			return "硝子"
		Keyword.PIERCE:
			return "貫通"
		Keyword.POISON:
			return "毒砂"
		Keyword.LIFESTEAL:
			return "吸命"
		Keyword.DOUBLE_STRIKE:
			return "連撃"
		Keyword.QUICK:
			return "疾走"
		Keyword.DAMAGE_BOOST:
			return "倍撃"
		Keyword.STILL:
			return "静止"
	return ""


## 能力の説明文(GameDesign.md 6章の表)。語にするものは【語】に添えて、
## 語にしないものはこれ単体で出す。デッキ編集の一覧にも収まる長さに保つ。
static func keyword_description(keyword: int) -> String:
	match keyword:
		Keyword.GUARD:
			return "相手はこの砂時計を無視して他を攻撃できない。"
		Keyword.GLASS:
			return "最初に受けるダメージを1度だけ無効にする。"
		Keyword.PIERCE:
			return "砂時計を攻撃したとき、超過分が相手プレイヤーへ抜ける。"
		Keyword.POISON:
			return "ダメージを与えた砂時計を破壊する"
		Keyword.LIFESTEAL:
			return "与えたダメージぶん自分のHPを回復する"
		Keyword.DOUBLE_STRIKE:
			return "1ターンに2回攻撃できる"
		Keyword.QUICK:
			return "出したターンから攻撃できる。"
		Keyword.DAMAGE_BOOST:
			return "戦闘で与えるダメージが2倍になる。"
		Keyword.STILL:
			return "ターン終了時に砂が落ちない(老いない代わりに攻撃力も伸びない)。"
	return ""


## トリガーの表示名(GameDesign.md 6章の語)。
static func trigger_name(trigger: int) -> String:
	match trigger:
		Trigger.ON_PLAY:
			return "設置"
		Trigger.ON_FLIP:
			return "反転"
		Trigger.ON_DEATH:
			return "余砂"
		Trigger.ON_TURN_END:
			return "落砂"
		Trigger.ON_DAMAGED:
			return "被弾"
		Trigger.ON_ALLY_DEATH, Trigger.ON_ENEMY_FLIP, Trigger.ON_ENEMY_DRAW, Trigger.ON_OWN_SPELL:
			return "常在"
		Trigger.ON_ATTACK, Trigger.ON_OWN_HP_LOST, Trigger.ON_ALLY_ENTER:
			return "常在"
		Trigger.ON_DEAL_DAMAGE, Trigger.ON_FOE_SAND_RAISED:
			return "常在"
	return ""
