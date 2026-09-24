# 10.16 ランクマッチ(GameDesign.md 28章)

**新しいマッチングプールを1本追加するだけで、対局そのものの仕組みは一切変えない。**
`MatchState`・`OnlineMatch`・`MatchAction` はルームマッチと完全に共用し、
ランクマッチ固有なのは「マッチングの入口」と「終局後に段位を更新する処理」の2箇所だけ。

| クラス | 責務 |
|---|---|
| `RankRules`(`scripts/logic/rank_rules.gd`, static) | 段位表・星の必要数・レートの増減表(GameDesign.md 28章の表そのもの)を1箇所に持つ |
| `RankedMatchmakingQueue`(`scripts/net/ranked_matchmaking_queue.gd`) | `MatchmakingQueue`のコレクションを`ranked_queue`へ差し替える(6.1節の原子的マッチ成立・募集通知をそのまま使う)。ホームへ出す待機人数も `count_waiting()` で数える(自分を除く・古い待機者を除く・同じビルドだけ) |
| `CardRankedMatchScreen`(`scripts/ui/card_ranked_match_screen.gd`) | 待機画面(6.6節) |
| `RankProgress`(`scripts/logic/rank_progress.gd`, static) | `players/{uid}`の段位フィールドを読み書きする。シーズン切り替えの判定もここに集約する |
| `CardRankScreen`(`scripts/ui/card_rank_screen.gd`) | 現在の段位・レートの表示と、ランキング一覧 |

## `players/{uid}` へ足すフィールド

| フィールド | 型 | 内容 |
|---|---|---|
| `rank_season` | String | 最後にプレイしたシーズン(`"2026-09"`のような月キー、JST基準) |
| `rank_tier` | String | `"bronze1"`〜`"gold5"`、または`"platinum"` |
| `rank_stars` | int | ブロンズ〜ゴールドの間だけ使う星の数 |
| `rank_rating` | int | プラチナ以降のレート。ブロンズ〜ゴールドの間は未使用(0のまま) |
| `rank_peak_tier` | String | そのシーズン中に到達した最高段位。月末報酬の判定に使う |
| `rank_reward_claimed_season` | String | 月末報酬を受け取り済みのシーズン。`rank_season`と一致していれば受取済み |
| `rank_progress_score` | int | 帯・階級・★・レートを1本の順序へ束ねた合成スコア(`RankRules.progress_score()`)。ランキングの並び順そのもの |
| `rank_win_streak` | int | 現在の連勝数。勝利で+1、敗北で0へ戻す。連勝ボーナス(GameDesign.md 28章)の判定に使う |

## シーズン切り替えは「サーバー側の一括更新」を持たない

**Cloud Functionsで全プレイヤーを月初に一括リセットする方式は採らない。**この作品は
常駐サーバーを持たず、`players/{uid}`は数万件規模になりうるため、全件を書き換える
バッチ処理は10章の方針(サーバーレス・自前サーバーなし)と相性が悪い。

代わりに、**各プレイヤーのドキュメントは、次にそのプレイヤーが遊びに来た時点で
自分自身を新シーズンへ切り替える(遅延リセット)**。`SundayEventRules.is_active()`が
クライアントのローカル時刻だけで日曜判定を完結させているのと同じ考え方。

- `RankProgress.ensure_current_season(profile)` を、ランクマッチへ入る直前と
  ランク画面を開いた直後の2箇所で呼ぶ
- 現在の月キー(JST)と`rank_season`が異なれば、**まず旧シーズンの月末報酬が
  未受領なら`rank_peak_tier`をもとに付与し**(`AccountService.unlock_free()`と
  同じ「`updateTime`前提の`commit()`」の形。10.8.1節)、そのうえで
  `rank_tier = "bronze1"` / `rank_stars = 0` / `rank_rating = 0` /
  `rank_peak_tier = "bronze1"` / `rank_season = 今月のキー` へ書き換える
- **この方式の既知の限界:今月まだ一度もログインしていないプレイヤーは、
  ランキング一覧上は前シーズンのレートのまま表示され続ける。**月初に総当たりで
  正すことはしない(上記の理由)。ランキング画面は「現在の月キーを持つドキュメントだけを
  対象に集計する」ことで、少なくとも新シーズンの上位表示に古いレートが紛れ込まないようにする

## 段位の更新

`CardMatchOutcome`(10.7節)へ、通常の砂金・戦績付与の後段として
`RankProgress.apply_result(uid, won)` を足す。**`_match_kind == RANKED` のときだけ**
呼ぶ(`MatchKind`に`RANKED`を1つ追加する。既存の`RANDOM`/`ROOM`と同列)。

- `rank_tier`がブロンズ〜ゴールドの間:勝利で`RankRules.star_gain(streak_after_win)`
  (連勝ボーナス込みの★増分。GameDesign.md 28章「連勝ボーナス」)ぶん★を増やし、
  敗北で`RankRules.retreat_stars()`(-1、下限0)。必要数に達したら次の段位・階級
  (無ければ次の帯)へ進める。ゴールド5から必要数を満たしたら
  `rank_tier = "platinum"` / `rank_rating = 1000`にする
- `rank_tier == "platinum"`:`RankRules.rating_delta(rating, won)`(28章の表)を見て
  加減する。**下限は設けない**(GameDesign.md 28章「レートが1000を下回っても降格しない」)。
  **連勝ボーナスはここでは効かない**(GameDesign.md 28章「プラチナには適用しない」)
- **連勝は`players/{uid}.rank_win_streak`(int)で持つ。**勝てば+1、負ければ0へ戻す。
  `RankRules.star_gain(streak_after_win)`は、この勝利を含めた連勝数が
  `WIN_STREAK_BONUS_THRESHOLD`(3)以上のとき+1(合計+2)、それ未満は+1を返す。
  シーズンが切り替わるとき(`ensure_current_season()`)は他の段位の値と同じく0へ戻す
- 昇格・レート変動のたびに`rank_peak_tier`を「いまの段位のほうが高ければ」更新する
  (`RankRules.compare_tier()`で比較。星取り帯どうしはブロンズ<シルバー<ゴールド<プラチナの順、
  プラチナ内はレートの最高値を別途`rank_peak_rating`として持たず、`rank_peak_tier`は
  `"platinum"`に達した事実だけを記録すれば足りる。月末報酬が段位区分だけを見るため)

## マッチングとレート操作対策

`RankedMatchmakingQueue`はv1では段位を考慮せず、`MatchmakingQueue`と同じ
「早い者勝ち」でマッチさせる。**マッチング精度(近い段位同士を優先する)の改善は
次のステップ**とし、いまは「ランクマッチという専用の入口がある」ことを優先する。

**レートの吊り上げ対策は、15章「不正な稼ぎ方への線引き」と同じ関数を通す。**
`CurrencyRules`が持つ「総手数10手未満は報酬対象外」の判定(`MatchState.turn_count`)を
`RankProgress.apply_result()`の入口でも見て、**10手未満の対局は段位も動かさない**
(自己対戦の繰り返しで手軽にレートを吊り上げる経路を塞ぐ)。**同一相手との連戦を
検知する仕組みは持たない**(キューはそもそも相手を選べないため、
結託した2アカウントが繰り返し対戦する形でしか成立せず、既存の
不正対策の範囲を超える。必要になった時点で別途検討する)。

## ランキング画面

`CardRankScreen`は、自分の段位・星(またはレート)を大きく表示し、下に現在シーズンの
参加者一覧を出す。**ブロンズ〜プラチナまで全員を1本のランキングへ並べる**(GameDesign.md 28章)。

**帯・階級・★・レートを1つの合成スコアへ束ねる。**星取り制の段位はレートのような
一意の順序を持たないため、そのままでは"参加者一覧"に混ぜても意味を持つ順序にならない。
**帯・階級・★を積み上げた整数、プラチナはその上に
レートを載せた整数として1本の順序へ変換すれば、全員を比較できる**——これが
`RankRules.progress_score(tier_key, stars, rating)`。

```
非プラチナ: BRACKET_ORDER.find(bracket) * 100 + step * 10 + stars
プラチナ:   PROGRESS_SCORE_PLATINUM_BASE(100000) + rating
```

**`PROGRESS_SCORE_PLATINUM_BASE` は非プラチナの最大値より十分大きく取る**ことで、
プラチナの誰よりも下位の帯が上に来ることはない。この値は`players/{uid}`へ
`rank_progress_score`(int)として持たせ、`RankProgress.apply_result()`と
`ensure_current_season()`が段位・★・レートを書くたびに合わせて書き直す
(`AccountService.rank_progress_score()`で読む)。

**取得は`players`コレクションを`rank_season == 今月のキー`の単一フィールドの
等価フィルタで絞り込み、`rank_progress_score`降順に並べる**(6章のクエリ方針にある
単一フィールドの等価フィルタ+単一の`orderBy`に収まる。以前の`rank_tier == "platinum"`
との複合フィルタより単純になった)。一覧の各行は、プラチナなら数字のレート、
それ未満なら「ゴールド3 ★4」のように帯の表示名と★を出す(`CardRankScreen`が
`rank_tier`を見て分岐する)。

## unityroomランキング連携

unityroomのランキングAPI(`POST /gameplay_api/v1/scoreboards/{boardNo}/scores`、
HMAC-SHA256署名)は「そのボードへ今回のスコアを送る」だけの一方向のAPIで、読み出し口は
公開されていない。したがって**ゲーム内の`CardRankScreen`をunityroom側の値で
置き換えることはできない**。「スコアの更新(上書き)」を許すかどうかはボードごとの
記録方式(降順ハイスコア/昇順ハイスコア/常に記録)として**unityroom側のゲーム管理画面**が
持っており、APIのリクエスト自体はどのモードでも同じ(サーバー側が保存するかどうかを
判断し、結果を`{"saved": bool}`で返す)。

**採用した方針**:ゲーム内ランキング(`CardRankScreen`)を主としたまま、**unityroom側へは
プラチナのレートが動くたびに追加で送る**(そのゲームページへ来た人が見る、公開された
副次的なランキングという位置づけ。10.16節「連携できない場合はゲーム内ランキングのみで
運用する」の中間案)。

| クラス | 責務 |
|---|---|
| `UnityroomRankingClient`(`scripts/net/unityroom_ranking_client.gd`, staticのみ) | HMAC署名の組み立てとスコア送信。Web書き出しでのみ動く(`OS.has_feature("web")`) |

- **鍵は`data/unityroom_hmac_key.txt`に置き、`.gitignore`で管理外にする**
  (`QueueNotifier`のDiscord Webhook URLと同じ扱い。6.3節)。Web書き出しの時点で
  クライアントへ埋め込まれるため元々秘匿はできないが、公開リポジトリへコミットする
  理由も無いため同じ扱いにする。`export_presets.cfg`の`include_filter`・
  `tools/ensure_export_filters.py`・`tools/verify_web_pck.gd`のいずれにもこのファイルを追記済み
- **署名はGodot組み込みの`HMACContext`だけで計算する**(外部ライブラリ不要)。
  鍵はbase64、署名元文字列は`"POST\n{path}\n{unixTime}\n{scoreText}"`、結果は16進文字列。
  手順はGodot用の非公式unityroom SDK(seisei0809/unityroom-godot-ranking、MIT)の実装を
  踏襲しているが、鍵の置き場所(Inspectorではなく`data/`のファイル)と送信の再試行
  (`HttpJson.request_with_retry`を再利用)はこのプロジェクトの流儀に合わせて書き直した
- **呼び出しは`RankProgress.apply_result()`の中から、更新後の段位がプラチナのときだけ**
  行う(`RANK_SCOREBOARD_ID`で指定するボードNoへ、`rank_rating`をスコアとして送る)。
  応答は待たない(GameDesign.md 11章の募集通知と同じ「裏方の処理」としての扱い)
- **unityroom側のボードは「常に記録」に設定しておく必要がある。**「ハイスコア」の
  ままだと、シーズンが変わってレートが下がったときに古い最高値が残り続ける。この設定は
  unityroomのゲーム管理画面で行うものであり、このプロジェクトのコードからは変更できない
- **ボードNo(`RANK_SCOREBOARD_ID`、既定1)は、unityroomの管理画面で実際に作成した
  ボードの番号に合わせて調整すること。**このプロジェクト側からボードを作成するAPIは
  無い(unityroomの管理画面でのみ作成できる)

## 月初の表彰演出

GameDesign.md 28章に記載のとおり、具体的な見せ方(ホーム画面での告知等)は未確定。
実装するときは、`HomeScreen`の副題が外部要因で変わったときの「光る」演出(10.10.2節)
と同じ語彙(新しい要素を増やさず、既存の反応の仕組みへ乗せる)を優先して検討する。
