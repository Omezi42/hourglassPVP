# 7. リプレイ・観戦の実装方針

- `matches/{match_id}` には既に `deck_a`/`deck_b`(30枚のid)・`seed`(山札の並び)・`actions`(手順)が保存済みで、**任意の局面は初期状態から手を並べ直して作れる**。局面のスナップショットは持たない(4.0節)
- 対局終了時、`MatchState.match_ended` を検知したタイミングで対局画面が `matches/{match_id}` へ `finished_at`(タイムスタンプ)・`winner`(`"a"`/`"b"`)を書き込む。この書き込みが「終了済みマッチ」の判定基準を兼ねる(未書き込み=対局中または放棄されたマッチ)
- リプレイ一覧の取得は、`player_a == 自分のuid` と `player_b == 自分のuid` の**2本の等価フィルタクエリ**をそれぞれ実行し、結果をクライアント側でマージ・`finished_at`降順ソートする(複合インデックスを要求する `OR` 条件や `orderBy` 併用を避ける、既存のクエリ方針を踏襲)
- リプレイ閲覧は `player_a`/`player_b` のuidが自分のuidと一致する場合のみ許可する(クライアント側での表示制御。Firestoreセキュリティルール側でも同様の制限を検討する)
- 保存件数の上限(直近30件)は、対局終了時の書き込み後に「終了済みマッチが30件を超えていないか」をチェックし、超過分を `finished_at` の古い順に削除するクリーンアップ処理で維持する。プレイヤー単位ではなくアプリ全体で30件とし、シンプルな実装に留める
- `ReplayListScreen`:`DeckListScreen` と同様の横長カード縦スクロール一覧。各カードは対局日時・勝敗・先手/後手に加え、`deck_a`/`deck_b` からデッキを代表する数枚のアイコンを表示する(30枚をそのまま並べるとカードに収まらないため)。`BattleTab` に追加する「リプレイ」ボタンから遷移する
- 投了で終わった対局は、`actions`の末尾に`surrender`が1件入った状態で保存される。リプレイ再生時は他の手と同じく`OnlineMatch.apply()`へ流れて`match_ended`が発火するが、再生モードでは元々結果パネルを出さない仕様のため追加の分岐は要らない。手数表示では投了も1手として数える(将棋の棋譜で投了を1手と数えるのと同じ扱い)
- 再生画面は新規シーンを作らず、対局画面に「再生モード」を追加する形で実装する。再生モードでは `MatchState` をデッキと種から作り直し、保存済み `actions` を1件ずつ `MatchAction.apply()` へ流し込んで進行を再現する。行動の列には、先頭へ/1手戻る/再生・一時停止/1手進む/最後へ、の5ボタンと手数表示、および一覧へ戻る導線を置き、盤面のクリック操作は無効化する
- ルームマッチの観戦は既存の**ルームコード**を再利用する。`rooms/{code}` には対局成立後も `match_id` が残っているため、観戦者が同じコードを入力すると `rooms/{code}` から `match_id` を引き、`matches/{match_id}` の購読(ポーリング)を開始できる
- 対局画面に「観戦モード」を追加する(対局モード・再生モードに続く3つ目のモード)。入口は `CardMatchOnline.spectate(client, match_id)` の1つで、ルームマッチもランクマッチも同じ経路を通る。`OnlineMatch` のポーリング機構をそのまま使い、`send_and_apply` を呼ばずに `action_received` シグナルだけを購読して盤面へ反映する。行動のボタンは出さず、盤面操作は無効化する。対局終了の検知(`match_ended`)は通常通り行うが、`finished_at`/`winner` の書き込みは対局者側のみが行い、観戦者側では行わない。両者の情報帯には `player_a`/`player_b` のプロフィールを `AccountService.fetch_profile()` で引いて出す
- `BattleTab` のルームコード入力欄に「観戦する」ボタンを追加し、参加導線と並べて配置する

## 7.1 CPU戦のローカルリプレイ保存(フェーズ11 K-2、実装済み)

- `LocalReplayService`(`scripts/net/local_replay_service.gd`、`RefCounted`のstaticクラス、
  `DeckSave`と同様「Autoloadを使わずstaticで持つ」流儀)が、CPU戦の棋譜を
  `user://cpu_replays.json` へ配列として保存する。1件のレコードは、オンライン版
  `matches/{id}` ドキュメントと対応する内容(`deck_a`/`deck_b`・`seed`・
  `actions`・`finished_at`・`winner`)に加えて `id`(`"cpu_<unixtime>_<乱数>"`)・
  `source`(常に`"cpu"`、一覧画面でのオンライン/CPU戦の判別に使う)を持つ。
  `mark_finished(record)` が保存(+保存件数の上限維持)、`list_replays()` が
  `ReplayService.list_replays()`と同じ`{"id":..., "fields":{...}}`形の配列(`finished_at`降順)を
  返し、`get_replay(id)` がidに一致する1件をフラットな形(対局画面の再生モードが
  そのまま読める形)で返す
- 保存件数の上限(直近30件、`RETENTION_LIMIT`)は、オンライン対戦(Firestore、
  `ReplayService.RETENTION_LIMIT`)とCPU戦(ローカル、`LocalReplayService.RETENTION_LIMIT`)を
  **それぞれ独立に**30件まで保持する(合算で管理すると片方の対局頻度が高い場合にもう片方が
  不当に圧迫されるため)
- CPU戦の棋譜は `CardMatchScreen._cpu_record`(Dictionary)へ溜める。**`start_cpu_match()` が
  山札の種を決めてから対局を始める**のがこの記録の前提で、両者のデッキのidと種をここで控え、
  以後は手を送るのと同じ `_perform()` が `actions` へ1件ずつ足す。終局後の後始末を持つ
  `CardMatchOutcome` が `LocalReplayService.mark_finished()` へ渡す。オンライン対戦の
  `OnlineMatch` がFirestoreへ逐次書き込むのとは異なり、CPU戦は終局時に一括で1回だけ保存する
- **再生の入口は `CardMatchScreen.start_replay(record)` の1つだけ**。Firestoreの
  `get_document()` も `LocalReplayService.get_replay()` もフラットな `Dictionary` を返すため、
  オンライン対戦とCPU戦で再生の経路を分ける必要がない
- `ReplayListScreen.refresh()` は、Firestoreからの一覧取得(既存、サインイン失敗時は
  空扱い)と`LocalReplayService.list_replays()`(新規、ローカルのためサインイン不要)の
  両方を行い、クライアント側で`finished_at`降順にマージして1つの一覧として表示する
  (オンライン側のサインインが失敗してもCPU戦のリプレイだけは表示できるようにしている)。
  `ReplayListCard`は`fields.source == "cpu"`かどうかで、`player_a`/`player_b`のuid比較を
  スキップして常に自分を先手(側A)として扱い、`info_label`のテキスト末尾に
  `[CPU戦]`/`[オンライン]`の表示を追加する(専用のバッジ用ノードは追加せず、
  既存の`InfoLabel`へテキストとして組み込む形に留めている)。`Main._on_replay_selected()`は
  `match_id`が`"cpu_"`始まりかどうかで`start_local_replay()`/`start_replay()`を振り分ける
- 観戦機能はCPU戦の対象外のまま変更していない(ローカル対局に第三者が参加する経路が存在しないため)

## 7.2 ランクマッチの観戦一覧

- **`matches/{id}` は作られた時点で `kind`(`"ranked"` / `"room"` / `"random"`)と `build` を持つ**。種別と版は一覧の絞り込みにしか使わないため、対局を作る1回のcommit(`MatchmakingQueue._claim()` / `RoomMatch.join()`)へ足すだけにする。`kind` は `MatchmakingQueue.match_kind`(派生の `RankedMatchmakingQueue` が差し替える)から書く
- `LiveMatchService`(`scripts/net/live_match_service.gd`、staticのみ)が一覧を作る。`matches` を `created_at` の新しい順に `QUERY_LIMIT` 件取る1本のクエリ(`FirestoreClient.query_recent()`。単一フィールドの並べ替えだけなので複合インデックスは要らない)を投げ、クライアント側で「`kind` がランク・同じビルド・両者のデッキと種がある・`finished_at` も `abandoned` も無い・サーバー時刻の `read_time - update_time` が `LIVE_SECONDS` 以内」のものだけを残して `LIST_LIMIT` 件に切る。**生きているかどうかは端末の時計でなく `updateTime` と `readTime` で比べる**(Pitfalls.md)。持ち時間は1手番60秒で、時間切れも手として書かれるため、3分書き込みが無ければ両者とも去ったものとみなせる
- ターン数は `actions` のうち手番を終える手(`end_turn` / `time_up`)の数 + 1 とする(`LiveMatchService.turn_of()`)
- `CardSpectateListScreen`(`scripts/ui/card_spectate_list_screen.gd`)が一覧画面。行は `SpectateMatchRow`(左右に両者のアイコン・名前・段位の徽章、中央にターン数)で、押すと `spectate_requested(match_id)` を出す。名前と段位は行ごとに `players/{uid}` を読んで出す(最大20件の読み取り。`AccountService.fetch_profile()` は段位を持たないため)。観戦を終えて「戻る」を押すとこの一覧へ帰り、読み直す
- **ランクマッチの観戦では両者の手札を伏せる**(GameDesign.md 12章)。`CardMatchScreen.hide_hands` が立っていると `_refresh_hand()` は空の手札として並べ、`PlayerInfoBar.show_hand_pile` を立てた自分側の情報帯にも手札の山を出す。ドローや「砂へ還す」の行き先(`CardMatchEffects.hand_center()`)もその山へ向ける。`CardMatchReset` が毎局落とす
