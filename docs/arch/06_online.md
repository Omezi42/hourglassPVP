# 6. オンライン対戦の実装方針

- バックエンドは自前サーバーを立てず、**Firestore(Firebase)のようなサーバーレスDB**を使う。1手を1ドキュメント書き込みとして扱う
- 通信はGodot標準の `HTTPRequest` による **Firestore REST API呼び出し**で行う(認証はFirebase Authenticationの匿名サインイン)。unityroom向けのHTML5/WebGLエクスポートではGDExtension系プラグイン(サードパーティのFirebase SDKラッパー等)が不安定・非対応なことが多く、またFirebase公式C++ SDKもWebAssemblyターゲットを公式サポートしていないため、追加プラグイン不要でどの書き出し先でも確実に動く方式を優先する
- 相手の手の反映は、ドキュメントの**ポーリング(数秒間隔での定期取得)**によって行う。リアルタイムリスナー(gRPC-Web双方向ストリーミング)は実装が複雑なため採用しない。ターン制で1手ごとの時間的猶予があるため、数秒の遅延は体験上問題にならない
- `HomeScreen` の「対戦」タブを、**ランダムマッチ待機**・**ルームコード作成/参加**の2導線に分岐させる
- **ルームコードは4桁の数字**(`RoomMatch.CODE_LENGTH`)。取りうる番号が1万通りしか
  無いため、**空いている番号を選んで作る**(`create_document()` の `exists:false`)。
  埋まっていた場合は、その部屋が `ROOM_STALE_SECONDS` より古く、まだ対局が始まって
  いなければ番号ごと引き取る(`updateTime` を前提条件にした `commit()`)。**この
  引き取りが無いと、放置された部屋が番号を占め続けて作れなくなる**。観戦は
  `rooms/{code}` を辿るため部屋の文書自体は消さない(7章)
- ランダムマッチのキューは、複数プレイヤーが同時に参加しても二重マッチや取りこぼしが起きないよう、**Firestoreのトランザクション(read-modify-write)でキューの追加/成立を原子的に処理する**。具体的には「待機中のドキュメントを1件取得→トランザクション内で取得できればマッチ成立とみなし両者のマッチIDを確定、取得できなければ自分が待機ドキュメントとして登録される」という手順を想定する
- 持ち時間の管理はロジック層の `MatchClock` が担う。**1手番につき60秒で、手番が移るたびに
  その側の残り時間を60秒へ戻す**(GameDesign.md 5章)。時間切れは `MatchState.match_ended` と
  同様の決着トリガーとして扱い、オンライン対戦時はこの持ち時間切れが切断・放置時の敗北条件を
  兼ねるため、別途タイムアウト監視の仕組みを持たない
- **手番の始まりは `start_turn(side)` の1本だけで表し、「側が変わったときだけ戻す」**。
  1手番のうちに何度も指す(出す→攻撃→反転)たびに戻すと、指し続けている限り時間が尽きない。
  「active_side を移すだけ」の関数を別に持つと、戻す判定と手番の移動が2つの関数に分かれて食い違う
- **時間切れは敗北ではなく手番の強制終了**(GameDesign.md 5章)。手として
  `{"type": "time_up", "side":}` を送り合い、`MatchState.time_up()` が適用する。
  **切断とみなして即座に負けにする `{"type": "timeout"}` は別物として残す**
  (下記の猶予から呼ぶ)。過去の棋譜が持つ `timeout` の意味を変えないためでもある
- **連続回数は `MatchState.turn_forfeits` が持つ**。手として送り合うため両者で同じ値になり、
  `TURN_FORFEIT_LIMIT` による敗北判定がこれを見る。**回数を `MatchClock` へ置かない**
  (時計はUIが対局ごとに作り直すため、そこへ回数を置くと復帰・観戦で失われる)。
  **時間切れを重ねても持ち時間は短くしない**(GameDesign.md 5章)ため、`MatchClock` は
  回数そのものを知らない
- **`end_turn()` は冒頭でその側の回数を0へ戻し、`time_up()` は `end_turn()` を呼んだ後に
  数え直した値を書き戻す**。「1手でも指せば数え直す」を1箇所で表すためで、順序を逆にすると
  連続を数えられない。リセットを `play_card()` 等の側へ配ると、増えるたびに書き漏らす
- **`time_out` は「手番側の時計が尽きた」という通知であり、自分の時間切れとは限らない**。
  `tick()` が減らすのは `active_side` の時計なので、相手の手番でも発火する。受け口
  (`CardMatchScreen._on_local_timeout()`)は**引数の側が自分でなければ何もしない**。
  ここで側を見ずに `my_side` で申告すると、**相手が時間切れになった瞬間に自分が負けを
  送る**。相手の時間切れは `_watch_opponent_timeout()` が
  猶予を置いて拾う側の仕事で、経路が別々にある
- **相手を待つ猶予(`OPPONENT_TIMEOUT_GRACE`)は20秒**。時間切れ自体が敗北でなくなった以上、
  ここに掛かるのは「申告そのものが届かない=切断」の判定だけになった。生きている相手は必ず
  `time_up` を送ってくるため、ポーリングの間隔(1.5秒・失敗時は最大8秒まで伸びる)と送信の
  再試行より十分長く取る。**短いと、通信が一時的に詰まっただけの相手を切断とみなして勝つ**
- **時間切れは盤面に何も起こさないため、ログと実況の両方へ出す**。`CardMatchLog` は
  `turn_forfeited` を購読して `_append(..., "time_up", side, -1)` で積み、
  `CardMatchTurnFeed.NARRATED` へ `"time_up"` を足して相手のぶんだけ実況する。
  出さないと、相手が何もせず手番が戻ってきたようにしか見えない
- **残り時間が赤くなる境目は固定の秒数ではなく、その手番の持ち時間の半分**とする
  (`PlayerInfoBar.clock_total`)。持ち時間はいま常に60秒だが、ルームマッチで持ち時間を
  切った対局など「1手番の枠」が変わりうる経路が残っているため、割合で持つ形は変えない
- サーバー側での操作の正当性検証は行わず、クライアントの操作をそのまま信頼する(不正対策は将来検討)
- Firebaseの接続情報(`apiKey`/`projectId`等)は `FirebaseConfig`(Resource)として `data/firebase_config.tres` に保持する。Web向けAPIキーは元々クライアント埋め込み前提の値であり、Firestoreセキュリティルール側でアクセス制御する運用とする
- ルームマッチは両者の入室後、`rooms/{code}.started` が `true` になるまでロビーで待つ。デッキと持ち時間を確認でき、開始操作はホストだけが行う。開始後、両者は `matches/{match_id}` ドキュメントへ自分のデッキ(30枚のid配列)を `deck_a`/`deck_b` として、先手側は山札の `seed` も書き込む(`OnlineSetup` が担当)。相手側はポーリングでこれを検知する。**v5.0は配置フェーズを持たないため、交換するのはデッキと種だけ**で、揃った時点で `MatchState.start_match()` へ入る(4.0節)
- オンライン時は対局画面の表示視点(自分/相手)を `state.current_turn` ではなく固定の `my_side` にし、自分の手番でない間は操作を受け付けない
- マリガン(GameDesign.md 2章)は手と同じ `actions` の1件として送り合う。**両者ぶんが揃ってから A → B の固定順で適用する**(適用が山札を切り直して乱数を消費するため、届いた順に適用すると同じ種から始めた対局が食い違う)
- 対局中の実際の手の送受信は `OnlineMatch` が担当し、対局画面は自分の操作を `OnlineMatch.send_and_apply` 経由で送信しつつ即座にローカル反映する
- **投了は指し手と同じ`actions`配列の1件として送受信する**(`{"type": "surrender", "side": <投了した側>}`)。`OnlineMatch.apply()`のmatch文へ`"surrender"`分岐を1つ足し、`MatchState.surrender(side)`を呼ぶだけで済むため、ポーリング・送信の仕組みを新設せずに相手へ伝わる。ただし投了は盤面を変えずに即終局する点で他の手と性質が異なるため、**対局画面側では手の演出とターン交代を行わない**(適用した時点で`match_ended`が発火し、以降の処理は結果パネルの表示に引き継がれる)。`actions`と`finished_at`/`winner`は同じドキュメントの別フィールドだが、`FirestoreClient.set_document()`が`updateMask`付きのPATCHでフィールド単位に書くため、投了側が両方をほぼ同時に書いても互いを打ち消さない

## 6.2 切断からの復帰(GameDesign.md 11章)

**局面のスナップショットは保存しない。**`matches/{id}` には「両者のデッキ・山札の種・
指した手の並び」が残っており、そこから作り直せる(リプレイ・観戦とまったく同じ経路)。
`OnlineResume`(`scripts/net/online_resume.gd`、`user://online_match.json`)が持つのは
**どの対局のどちら側だったか**だけで、対局が始まった時点で書き、終局と対局前の中断で消す。

`CardMatchScreen.resume_online_match()` は、ドキュメントを読んで
`_begin_state()` → 記録済みの手をすべて `MatchAction.apply()` → `OnlineMatch.start(id, 適用済みの数)`
の順に復元する。終局済み(`finished_at` がある / 手を並べ終えた時点で決着している)なら
戻さずに理由を出す。

**復帰しても持ち時間は戻らない。**こちら側は初期値から数え直すが、**相手はこちらの残り時間を
自分の手元で減らし続けている**(6.1節)ため、再読み込みで時計を延ばす抜け道にはならない。

**戻れる対局があるかどうかは、ホーム画面では通信せずに判定する**(記録の有無だけを見る)。
押した時点で初めて `matches/{id}` を読む。毎回ホームで通信すると、オフラインでも
遊べる(CPU戦)という前提を崩すため。

---

## 6.1 通信の堅牢化(フェーズ26)

自己検証で、オンライン対戦が「通信が理想的に成功し続ける場合しか成立しない」実装に
なっていることが分かった。以下はいずれもその修正であり、ルール(GameDesign.md)は変えていない。

- **HTTP通信は必ずタイムアウトを設定する**。`HTTPRequest.timeout`の既定値は0(無制限)で、
  応答が返らないと`await request_completed`が永久に解決せず、その導線(サインイン・
  マッチング・手の送信)が固まったまま復帰しない。生成・タイムアウト・一時的失敗の
  リトライ・JSONのパースは`HttpJson`(`scripts/net/http_json.gd`、staticのみ)へ集約し、
  `FirebaseAuth`と`FirestoreClient`の両方がこれを経由する。リトライの対象は
  「応答が得られなかった/429/5xx」だけで、400番台は呼び出し側の判断が要るため再試行しない
- **IDトークンを自動更新する**。Firebaseの匿名サインインで得るIDトークンは1時間で失効する。
  更新の仕組みが無いと、長く遊んだセッションで以降のFirestore通信がすべて401で黙って失敗し、
  画面上は「相手が指してこない」ようにしか見えない。`FirebaseAuth`が`refreshToken`と
  有効期限を保持し、`ensure_fresh_token()`が期限の5分前から`securetoken.googleapis.com`で
  更新する。`FirestoreClient`は全リクエストの前にこれを呼び、それでも401が返った場合は
  1度だけ強制更新して再送する(クライアント時刻がずれている場合に備える)
- **マッチ成立は1回のcommitで原子的に行う**。キュー/ルームのclaimと
  `matches/{id}`の`player_a`/`player_b`の書き込みを別々にすると、掴まれた側が
  `match_id`を見て`matches/{id}`を読んだときにまだ空という窓ができる。この窓に入ると
  `BattleTab._on_matched()`の判定(`player_a == 自分のuid`なら先手)が両者ともfalseになり、
  **双方が後手(side B)として`deck_b`を書き、互いに`deck_a`を待ち続けて対局が始まらない**。
  `MatchmakingQueue`は「相手のキュー更新 + 自分のキュー更新 + `matches/{id}`の作成
  (`exists:false`)」の3write、`RoomMatch`は「ルーム更新 + `matches/{id}`の作成」の2writeを
  1つの`commit()`にまとめ、この窓自体を無くした
- **先手・後手は`MatchSides.assign()`が五分五分に振る**(GameDesign.md 11章)。
  振るのは**対局を成立させた側だけ**(`MatchmakingQueue._claim()` / `RoomMatch.join_room()`)で、
  結果は上記のcommitの中で`matches/{id}`の`player_a`(先手)・`player_b`(後手)として
  書かれる。両者は既存の判定(`player_a == 自分のuid`なら先手)をそのまま通るため、
  **側を決める経路は1本のまま変わらない**。双方が別々に振ると必ず食い違うため、
  振る場所を1箇所に閉じることがこの機能の要件になる
  - **`opponent_uid`と`is_host`は側とは無関係**であり、
    creator / joiner の役から決める(部屋の開始操作はホストだけが行う)
  - **CPU戦・ソロモード・誘導対局・パズルは`MatchState.Side.A`固定のまま**
    (`start_match()`の第3引数を触らない)
- **キューに残った切断済みプレイヤーを掴まない**。ブラウザを閉じたプレイヤーのキュー
  ドキュメントは残り続けるため、後から来た人がそれを掴んで永久に相手のデッキを待つ状態に
  なっていた。最後の更新(`updateTime`)がクエリの`readTime`から`STALE_SECONDS`より古い候補は
  掴まずに削除し、待機中の自分は`HEARTBEAT_SECONDS`ごとに`joined_at`を更新して自分が生きていることを示す
  (古さをサーバーの時刻同士で測るのは、端末の時計のずれで生きている待機者を消さないため。
  更新が頻繁だと相手のclaimの前提条件(`updateTime`)を無効化してしまうため、
  ポーリング間隔より十分長い間隔にしている)
  - **ポーリングで自分のキュードキュメントが404なら書き直す。**裏のタブではメインループが止まり
    心拍が途絶えるため、戻ってくるまでに他の待機者に掃除されていることがある。書き直さないと
    誰からも見えないまま待ち続ける
- **手の送信を確実にする**。`OnlineMatch`は`actions`配列をread-modify-writeで書くが、
  `set_document()`の成否を見ずに進めると、失敗しても盤面だけ進んで相手と食い違う。
  `updateTime`を前提条件にした`commit()`で書き、競合・失敗時はドキュメントを
  読み直して再試行する。送信は`_send_queue`へ積んで1件ずつ処理し、順序と重複を保証する
- **自分の手をポーリングが拾って二重適用する競合を無くす**。送信した手にはFirestoreへ
  書く時点で`by`(自分のuid)を付け、ポーリング側は`by`が自分のものである手を配らない。
  「書き込み完了 → `_known_action_count`の更新」の間にポーリングの読み取りが
  挟まると、自分の手が`action_received`として自分に返り、同じ手が2度適用される。
  `by`は`OnlineMatch.apply()`もリプレイ再生も参照しない追加キーのため、既存の棋譜と互換性がある
- **受け取った手は1ポーリングにつき1件だけ配る**。対局画面の受け口は
  予約マークの表示・解決演出で数秒awaitするため、同時に2件流し込むとターン進行が
  二重に走る。残りは`_inbox`に留めて次のポーリングで配る
- **終局・画面離脱でポーリングを止める**(次の対局開始時まで放置するとホームへ戻った後も
  Firestoreを読み続ける)。`_on_match_ended()`(リプレイ保存の
  書き込みの後)と、戻る/ホームへボタンの両方から止める。**停止したノードは解放しない**。
  ポーリング・送信のコルーチンがawaitの途中で残っている可能性があり、解放すると
  「Resumed function on a freed object」になるため。`_polling`をfalseにした時点で
  以降は何もしない不活性なノードとして残す
- **持ち時間の同期**(GameDesign.md 11章):送信する手に`clock`(送信側の残り時間)を添え、
  受け取った側は`MatchClock.remaining[相手側]`をその値で上書きする。時間切れは
  `{"type": "timeout", "side": ...}`を投了と同じ`actions`の1件として送る。相手の
  申告が来ない(切断した)場合は、相手の残り時間が0になってから`OPPONENT_TIMEOUT_GRACE`
  の猶予を置いて、待っている側の勝利として終局させる。この判定と通信状態の表示は
  `MatchNetController`(`scripts/ui/match_net_controller.gd`、`_screen`参照を持つRefCounted)へ
  切り出している(`match_screen.gd`が1000行の上限に近いため)
- **対局開始前の中断**(GameDesign.md 11章):`OnlineSetup`に`cancel()`を持たせ、
  ポーリングを即座に打ち切ったうえで`matches/{id}`へ`abandoned`を書く。待っている側は
  `_poll_for_ids()`がこのフィールドを見つけた時点で待機をやめ、「対戦相手が対局を
  取りやめました」を表示する。配置フェーズがオンラインのときだけ、対局画面の戻るボタンを
  表示してこの導線を出す
- **Firestoreのセキュリティルール**は`firestore.rules`にリポジトリ同梱で置く。
  適用はFirebaseコンソール側の操作であり、このファイルは「何を許可する前提で
  実装しているか」の記録として持つ

---

## 6.3 対戦相手の募集をDiscordへ通知する(GameDesign.md 11章)

`QueueNotifier`(`scripts/net/queue_notifier.gd`、staticのみ)がDiscordのWebhookへ
1行を投げる。`MatchmakingQueue.join()` が**最初の `_try_claim_or_check()` で相手を
掴めなかった時点**で1度だけ呼ぶ。ここが「自分が待機側になった」ことの確定であり、
即座にマッチした場合は通らないため、条件分岐を足さずに仕様を満たせる。

**WebhookのURLはリポジトリへ置かない。**`data/discord_webhook.txt` に置き `.gitignore`
で管理外にする。**Godotのエクスポートはgitではなくファイルシステムを見るため、管理外でも
pckには入る**。リポジトリへ置けない理由は2つ。

- リポジトリは公開のまま保つ必要がある(BGMの配信にjsDelivrを使うため。4.1.6節)
- **GitHubはpublicリポジトリに含まれるDiscordのWebhook URLを検出し、Discord側が
  自動的に無効化する**(secret scanningの提携先にDiscordが含まれる)。コミットすれば
  この機能は黙って壊れる

ファイルが無ければ通知を送らないだけで、対局には影響しない(クローン直後やテストは
この状態になる)。**逆に言うと、pckへ入っていない状態と設定していない状態は
画面上まったく同じに見える**(黙って通知だけが飛ばなくなる)。

> **`.txt` は「リソース」ではないため、`export_filter="all_resources"` だけでは
> pckへ入らない。**`export_presets.cfg` の `include_filter` へ
> `data/discord_webhook.txt` を明示しない限り、エディタ実行では通知が飛ぶのに
> **書き出した版でだけ飛ばない**。実際にこれで unityroom 版の通知が一度も
> 届いていなかった。確認は
> `python -c "print(b'discord_webhook' in open('build/web/index.pck','rb').read())"` で足りる。

**クライアントへ埋めるのはWebhookに限り、Botトークンは絶対に置かない。**Webhookは
「そのチャンネルへ投稿する」以外に何もできないが、Botトークンはサーバーの操作権限を
持つため、pckから取り出された時点でサーバーごと失われる。

**送信の土台は `MatchmakingQueue` ではなくシーンツリーのルートにする。**キューは
対局が成立した時点でもキャンセルした時点でも `queue_free()` されるため、そこへ
HTTPRequest をぶら下げると送信の途中で巻き添えに消える。画面には何も出ないため、
「通知だけが飛ばない」という形でしか気づけなかった。

結果は `notify_waiting()` の `on_done`(Callable)で返し、`MatchmakingQueue` が
`announce_result` として画面へ流す。**文言としては出さない**(GameDesign.md 11章)。
`CardRandomMatchScreen`(6.6節)は届いたときだけ待機中の文言の右へ `StatusBadge`(丸い印)を出し、
説明はカーソルを乗せたときのツールチップに預ける。**受け口を Callable
にしているのは、待っている
うちにキューが解放されることがあるため**で、`Callable.is_valid()` が偽になった時点で
呼ばない(解放済みのオブジェクトで再開すると "Resumed function on a freed object" になる)。
届くまでは `ANNOUNCE_RETRY_SECONDS` の間を置いて試し直し、届いたら送り直さない。

**同じプレイヤーの連投を抑える仕組みは持たない**(GameDesign.md 11章)。送信間隔を
`static var` で持つと、失敗時にその印を戻し忘れたとき**入り直しても二度と飛ばなくなる**。
`can_send()` はWebhookが設定済みかどうかだけを答える。

バージョンは `ProjectSettings.get_setting("application/config/version")` から読む
(`project.godot` の `config/version`)。日付方式(`2026.08.29`)。

---

## 6.4 バージョンが違う相手とマッチングしない(GameDesign.md 11章)

`GameVersion`(`scripts/logic/game_version.gd`、staticのみ)が
`application/config/version`(人が読む日付方式)と `application/config/build_id`
(マッチングの突き合わせに使うビルドID)を読む唯一の場所になる。

**ビルドIDと日付方式のバージョンは、`tools/export_web.sh` が書き出しの直前に
`tools/stamp_build_id.py` を通して `project.godot` へ書き込む。**バージョンだけを手で
更新する値として残していたところ、書き出しを重ねても古い日付のままで、募集の通知に
何日も同じ数字が出ていた。同じ日に2回以上書き出した場合は `-2` `-3` と後ろへ足す。
値はUTCの書き出し時刻(`20260829-143052`)で、**時刻順に文字列比較できる**ため
「どちらが古いか」を判定でき、画面へ出す文言を書き分けられる。手で更新する値を
増やさないために自動化しており、**書き込んだ値はそのままコミットする**
(直近のビルドがどれかを追えるようにするため)。

**エディタ実行は最後に書き出したときのIDを持つ。**書き出した版と手元で対戦して
検証できる利点を取り、「ビルド以降にエディタで何を変えても同じ扱い」という緩さを
許容している。ビルドIDを厳密にすると検証のたびに書き出しが必要になる。

- **`MatchmakingQueue`**:キュー文書へ `build` を書き、`_try_claim_or_check()` が
  自分と違う候補を掴まない。**掴まないだけで削除はしない**(古い版の人が待つ権利は
  残す。`STALE_SECONDS` による掃除とは目的が違う)。全候補が版違いだった場合は
  `version_mismatch(newer_exists)` を発行して画面へ返す
- **`RoomMatch`**:ルーム文書へ `build` を書き、`join_room()` / `spectate()` が
  参加前に突き合わせる。参加側で弾くため、作成側が版違いの相手を掴むことはない
- **絞り込みはクライアント側で行う**。`query_waiting()` は `match_id == ""` の
  単一フィールドの等価フィルタで、ここへ `build` を足すと複合インデックスを
  要求することになる(6章のクエリ方針に反する)

**`build` を持たない相手(この機能より前の版)は版違いとして扱う。**盤面が食い違う
可能性があるのはまさにその組み合わせであり、未設定を「何でも通す」側へ倒すと
守りたいケースを素通りさせる。


## 6.5 ルームマッチ画面(GameDesign.md 11章)

| クラス | 責務 |
|---|---|
| `CardRoomScreen`(`scripts/ui/card_room_screen.gd`) | ルームマッチの3つの入口(部屋を作る / コードで参加 / 観戦)と、その待機。使用デッキと持ち時間の設定もここに置く |

**`RoomMatch` を持つのはこの画面**であり、`BattleTab` からは参加・観戦・部屋作成の
コードをすべて外した(バトルタブに残るのはCPU戦・リプレイ・戦績・復帰の入口。
ランダムマッチも6.6節の専用画面へ入るため、バトルタブは「入口の並び」だけを持つ)。
待機中の巡回ドット・キャンセル・失敗の文言は、6.6節の画面と同じ組み立てをこの画面が
自前で持つ。**共通化しない**のは、こちらは部屋の作成・相手待ち・参加・観戦待ちと状態が
4つあり、6.6節側(マッチング中の1状態しか持たない)に合わせると使わない分岐を抱えるため。


## 6.6 ランダムマッチ画面(GameDesign.md 11章)

| クラス | 責務 |
|---|---|
| `CardRandomMatchScreen`(`scripts/ui/card_random_match_screen.gd`) | ランダムマッチの待機。デッキ選択画面でデッキを確定した直後に開き、マッチングキューへの参加・巡回ドット・キャンセル・募集通知の印をここで完結させる |

**`MatchmakingQueue` を持つのはこの画面**であり、`BattleTab` からはキューへ参加する
コード(`begin_random_match()` / `_on_matched()` / `_announce_badge` 等)をすべて外した
(GameDesign.md 11章)。バトルタブに残るのは「ランダムマッチ」の入口タイルが
`random_match_deck_requested` を発行するところまでで、以後の待機・成立の処理は
すべてこの画面が持つ。

**待機の見せ方は「一覧に並べるものが無いとき」の形(`EmptyState`、GameDesign.md 9章)を
そのまま使う。**専用の全画面を持てるようになったことで、以前バトルタブの狭い行へ
詰め込んでいた文言・巡回ドットを、砂時計の印付きの標準形へ置き換えられる。
`EmptyState` 自身は「押せるものを置かない」設計のため、キャンセルボタンと
募集通知の印(`StatusBadge`)は `EmptyState` の外側に、コンテンツ領域の寸法から
求めた固定位置として重ねる——**`EmptyState` の内部状態(ヒントの有無による
中央寄せの結果)を、`EMBLEM_SIZE` 等の公開定数から再計算して合わせる**ことで、
「待機中の文言の右へ丸い印を添える」(GameDesign.md 11章)という配置をここでも守る。

マッチが成立したら `matched(match_id, my_side, opponent_uid)` を発行し、`Main` は
これを既存の `_on_online_match_found()` へそのままつなぐ(`CardRoomScreen.matched` が
`_on_room_match_found()` へつながるのと同じ形)。

**持ち時間の入/切は `rooms/{code}` の `time_limit` として持つ**(GameDesign.md 5章)。
部屋を作る側が書き、参加する側は `join_room()` が読んで `RoomMatch.time_limit` へ控える。
両者が入室するとロビーへ入り、ホストが `started` を立てるまで対局へ遷移しない。
**画面はマッチ成立時にこの値を対局画面まで運ぶ**(`matched` → `Main` →
`CardMatchScreen.start_online_match()` → `CardMatchOnline.start()`)。
`CardMatchOnline` は `time_limit` が偽のとき `MatchClock` を生成しない。
**`_clock == null` は既にCPU戦が通っている経路**(`_process()` の先頭・手の送信の
`clock` 付与・相手の時間切れ監視がいずれも null を見て降りる)ため、
持ち時間なしのために新しい分岐を足す必要はない。

**切断からの復帰でも持ち時間の設定を引き継ぐ**。`OnlineResume` のレコードへ
`time_limit` を足し、`resume()` はその値を見て時計を作るかどうかを決める。
`time_limit` を持たない古い記録は、これまでどおり持ち時間ありとして扱う。

**観戦は、対局が始まっていなければ同じ画面で待つ**(GameDesign.md 11章)。
`RoomMatch.spectate()` は `match_id` が空でも失敗させず、`spectate_waiting` を1度出してから
`POLL_INTERVAL_SECONDS` ごとに読み直す。**バージョンの突き合わせは待ち始める前に行う**
(版が違う部屋を待ち続けても、始まった瞬間に弾かれるだけのため)。

**参加コードのコピーは `DisplayServer.clipboard_set()`**。Web版ではブラウザに拒否される
ことがあるが、**失敗しても画面には何も出さない**。コード自体が大きく出ており、
手入力で足りるため(GameDesign.md 11章)。

## 6.6 対局中エモートの送受信と表示(GameDesign.md 9章)

- 定型文の定義は `EmoteLibrary`(`scripts/data/emote_library.gd`、staticのみ)で管理する。
- エモートは `{"type": "emote", "side": side, "emote_id": emote_id}` として `MatchAction.emote()` で生成され、他の手と同様に `OnlineMatch.send()` 経由で Firestore の `matches/{id}.actions` に追記される。
- `MatchAction.apply()` では盤面状態の変更を行わず、`return true` で安全に通過する。
- UI演出は `EmoteBubble`(`scripts/ui/emote_bubble.gd`)が担当し、発言側の `PlayerInfoBar.show_emote()` を通じて名札付近に約3.8秒間(完全不透明で3.0秒)フェードイン・自動フェードアウト表示する。**`Tween.set_parallel(true)` は「直前のtweenerと並行に走らせる」指定であり、段を区切る手段ではない**(待機のあとに置くとフェードアウトが待機と同時に始まり、実際には0.3秒しか見えていなかった)。段の区切りは `chain()`、並行は `parallel()` で1つずつ明示する。
- **エモートのボタンは `CardMatchScreen.ACTION_BUTTON_SIZE` を使い、「ログ」「投了」と同じ `CodedButton.make()` で作る。**寸法を別に持つと、同じ列に並んだときに1つだけ別のボタンに見える。
- **選択肢のポップアップ(`EmotePopupPanel`)は `PanelContainer` を継承し、余白だけを持つ空のスタイルを当てて面は `_draw()` で描く**(多段グラデーション + グレイン + 落ち込み影 + 真鍮の枠)。テーマ既定の平坦なパネルのままだと、盤面の上でここだけ別のUIから来たように見える。行の区切りも `HSeparator`(テーマ既定の白い線)ではなく真鍮の細線にする。**面を描くのに `Control` を直に使わない**。子より背面に描かれる性質は望ましいが、コンテナでないと中身の大きさに合わせて自分の大きさが決まらず、パネルが0サイズのまま何も描かれない。
- 画面側(`CardMatchEmote`)では送信後9秒間のクールダウンを持ち、吹き出しが完全に消えて余韻を待ってから再利用できるようにする。**残り時間は `CardMatchScreen._process()` から渡される `delta` だけで減らす**(専用の `Timer` を併せて持たせると二重に減り、クールダウンが半分の速さで明けてしまう)。
- **エモートは棋譜へ記録しない**(`CardMatchScreen._record()` が弾く)。盤面を動かさないため、残すとリプレイの手数だけが増え、コマ送りで何も起きない手を挟むことになる。オンラインでは通信の経路として `actions` に載せるが、これは受信のための搬送であって記録ではない。
- **エモートのUIは対局画面より後に `add_child()` されるため、結果パネル・ログより手前に描かれる**(Godotは後の子ほど手前)。終局後はボタンとポップアップを隠して、結果パネルの操作を塞がないようにする。
- 吹き出し(`EmoteBubble`)の大きさは `_ready()` で文字から決める。**`_draw()` の中で `size` を書き換えない**(レイアウトが変わって再描画が呼ばれ、毎フレーム描き直し続けるため)。
- マリガン中(`state.mulligan_pending` / `_mulligan.visible`)はエモート送信を無効化し、**ボタン自体を隠す**(無効の見た目のボタンが「ログ」「投了」の隣に並ぶと、そこだけ色が違って見えるため)。
- 相手のエモートミュートフラグ(`mute_opponent_emotes`)をサポートし、ミュート中は相手からのエモート吹き出し表示をスキップする。

## 6.7 待っている間のCPU対戦(GameDesign.md 11章・28章)

| クラス | 責務 |
|---|---|
| `MatchmakingQueue` | 待機中のCPU戦の印(キューの `cpu` フィールド)を持つ。`set_cpu_playing()` で書き換え、CPU戦中は掴まず `others_waiting(uids)` だけを出す |
| `RankedMatchmakingQueue` | `MatchmakingQueue` の派生。コレクション(`ranked_queue`)とDiscordへの募集通知の有無だけを変える |
| `WaitingCpuOffer`(`scripts/ui/waiting_cpu_offer.gd`) | 待機画面の「待っている間CPUと対戦する」ボタンと、出すまでの15秒。ランダム・ランクの両画面が持つ |
| `WaitingCpuDeck`(`scripts/net/waiting_cpu_deck.gd`) | CPUに渡すデッキを `match_records` の直近の記録から1つ選ぶ。使えるものが無ければ `CardDeckSave.random_deck()` |
| `WaitingCpuMatch`(`scripts/ui/waiting_cpu_match.gd`) | `Main` の子。いま待機中のCPU戦をしている画面、知らせ(`WaitingCpuPrompt`)と「続ける」を選んだ相手の記録を持つ |

**掴んでよいのは両者とも `cpu` が偽の待機者どうし。**CPU戦中の側は `_try_claim_or_check()` で
掴みに行かず、同じビルド・新しい待機者のuidを毎回のポーリングで `others_waiting` へ流す。
「マッチングする」は `cpu` を偽へ戻して通常の待機へ戻すだけで、掴むのは次のポーリングの
通常経路に任せる(掴む処理を2本持たない)。相手もCPU戦中なら、こちらが偽へ戻った時点で
相手の `others_waiting` に現れ、相手の側に知らせが出る。

**待機画面はCPU戦の間も生きたまま隠れている**(`Main._show_only()` は画面を解放しない)ため、
キューのポーリング・生存確認はCPU戦の裏で続く。`Main._on_match_back()` は待機中のCPU戦から
戻るときだけ `reset_after_match()` ではなく `resume_waiting()` を呼び、キューを残す。

**打ち切りは `CardMatchScreen.abandon_match()`**。`_reset_for_new_match()` で盤面・CPUの
タイマー・棋譜を捨てるだけで、`CardMatchOutcome` を通さないため勝敗・砂金・戦績・リプレイは残らない。

**★を動かさないのは既存の経路のまま**:待機中のCPU戦は `start_cpu_match()` を通る通常のCPU戦
(`MatchKind.CPU`)であり、`RankProgress.apply_result()` はランクマッチの対局でしか呼ばれない。
