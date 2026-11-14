# 10.19 砂時計の絵のコード描画(GameDesign.md 9章)

**1種=シェーダー1本。ただし実行時にコンパイルするのは「動きだけ」の小さな部分にする。**
枠と飾りの陰影は部品ごとに展開されて重く、Web版(Chrome・ANGLE/D3D11)では1本の初回コンパイルが4〜5秒かかり、
その間ゲームが止まるため。止まっている部分はビルド前にPNGへ焼き、ガラスと砂は全カード共通の1本にする
(聖剣の試作で実測: Web版の初回コンパイルが約4.6秒→約0.2秒、見た目の差は画素平均0.1%)。

## 層

1枚の絵を、下から次の順に重ねて作る。

| 層 | 作り方 | 実行時のコンパイル |
|---|---|---|
| 1. 後ろ | 止めた後ろ(`art_back()`)を焼いたPNG + 後ろの動き(`motion_back()`) | カードごとの動きのシェーダー |
| 2. ガラスと砂 | 全カード共通のシェーダー(砂の質感ごとに1本) | 質感ごとに1回だけ |
| 3. 枠 | 止めた枠(`art_frame()`)を焼いたPNG + 手前の動き(`motion_front()`) | 1と同じシェーダー |

- **動きのシェーダーは、自分の下の焼いた絵を `under_tex` で読み、その上へ動きを重ねて出す**(後ろ・手前は uniform `layer` で切り替える)。
  加算の光(`add_light()`)が下の絵の上で正しく足されるようにするため
- **ガラスの中の動き(昇る光の粒など)は後ろの動きに描く。**ガラス越しに見え、砂に隠れる。ガラスの中へ描き足す差し込み口(`HOOK_CAVITY` / `HOOK_FRONT`)は持たない
  (共通のガラスへカードごとの処理を入れると、ガラスがカードごとのシェーダーに戻るため)
- 状態で変わる飾り(上の砂が多いほど強い光など)は `sand_top` を読む。止めた部分も3状態ぶん焼くので同じに書ける

## ファイル

| 場所 | 中身 |
|---|---|
| `resources/shaders/hourglasses/{art_key}.gdshader` | そのカードの絵。**カードを足すときはこれを1本置き、焼き直すだけ**(表もコードも変えない) |
| `resources/shaders/hourglass/hourglass_lib.gdshaderinc` | uniform・定数・道具(距離関数・陰影・輪郭・砂の質感・光の重ね方・`Px`) |
| `resources/shaders/hourglass/hourglass_glass.gdshaderinc` | ガラス玉と砂(`draw_glass()`) |
| `resources/shaders/hourglass/glass_{kind}.gdshader` | 全カード共通のガラスと砂。砂の質感6種ごとに1本(`SKIN_SAND_KIND` を `#define` して上を読むだけ) |
| `resources/shaders/hourglass/frame_parts.gdshaderinc` | 枠の部品(柱・輪・玉・板・受け金・目・象嵌)と共通の色。**止めた部分だけが使う** |
| `resources/shaders/hourglass/art_main.gdshaderinc` | `fragment()`。`ART_STATIC` があれば止めた部分(`layer` で後ろ/枠)を、無ければ動き(`under_tex` + `motion_*()`)を描く |
| `assets/hourglasses/overrides/{art_key}/state_{full,falling,empty}.png` | 焼いた止めた絵(手札・一覧などに出す完成形。生成物だがcommitする) |
| `assets/hourglasses/overrides/{art_key}/{back,frame}_{full,falling,empty}.png` | 焼いた層(動く絵の下地。後ろが空のカードは back を持たない) |
| `tools/bake_hourglass_art.gd` | 全シェーダーを焼いて上へ書き出す。ウィンドウありで回す(headlessは描画しない) |

カードのシェーダーは次の形に書く。

```
shader_type canvas_item;
#include ".../hourglass_lib.gdshaderinc"
// 形(距離関数・定数。止めた部分と動きで共有する)
#ifdef ART_STATIC
#include ".../frame_parts.gdshaderinc"
void art_back(inout vec4 acc, Px f) { ... }
void art_frame(inout vec4 acc, Px f) { ... }
#endif
void motion_back(inout vec4 acc, Px f) { ... }
void motion_front(inout vec4 acc, Px f) { ... }
#include ".../art_main.gdshaderinc"
```

- **実行時はこのファイルをそのまま読む**(`ART_STATIC` が無いので動きだけがコンパイルされる)。焼く道具だけが
  コードの先頭へ `#define ART_STATIC` を足した `Shader` を作って使う
- **動きの関数では陰影(`shade_mat()` など)と枠の部品を使わない。**形の距離関数・`over()`・`add_light()`・`star4()` などの軽い道具だけで描く。
  使うと動きのシェーダーが重くなり、層に分けた意味が無くなる
- **砂の色は uniform `sand_color` で外から渡し、値は色違いの表(`HourglassTintTable`)のそのカードの行から取る。**
  手札の光だまり(`HourglassArt.accent_color()`)・色違いの絵・シェーダーの絵が同じ1行を見るため、色の出どころが1つに保てる(9章「いまの色を引き継ぐ」)
- **砂の質感は uniform にしない。**6種の分岐が全部コンパイルされ、1.3〜1.5倍重くなるため。表の質感で `glass_{kind}` を選ぶ
- 400x532 の矩形へ描く(基本の絵の落下中と同じ高さ)。座標は基本の絵と同じで、上へ19px広いぶんを天板の上の飾りに使う
- 外から渡すのは `sand_color` と `sand_top` / `sand_bottom` / `flow`(上向き=0.85/0/0、落下中=0.45/0.40/1、落ちきり=0/0.85/0)、
  `clock`(秒)、`look`(視線。各軸 -1〜1)、動きのシェーダーには `under_tex` / `layer`

## 止めた絵(ビルド前に焼く)

- `tools/bake_hourglass_art.gd` が3状態ごとに、層(後ろ・枠)と、`clock` = 0・視線は中央で全層を重ねた完成形を焼く。
  焼き直しは、シェーダーか共通の部品か表の色・質感を変えたとき
- **焼き忘れを `tools/check.sh` が止める**:シェーダーがあるのにPNGが揃っていない、またはシェーダー・共通の部品より古いPNGがあれば失敗にする
- 取り込みは非可逆のWebP(画質は pck の増え方を見て決め、4.1節に書く)。可逆で持つと数十MBになるため
- Web版の半分の解像度の扱いは `HourglassArt` の固有の絵と同じ(4.1節)

## 動く絵

| クラス | 責務 |
|---|---|
| `HourglassLive`(`scripts/logic/hourglass_live.gd`, staticのみ) | `live_texture(art_key, state)`。シェーダーが無いカードは `HourglassArt.texture()` を返す。時計と視線は `Main` の子の `Host` ノードの `_process` で進める |

- **カード×状態ごとに1つの `SubViewport`** に、後ろ(動きのシェーダー + backのPNG)・ガラス(`glass_{kind}`)・枠(動きのシェーダー + frameのPNG)の3枚を重ねる。
  **同じカード・同じ状態の駒で1枚を共有し**、直前のフレームで引かれなかったものは描き直さない(`render_target_update_mode` を止める)
- 引く側は見えている間 `live_texture()` を毎フレーム呼ぶ(戻り値は捨ててよい。`ViewportTexture` は中身が自分で更新されるので、駒・ページを描き直す必要は無い)
- 引くのは `CardView` の場の表示(大きさと位置は止めた絵で決め、同じ矩形へ動く絵を貼る)と `AlmanacPage` の右のページだけ。**全環境で動かす**
- 初回のコンパイル(実測。内蔵AMD GPU):カードごとの動き デスクトップ約0.2秒 / Web版約0.2秒、共通のガラス デスクトップ約0.3〜0.5秒 / Web版約0.5〜0.7秒。
  **共通のガラスは、対局画面を開くときに自分のデッキの質感のぶんだけ先に1回描いてコンパイルを済ませる**(初めて駒を出す瞬間に重ねて止めないため)
- 重さ(実測。内蔵GPU・デスクトップ・vsyncなし):異なる12本を高さ224で描き続けて平均3〜4ms(基準0.6〜0.9ms)

## 廃止したカードスキンの返金(GameDesign.md 21章)

- `players/{uid}` の `owned_skins` に残っているidの数 × 500砂金を、`AccountService.refund_retired_skins()` がサインイン後のプロフィール読み込みの直後に返す。
  **残高の加算と `owned_skins` / `disabled_skins` / `enabled_skins` を空にする書き込みを1回の `commit()`(`updateTime` 前提)で行う**
  (二重に返さないため)。読み込みは `read_succeeded()` を確かめてから(Pitfalls)。競合は `grant()` と同じく数回やり直す
- 返したことは画面に出さない(残高が増えるだけ。#お知らせで案内する)
- `ShopCatalog.Kind.SKIN` は欠番として残す(enum は末尾にだけ足す。11章)
