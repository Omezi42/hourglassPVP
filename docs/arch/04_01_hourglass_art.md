# 4.1 砂時計イラストの解像度と配置

砂時計の絵は**カードごとに1本のシェーダーで描き、ビルド前にPNGへ焼いて配る**(10.19節)。
unityroom向けのWeb配信ではpckのサイズがそのままロード時間に直結するため、**実行時に読まないファイルは
`.gdignore` を置いてGodotの管理外へ出す**(インポートもエクスポートもされなくなる)。

| ディレクトリ | 内容 | Godotの扱い |
|---|---|---|
| `assets/hourglasses/overrides/{id}/state_*.png` | **実行時に読む砂時計の絵**(3状態)。`resources/shaders/hourglasses/{id}.gdshader` から焼いたもの。動く絵の層(`frame_*` / `back_*`)も同じ場所 | インポートする |
| `assets/hourglasses/emblems/{id}.png` | **カード固有の紋章**。白のシルエット192px | インポートする |
| `assets/hourglasses/emblems/sources/` | 紋章の取り込み元SVG(icooon-mono) | `.gdignore` + `.gitignore` |
| `assets/hourglasses/processed/{id}/` | 画像の絵だった頃の参考用の絵。Discord用の画像とすなえるの絵の土台に使う。**実行時には読まない** | `.gdignore` で無視 |
| `assets/hourglasses/sources/` `processed_backup/` `incoming/` | 画像の絵だった頃の生成元 | `.gdignore` で無視 |

紋章のPNGは `tools/build_emblem_icons.gd` がSVGから焼き直す。カードを追加したら、
モチーフのSVGを `sources/{id}.svg` へ置いてこれを1度回す。

| クラス | 責務 |
|---|---|
| `HourglassSandTable`(`scripts/data/hourglass_sand_table.gd` + `data/hourglass_sands.tres`) | 絵のid → 砂の色(`sand`)と砂の質感(`texture`、任意)。シェーダー・手札の光だまり・共通のガラスが同じ1行を見る |
| `HourglassArt`(`scripts/logic/hourglass_art.gd`, staticのみ) | 焼いた絵を読んで `Texture2D` として配る。焼いた絵が無いid(砂術)は null。`SoundBank` と同じ「Autoloadを使わずstaticで持つ」流儀 |

- **`CardData.icon_upright` などはプロパティの getter で、`.tres` は絵への参照を持たない。**
  絵のidはカードのidそのもの(`art_id` で別の絵を借りるのは砂術だけ。借りると2枚が同じ姿になるため)
- **砂の質感は文字列で持つ**(grain / liquid / crystal / glow / stardust。無ければさらさら)。
  `.tres` へ整数で残る enum の並び替え事故(Pitfalls.md)を避けるため

## コード描画の絵の取り込み(10.19節)

`overrides/{id}/` の焼いた絵(state・frame・back)は**キャンバス(400x532)の半分の 200x266 で焼き**、非可逆のWebP・画質0.85で取り込む(焼く道具が `.import` を置く)。
場の駒・図鑑の動く絵は高さ224で描き、手札・詳細はそれより小さいため、半分でも原寸と見分けが付かない。
取り込み後は1種あたり約0.1MBで、全101種で約10MB。半分にするのは、全カード×3状態の絵がGPUに常駐し、
原寸ではスマホのブラウザのメモリ上限に届くため。
焼いた絵が描き手(シェーダー・共通の部品・表の行)と食い違っていないかは、`tools/check_hourglass_bake.py` が
`tools/hourglass_bake_manifest.json` のハッシュで確かめる(check.sh)。

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
- **砂時計の絵は半分の大きさで焼く**(4.1節)。1種あたり約0.1MBで、カードを1種足すごとにここが増える
- **背景は1920x1080を覆う最小サイズまで縮める**。基準解像度は1280x720であり、
  2752x1290のような原寸をそのまま持つ理由がない
- **`tools/export_web.sh` は index.pck が前回より1MB以上増えたら止める**(前回の大きさは `tools/last_pck_size.txt`)。
  増えるのが分かっている回は `PCK_GROWTH_OK=1` を付ける。急増は気づいたときには配布物に入っているため

**ロスレスのctexはgzipでほとんど縮まない**ため、pckの数字がそのまま転送量になる。
wasmだけがgzipで1/4になる点と混同しないこと。

## BGMはpckへ入れず、実行時に取りに行く

BGM3曲は合計8.6MBあり、上の3点を守ってもなおpckの7割を占める。**曲を短く切るのではなく、
起動を待たせないようにする**ことで解決する。

- Webプリセットの `exclude_filter` に `assets/bgm/*` を入れ、pckから外す
  (**`export_presets.cfg` はエディタが書き出すたびにフィルタを空へ書き戻す**。
  実際に2度これが起きて、pckが4.1MBから15MBへ膨らみ、同時に
  `data/discord_webhook.txt` が落ちて募集通知が飛ばなくなった。
  **人が確認する運用では防げないため、`tools/export_web.sh` が書き出しの直前に
  `tools/ensure_export_filters.py` でフィルタと `export_path` を揃え直し、
  書き出した後に `tools/verify_web_pck.gd` でpckの中身を名指しで検査する**)
- **本番のpckからは `tools/` を丸ごと外す**(実行時に `res://tools/` を読むコードが無く、テスト・撮影・生データで約0.7MBあるため)。
  ただしテストのスクリプトはpckの中に要るため、`tools/` を残した検査用プリセット `WebCheck`(`build/web_check/index.pck`)も
  書き出し、`run_tests.gd` と `matchmaking_live_test.gd` はそちらへ回す。本番のpckは `tools/verify_web_pck.gd` を
  **ディスクのパスで渡して**中身を調べ、`res://tools/` や BGM が1つでも入っていれば落とす
  (検査用と本番は `tools/` の有無だけが違う。`.remap` の差異は検査用で拾える)
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
| `CardMatchTutorial`(`scripts/ui/card_match_tutorial.gd`) | 誘導対局の台本の進行そのもの。台本の手を1つずつ`MatchState`のシグナルで達成を判定し、関門(`gate_*()`)・CPUの手(`cpu_action()`)もここが答える。**帯の中身(すなえる・文・「つぎへ」)は `_band` という1つの `Control` の子として相対座標で持つ**。マリガン中だけ帯を下げるため、動かすのが `_band.position` の1箇所で済む。**「閉じる」は持たない**——台本は最後の一撃で勝って終わり、自由に続ける段が無いため。勝って終わったときは最後の手の `done` を締めの一言として残し、自分を親の最前面へ移して結果パネルより手前に出す。CPUの間合いは `cpu_delay()` が答え、`CardMatchScreen` はCPUのタイマーをこれで始める(帯の予告文の長さに比例) |
| `TutorialSkip`(`scripts/ui/tutorial_skip.gd`) | 画面の左下に固定して出す「スキップ」(GameDesign.md 18章)。押すと `ConfirmModal` で確かめ、`FunnelService` へ `tutorial_skip` を送ってから対局画面の「ホームへ戻る」と同じ経路で抜ける。`tutorial_done` は立てない。`card_match_tutorial.gd` が行数の上限に近いため別に持ち、`CardMatchTutorial` の子として画面座標へ置く(帯の子にすると、マリガン中に帯ごと動く)。誘導対局の間は `CardMatchScreen` が投了のボタンを出さない |
| `TutorialFocus`(`scripts/ui/tutorial_focus.gd`) | 誘導対局で光らせる場所(操作を求める輪郭・話題の数字)を、台本の1手から対局画面の矩形へ写す。**いつ光らせるか**(説明を読んでいる間は消す等)は `CardMatchTutorial` が決め、ここは場所だけを答える。`watch()` のたびに作り直す |
| `TutorialFacts`(`scripts/ui/tutorial_facts.gd`) | 段階を終えたときの一言へ差し込む実際の数値の文。台本の参照名 → `CardInstance` の表から組むだけの static。攻撃の結果だけは信号を数える必要があるため `CardMatchTutorial` に残す |
| `TutorialCpuStrategy`(`scripts/logic/tutorial_cpu_strategy.gd`) | `CardCpuStrategy`を継承するが貪欲法は呼ばず、`CardMatchTutorial.cpu_action()`へ委譲するだけの台本用の代役 |
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

**誘導対局は専用のモードを作らず、CPU戦の骨組みへ台本を重ねるだけにする。**ルールは `MatchState` /
`MatchAction.apply()` をそのまま通す。専用モードを作ると、対局のルールが2箇所に分かれて食い違う余地が生まれる。

**台本は `TutorialScriptData`(Resource、`resources/tutorial/tutorial_script.tres`)が持つ**(GameDesign.md 18章)。
両者の山札のid(並び=引く順。`MatchState.keep_deck_order` で切らずに始める)、相手の開始HP、
そして**両者の手を順に並べた `steps`**。各手は `side`("a"/"b"/"info")・`kind`(play/attack/flip/
flip_right/end_turn/mulligan)・指示の文・終えたときの説明・光らせる数字を持つ。**盤面のどの枠へ
置くか/どの枠を攻撃するかは枠番号ではなく`ref`(置いた駒に付ける参照名)で持つ**——空き枠は
プレイヤーが自由に選べるため、置き先の枠番号は対局のたびに変わりうる。`CardMatchTutorial._refs`
(参照名→`CardInstance`)がこれを盤面上の実際の枠へその場で引き直す。
台本をコードへ書かないのは、カードの調整で成立しなくなったときに `.tres` だけを直せば済むようにするため。

- **CPUの手は台本から出す**。`TutorialCpuStrategy`(`CardCpuStrategy`を継承するが貪欲法は呼ばず、
  `CardMatchTutorial.cpu_action()`へ委譲するだけ)を`_cpu`に差し、既存の間合い(1手ずつ間を置く)を
  そのまま使う。台本のCPUの手が尽きると(次の手の`side`が"a"になると)`end_turn`を返して自分で
  ターンを終える
- **プレイヤーの操作は、台本の次の手と一致するものだけを通す**。手札・駒の選択と行動の確定、
  それぞれの入口で `CardMatchTutorial.gate_*()`(関門)を呼び、誘導対局の間だけ答えを返す。
  通常の対局(`_active == false`)では常にtrueを返す
- マリガンは札を選べず「このままで開始」だけを受け付ける(`CardMatchMulligan.picking_disabled`)
- **手番の切り替わりの「あなたの番」は出さない**(GameDesign.md 9章)。`CardMatchScreen._on_turn_started()`
  が `is_tutorial` を見て `_feed.announce_turn()` を呼ばないぶんだけ分岐する。手番の流れはすなえるの帯が
  案内するため、実況と二重に出す必要がない
- 光らせるのは台本の次の手が指す1か所(駒を選んで相手を押す手は、選ぶ前は自分の駒・選んだ後は相手)。
  説明中の数字の光は `CardMatchGeometry` から位置を取り、輪郭とは色を分ける
- 成立は `tools/tests/tutorial_script_tests.gd` が確かめる(台本の手を順に `MatchState` へ直接適用し、
  すべて合法で、要所の数値が合っていて、最後の手でプレイヤーが勝つ)

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
**縦だけは帯を相手のマナの行と直前の手の列へ重ね(HPは覆わない)、面を不透明にする**。縦の卓の上端へ渡すと相手の列をほぼ覆い、押す相手の駒と輪が帯の下に入るため(GameDesign.md 9章「縦の対局画面」)。縦のマリガン中は画面の上端へ置く。

**マリガンの間だけ帯を確定ボタンの下(`MULLIGAN_BAND_TOP`)へ下げ、`_tutorial` を `_mulligan` より
後に `add_child()` する**(GameDesign.md 18章)。暗幕の下に敷くと読めず、マリガン中は帯ごと
隠すと**いちばん案内が要る最初の画面が無言になる**。マリガン画面は見出し・手札・確定ボタンで y=66〜432 を使うため、下げる先はその下しかない。

**段階を終えたときの説明は `Timer` で流さず「つぎへ」を押すまで残す**(GameDesign.md 18章)。
1秒程度で自動的に切り替えると読み切る前に消え、**案内が最初の1回しか出ていないように見える**。段階をすべて終えたら締めの一文
(`OUTRO_TEXT`)を出し、そのボタンが「とじる」に変わってから閉じる。
