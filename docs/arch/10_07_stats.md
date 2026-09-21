# 10.7 戦績(GameDesign.md 19章)

| クラス | 責務 |
|---|---|
| `MatchStats`(`scripts/logic/match_stats.gd`, static) | `user://match_stats.json` へ積み上げる。アカウント(uid)ごとに「種別別の通算 / カード別 / デッキ別」を持つ |
| `CardStatsScreen`(`scripts/ui/card_stats_screen.gd`) | 左に通算とデッキ別、右にカード別。共通の `ScreenHeader` を使う |
| `CardMatchOutcome`(`scripts/ui/card_match_outcome.gd`) | 終局後の後始末(リプレイの保存・砂金の付与・戦績の記録)。`card_match_screen.gd` が1000行の上限に達したため切り出した |

**リプレイから集計しない。**リプレイは直近30件しか残らないため(GameDesign.md 12章)、
古い対局が消えるたびに通算の勝率が変わってしまう。終局のたびに1件足す積み上げ方式にして、
保持件数と切り離す。

**テストは `MatchStats.reset_for_test()` を通す。**以後の保存が無効になるため、
`user://` の実データを書き換えずに検証できる。

**カード別は「そのカードを入れたデッキで戦った勝率」**であり、カードの強さではない
(強さの測り方は `docs/BalanceReport_v5.md` 2章の方式による)。画面の見出しにもそう書く。

## 10.7.0 戦績のFirestore同期(GameDesign.md 19章)

**別端末からログインしても同じ記録を続けて見られるようにする。**`MatchStats`自体は
Firestoreを一切知らないまま(ローカルの計算と保存だけを持つ)にし、同期は
`MatchStatsService`(`scripts/net/match_stats_service.gd`, static)へ切り出す。

| クラス | 責務 |
|---|---|
| `MatchStats.apply_delta()` | 1局ぶんの増分を任意のバケット(`{"kinds":, "cards":, "decks":}`)へ適用する計算そのもの。ローカルの`record()`とFirestore同期の両方がこれを共有する |
| `MatchStats.replace_bucket()` / `bucket_snapshot()` | ローカルのバケットを丸ごと差し替える/取り出す(同期の押す・引くで使う) |
| `MatchStatsService.push()` | 1局ぶんをFirestoreへ増分する。`AccountService.grant()`と同じ「`updateTime`前提の`commit()`でread-modify-write、競合したら読み直して再試行」の流儀 |
| `MatchStatsService.sync_after_sign_in()` | サインイン直後、`players/{uid}`の`stats_kinds`/`stats_cards`/`stats_decks`でローカルを差し替え、退避してあった未送信分を送り直す |

- `players/{uid}`へ`stats_kinds`/`stats_cards`/`stats_decks`の3フィールドを持たせる。
  中身は`MatchStats`が今持つバケットの3要素(`kinds`/`cards`/`decks`)とそのまま同じ形で、
  Firestoreのネストした`mapValue`(`FirestoreCodec`)がそのまま扱えるため変換は要らない
- **押すのは対局終了のたびに、`CardMatchOutcome.finish()`から`await`せずに呼ぶ**
  (砂金の付与と同じく、結果パネルの表示を通信で止めないため)。通信に失敗した・
  未サインインの場合は`AccountStore.add_pending_match()`(1局ぶんの増分を
  `{kind, won, turns, card_ids, deck_code}`として積む配列。砂金の退避と同じ理由で
  CPU戦がオフラインでも成立するため必要)へ退避する
- **引くのは`AccountService.load_profile()`が読んだフィールドをそのまま渡す形**
  (`sync_after_sign_in()`は二重に通信しない)。ローカルを丸ごと差し替えたうえで、
  退避してあった増分をローカルへ重ねて適用し直してから改めて送信を試みる。
  **ローカルへ重ねるのを差し替えの直後に行う**のは、まだサーバーへ届いていない
  「この端末で遊んだ分」が、差し替えた瞬間だけ画面から消えて見えることを防ぐため
- **Firestore側の正当性検証は行わない**(既存方針。11章)。クライアントが計算した
  増分をそのまま信じる
- カード別・デッキ別の`.tres`が持つ意味(強さそのものではない)は変わらないため、
  画面(`CardStatsScreen`等)の読み出し側は無変更で済む

---

## 10.7.1 プレイマット(GameDesign.md 9章・21章)

対局の卓へ敷く見た目の品。**画像ではなくコード描画**で作り、1件が持つのは
地の色・模様の種類・縁の色・箔の色だけにする(種類を足しても配布物が増えない)。

**既定は「なし」(`PlaymatLibrary.NONE_ID`)であり、卓に何も敷かない。**
`DEFAULT_ID` はこの `NONE_ID` を指す。`MATS` には `"none"` を通常のマットと同じ形の
エントリとして持たせ(`display_name()` 等の既存メソッドがそのまま動くように)、
`PlaymatPaint.draw_mat()` の先頭で `mat_id == PlaymatLibrary.NONE_ID` を弾いて何も描かない
ことで表現する。**新しい模様(`Weave`)は増やさない**——「無地の布」ではなく「布そのものが
無い」状態であり、木の額とレールの内側がそのまま見える(マット導入前の見た目に戻る)。
「砂の海」はこの変更で `price` を `PRICE_STANDARD` へ変え、他の品と同じくショップで買う。

- **マットは切り抜きの効く層(`BoardTable.MatLayer`)として敷く。**模様(砂紋の弧・
  唐草の蔓)は矩形の外まで伸びるため、`_draw()` で直に描くと**卓の外——情報帯や手札の
  上——へ漏れる**(実際に漏れた)。`clip_contents` を立てた `Control` を1枚ずつ置く。
  **ショップとアカウント画面の見本も同じ理由で切り抜く**
- **層は子ノードにする。**`Control._draw()` は自分の子より背面に描かれるため、
  木の額をクラス側が描き、その上へマット、さらにその上へレールの層を重ねる
- **敷き替えは `CardMatchScreen._set_playmats()`**(私設)。このクラスは gdlint の
  公開メソッドの上限へ張り付いており、切り出した進行役は他の私設メンバも直に触っている
  - CPU戦 = 自分の設定 + `PlaymatLibrary.CPU_ID`
  - オンライン = 自分の設定 + `AccountService.fetch_profile()` の `playmat_id`
    (表示名・アイコン・称号と同じ経路)
  - **リプレイ・観戦は既定**。`_reset_for_new_match()` が毎回既定へ戻し、
    対局へ入る側だけが敷き替える(棋譜はマットを記録しない)
- **値段は品ごとに違う**ため、`ShopCatalog.price()` は `id` を受け取る形にしてある
  (アイコン・エモートは品種で一律)
