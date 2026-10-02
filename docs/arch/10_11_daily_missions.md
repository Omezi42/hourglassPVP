# 10.11 デイリーミッション(GameDesign.md 23章)

| クラス | 責務 |
|---|---|
| `DailyMissionData`(`scripts/data/daily_mission_data.gd`, static) | 課題の表(id・数え方・目標・文言・報酬)と数え方の enum(`Metric`) |
| `DailyMissionService`(`scripts/net/daily_mission_service.gd`, static) | 日付判定・進捗・受取。`user://daily_missions.json` へ**アカウント(uid)ごとに**貯める |
| `DailyMissionPanel`(`scripts/ui/daily_mission_panel.gd`) | 確認と受取のモーダル。ホーム画面が最初に開いたときだけ作る |

**課題は Resource ではなくコードの表で持つ。**カード(`.tres`)と違って Inspector から
編集する余地が無く、`Metric` とコードが1対1で対応する。1件足すのは `all()` へ1行足すだけ。
**`Metric` の並びは保存データではない**(進捗は課題の id をキーに持つ)。

**進捗は `MatchState` のシグナルだけで数える。**`DailyMissionService.watch(state, my_side)` を
`_begin_state()` から張り、`unit_flipped` と `flip_right_used`(使った側 `actor_side` で数える)/ `spell_cast` / `unit_played` / `attack_performed` と、
落砂のために足した **`trigger_fired(side, trigger)`** を数える。`trigger_fired` は
`MatchState._fire()`(効果の解決を1箇所へ通す私設のヘルパ)が、**効果を持つ駒のときだけ**出す。
呼び出し側へ数える処理を配ると、トリガーを足すたびに書き漏らす。

**数えたぶんは終局まで書かない**(`commit()`)。10手に満たない対局は数えないため、
対局中に書き込むと取り消せない。書くのは `CardMatchOutcome.finish()` の1箇所で、
**戦績(`MatchStats`)と同じ行に並べる**。観戦・リプレイ再生は `_interactive` が false で
`watch()` を張らない。パズルは `finish()` へ到達しないため数えない。

**受取だけは通信を要する**(`AccountService.grant()`)。残高はアカウントにあり、
手元で受取済みにすると権利だけが消える(ショップと同じ扱い。10.8節)。

## はじめの7日(GameDesign.md 23章)

| クラス | 責務 |
|---|---|
| `WelcomeDays`(`scripts/net/welcome_days.gd`, static) | 日ごとの受け取るもの(`reward_for(day)`)・今日受け取れるか(`can_claim_today()`)・受取(`claim()`)。受け取った日数と最後に受け取った日(日本時間)は `players/{uid}` の `welcome_days` / `welcome_last_date` に持つ |
| `WelcomeDaysPanel`(`scripts/ui/welcome_days_panel.gd`) | ホームに重ねる受取の札。`Main` がホームを出したときに `WelcomeDays.can_claim_today()` を見て開く |

**受取は `players/{uid}` への1回の `commit()`(`updateTime` の前提条件付き)で、日数・日付・砂金をまとめて書く。**
`AccountService.grant()` と別に書くと、片方だけ通ったときに権利か砂金のどちらかが消える。
競合したら読み直して、今日のぶんがもう書かれていれば何もしない(2つのタブで同時に押した場合)。
7日目のアイコンは `AccountService.unlock_icon()`(既に持っていれば何もしない)。
日付の境目は `DailyMissionService.today()`(日本時間)を使う。
CPU戦の結果パネルの1行は `WelcomeDays.tomorrow_line()` が返し、空文字なら出さない。
