# 7. リプレイの実装方針

- **ゲームの中にリプレイの一覧は持たず、観戦も持たない**(GameDesign.md 12章)。再生の仕組み(下記)だけを残し、攻略サイト(10.21節)が呼び出す
- `matches/{match_id}` には既に `deck_a`/`deck_b`(30枚のid)・`seed`(山札の並び)・`actions`(手順)が保存済みで、**任意の局面は初期状態から手を並べ直して作れる**。局面のスナップショットは持たない(4.0節)
- 対局終了時、`MatchState.match_ended` を検知したタイミングで対局画面(`CardMatchOutcome.save_replay()`)が `matches/{match_id}` へ `finished_at`(タイムスタンプ)・`winner`(`"a"`/`"b"`)を書き込む(`ReplayService.mark_finished()`)。この書き込みが「終了済みマッチ」の判定基準を兼ねる(未書き込み=対局中または放棄されたマッチ)。CPU戦の棋譜は残さない
- 保存件数の上限(アカウントごとに直近30件)は、書き込みの後に自分の終了済みマッチを `player_a == 自分のuid` と `player_b == 自分のuid` の**2本の等価フィルタクエリ**で集め(`ReplayService.list_replays()`。`OR` 条件や `orderBy` 併用の複合インデックスを避ける)、`finished_at` の新しい順で31件目以降を消して保つ
- 投了で終わった対局は、`actions`の末尾に`surrender`が1件入った状態で保存される。再生時は他の手と同じく`OnlineMatch.apply()`へ流れて`match_ended`が発火するが、再生モードでは結果パネルを出さないため追加の分岐は要らない。手数表示では投了も1手として数える
- 再生画面は新規シーンを作らず、対局画面の「再生モード」(`CardMatchReplay`)として実装する。入口は `CardMatchScreen.start_replay(record)` の1つで、`MatchState` をデッキと種から作り直し、保存済み `actions` を1件ずつ `MatchAction.apply()` へ流し込んで進行を再現する。行動の列には、先頭へ/1手戻る/再生・一時停止/1手進む/最後へ、の5ボタンと手数表示を置き、盤面のクリック操作は無効化する
