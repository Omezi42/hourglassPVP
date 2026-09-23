# 開発時の落とし穴(Pitfalls)

実装・検証で繰り返し踏んだもの。**いずれも「エディタ実行やヘッドレステストでは再現せず、書き出した版や実機でだけ壊れる」種類**であり、知らずに作業すると同じ穴を掘り直す。**コードやシーンを触る前に一度読む。**新しく踏んだ穴はここへ足す(Architecture.md には書かない)。


### 検証の抜け

- **新しい `class_name` を持つスクリプトを追加した直後は `godot --headless --path . --import` を
  1度実行する。**`.godot/global_script_class_cache.cfg` へ登録されず、`--script` 起動が
  「Could not find type "..." in the current scope」で失敗する
- **`tools/tests/run_tests.gd` は `scripts/ui/` を読まないため、UIのパースエラーを検出できない。**
  UIを触ったら `--quit-after` での起動スモークまで回す
- **GUIのクリックはヘッドレスでは一切届かない**(`push_input` しても
  `gui_get_hovered_control()` は none のまま)。押下の確認は非ヘッドレスで行う
- **演出のスクリーンショットは `Engine.time_scale` を0.2程度へ落として撮る。**
  `get_viewport().get_texture().get_image()` + `save_png` は演出より実時間のコストが
  大きく、0.3秒程度の動きは撮り逃して「実装が効いていない」ように見える
- **エクスポート済みpckに対しても回す**
  (`godot --headless --main-pack build/web/index.pck --script res://tools/tests/run_tests.gd`)。
  `.tres` が `.tres.remap` になることに起因するパス解決の差異は、これでしか出ない

### データとコードの境目

- **`CardEnums` の enum の並びは保存データである。**`.tres` は enum を整数で保存するため、
  途中へ値を挿入すると**既存のカードの効果・対象・トリガーが丸ごとずれる**。
  実際に `ADD_ATTACK` を `ADD_TOTAL` の隣へ入れたところ、エコーのドローが砂落としになり、
  スイープの全体除去が別の対象になった。**新しい値は必ず末尾へ足す。**
  並びの読みやすさより、保存済みの `.tres` との整合を優先する
- **`.tres` から読んだ `CardData` を書き換えない。**`load()` は同じインスタンスを返すため、
  対局中に書き換えるとその版の全対局(リプレイ・シミュレーションを含む)へ残る。
  キーワードの付与・消去は `CardInstance` 側の `granted_keywords` / `silenced` で持つ
- **`@export` の配列は `PackedStringArray` ではなく `Array[String]` にする。**
  エクスポート時のテキスト→バイナリ変換で **`PackedStringArray` の中身が丸ごと落ちる**。
  `.tres` には値が書かれているのに、書き出した版では空の配列になる。実際にリーサルパズルの
  `hand_ids` / `own_units` / `foe_units` がこれで空になり、**盤面にも手札にも砂時計が
  1つも無い状態で出荷した**。エディタ実行でもヘッドレステストでも再現せず、
  **pckに対してテストを回して初めて出る**(5章の `.remap` と同じ種類の穴)

### GDScript

- **型付き配列(`Array[String]`)を要求する関数へ untyped の `Array` を渡すと、
  実行時に関数ごと呼ばれない。**コンパイルは通り、その経路を通るまで気づけない。
  渡す値は生成側の戻り値の型まで揃える
- **ラムダは外側のローカル変数を値でキャプチャする。**シグナルの引数をラムダから
  外側の変数へ代入しても伝わらない。`Array` / `Dictionary` でラップして要素へ代入する
- **static だけのクラスに `reload()` のような `Script` の組み込みメソッドと同じ名前の関数を作らない。**
  `ClassName.reload()` はその関数ではなく `GDScript.reload()` を呼び、**スクリプトを読み直して
  static var をすべて初期値へ戻す**。エラーは出ず、「外から代入した static var が効かない」ように見える
- **`var x := ProjectSettings.get_setting(...)` は Variant 推論の警告でコンパイルが落ちる**
  (警告がエラー扱いのため)。`var x: Variant = ...` と明示する

### Godotの挙動

- **`set_anchors_preset()` は「今の矩形を保つように」offsetを計算し直す。**コードで生成した
  直後(サイズ0)のノードへ使うと0サイズのまま固定され、何も描かれない。
  `anchor_right` / `anchor_bottom` への直接代入で設定する
- **`Control._draw()` は自分の子より背面に描かれる。**画面側で描いた線は子ノードに隠れる。
  手前に出したいものは独立したオーバーレイのノードにする
- **後から `add_child()` した子ほど手前に描かれる。**モーダル・暗幕は最後の子へ置く
- **`Label.autowrap_mode` は `size` より先に立てる。**折り返しが無効なあいだ Label の
  最小幅は文章そのものの幅であり、`Control` はそれより小さくならない。後から折り返しを
  有効にしても既に広がった `size` は戻らず、狭い欄に置いた説明文どうしが重なる
- **`MOUSE_FILTER_PASS` はイベントを背面の兄弟ではなく親へ渡す。**全面に敷いた
  `MarginContainer` より前の子は、ホバーを奪われて押せなくなる
- **`ResourceLoader.exists()` は pck から除外した後も true を返すことがある**(実測)。
  ファイルの有無の判定には使えない。Web/デスクトップの分岐は `OS.has_feature("web")` で行う
- **`class_name` を持つ2つのスクリプトが、互いの const を const から参照してはいけない。**
  読み込みが循環して**起動したまま固まる**(エラーも出ない)。実際に `CardMatchDetail` の
  const から `CardMatchScreen.TABLE_RECT` を読んで踏んだ。参照は関数の中(実行時)へ移す
- **角丸の外周点列は、重複した頂点を残したまま塗ってはいけない。**半径が辺の半分に達すると
  隣り合う2つの角が同じ中心を共有し、境目の頂点が重なる。この点列を
  `canvas_item_add_polygon()` へ渡すと、浮動小数点誤差しだいで
  **「Invalid polygon data, triangulation failed」でその面が黙って描かれなくなる**
  (HPバーの残量が12px以下になった瞬間に実際に出た。エディタ実行でも出るがログを
  見ていないと気づけず、幅によって出たり出なかったりする)。`UiPaint.rounded_rect_points()` /
  `chevron_left_points()` は `dedupe_ring()` を通してから返す。**円は
  `circle_points()` を使う**(4隅の弧の中心がすべて同一点へ縮退するため、
  角丸矩形を円として流用しない)
- **`.tscn` はテキストとして直接編集しない。**`tools/godot_apply_patch.gd` か
  一時ビルドスクリプト(適用後に削除)経由で更新する。ルートにスクリプトを持つシーンを
  再生成する際は `root.set_script()` を忘れない(忘れるとその画面が一切起動しなくなる)

### 非ヘッドレスの静止画・動画キャプチャ(`--write-movie` / スクリーンショット)

Discord用のカード画像・実演GIF(10.14節)を作る過程で踏んだもの。

- **`--headless` では実際のピクセルが得られない。**`get_viewport().get_texture().get_image()`
  も `--write-movie` も、GPU(またはソフトウェアレンダラ)で実際に描画された結果を読むため、
  `--headless` を付けると空またはエラーになる。静止画・GIFの撮影ツールはすべて
  通常起動(ウィンドウを開く)で実行する。**ビルドスクリプト(`export_web.sh`)が
  全工程を `--headless` で回す前提になっている場合、これらのツールはそこへ組み込まず
  別に持つ**
- **Windows版Pythonの標準出力はCRLFで返る。**`IDS=$(python script.py)` のように
  bashへ複数行の結果を渡すと、各行の末尾に `\r` が残ったまま単語分割される。
  この `\r` 付きの文字列を外部プログラム(Godot等)へパスとして渡すと、
  パスの解決自体が失敗し、しかも**エラーメッセージが「ディレクトリが開けない」
  のような一見無関係な内容になる**ため原因に気づきにくい。`tr -d '\r'` を通すか、
  コマンドライン引数を経由させずファイル内で相対パスとして直接開く
- **同じ出力ディレクトリへ複数の `--write-movie` プロセスを重複して走らせると、
  互いに干渉して撮影が失敗する。**デバッグ中に起動したプロセスが完了(またはkill)する
  前に本番の一括実行を始めると、まったく同じ症状(大半のカードが0バイトで、
  最後に処理したものだけ正常)が起きる。バッチ処理の前に `tasklist` で
  Godotプロセスが残っていないことを確認する

### Node.js(Cloud Functions)側

- **`@napi-rs/canvas` はシステムに日本語フォントが1つも登録されていない前提で動く。**
  Cloud Functions(Linux)には日本語フォントが入っておらず、フォントを指定せずに
  `fillText()` すると**文字がすべて豆腐(□)になる**(実測で確認済み。10.6.1節の
  `SubViewport` のフォント解決と同種の問題がNode.js側にもある)。`GlobalFonts
  .registerFromPath()` で同梱フォントを明示的に登録してから使う
- **`functions/` の外にあるファイルはデプロイされない。**`firebase.json` の
  `functions.source` が `functions` ディレクトリだけを指すため、
  `assets/fonts/` のようなプロジェクトルート直下のファイルを参照しようとしても
  本番環境には存在しない。フォントのように実行時に要るファイルは `functions/` の
  中へコピーして持たせる

### 触ってはいけないもの

- **`user://` 配下の実データ(`card_decks.json` 等)に触らない。**過去に誤って削除する事故が
  発生している。テストで扱う場合は必ず「控える → 上書き → 検証 → 戻す」の往復にする

### 行数の上限

- gdlint の `max-file-lines` が1000行。`card_match_screen.gd` と `run_tests.gd` は
  この上限に張り付いているため、**足す前に切り出す**
  (`_screen` 参照を持つ `RefCounted` へ分ける既存の流儀に従う)

---

