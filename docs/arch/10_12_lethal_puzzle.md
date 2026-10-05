# 10.12 リーサルパズル(GameDesign.md 24章)

| クラス | 責務 |
|---|---|
| `PuzzleStageData`(`scripts/data/puzzle_stage_data.gd`, Resource) | 1問の初期配置。盤面の駒は **`"id:体力:攻撃力"` の文字列**で持つ |
| `PuzzleLibrary`(`scripts/logic/puzzle_library.gd`, static) | `data/puzzles/` を走査して `order` 順に返す。`CardLibrary` と同じ流儀(`.remap` の扱いを含む) |
| `PuzzleProgress`(`scripts/logic/puzzle_progress.gd`, static) | クリア記録。`user://puzzle_progress.json` へアカウントごとに持つ |
| `CardMatchPuzzle`(`scripts/ui/card_match_puzzle.gd`, RefCounted) | 局面の差し替えと正誤の判定。`CardMatchOnline` と同じ `_screen` 参照の切り出し |
| `CardChallengeResult`(`scripts/ui/card_challenge_result.gd`) | ソロモード(10.15節)と共用の結果パネル。中身は呼び出し側が `CardChallengeResult.Outcome` に詰めて渡し、パネルは並べ方とボタンの主従(GameDesign.md 24章の表)だけを持つ。高さは中身に合わせて1コマ後に決める(折り返す説明文の高さがそれまで確定しないため) |
| `StageReward`(`scripts/logic/stage_reward.gd`) | 初回クリアで渡したもの(砂金・控えたか・カードセット・アイコン・解き直しか)。結果パネルが札にして並べるため、文ではなく中身で返す |
| `ResultPanelFrame` / `ResultSandFall`(`scripts/ui/`) | 結果パネルの質感と舞い落ちる砂。`CardMatchResult` と `CardChallengeResult` が共有する |
| `CardPuzzlePickerScreen`(`scripts/ui/card_puzzle_picker_screen.gd`) | ステージ選択。共通ヘッダー + 横2列のグリッド |

**専用の対局画面(`CardPuzzleScreen`)は作らない。**盤面・手札・演出・ログはすべて
`CardMatchScreen` のものをそのまま使い、パズル側は「固定の局面を作る」「解けたかを見る」
だけを持つ。誘導対局(4.1.5節)と同じ理由で、**専用モードを作ると対局のルールが2箇所へ
分かれて食い違う余地が生まれる**。

**局面は `MatchState` を普通に作ってから差し替える**(ルール画面の教材の盤面と同じ作り方。
4.2節)。置いた駒は `summoned_this_turn` を下ろす——そのままだと反転も攻撃もできず、
どの問題も解けない。

> **`start()` は局面を作ってから `_stage` を覚える。**`_begin_state()` は画面の後始末
> (`_reset_for_new_match()`)を通り、そこで `close()` が `_stage` を消す。先に覚えると
> その場で消え、**判定が一切働かない**(実際にそうなり、結果パネルが出なかった)。

**画面側へ足したのは3つだけ**:`puzzle` プロパティ(`CardMatchScreen` は公開メソッドの
上限に張り付いているため、入口はメソッドではなくプロパティにした)、`_perform()` の
1手ごとの判定、`_on_match_ended()` の分岐。**パズルではリプレイも砂金も戦績も残さない**
(`_match_kind` は `NONE`)。

**問題が解けることはテストで確かめる**(`tools/tests/puzzle_mission_tests.gd`)。
問題ごとの解答手順を持ち、`MatchState` へ直接流して相手のHPが0になることを見る。
**データが読めることだけを見て終えると、届かない問題を出荷してしまう。**

## 10.12.1 エンドレスモード(同梱の問題集・GameDesign.md 24章)

| クラス / ファイル | 責務 |
|---|---|
| `EndlessPuzzles`(`scripts/logic/endless_puzzles.gd`, static) | 問題集を1度だけ読み、直前に出した問題を避けてランダムに1問を `PuzzleStageData` で返す |
| `data/endless_puzzles.json` | エンドレスの問題集。1問ごとに `stage`(`PuzzleStageData` と同じ項目)・`solution`(`MatchAction` の配列)・`metrics` を持つ。**`make_short.py forge-endless <問数>` が書き足す**(手で作らない) |

**出題のたびに問題を作らない。**問題探し(`tools/shorts/puzzle_forge.gd`)は総当たり
(`puzzle_solver.gd`)で最大打点と難しさを測るため、デスクトップでも1回の試行に0.1〜数十秒かかり、
基準に通るのは数十〜数百回に1問。Web書き出しで押すたびに回すのは無理なので、手元で並列に回して同梱する。
問題探しはとどめ問題と共通で、出力先だけが違う。**問題探しは両方の問題集にある盤面を避ける**
(エンドレスと今日の1問を重ねないため)。

**JSONのままpckへ入れる。**`.tres` を数百個置くより1ファイルの方が扱いやすい。リソースではないため
`export_presets.cfg` の `include_filter` に載せる。読むのは `FileAccess`(`.remap` は付かない)。
JSONを通ると整数が小数になるため、`PuzzleStageData.from_dict()` で型を戻す。

**問題集の各問が解けることはテストで確かめる**(`tools/tests/endless_puzzle_tests.gd`)。
全問を正解手順で `MatchState` へ流して相手のHPが0になることと、今日の1問の問題集と重ならないことを見る。

**エンドレスの問題は進捗を持たない。**`PuzzleProgress` を触らず、`CardMatchPuzzle` は
`start(target, endless)` の第2引数でこれを区別し、`endless` のときは `_grant()` を呼ばない。
結果パネルの「次の問題へ」は、エンドレスなら `EndlessPuzzles.next()`、固定の問題なら
`PuzzleLibrary` の並びで次の問題を始める。

## 10.12.2 今日の1問(GameDesign.md 24章)

| クラス / ファイル | 責務 |
|---|---|
| `DailyPuzzle`(`scripts/logic/daily_puzzle.gd`, static) | 日本時間の今日の日付を決め、`data/daily_puzzles/<YYYY-MM-DD>.tres` を引く。無ければ null |
| `data/daily_puzzles/*.tres` | 1日1問の `PuzzleStageData`。**`tools/shorts/schedule.py` が投稿の割り振りから書き出す**(手で作らない) |

**問題は固定の問題と同じ `PuzzleStageData` で持ち、解く経路も同じ**(`CardMatchPuzzle.start(stage)`)。
id を `daily_<日付>` にして `PuzzleProgress` へそのまま記録するため、初回クリアの判定と50砂金の渡し方は
固定の問題と共通になる。所属の行と「次の問題へ」を出さない分岐だけを `DailyPuzzle.is_daily()` で見る。

**同梱する(Firestoreから引かない)。**unityroomへはpckだけを上げるが、`.tres` はpckへ入るため届く。
数週間先まで割り振っておき、ビルドのたびに一緒に出る。ファイルの有無は `ResourceLoader.exists()` ではなく
`DirAccess` の一覧で見る(Pitfalls.md。書き出した版では `.remap` が付く)。

**問題が解けることはテストで確かめる**(`tools/tests/daily_puzzle_tests.gd`)。同梱した各日の問題を
問題集 `tools/shorts/puzzles.json` の正解手順で `MatchState` へ流し、相手のHPが0になることを見る。

