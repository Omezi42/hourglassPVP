# 10.9 対局の記録と分析(GameDesign.md 22章)

| クラス | 責務 |
|---|---|
| `MatchRecordService`(`scripts/net/match_record_service.gd`, static) | 分析用の記録を `match_records/{match_id}` へ1件書き、続けて集計 `stats/global` を増分で更新する。`ReplayService` と同じく `FirestoreClient` を受け取る形にし、対局画面が Firestore を直接叩かない |
| `tools/analyze_matches.py` | 記録を読んで集計し、Discordへ投稿する道具。求めたときだけ動かす |

**記録は `matches/{id}` を読み直して作る。**必要なもの(デッキ30枚・種・手順・両者のuid)は
すべてそこに揃っており、**終局の直前に `ReplayService.mark_finished()` が書き終えている**。
開始時刻 `started_at` も `matches/{id}` の `created_at`(対局が決まって作られた時刻)を写す。
`analyze_matches.py` は `finished_at - started_at` の平均と中央値を出す(切断からの復帰で長く伸びた局があるため中央値も見る)。
`started_at` を持たない記録は、`matches/{id}` が残っていればその `created_at` で補う(`matches` は30件で消えるため、補えるのは残っている間だけ)。
対局画面へ棋譜の写しを持たせる案は採らない——オンライン対戦は自分の手しか手元に残しておらず、
相手の手を含めた並びを正しく持つのは Firestore の側だけであるため。

**先着1件だけを通すのは `create_document()`(`exists:false`)。**両者が書きにいくため、
2件目は必ず失敗する。**この失敗は正常な結果であり、再試行しない。**

**集計を更新するのは、記録を書けた側だけ。**`create_document()` が true を返した側だけが
`stats/global` を触ることで、1局を2回数える経路が構造的に無くなる。更新は
`AccountService.grant()` と同じ流儀で、**`updateTime` を前提条件にした `commit()` で
競合したら読み直して再試行する**(初回だけは `exists:false`)。

**呼ぶのは `CardMatchOutcome.finish()` の中、リプレイの保存の後。**終局後の後始末を1箇所へ
集める既存の役割に乗せる。**`await` しない**——結果パネルの表示を通信で待たせないためで、
これは砂金の付与が既に通っている扱いと同じ。失敗しても画面には何も出さない
(GameDesign.md 22章)。

**CPU戦・観戦・リプレイ再生では呼ばれない。**`finish()` 自体が `_interactive` のときにしか
呼ばれず(観戦・再生を除外)、その中で種別がランク・ルーム(と統合前のランダム)であり
オンラインの `_match_id` を持つ場合だけ記録する(`MatchRecordService.is_recorded_kind()`)。
**ランクマッチの種別キーは `"random"`**(見知らぬ人との対戦。戦績画面の「みんな」が `kind_random` を
ランクマッチとして読む)。

**集計は版で分けず `stats/global` の1件へ通算で貯める**(GameDesign.md 22章)。
カードごとの成績は `cards` の下の map(`{id: {"g": 採用局数, "w": 勝った局数}}`)として持つ。
**1局につき両者のデッキを1回ずつ数える**ため、`games` の2倍が `cards` の分母になる。

**戦績画面(`CardStatsScreen`)は、ヘッダーの主アクションのボタン1つで「自分」と「みんな」を
往復する**(`CardListScreen` の並び替えと同じ流儀)。みんなの側は開いた時点で1度だけ
`stats/global` を読み、結果をセッション内に控える。**読めなかったときはその旨を1行で出す**
(自分の戦績はローカルにあるため、通信できなくても読める)。

## 通過数(GameDesign.md 22章「来た人がどこまで進んだか」)

| クラス | 責務 |
|---|---|
| `FunnelService`(`scripts/net/funnel_service.gd`, static) | 段階を通ったことを端末に控え、`stats/funnel` の日ごとの人数へ1を足す |

**端末の控えは `user://funnel.json`。**`first_day`(初めて起動した日)・`sent`(送り終えた段階)・
`pending`(通ったがまだ送れていない段階 → 通った日)を持つ。`reach()` は `sent` にも `pending` にも
無い段階だけを `pending` へ入れ、続けて送る。**送れたものだけを `sent` へ移す**ため、
送れなかった段階は次の `flush()`(起動時)で送り直される。

**数え始める前から遊んでいた端末は `excluded` を立てて以後どの段階も数えない。**`on_launch()` の時点で
控えに `first_day` が無いのに `UiState.has_seen_home()` が真なら、その端末は以前から遊んでいた人と見なす。

**送り先は `stats/funnel` の1件。**`days` の下に `{"d20260925": {"launch": 3, ...}}` の形で持つ
(キーの先頭を英字にするのは、Firestoreのフィールドパスで数字始まりを避けるため)。
更新は `MatchRecordService._bump_stats()` と同じく **`updateTime` を前提条件にした `commit()`**。
**送信は1本ずつ直列に行う**(起動時に「起動」と「別の日に来た」が同時に立つため、
並べて送ると自分どうしで競合する)。送っている間に立った段階は、次の1本にまとめて送る。

**呼ぶ場所**(いずれも `await` しない):

| 段階(キー) | 場所 |
|---|---|
| `launch` / `return` | `Main._ready()` の `FunnelService.on_launch()` |
| `home` | `Main._show_only()` でホームを出したとき(「ホームを見た」の印と同じ時点) |
| `tutorial_start` | `Main._on_tutorial_requested()` と、初回にタイトルから直行する `Main._on_title_start_requested()` |
| `tutorial_clear` | `CardMatchTutorial._finish()` で勝って終えたとき |
| `tutorial_skip` | 誘導対局の「スキップ」を確かめて閉じたとき(`TutorialSkip`) |
| `match_end` / `online_end` | `CardMatchOutcome.finish()`(種別がCPUか、それ以外か) |
| `online_try` | `Main` のランダム・ランク・ルームの入口 |
| `tutorial_NN` | `CardMatchTutorial._enter_step()`(NN は台本の手順の番号、2桁) |
| `tutorial_skip_NN` | `tutorial_skip` と同時に `FunnelService.reach_tutorial_skip(index)` で立てる(NN は飛ばしたときの手順。端末で最初のスキップだけ数え、合計を `tutorial_skip` と揃える) |
| `ranked_*` | `RankedWaitFunnel`(下記) |
| `daily_puzzle` | `Main._on_puzzle_stage_selected()`(今日の1問を選んだとき) |
| `solo_start` / `solo_again` | `CardSoloMapScreen._on_theme_chosen()`。`solo_start` を既に通っていれば `solo_again` |
| `solo_floor3` | `CardSoloMapScreen._on_destination_chosen()`(選ぶ前の段が3段目以降) |
| `solo_win` / `solo_clear` | `CardMatchSolo._settle()`(勝ったとき / 踏破したとき) |
| `solo_b1_start` | `CardMatchSolo.start()` |
| `solo_b1_win` / `solo_b1_lose` / `solo_b1_quit` | `CardMatchSolo._settle()`。投了は `MatchState.end_reason` が `SURRENDER` で、`SoloBattleRules.decided`(特殊勝利条件で決めた)が false のとき `solo_b1_quit` |
| `solo_b1_quit`(閉じた) | `SoloProgress.load_run()` が `in_battle` のまま残った遠征を負けにしたとき |

`solo_b1_*` は `FunnelService.reach_first_solo_battle(step, floor)` を通し、1段目(`floor == 0`)かつ
`solo_again` をまだ通っていない(=最初の遠征)ときだけ立てる。

**ランクマッチの待機は `RankedWaitFunnel`(`scripts/ui/ranked_wait_funnel.gd`, RefCounted)が追う。**
`CardRankedMatchScreen` が1つ持ち、キューへ参加した時点で `begin()` を呼ぶ。`ranked_wait` をまだ通っていない
(=その端末の最初の待機)ときだけ追い始め、`RANKED_WAIT_SECONDS` の各秒数にタイマーで `ranked_wait_N` を立てる。
成立(`ranked_matched`)・キャンセル(`ranked_cancel`)・通信失敗で `end()` し、以後のタイマーは番号で無効にする
(`WaitingCpuOffer` の予約の取り消しと同じ流儀)。CPU戦のボタンは `ranked_cpu` を立てるだけで追跡は続ける。

**配信先ごとの人数は `portals` の下に `{"itch": {"d20260926": {"launch": 1, ...}}}` の形で、`days` と同じ書き込みで
足す。**配信先は `PortalInfo.site()` が返す(自前の起動部でなければ `unityroom`、起動部ならホスト名と参照元に
`itch` / `plicy` を含むかで見分け、どれでもなければ `other`)。端末の控え(`user://`)は配信先のオリジンごとに
分かれるため、段階を通った時点ではなく送る時点で判定してよい。

**サインインは `FunnelService` が送る直前に `NetSession.sign_in()` で行う。**起動しただけの人にも
匿名アカウントができるが、段階を送るにはどのみちサインインが要る。
`tools/analyze_matches.py --funnel` が `stats/funnel` を読み、期間を指定して段階ごとの人数と
起動に対する割合を出す(段階は順に通るとは限らないため)。

## 1局の時間(GameDesign.md 22章「1局の時間(CPU戦・遠征)」)

| クラス | 責務 |
|---|---|
| `PlayTimeService`(`scripts/net/play_time_service.gd`, static) | CPU戦・遠征の1局ぶんの帯・手数・勝敗を `stats/play_time` の日ごとの数へ足す |

**送り先は `stats/funnel` と分けた `stats/play_time` の1件。**通過数は「端末ごとに初回の1回だけ」、こちらは
「1局ごと」に数えるため、同じ文書に置くと取り違えて読みやすい。起動直後の通過数の書き込みと競合しないためでもある。
`days` の下に `{"d20261009": {"cpu_games": 3, "cpu_wins": 2, "cpu_turns": 61, "cpu_m10": 2, "cpu_over": 1, "solo_games": ...}}` の形で持つ。
帯のキーは `m5` / `m10` / `m15` / `over`(`PlayTimeService.band_key()`)。更新は `FunnelService.send()` と同じく
**`updateTime` を前提条件にした `commit()`**。**端末に控えず、送れなければその1局は捨てる。**
`FunnelService` と同じく書き出した版でだけ送る(開発機の対局を混ぜないため)。

**所要時間は `CardMatchScreen._begin_state()` で控えた `Time.get_ticks_msec()` からの経過**(`elapsed_seconds()`)。
CPU戦・遠征はどちらも `CardMatchCpu` からこの経路で始まる。

**呼ぶ場所**(いずれも `await` しない):CPU戦は `CardMatchOutcome.finish()`(種別がCPUで、誘導対局ではない局)、
遠征は `CardMatchSolo._settle()`。今日の1問は `CardMatchFinale` がどちらも通さないため数えない。
`tools/analyze_matches.py --play-time` が `stats/play_time` を読み、種別ごとに帯の局数と割合・平均手数・勝率を出す。
