# 4.1 砂時計イラストの解像度と配置

砂時計のイラストは、実行時に使うものと、それを作るための元データを明確に分ける。unityroom向けの
Web配信ではpckのサイズがそのままロード時間に直結するため、**実行時に読まないファイルは
`.gdignore` を置いてGodotの管理外へ出す**(インポートもエクスポートもされなくなる)。

| ディレクトリ | 内容 | Godotの扱い |
|---|---|---|
| `assets/hourglasses/master/state_*.png` | **実行時に読む唯一の砂時計の絵**(サンドの3状態)。幅400px基準 | インポートする |
| `assets/hourglasses/processed/{id}/` | 色違いを焼いた参考用の絵。**実行時には読まない** | `.gdignore` で無視 |
| `assets/hourglasses/overrides/{id}/state_*.png` | そのカードだけの固有の絵(あれば色変換より優先) | インポートする |
| `assets/hourglasses/sources/{id}/` | 生成元(`source.png`)と縮小前の原寸`state_*.png` | `.gdignore` で無視 |
| `assets/hourglasses/processed_backup/` | 正規化前の絵(現行とは内容が異なる) | `.gdignore` で無視 |
| `assets/hourglasses/incoming/` | 取り込み待ちの生成画像 | `.gdignore` で無視 |
| `assets/hourglasses/emblems/{id}.png` | **カード固有の紋章**。白のシルエット192px | インポートする |
| `assets/hourglasses/emblems/sources/` | 紋章の取り込み元SVG(icooon-mono) | `.gdignore` + `.gitignore` |

紋章のPNGは `tools/build_emblem_icons.gd` がSVGから焼き直す。カードを追加したら、
モチーフのSVGを `sources/{id}.svg` へ置いてこれを1度回す。

## 絵は1組だけ持ち、色は実行時に付ける(GameDesign.md 9章)

**全58種はサンドの絵1枚の色違いであり、輪郭は完全に一致する。**色違いを焼いた画像を
種類の数だけ配ると、pckの7割(6.7MB)を同じ絵が占め、**カードを1種足すたびに約115KBずつ
積み上がる**。そこで実行時に持つのは1組だけにし、色は数値として持つ。

| クラス | 責務 |
|---|---|
| `HourglassTintTable`(`scripts/data/hourglass_tint_table.gd` + `data/hourglass_tints.tres`) | 絵のid → 「親のid + 色変換1段」の表。**親をたどると必ずサンドへ着く** |
| `HourglassArt`(`scripts/logic/hourglass_art.gd`, staticのみ) | 表に従って絵を焼き、`Texture2D` として配る。`SoundBank` と同じ「Autoloadを使わずstaticで持つ」流儀 |

色変換1段の定義は次のとおりで、`tools/tint_hourglass_icons.gd` の `_tint()` と同じもの
(明度と彩度の下駄を足してある)。**1画素の色だけで決まる**ため、そのままシェーダになる。

```
s < threshold の画素は触らない   … 無彩色のガラスと輪郭を色付けしないため
h' = h + hue
s' = clamp(max(s * sat + sat_bias, floor), 0, 1)
v' = clamp(v * value + value_bias, 0, 1)
```

- **焼くのは `SubViewport` + シェーダで、結果を `ImageTexture` として持つ。**描画側は
  今までどおり `Texture2D` を受け取るだけで、`CardView` / `CardDetailPanel` /
  `CardDeckShelf` / `CardDeckListScreen` / `ReplayListCard` のいずれも変更しない。
  **描画のたびにシェーダを掛ける方式は採らない**。カードの絵は5つの画面がそれぞれ別の
  描き方(`draw_texture_rect` と `TextureRect`)で出しており、5箇所へシェーダを配ると
  1箇所書き漏らしただけで色が違うカードが出る
- **`CardData.icon_upright` などはプロパティの getter へ変え、`.tres` からは絵への参照を外す。**
  `.tres` が持つのは絵のidだけになる(既定はカードのid。ガード=`king` / グロウ=`judge` のように
  別の絵を指す場合だけ `art_id` を書く)
- **親から順に焼く。**深さは最大2段(サンド → 元絵9種 → その色違い)。親の焼き上がりを
  次の段の入力にするため、シェーダは1段ぶんだけを知っていればよい
- **焼き上がる前に配る `ImageTexture` は、サンドの絵で初期化しておき、焼けた時点で
  `set_image()` で中身を差し替える。**同じオブジェクトを配り続けるので、受け取った側は
  何も知らなくてよい。焼きは `Main._ready()` から始めて58フレーム(約1秒)で終わり、
  その間はタイトル画面が出ているため、砂時計の絵は1枚も画面に無い
- **固有の絵(`overrides/{id}/`)があればそれをそのまま配り、色変換を行わない**
  (GameDesign.md 9章)

**色の数値は `tools/fit_hourglass_tints.py` が現行の絵から逆算した。**既知の変換を持つ
40種は完全に一致し(誤差1/255はPNGの丸め)、変換の記録が無い9種とその子8種は
平均1.4〜4.3/255の近似になる。**この差は輪郭のコントラストがわずかに緩む形で出る**ため、
数値を作り直したら現行の絵と並べて目で確かめること。

解像度を幅400pxとしたのは、プロジェクト内で最大の表示サイズが`DeckEditorScreen`の
カード(132x168)であり、基準解像度1280x720を4K全画面へ拡大した場合でも実効336px程度に
収まるため。生成された1038x1330のまま使うと実行時に読む30枚だけで23MBを占める(縮小後は4.4MB)。
2倍表示でも輪郭はぼけない。

縮小の際は、**一律のピクセルサイズへ揃えるのではなく、全画像へ同じ倍率を掛ける**。
`state_falling`のみキャンバスが1077x1380で他の状態(1038x1330)と数%異なっており、
同一サイズへ揃えると状態を切り替えたときに絵柄の大きさが跳ねてしまうため。

新しい駒を追加する際の手順は `.claude/skills/add-hourglass/SKILL.md` に反映済み。

同じ理由から、**砂時計以外の取り込み元(`incoming/`)もすべて `.gdignore` で管理外に置く**。
下記はいずれも実行時に参照されておらず(`assets/ui/`・`assets/buttons/` に残る記述は
コード描画で色をサンプリングした出所を示すコメントのみ)、pckへ入れる理由がない。
元データとしての価値はあるためファイル自体は残す。

| ディレクトリ | 内容 |
|---|---|
| `assets/backgrounds/incoming/` | 背景の生成元(本番は `processed/{画面}/background.png`) |
| `assets/ui/incoming/` | UIパーツの生成元シート(フェーズ12でコード描画へ移行済み) |
| `assets/buttons/incoming/` | ボタンの生成元シート(同上) |

この整理により、インポート済みデータ(pckに入るリソースの目安)は約124MBから約17MBになった。
残る大半は画面背景4枚(約10MB)で、これも表示サイズに対して解像度が過大な可能性があるが、
砂時計と違って全画面に敷くため縮小の判断は別途行う。

---

## 4.1.6 Web配信のロード時間(pckを小さく保つ)

unityroomはpckとwasmを**全部読み終えてから**ゲームが始まるため、pckの大きさが
そのまま起動待ちになる。wasm(37MB・gzipで約9.5MB)は公式テンプレートの固定費で
下げられないため、**削れるのはpckだけ**である。次の3つを常に守る。

- **実行時に読まないディレクトリには必ず `.gdignore` を置く**。検証用の
  スクリーンショットを置く `scratchpad/` と `logs/` は、置き忘れると
  1枚0.8MBのPNGが丸ごとpckへ入る(実際に12MB分が入っていた)
- **テクスチャは非可逆(WebP)で取り込む**(`compress/mode=1`)。砂時計・紋章は
  `lossy_quality=0.85`、背景は0.75。ロスレスのままだと砂時計63枚で7.6MB・
  背景2枚で5.2MBを占める。非可逆にすると合わせて1.7MBになり、
  実際にレンダリングして輪郭の劣化が見えないことを確認済み
- **同じ絵の色違いを画像として配らない**(4.1節)。砂時計の絵は58種ぶんで6.7MBあり、
  **pckの69%を1枚の絵の色違いが占めていた**。1組だけ配って色を実行時に付ける形にすると
  0.12MBになり、**カードを増やしてもここは増えない**
- **背景は1920x1080を覆う最小サイズまで縮める**。基準解像度は1280x720であり、
  2752x1290のような原寸をそのまま持つ理由がない

**ロスレスのctexはgzipでほとんど縮まない**ため、pckの数字がそのまま転送量になる。
wasmだけがgzipで1/4になる点と混同しないこと。

## BGMはpckへ入れず、実行時に取りに行く

BGM3曲は合計8.8MBあり、上の3点を守ってもなおpckの7割を占める。**曲を短く切るのではなく、
起動を待たせないようにする**ことで解決する。

- Webプリセットの `exclude_filter` に `assets/bgm/*` を入れ、pckから外す
  (**`export_presets.cfg` はエディタが書き出すたびにフィルタを空へ書き戻す**。
  実際に2度これが起きて、pckが4.1MBから15MBへ膨らみ、同時に
  `data/discord_webhook.txt` が落ちて募集通知が飛ばなくなった。
  **人が確認する運用では防げないため、`tools/export_web.sh` が書き出しの直前に
  `tools/ensure_export_filters.py` でフィルタと `export_path` を揃え直し、
  書き出した後に `tools/verify_web_pck.gd` でpckの中身を名指しで検査する**)
- **エディタの書き出し先も `build/web/index.html` へ揃える。**unityroomへ上げるのは
  `index.pck` 1つだけなので、別名のpckが並んでどちらを上げるのか迷う状態を作らない
- **Discordのお知らせ用に作る画像・GIFは `assets/` の下へ出さない**
  (`tools/discord/out/`。`.gdignore` 済み)。`assets/mascot/` へ置いていた頃は
  Godotがそれらをインポートし、告知用のバナーやカード画像がpckへ入っていた
- `MusicPlayer` は、Web版では `res://` を試さずに `HTTPRequest` で
  `https://cdn.jsdelivr.net/gh/Omezi42/hourglassPVP@main/assets/bgm/{曲}.ogg` を取得し、
  `AudioStreamOggVorbis.load_from_buffer()` で鳴らす

**置き場所をリポジトリそのもの(jsDelivr経由)にしているのは、unityroomへ上げるのが
`index.pck` だけだからである。**`index.html` の隣へ素のoggを置く形は、その追加ファイルが
配信されないため使えない。jsDelivrは `Access-Control-Allow-Origin: *` を返すため、
unityroomのオリジンからでも読める(実測で確認済み)。

> **この方式は「リポジトリを公開のまま保つ」ことが前提になる。**非公開にすると
> CDNが404を返し、BGMだけが鳴らなくなる(ゲーム自体は動く)。

**この方式が成立するのは、BGMがもともとすぐには鳴らないから**である。ブラウザの自動再生制限で
最初のクリックまで再生を保留しており(9章)、その間にダウンロードが終わる。取得に失敗しても
無音のまま対局は成立するので、エラーで止めない。

**デスクトップ側は `res://` から読む経路をそのまま残す**(`exclude_filter` はWebプリセット
だけのもの)。判定は `OS.has_feature("web")` で行う。`ResourceLoader.exists()` は
pckから除外した後も true を返すことがあり、有無の判定には使えない(実測)。

`tools/balance/` のシミュレーション結果(1.1MB)も実行時に読まないため同様に除外する。

---

## 4.1.5 はじめてのプレイ(GameDesign.md 18章)

| クラス | 責務 |
|---|---|
| `CardPresetDecks`(`scripts/logic/card_preset_decks.gd`, static) | プリセット3つを「idと枚数の表」として持つ。30枚に足りない場合はコストの安い順に埋めるため、**表が古くなっても対局へ入れなくなることはない** |
| `CardPresetPicker`(`scripts/ui/card_preset_picker.gd`) | プリセットを選ぶモーダル。名前だけでは何のデッキか分からないため、狙いの一文を必ず添える |
| `CardMatchTutorial`(`scripts/ui/card_match_tutorial.gd`) | 誘導対局の指示。段階ごとに1つだけ操作を求め、`MatchState` のシグナルで達成を判定する。**帯の中身(すなえる・文・「つぎへ」「閉じる」)は `_band` という1つの `Control` の子として相対座標で持つ**。マリガン中だけ帯を下げるため、動かすのが `_band.position` の1箇所で済む |
| `SunaeruPortrait`(`scripts/ui/sunaeru_portrait.gd`) | 指示の帯の左端に置くすなえるの立ち絵。**絵を持つだけのノード**にし、何を言うかは `CardMatchTutorial` が持つ |

**指示は「文」だけでなく「いま触るもの」も示す**(GameDesign.md 18章)。`CardMatchTutorial`
は `watch()` で対局画面そのものを受け取り、段階ごとの対象(出せる手札 / ターン終了ボタン /
攻撃できる駒 / 反転できる駒)を脈打つ枠で囲む。`mouse_filter` は IGNORE のままで枠だけを
描くため、**手を塞がない**という方針(GameDesign.md 18章)と両立する。

**囲むのは「いま出せる手札」だけで、空き枠は囲まない。**両方を光らせると盤面の大半が
枠だらけになり、どれを押せばよいのか却って分からなくなる(実際に描画して確認した)。
押した後に空き枠が光るのは通常の操作のとおり。

**出せる札が1枚も無い間は、代わりにターン終了を示す**(GameDesign.md 18章)。マナは手番の
始めに増えるため、`_process()` で毎フレーム見て**状態が切り替わったときだけ**文を組み直す。

**段階を終えたときの一言には、その場の実際の数値を差し込む。**駒の名前・砂の前後・
相打ちで双方が削れた量を `MatchState` から読んで前置きにする。
**攻撃だけは後から数える**必要がある。`attack_performed` はダメージの解決より前に出るため、
続けて届く `unit_damaged` / `hp_changed` を数えながら文を組み直す。

**誘導対局は専用のモードを作らず、CPU戦へ指示を重ねるだけにする。**`start_tutorial_match()` は
`start_cpu_match()` をプリセットの「基本」で呼び、その後 `CardMatchTutorial.watch()` を張る。
専用モードを作ると、対局のルールが2箇所に分かれて食い違う余地が生まれる。

**誘導対局の結果パネルだけは主と副を入れ替える**(GameDesign.md 18章)。真鍮のボタンを「CPUともう1局」
(通常の「もう一度」と同じく `start_cpu_match()` を「基本」で呼び、案内は重ねない)にし、「ホームへ」を
凹んだパネルへ下げる。誘導対局かどうかは `CardMatchScreen` が対局の開始時に持っておき、結果パネルへ渡す。

**指示は手を塞がない**(`mouse_filter` は IGNORE)。従わない操作を禁止すると
「言われた通りにしか動かせない」体験になるため(GameDesign.md 18章)。

**途中で閉じるボタンは持たない**(GameDesign.md 18章)。`close()` は締めの一文の
「とじる」からしか呼ばない。一度閉じると以降の段階の案内が二度と読めなくなるため。

**すなえるの絵は `assets/mascot/mascot_avatar.png` 1枚だけを実行時に読む**(GameDesign.md 18章)。
生成元(`tools/build_mascot.py` の出力する原寸とDiscord用のプレビュー)は
`assets/mascot/sources/` へ移し `.gdignore` で管理外に置く。表示は96px程度のため、
取り込みは非可逆(WebP)にする(4.1.6節)。

**表情の差分は持たない。**口を描かない設計(GameDesign.md 18章)のため差分を作る余地が薄く、
1枚で足りる。段階が進んだときの反応は、絵の差し替えではなく**跳ねる動き**で見せる。

**指示の置き場所は卓の上端へ渡した帯**(`BAND_RECT`)。画面の最上段へ敷くと相手のHP・マナ・
山札を覆い、攻撃や反転の判断に要る情報が誘導対局の間ずっと読めなくなる(実際に描いて確認した)。

**マリガンの間だけ帯を確定ボタンの下(`MULLIGAN_BAND_TOP`)へ下げ、`_tutorial` を `_mulligan` より
後に `add_child()` する**(GameDesign.md 18章)。暗幕の下に敷くと読めず、マリガン中は帯ごと
隠すと**いちばん案内が要る最初の画面が無言になる**。マリガン画面は見出し・手札・確定ボタンで y=66〜432 を使うため、下げる先はその下しかない。

**段階を終えたときの説明は `Timer` で流さず「つぎへ」を押すまで残す**(GameDesign.md 18章)。
1秒程度で自動的に切り替えると読み切る前に消え、**案内が最初の1回しか出ていないように見える**。段階をすべて終えたら締めの一文
(`OUTRO_TEXT`)を出し、そのボタンが「とじる」に変わってから閉じる。
