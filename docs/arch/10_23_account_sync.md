# 10.23 デッキ・遠征・とどめ問題・ミッションのアカウント同期

GameDesign.md 14章「アカウントに紐づけるもの」の実装。`AccountSyncService`(`scripts/net/account_sync_service.gd`、static)が
`players/{uid}` との間を受け持ち、各保存クラスは手元の控え(`user://`)を持ち続ける。オフラインでも遊べるようにするため。

| フィールド | 手元の控え | 合わせ方 |
|---|---|---|
| `decks`(`{"name", "ids"}` の配列)・`deck_selected` | `CardDeckSave`(`card_decks.json`) | まとめて上書き |
| `solo_progress`(1アカウントぶんの記録。途中の遠征を含む) | `SoloProgress`(`solo_progress.json` の uid の項) | まとめて上書き |
| `puzzle_cleared`(クリアした問題idの配列) | `PuzzleProgress` | 和集合 |
| `daily_missions`(`{"date", "ids", "progress", "claimed"}`) | `DailyMissionService` | 同じ日なら進捗は最大・受け取りは和集合、違う日なら新しい日 |

- **引く**: `AccountService.load_profile()` が読んだフィールドを `sync_after_sign_in()` へ渡す。画面が控えを読む前に
  合わせ終えるため、`load_profile()` はこれを await する
- **押す**: 各保存クラスが変更のたびに `push_*()` を呼ぶ(await しない)。**引き終えたアカウント(`_synced_uid`)へしか
  押さない**。引く前に押すと、別の端末で保存した内容を古い控えで上書きするため。`AccountService.reset()` で空に戻す
- **まとめて上書きする2つは「送れていない」印を控えに持つ**(デッキはファイルの `dirty`、遠征は項の `sync_dirty`)。
  サインインのとき印があれば手元を送り、無ければアカウントの値で置き換える。送っている間の変更で印を消さないよう、
  変更のたびに `revision` を進め、送った時点の値と同じときだけ印を消す
- **デッキの控えは `owner`(どのアカウントのものか)を持つ**。`owner` が空(同期の前から持っていた控え)か自分なら
  アカウントに無いとき上げ、別のアカウントのもの(ログアウトした後)なら上げずに空にする
- **和集合で合わせる2つは退避を持たない**。`updateTime` を前提条件にして読み直しながら書き(`MatchStatsService` と同じ流儀)、
  失敗しても次のサインインで手元にしか無いぶんが送り直される
- 送る失敗は画面に出さない(裏方の処理のため)
- テストは `run_tests.gd` が `CardDeckSave.save_path` をテスト用へ差し替え、他の3つを `reset_for_test()` で書き込まない
  状態にしてから走らせる(サインインを通すテストが `user://` の実データを書き換えないため)
