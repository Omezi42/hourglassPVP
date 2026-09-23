# 4.2 ルール画面(GameDesign.md 16章)

| クラス | 責務 |
|---|---|
| `RulePages`(`scripts/ui/rule_pages.gd`, static) | 紙芝居の中身。章・見出し・本文・盤面の種類を Dictionary の配列として1箇所へ持つ |
| `RuleStage`(`scripts/ui/rule_stage.gd`, Control) | 1ページ分の盤面。`RulePages` の指定に従って `CardView` 等を並べ、`play()` で演出を再生する |
| `RuleScreen`(`scripts/ui/rule_screen.gd`, Control) | 目次・本文・`RuleStage`・ページ送りを並べる画面 |
| `RulesTab`(`scripts/ui/rules_tab.gd`, Control) | ホーム画面の「ルール」タブ。**「遊んで覚える」と「読んで覚える」の2つの枠**に分け、入口だけを持つ(GameDesign.md 9章) |

**盤面は `CardView` / `BoardTable` / `PlayerInfoBar` / `CardInstance` / `MatchState` を
そのまま使う。**ルール画面専用の描画を1つも書かないことが要件で、教材用の絵を別に持つと
対局画面と食い違った時点で誤った予習になる(GameDesign.md 16章)。同じ理由で、演出も
`CardView.play_drop()` / `play_shatter()` / `play_flip()` を直接呼ぶ。

**第7章の盤面は `MatchState` を実際に生成してから、`board` と `hp` を教材用の局面へ
差し替えて作る。**`PlayerInfoBar.show_state()` が `MatchState` を要求するため、
情報帯(HP・マナ・山札・墓地)を本物と同じ描画で出すにはこれが要る。ランダムな
デッキから引いた局面をそのまま見せると、説明したい形が毎回変わってしまう。

**`RulesTab` と「ルール」のタブボタンは `HomeScreen._ready()` がコードで生成する。**
`scenes/home_screen.tscn` を書き換えずに済ませるためで、タブボタンは既存の
「デッキ」ボタンを `duplicate()` して文言だけ差し替える(スタイルの指定漏れが起きない)。
これは v5.0 の画面が `.tscn` を持たないのと同じ流儀。

**初回起動の判定は `UiState`(`scripts/logic/ui_state.gd`、`user://ui_state.json`)が持つ。**
`CardDeckSave` 等と同じ「Autoloadを使わずstaticで持つ」流儀。`home_seen` が偽のままタイトルを押されたら、
`Main` はホームを出さずに誘導対局を始める(GameDesign.md 18章)。`home_seen` はホームを表示した時点で立てるため、
誘導対局の途中でブラウザを閉じた人は次の起動でも誘導対局から始まる。`tutorial_done` は締めのひと言まで
進んだ時点(`FunnelService.TUTORIAL_CLEAR` と同じ所)で立て、「1局遊んで覚える」の入口を下げる判定に使う。
