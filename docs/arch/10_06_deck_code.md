# 10.6 デッキコード(GameDesign.md 9章)

**画面へ出すコードは8桁の数字であり、中身は持たない。**`deckcodes/{コード}` へ
「id*枚数」を `,` で連ねた文字列(`CardDeckCode.to_text()`)を預け、番号だけを渡す。
30枚の組み合わせは1億通りをはるかに超えるため、**中身を持ったまま8桁へ収めることは
原理的にできない**。

| クラス | 責務 |
|---|---|
| `DeckCodeService`(`scripts/net/deck_code_service.gd`, static) | 預ける(`publish`)・引く(`fetch`)。`AccountService` と同じく `FirestoreClient` を受け取る形にし、UI が Firestore を直接叩かない |
| `CardDeckCode`(static) | デッキ ⇄ テキストの変換(`to_text` / `from_text`)と、戦績が使う指紋(下記) |

- **発行は `CardDeckSharePanel` の「コードを発行してコピー」を押したときだけ行う。**画面を開くだけで
  預けると、使われないドキュメントが際限なく増える。**同じ構築には同じ番号を返す**ため、
  `publish()` は指紋 → コードの対応をセッション内でキャッシュする
- **コードは使われていない番号を選んで作る**(`create_document()` の `exists:false`)。
  衝突したら引き直す
- **預けたデッキは消さない**(GameDesign.md 9章)。保持件数の上限も持たない
- **`CardDeckCode.fingerprint()` は画面へ出さない内部の識別子**として残す。戦績
  (10.7節)がデッキ別の勝率を数えるのに使っており、**記録のたびに通信させるわけには
  いかない**ため、こちらはローカルで完結する文字列(`HG1-` + deflate + Base64)。
  読み込みの経路は無く、突き合わせにしか使わない

**プールから消えたカードを含むコードは読めない。**`from_text()` が `CardLibrary` に
無い id を見つけた時点で空の配列を返す。カードが増えるぶんには既存のコードは読める。

## 10.6.1 デッキ表の画像(GameDesign.md 9章)

**共有の入口は `CardDeckSharePanel` の1つだけ**とし、「渡す / 受け取る」の2面を
`Face` で出し分ける(面ごとに `Control` の層を持ち、`visible` を切り替えるだけ)。渡す面にデッキ表と
デッキコードを並べる。ヘッダーの主アクションは3つまでで
既に保存・プリセットが埋まっており、**分けると4つ目が必要になる**という事情もある。

| クラス | 責務 |
|---|---|
| `CardDeckSheet`(`scripts/ui/card_deck_sheet.gd`) | 表そのものの組み立てと描画。大きさは `SHEET_SIZE` の固定値 |
| `ImageShare`(`scripts/logic/image_share.gd`, static) | PNGをクリップボードへ置く / ファイルへ保存する。Web と それ以外の分岐を1箇所へ集める |

- **表は `SubViewport` の中で組み、その `ViewportTexture` をそのままパネルへ映す**。
  書き出す画像と画面に見えているものが同じ実体になるため、**見本と書き出しが食い違う
  経路そのものが無い**。`HourglassArt` が焼き付けに使っているのと同じ流儀
- **棚は `CardDeckShelf` を使い回す**(`columns = 10` / `readonly = true`)。
  共有のためだけに似た並べ方をもう1つ書くと、片方だけが古くなる。
  **大きさは 1280x720 の固定**(枠の数が固定になったため高さも決まる)
- **コードの表示と入力は `CodeTiles`(`digits = CODE_LENGTH`)**。ルーム画面と同じ升を使い回す。受け取る面の `NumberPad` は常に出し、「決定」は持たない(確定は「読み込む」)
- **読み込みの確認は `ConfirmModal` をパネルの最後の子に置いて出す。**引いたデッキは `_pending_deck` に持ち、「入れ替える」で初めて `loaded` を流す
- **並びは `CardLibrary.compare_by_cost` を通す。**画面ごとに並べ方を決めない
  (GameDesign.md 9章)
- **コードは既に発行済みのときだけ載せる。**画像を出すためだけに `publish()` を
  呼ぶと、見せるだけのつもりで通信し、使われない番号を預けることになる
- **画像をクリップボードへ置けるのは Web だけ。**Godot 4.6 の `DisplayServer` は
  `clipboard_get_image()` しか持たない(`clipboard_set_image()` は存在しない)ため、
  `ImageShare` は Web では `JavaScriptBridge` から `navigator.clipboard.write()` を呼び、
  **断られたらDOMオーバーレイで画像を表示して右クリックコピーできるようにする**(併せて保存リンクも用意)。
  それ以外の環境では `user://` へ保存して保存先を1行で示す。判定は `OS.has_feature("web")` で行う
- **`JavaScriptBridge.create_callback()` の戻り値は変数へ持ち続ける。**その場で捨てると
  JS 側から呼び戻される前に解放され、結果が返らない
- **`SubViewport` 内のフォント解決と文字化け対策。** `SubViewport` は親 Control の `theme` を
  自動継承しないため、`project.godot` の `[gui] theme/custom` に `main_theme.tres` を設定し、
  さらに `CardDeckSheet` 自体も `THEME_PATH` を `_ready()` で読み込む。
  `CardDeckShelf` のフォールバック先もエンジン組み込みフォントではなく
  同梱の日本語フォント(`ZenKakuGothicNew-Bold.ttf`)を参照させ、Web書き出し環境等で
  画像内の日本語文字が豆腐(□)に化けるのを防ぐ
