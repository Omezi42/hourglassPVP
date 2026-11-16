# 10.19 砂時計の絵のコード描画(GameDesign.md 9章)

**1種=シェーダー1本。ただしカードのシェーダーは実行時に使わず、ビルド前にPNGへ焼く。実行時に動かすのはガラスと砂だけ。**
枠と飾りの陰影は部品ごとに展開されて重く、Web版(Chrome・ANGLE/D3D11)では1本の初回コンパイルが4〜5秒かかり、
その間ゲームが止まるため。ガラスと砂は全カード共通で、砂の質感ごとに1本だけをコンパイルする。

## 層

1枚の絵を、下から次の順に重ねて作る。

| 層 | 作り方 | 実行時のコンパイル |
|---|---|---|
| 1. 後ろ | カードのシェーダーの `art_back()` を焼いたPNG(ガラス越しに透けて見えるもの: 後光・結界の光・柱の陰の翼) | なし |
| 2. ガラスと砂 | 全カード共通のシェーダー(砂の質感ごとに1本)。**ここだけが動く** | 質感ごとに1回だけ |
| 3. 枠 | カードのシェーダーの `art_frame()` を焼いたPNG(ガラスより手前の柱・板・飾り) | なし |

- **ガラスの中に見せる飾り(光の粒など)は後ろに描く。**ガラス越しに見え、砂に隠れる。共通のガラスへカードごとの処理は入れない
  (入れるとガラスがカードごとのシェーダーに戻るため)
- 状態で変わる飾り(上の砂が多いほど強い光など)は `sand_top` を読む。3状態ぶん焼くので同じに書ける
- **後ろの下へ敷く光(結界など)は、描いた絵の濃い所を `(1.0 - acc.a)` で弱めて「下に敷いた」ように見せる**

## ファイル

| 場所 | 中身 |
|---|---|
| `resources/shaders/hourglasses/{art_key}.gdshader` | そのカードの絵。**カードを足すときはこれを1本置き、焼き直すだけ**(表もコードも変えない) |
| `resources/shaders/hourglass/hourglass_lib.gdshaderinc` | uniform・定数・道具(距離関数・陰影・輪郭・砂の質感・光の重ね方・`Px`) |
| `resources/shaders/hourglass/hourglass_glass.gdshaderinc` | ガラス玉と砂(`draw_glass()`)。砂の筋と砂の面の波紋を `clock` で動かす |
| `resources/shaders/hourglass/glass_{kind}.gdshader` | 全カード共通のガラスと砂。砂の質感6種(sand/grain/liquid/crystal/glow/stardust)ごとに1本(`SAND_KIND` を `#define` して上を読むだけ) |
| `resources/shaders/hourglass/frame_parts.gdshaderinc` | 枠の部品(柱・輪・玉・板・受け金・目・象嵌)と共通の色 |
| `resources/shaders/hourglass/art_main.gdshaderinc` | `fragment()`。uniform `layer`(0=後ろ / 1=枠)で `art_back()` / `art_frame()` を描く |
| `assets/hourglasses/overrides/{art_key}/state_{full,falling,empty}.png` | 焼いた完成形(手札・一覧などに出す止めた絵。生成物だがcommitする) |
| `assets/hourglasses/overrides/{art_key}/{back,frame}_{full,falling,empty}.png` | 焼いた層(動く絵の下地と上張り。後ろが空のカードは back を持たない) |
| `tools/bake_hourglass_art.gd` | 全シェーダーを焼いて上へ書き出す。ウィンドウありで回す(headlessは描画しない)。`-- {art_key}` で1枚だけ |

カードのシェーダーは次の形に書く。

```
shader_type canvas_item;
#include ".../hourglass_lib.gdshaderinc"
#include ".../frame_parts.gdshaderinc"
// 形(距離関数・定数)
void art_back(inout vec4 acc, Px f) { ... }
void art_frame(inout vec4 acc, Px f) { ... }
#include ".../art_main.gdshaderinc"
```

- **`clock` と時間で動く式を使わない**(焼くときは0で評価され、実行時には使われないため)
- **砂の色は uniform `sand_color` で外から渡し、値は色違いの表(`HourglassTintTable`)のそのカードの行から取る**(コード描画のカードの行は色変換の連鎖ではなく `sand` = [r, g, b] で持ち、質感は `texture`)。
  手札の光だまり(`HourglassArt.accent_color()`)・色違いの絵・シェーダーの絵が同じ1行を見るため、色の出どころが1つに保てる(9章「いまの色を引き継ぐ」)
- **砂の質感は uniform にしない。**6種の分岐が全部コンパイルされ、1.3〜1.5倍重くなるため。表の質感で `glass_{kind}` を選ぶ
- 400x532 の矩形へ描く(基本の絵の落下中と同じ高さ)。座標は基本の絵と同じで、上へ19px広いぶんを天板の上の飾りに使う
- 外から渡すのは `sand_color` と `sand_top` / `sand_bottom` / `flow`(上向き=0.85/0/0、落下中=0.45/0.40/1、落ちきり=0/0.85/0)、
  共通のガラスには `clock`(秒)

## 焼く(ビルド前)

- `tools/bake_hourglass_art.gd` が3状態ごとに、層(後ろ・枠)と、`clock` = 0 で全層を重ねた完成形を焼く。
  焼き直しは、シェーダーか共通の部品か表の色・質感を変えたとき
- 取り込みは非可逆のWebP(画質0.85。4.1節)。取り込み設定は焼く道具が置く
- **焼き忘れの検査は `tools/check_hourglass_bake.py`**(`check.sh` が回す)。焼いた元(共通の部品・そのカードのシェーダー・共通のガラス・表のそのカードの行)のハッシュを `tools/hourglass_bake_manifest.json` に控え、PNGが揃っていないか控えと違えば失敗にする。更新は `bake_hourglass_art.gd` が行う
- Web版の半分の解像度の扱いは `HourglassArt` の固有の絵と同じ(4.1節)

## 動く絵

| クラス | 責務 |
|---|---|
| `HourglassLive`(`scripts/logic/hourglass_live.gd`, staticのみ) | `live_texture(art_key, state)`。シェーダーが無いカードは `HourglassArt.texture()` を返す。時計は `Main` の子の `Host` ノードの `_process` で進める |

- **カード×状態ごとに1つの `SubViewport`** に、後ろ(backのPNG)・ガラス(`glass_{kind}`)・枠(frameのPNG)の3枚を重ねる。
  **同じカード・同じ状態の駒で1枚を共有し**、直前のフレームで引かれなかったものは描き直さない(`render_target_update_mode` を止める)
- 引く側は見えている間 `live_texture()` を毎フレーム呼ぶ(戻り値は捨ててよい。`ViewportTexture` は中身が自分で更新されるので、駒・ページを描き直す必要は無い)
- 引くのは `CardView` の場の表示(大きさと位置は止めた絵で決め、同じ矩形へ動く絵を貼る)と `AlmanacPage` の右のページだけ。**全環境で動かす**
- 共通のガラスの初回コンパイル(実測。内蔵AMD GPU):デスクトップ約0.3〜0.5秒 / Web版約0.5〜0.7秒。
  **対局画面を開くときに自分のデッキの質感のぶんだけ先に1回描いてコンパイルを済ませる**(初めて駒を出す瞬間に重ねて止めないため)

## 廃止したカードスキン(GameDesign.md 21章)

- 買った人への補償はプレゼント「スキン廃止のおわび」で配る(10.22節)。そのため `players/{uid}` の `owned_skins` は読み書きを止めたまま、補償を受け取るまでサーバーに残す
- `ShopCatalog.Kind.SKIN` は欠番として残す(enum は末尾にだけ足す。11章)
