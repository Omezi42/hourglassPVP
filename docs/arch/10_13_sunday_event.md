# 10.13 日曜イベントとその告知(GameDesign.md 15章・25章)

| クラス | 責務 |
|---|---|
| `SundayEventRules`(`scripts/logic/sunday_event_rules.gd`, static) | いま日曜イベント中かどうかの判定と、報酬の倍率適用 |
| `functions/`(Firebaseプロジェクト直下、Node.js) | `announceSundayEvent`(定期告知)・`discordInteractions`(将来のスラッシュコマンドの受け口) |

**`SundayEventRules.is_active()` は `Time.get_datetime_dict_from_system(true)` の
UTC時刻を +9時間して日本時間へ換算し、曜日を見る。**サーバー側で正当性検証を行わない
既存方針(GameDesign.md 11章)に揃え、**クライアントのローカル時刻をそのまま信頼する**。

- **`CurrencyRules` はこの判定を呼ぶだけで、曜日の計算そのものを持たない。**
  `grant_amount(kind, won)` が `SundayEventRules.is_active()` を見て、
  ランダムマッチ(`MatchKind.RANDOM`)かつ true のときだけ倍率(2倍)を掛ける。
  ルームマッチ・CPU戦は `is_active()` を見ない
- **表示は `HomeScreen` と `CardMatchOutcome`(結果パネル)の2箇所だけに足す。**
  いずれも `SundayEventRules.is_active()` を読むだけの1行で、通常時は何も出さない
- **Firebase Cloud Functions を1つ追加する。**この作品が初めて持つ「常駐しないが
  サーバー側で動くコード」であり、GameDesign.md 10章冒頭の「バックエンドは自前サーバーを
  立てず、サーバーレスDBを使う」という方針の範囲内(Cloud Functions自体もサーバーレスの
  実行環境である)

| 関数 | トリガー | 役割 |
|---|---|---|
| `announceSundayEvent` | Cloud Scheduler(`0 0 * * 0`, Asia/Tokyo) | Discordの#お知らせへ日曜イベント開始のメッセージを投稿する |
| `discordInteractions` | HTTPS(Discordの Interactions Endpoint URL) | 将来のスラッシュコマンドを受け付ける入口。現時点ではコマンドを1つも持たず、`PING`(type 1)への`PONG`(type 1)応答だけを返す |

- **常駐プロセスは持たない。**いずれの関数も呼ばれたときだけ実行され、
  リクエストの外で状態を保持しない
- **DiscordのBotトークン・Interactionsの公開鍵は Firebase Functions のシークレット管理
  (`firebase functions:secrets:set`)へ置き、リポジトリへは一切コミットしない。**
  6.3節のWebhook URL(`data/discord_webhook.txt`)と同じ扱いで、`functions/` 側は
  環境変数からのみ読む
- **`discordInteractions` の署名検証は `discord-interactions`(公式ライブラリ)の
  `verifyKey()` を必ず通す。**検証を怠ると、Discord以外の第三者からのリクエストを
  受け付けてしまう
- **クライアント(Godot)側の変更は「判定・倍率・バナー表示」だけに留める。**
  告知そのものはクライアントを経由しない(6.3節の募集通知はクライアント発火だが、
  こちらはサーバー側の定期実行が発火する点が異なる)
- **将来スラッシュコマンドを足すときは `discordInteractions` へ分岐を1つ足すだけにする。**
  Botのプロセスを新設せず、この1関数へ集約する
