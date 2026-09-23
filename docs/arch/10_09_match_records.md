# 10.9 対局の記録と分析(GameDesign.md 22章)

| クラス | 責務 |
|---|---|
| `MatchRecordService`(`scripts/net/match_record_service.gd`, static) | 分析用の記録を `match_records/{match_id}` へ1件書き、続けて集計 `stats/global` を増分で更新する。`ReplayService` と同じく `FirestoreClient` を受け取る形にし、対局画面が Firestore を直接叩かない |
| `tools/analyze_matches.py` | 記録を読んで集計し、Discordへ投稿する道具。求めたときだけ動かす |

**記録は `matches/{id}` を読み直して作る。**必要なもの(デッキ30枚・種・手順・両者のuid)は
すべてそこに揃っており、**終局の直前に `ReplayService.mark_finished()` が書き終えている**。
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
呼ばれず(観戦・再生を除外)、その中で `_cpu_record` が空でありオンラインの `_match_id` を
持つ場合だけ記録する。

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

**送り先は `stats/funnel` の1件。**`days` の下に `{"d20260925": {"launch": 3, ...}}` の形で持つ
(キーの先頭を英字にするのは、Firestoreのフィールドパスで数字始まりを避けるため)。
更新は `MatchRecordService._bump_stats()` と同じく **`updateTime` を前提条件にした `commit()`**。
**送信は1本ずつ直列に行う**(起動時に「起動」と「別の日に来た」が同時に立つため、
並べて送ると自分どうしで競合する)。送っている間に立った段階は、次の1本にまとめて送る。

**呼ぶ場所**(いずれも `await` しない):

| 段階(キー) | 場所 |
|---|---|
| `launch` / `return` | `Main._ready()` の `FunnelService.on_launch()` |
| `home` | `Main._on_title_start_requested()` |
| `tutorial_start` | `Main._on_tutorial_requested()` |
| `tutorial_clear` | `CardMatchTutorial` が最後の段階を終えたとき |
| `match_end` / `online_end` | `CardMatchOutcome.finish()`(種別がCPUか、それ以外か) |
| `online_try` | `Main` のランダム・ランク・ルームの入口 |

**サインインは `FunnelService` が送る直前に `NetSession.sign_in()` で行う。**起動しただけの人にも
匿名アカウントができるが、段階を送るにはどのみちサインインが要る。
`tools/analyze_matches.py --funnel` が `stats/funnel` を読み、期間を指定して段階ごとの人数と
前の段階からの割合を出す。
