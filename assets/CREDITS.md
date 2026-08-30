# 素材クレジット

このプロジェクトが同梱している外部素材の出所・作者・ライセンスの記録。

音源の採用条件は **CC0(パブリックドメイン)のみ**(GameDesign.md 9章)。アイコンは
**商用可・クレジット表記不要**であることを条件とする(CC0に限らない)。CC0は表示義務を持たないため
この記録は法的な要求ではないが、後から「この素材はどこから来たのか」を追えないとライセンスの
再確認も差し替えもできなくなるため、取り込んだものは必ずここへ書く。

---

## 効果音(`assets/sfx/`)

すべて Kenney(https://kenney.nl/)による CC0 素材。各パックに同梱の License.txt で
CC0 1.0 Universal であることを確認済み。

| ファイル | 元素材 | パック |
|---|---|---|
| `button.wav` | `click_005.wav` | [Interface Sounds](https://kenney.nl/assets/interface-sounds) |
| `flip.wav` | `switch_003.wav` | Interface Sounds |
| `move.wav` | `drop_002.wav` | Interface Sounds |
| `swap.wav` | `maximize_008.wav` | Interface Sounds |
| `damage.ogg` | `impactGlass_medium_000.ogg` | [Impact Sounds](https://kenney.nl/assets/impact-sounds) |
| `result_win.ogg` | `jingles_PIZZI02.ogg` | [Music Jingles](https://kenney.nl/assets/music-jingles) |
| `result_lose.ogg` | `jingles_PIZZI01.ogg` | Music Jingles |

選定の理由:

- 被弾に**ガラスへの打撃音**を充てたのは、砂時計がガラス製であるため
- 決着ジングルに**弦楽器のピチカート**を選んだのは、BGMのピアノ(クラシック)と音色が調和するため。
  勝敗の鳴り分けは、17個ある候補を実際に再生してスペクトル重心の時間変化を測り、
  **音程が上がって終わるもの(PIZZI02)を勝利、下がって終わるもの(PIZZI01)を敗北**に割り当てた
- Interface Sounds の各候補は、長さ・ピーク・RMS・ゼロ交差率を計測した上で、
  低めで柔らかい音(真鍮・木のUIに合う)を優先して選んだ

## BGM(`assets/bgm/`)

いずれも**楽曲だけでなく録音そのものがパブリックドメイン/CC0**であることを個別に確認済み。
クラシックは作曲家の著作権が切れていても録音に別途著作隣接権が発生するため、この確認は必須。

| ファイル | 曲 | 演奏 | 出所 | ライセンス |
|---|---|---|---|---|
| `title.ogg` | ムソルグスキー「展覧会の絵」より「キエフの大門」 | 演奏者不明(musopen.org 提供) | [Wikimedia Commons](https://commons.wikimedia.org/wiki/File:Modest_Mussorgsky_-_pictures_at_an_exhibition_-_x._la_grande_porte_de_kiev_-_allegro_alla_breve._maestoso._con_grandezza.ogg)(出所は musopen.org) | パブリックドメイン |
| `home.ogg` | エリック・サティ「ジムノペディ第1番」 | Robin Alciatore | [Wikimedia Commons](https://commons.wikimedia.org/wiki/File:Erik_Satie_-_gymnopedies_-_la_1_ere._lent_et_douloureux.ogg)(出所は musopen.org) | パブリックドメイン(録音者による放棄) |
| `match.ogg` | J.S.バッハ「ゴルトベルク変奏曲 BWV988」アリア | Kimiko Ishizaka | [Open Goldberg Variations](https://opengoldbergvariations.org/) / [Internet Archive](https://archive.org/details/The_Open_Goldberg_Variations-11823) | CC0 |

Open Goldberg Variations は、Kickstarterで資金を集めて録音と楽譜をまるごとCC0で公開した企画。

`title.ogg` は元の録音(5分28秒・7.0MB)の**冒頭100秒をOggのページ境界でそのまま切り出したもの**
(2.1MB)。タイトル画面はすぐに抜ける画面であり、曲の全長をpckへ入れるとWeb配信のロード時間に
見合わないため。再エンコードはしていないので音質は元のまま。切り口は`MusicPlayer`側の
末尾フェードアウトで滑らかにしている。

## 砂時計イラスト・背景イラスト

`assets/hourglasses/` と `assets/backgrounds/` の画像は、nanobanana(Gemini画像生成)で
このプロジェクトのために生成したもの。生成手順は `docs/AssetPromptTemplate.md` を参照。

## フォント

`assets/fonts/ZenKakuGothicNew-Bold.ttf` は Google Fonts の「Zen Kaku Gothic New」
(SIL Open Font License 1.1)。

---

## カードの紋章(`assets/hourglasses/emblems/`)

すべて [icooon-mono](https://icooon-mono.com/)(商用利用可・クレジット表記不要)の
アイコンを取り込んだもの。実行時に読むのは白のシルエットへ焼き直した `{id}.png` で、
取り込み元のSVGは `sources/` に置く(`.gdignore` でGodotの管理外。**リポジトリにも含めない**。
素材そのものの再配布とみなされうるため、`.gitignore` で除外している)。

焼き直しは `tools/build_emblem_icons.gd` が行う。

| カード | 紋章 | 元アイコン |
|---|---|---|
| サンド | 砂時計 | スタンダードな砂時計アイコン(11603) |
| ダスト | 飛散 | 爆発アイコン(15845) |
| グレイン | 雪の結晶 | 雪の結晶アイコン1(14240) |
| シールド | 盾 | 盾アイコン(15865) |
| ガード | 兜 | 古代ギリシャの兜-1(12219) |
| ダッシュ | 雷 | 雷アイコン(16097) |
| グラス | グラス | グラスアイコン1(14541) |
| ドリル | ドリル | ドリルアイコン(15412) |
| ヴァンプ | コウモリ | コウモリのイラストアイコン(11466) |
| ソード | 剣 | 剣のアイコン(10688) |
| エコー | 音叉 | 音叉の無料アイコン(16046) |
| アイ | 目 | 目アイコン6(14310) |
| ハンマー | 槌 | シンプルなハンマーアイコン(10175) |
| ロック | 南京錠 | 無料の南京錠アイコン1(12591) |
| ツイン | 手裏剣 | 手裏剣のアイコン(11792) |
| ランス | 矢 | 矢アイコン2(14114) |
| スウォーム | 蜂 | 蜂アイコン1(13831) |
| ミラー | 手鏡 | 手鏡アイコン2(13447) |
| ポイズン | 髑髏 | ドクロアイコン10(14987) |
| グロウ | 太陽 | 太陽アイコン(16073) |
| スイープ | 箒 | ほうきのアイコン1(13178) |
| ウォール | 煉瓦の壁 | 壁のアイコン1(12871) |
