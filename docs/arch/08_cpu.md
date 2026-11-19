# 8. CPU戦の実装方針

- CPUの思考は `CardCpuStrategy`(`scripts/logic/card_cpu_strategy.gd`、`RefCounted`)へ切り出し、
  `CardMatchScreen` は思考の中身を知らずに `choose_action(state, side) -> Dictionary` を呼ぶだけにする
- 1手番の中の順序は「場に出す → 攻撃する → 反転する → 終える」の貪欲法。**攻撃してから
  反転する**のが要点で、逆にすると攻撃力の高い状態を捨ててしまう。価値の物差しは
  `CardInstance.lifetime_damage()`(GameDesign.md 1章)を使う
- **砂術は「出す」の中で一緒に選ぶ。**1手番の順序へ新しい段を足さず、`_choose_play()` が
  手札の砂時計と砂術を同じ物差し(生涯ダメージ)で比べる。砂時計は `_card_value()`、
  砂術は **1手読み**(`CardCpuSpellSearch`、`scripts/logic/card_cpu_spell_search.gd`、static)で測る:
  - 写しの盤面(`SpellForecast.fork()`)へ対象の候補ごとに実際に撃ち、**その手番の攻撃を `_choose_attack()` で
    続けた盤面**を、撃たずに攻撃だけ続けた盤面と比べた差を価値とする。撃った直後だけで比べると、
    除去で守護をどけて本体を殴る・削ってから仕留める価値を拾えず、旧来の見積もりとほぼ差が出なかった
    (`docs/BalanceReport_v5.md` 17章)。効果の種類ごとの見積もりを書かないため、砂術を足しても変えずに済む
  - 盤面の評価(`evaluate()`)は、駒の生涯ダメージ+キーワード・繰り返し効果、HPの差×本体の重み(`_face_weight()`。
    上級は上級の重み)、自分の手札と反転権。**相手の手札は中身が分からないため数えない**
  - ランダムな対象を取る砂術は、写しの乱数を引き直して `RANDOM_SAMPLES` 回の平均を見る(乱数の先を覗かないため)
  - **対象を取る砂術は、対象が1体もいなければ撃たない**(自動選択に任せると、対象のいない除去を無駄撃ちする)
  - **自分の砂時計を対象に取る砂術は、その駒がまだ攻撃できるなら攻撃の後(`_choose_play(…, true)` の段)へ回す**
    (`_defer_until_attacked()`。「攻撃してから反転する」と同じ理由)。この後段では、反転済みの駒を戻すカードに加えて
    砂術すべてを見直す
  - **温存の閾値は持たない。**得が0以下の砂術(満タンでの回復・対象のいない除去等)は撃たれずに残る。
    閾値を足すと弱くなった(17.1節)
  - 撃たない場合の評価は手札の砂術すべてで同じため、同じ盤面のあいだは1度だけ測る(`_baseline`)
  - `spell_lookahead = false` で旧来の効果ごとの見積もり(`_spell_value()`)へ戻る。**新旧を自己対戦で比べるためだけに残す**
    (`tools/balance/run_cpu_spell_ab.gd`。`run_v5_simulation.gd spell_lookahead=0`)
- **反転権(GameDesign.md 2章)は2箇所に分けて検討する。**片方だけでは
  「体力を残したまま弱めて、攻撃力を相手へ渡すだけ」になり実質使われない置物になると
  実測で分かったため(`docs/BalanceReport_v5.md` 12.2節)、攻撃とセットの1手を別に持つ。
  - **`_choose_flip_right_setup()` は攻撃より前(`_choose_attack()` の手前)に検討する。**
    いま持っている最大攻撃力ではまだ倒せない相手が、反転させれば(新しい体力 = 相手の
    いまの攻撃力)倒せるようになる場合だけ反転権を使う。使った直後の `choose_action()` の
    再評価で `_choose_attack()` が普通に仕留める——**反転権と攻撃が2手にまたがる連携として
    自然に繋がる**のは、`choose_action()` が1手ごとに盤面を読み直す貪欲法だからこそ成立する
  - **`_choose_flip_right()`(通常の反転の次)は、自分の駒を得な状態へ戻す案と、
    相手の駒を確実に破壊できる(反転させた結果その場で体力が0になる)場合だけを見る。**
    それ以外の「相手を生かしたまま弱める」使い方は上の `_setup()` の役目であり、
    ここでは扱わない(扱うと同じ相手を二重に検討することになる)
  - **どちらも、敵の駒に反転トリガー(グロウ/ホイール/ティック/ページ)があれば触らない**——
    誰が反転させても持ち主を利する形で発火するため(GameDesign.md 6章)。破壊する場合の
    余砂(ON_DEATH)は、`_choose_flip_right()` 側(反転そのもので破壊する経路)だけ避ける。
    `_setup()` 側は攻撃の一撃で破壊するため、他の除去と同じく余砂は避けない
    (`_choose_attack()` も攻撃で殺す際に余砂を避けていないため、ここだけ特別扱いしない)
  - **希少な資源のため `FLIP_RIGHT_MIN_GAIN` 未満の得なら温存する**(`_choose_flip_right()`
    のみ。`_setup()` は「倒せるかどうか」の二値なので閾値を持たない)。コインと同じく
    使えたかどうかは `use_flip_right()` の戻り値だけで判断する(4.5節・3.1.2節)
  - **`_setup()` を足す前は、確実に破壊できる好機自体が少なく、反転権はほとんど
    使われなかった。**足した後は先手2・後手3で5指標すべてが目標圏へ収まることを確認した
    (`docs/BalanceReport_v5.md` 12.4節)
- マリガンの選択は `choose_mulligan()` が持つ(コスト4以上を戻す)
- CPUの手番になったら `CardMatchCpu`(4.0節)が `CPU_THINK_SECONDS` の間合いを置いてから
  1手だけ適用し、また間合いを置く。**まとめて指すと何が起きたか追えない**ため1手ずつ進める
- 適用の経路は自分の手・オンラインの手・リプレイ再生と同じ `MatchAction.apply()`。
  CPUのためだけの経路を作らない
- CPUのデッキは `CardCpuDecks`(`scripts/logic/card_cpu_decks.gd`、static)の表から `pick(rng)` で1つ選ぶ
  (GameDesign.md 13章)。戻り値は `{"name": String, "cards": Array}`。表の1行は id・名前・狙い・
  `preset`(`CardPresetDecks` のid。中身を二重に持たないため)か `cards`(id → 枚数)のどちらかを持ち、
  組み立ては `CardPresetDecks.build()` を共用する。**`CardPresetDecks` と同じく表として持ち `.tres` にしない**
  (デッキはカードの参照の並びにすぎず、プリセットと流儀を揃えるため)。
  相手の名前は `"CPU ・ " + name` として `start_cpu_match()` の `foe_name` へ渡す。「もう一度」(`CardMatchCpu.rematch()`)も引き直す
- 表の健全さは `tools/tests/cpu_deck_tests.gd` が見張る:全行が補充(`_fill`)なしでちょうど30枚になる・
  同名2枚まで・`price == 0` のカードセット(ソロモード限定。10.15節)のカードを含まない。
  カードを消したり枚数の制限を変えたりしたときに、黙って別の中身へすり替わるのを防ぐため
- デッキどうしの強さの釣り合いは `tools/balance/run_cpu_deck_league.gd` で測る(総当たり・ランダム混成相手。
  `trial=id,...` で表を変えずに候補の15種を測れる)。表を変えたら回し、`BalanceReport_v5.md` 13章を更新する
- 誘導対局のときだけ台本(`TutorialScriptData`、4.1.5節)の山札を切らずに使う(GameDesign.md 18章)
- CPU戦はオンライン対戦ではないため、`matches/{match_id}` への書き込みは行わない。棋譜も残さない(GameDesign.md 12章)

## 8.1 CPU戦の思考レベル(GameDesign.md 13章)

- `CardCpuStrategy.Difficulty`(`BEGINNER` / `NORMAL` / `EXPERT`)を持ち、`difficulty` プロパティ
  (既定 `NORMAL`)で切り替える。**既存の全ロジックは `NORMAL` としてそのまま残す**——
  反転権の検証(`docs/BalanceReport_v5.md` 12章)が `NORMAL` 相当で行われているため、
  この段を動かすとバランス指標が総崩れになる
- **`BEGINNER` は別経路 `CardCpuBeginner`(`scripts/logic/card_cpu_beginner.gd`、static)を通る**。既存の `choose_action()` の
  貪欲法(価値計算)を一切通さず、
  - 出す:手札を先頭から見て、出せる最初の1枚をそのまま出す(価値比較をしない)。
    対象を1体取る効果は `_random_target()` でランダムに選ぶ
  - 攻撃:攻撃できる駒と、選べる対象(本体を含む)をそれぞれランダムに選ぶ
    (`CardCpuBeginner._choose_attack()`)。守護がいれば無視できないのは `attackable_slots()` が
    通常どおり返す集合のままなので、ここでの分岐は要らない
  - 反転・反転権:呼ばない。使わせないことがそのまま弱さになるため、判定自体を削る
- **`EXPERT` は `NORMAL` の関数へ軽い分岐を足すだけに留め、新しい探索を書かない**
  (GameDesign.md 13章「複数手先の探索は行わない」)。強さは `run_cpu_deck_league.gd levels=expert,normal`
  で測る(対中級70%前後。勝ち越しのほぼすべてを攻撃の2つが生み、残りはほぼ中立)。追加する評価軸は7つ:
  - `_choose_attack()`:攻撃できる駒の攻撃力の合計(倍撃は2倍)が相手の残りHP以上で本体を
    狙えるなら、1体ずつ本体を殴る(`_expert_lethal_attack()`)。中級は1体で削りきれるときしか気づかない
  - `_choose_attack()`:本体を殴る価値に `EXPERT_FACE_WEIGHT_RATIO` を掛ける(`_face_weight()`)。
    中級の `FACE_WEIGHT` はバランス指標に合わせた値で、勝ちに対しては盤面を取りすぎる。
    **「次の手番の被害を見て本体を控える」割引は、入れると弱くなる(実測)ため持たない**
  - `_choose_attack()` / `_trade_value()`:相打ちで自分の守護持ちが失われる場合、
    その駒が場に残ることで防いでいた被弾ぶんを割り引く(`_expert_guard_retention_penalty()`)。
    後続のターンで本体・他の駒が守護無しの被弾を受けやすくなることの近似
  - **反転には上級だけの分岐を置かない**(GameDesign.md 13章「中級と同じ」)。
    得な反転(攻撃力が体力を上回る駒)は体力を増やすため、反転したせいで仕留められる形は生じない
  - `choose_mulligan()`:中級以下はコストの上限だけで戻すが、上級は**残す手札の
    コスト1〜2の枚数**を見て、それが少ないほど重いカードをより積極的に戻す
    (`_expert_mulligan_threshold()`)。**「通常の反転が使えない駒を反転権で戻す」は
    `NORMAL` の `_choose_flip_right()` が既に行っており(この戦闘システムは常に
    1対1の相打ちで、複数体の合計攻撃力という概念が無いため拡張の余地が薄い)、
    上級専用の追加候補から外した**
  - `_effect_target()`:ダメージを与える効果(`DAMAGE_UNIT`)は、硝子が残っている
    駒を候補から外してから最善の1体を選ぶ(`_expert_damageable_enemy()`)。
    **確定破壊(`DESTROY_UNIT`)は硝子を無視して通るため対象外**(`destroy_unit()` は
    ダメージ処理を経由しない)。中級は効果の種類を見ずに「生涯ダメージが最大」だけで
    選ぶため、硝子で無効化される一撃を選ぶことがある
  - `_best_slot()`:このカードを出した残りマナで、他に何も出せなくなる出し方に
    わずかなペナルティを掛ける(`_mana_leftover_penalty()`)。端数のマナを1〜2残す
    ような出し方をわずかに優先する程度に留め、コストの分布次第で逆転しない範囲の値にする
  - `_should_use_coin()`:中級は「あと1マナ足せば出せる手がある」だけで切るが、
    上級は**コインを使った場合に出せる中でいちばん高い1枚の価値**と、
    **使わずに温存した場合にいま出せる中でいちばん高い1枚の価値**を比較し、
    前者が上回るときだけ切る(`_expert_should_use_coin()`)
- **難易度はCPU自己対戦のバランス検証(全体指標・カード別勝率)の対象にしない**。
  検証は常に `NORMAL` で行う(GameDesign.md 7章の指標は `NORMAL` の値のまま)
- 誘導対局(4.1.5節)ではCPUの思考を使わず、台本の手を返す指し手を `_cpu` に差す(GameDesign.md 18章)

## 8.2 CPU戦の思考レベル選択画面と詳細設定(GameDesign.md 13章)

| クラス | 責務 |
|---|---|
| `CardCpuDifficultyPicker`(`scripts/ui/card_cpu_difficulty_picker.gd`) | 初級/中級/上級を選ぶモーダル。押すと保存済みの詳細設定を添えて `picked(settings)` を出す。下に「詳細設定」と、変えた項目の1行(`CardCpuSettingsPanel.summary_of()`) |
| `CardCpuSettingsPanel`(`scripts/ui/card_cpu_settings_panel.gd`) | 詳細設定の「◀ 値 ▶」の行を並べるモーダル。`CardCpuDifficultyPicker` の子として上に重ねる。「決める」で保存、「戻る」で捨て、どちらも `closed` |
| `CpuMatchSettings`(`scripts/logic/cpu_match_settings.gd`、`RefCounted`) | 詳細設定の値(先手/後手・相手のデッキ・速さ・両者のHP・マリガン・コイン・手札を見せる)と `user://cpu_match_settings.json` への保存。`is_practice()`・`first_side(rng)`・`pick_foe_deck(rng)` を持つ |

- 2つのモーダルは暗幕+`content_panel.tres`の中央パネルという既存パターン(`SettingsPanel`等)を踏襲する
- **CPU戦のときだけ**、デッキ選択(`CardDeckListScreen.open_pick()`)の直後に `CardCpuDifficultyPicker` を開く。
  `Main._start_cpu_match()` の直前に一度だけ開く(デッキ選択とモーダルの2段を
  `_pending_battle` の1つのCallableへ畳み込むと分岐が読みにくくなるため、
  CPU戦の入口関数側で明示的に1段追加する)
- 思考レベルは `CardCpuDifficultySave`(`user://cpu_difficulty.json`)が持つ(`CardCpuStrategy.resolve_difficulty()` と待っている間のCPU戦が読むため)。
  それ以外の値を `CpuMatchSettings` が持つ。どちらも `CardDeckSave` と同じ「Autoloadを使わずstaticで持つ」流儀
- 相手のデッキは文字列のキーで持つ:空文字がランダム、CPUデッキのid、`own:N`(保存デッキの位置)。保存デッキが消えて位置が無くなったらランダムへ落とす
- **設定は `CardMatchScreen.start_cpu_match()` の引数 `settings` で渡す。**省略(null)なら従来のCPU戦と同じ(待っている間のCPU戦・誘導対局が使う)。
  `CardMatchCpu.start()` が先手・マリガン・コインを `_begin_state()` へ渡し、HPを `MatchState.hp_max` と `hp` へ直に当て(遠征と同じく `hp_changed` は出さない)、
  速さ・練習・手札の公開を画面の `_cpu_settings` に控える。「もう一度」(`rematch()`)も同じ `settings` を渡す
- **最大HPは `MatchState.hp_max`(側ごと)が持つ。**`heal_player()` の上限と砂術「HPの反転」の基準はこれを読む。
  遠征(`SoloBattleRules.apply()`)も最大HPをここへ入れ、情報帯の器の大きさも `hp_max` から取る
- 練習の対局は `CardMatchOutcome.finish()` が戦績・1局の時間・デイリー・砂金を飛ばし、結果パネルへ理由の1行だけを返す
- 手札を見せる対局では、相手の情報帯の `gui_input` を `CardMatchBuild` で受け、手札の山(`PlayerInfoBar.hand_pile_rect()`)を押したら
  `CardPileViewer.open_pile()` で一覧を開く(帯に分岐を足さない。`player_info_bar.gd` が行数の上限に近いため)
- 誘導対局・リプレイ再生・遠征・待っている間のCPU戦はこの画面を通らない
