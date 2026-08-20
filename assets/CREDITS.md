# 素材クレジット

このプロジェクトが同梱している外部素材の出所・作者・ライセンスの記録。

採用条件は **CC0(パブリックドメイン)のみ**(GameDesign.md 9章)。CC0は表示義務を持たないため
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
| `home.ogg` | エリック・サティ「ジムノペディ第1番」 | Robin Alciatore | [Wikimedia Commons](https://commons.wikimedia.org/wiki/File:Erik_Satie_-_gymnopedies_-_la_1_ere._lent_et_douloureux.ogg)(出所は musopen.org) | パブリックドメイン(録音者による放棄) |
| `match.ogg` | J.S.バッハ「ゴルトベルク変奏曲 BWV988」アリア | Kimiko Ishizaka | [Open Goldberg Variations](https://opengoldbergvariations.org/) / [Internet Archive](https://archive.org/details/The_Open_Goldberg_Variations-11823) | CC0 |

Open Goldberg Variations は、Kickstarterで資金を集めて録音と楽譜をまるごとCC0で公開した企画。

## 砂時計イラスト・背景イラスト

`assets/hourglasses/` と `assets/backgrounds/` の画像は、nanobanana(Gemini画像生成)で
このプロジェクトのために生成したもの。生成手順は `docs/AssetPromptTemplate.md` を参照。

## フォント

`assets/fonts/ZenKakuGothicNew-Bold.ttf` は Google Fonts の「Zen Kaku Gothic New」
(SIL Open Font License 1.1)。
