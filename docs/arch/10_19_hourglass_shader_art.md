# 10.19 砂時計の絵のコード描画(GameDesign.md 9章)

**1種=シェーダー1本。止めた絵はビルド前にPNGへ焼き、実行時はシェーダーをコンパイルしない。**
Web版(Chrome)ではシェーダー1本の初回コンパイルに数秒かかり、99本を起動時に焼くと数分待たされるため。
焼いたPNGは `HourglassArt` の固有の絵の置き場(4.1節の `overrides/`)へ置くので、絵を引く側は何も変えない。

## ファイル

| 場所 | 中身 |
|---|---|
| `resources/shaders/hourglasses/{art_key}.gdshader` | そのカードの絵。**カードを足すときはこれを1本置き、焼き直すだけ**(表もコードも変えない) |
| `resources/shaders/hourglass/hourglass_lib.gdshaderinc` | uniform・定数・道具(距離関数・陰影・輪郭・砂の質感・`Px`) |
| `resources/shaders/hourglass/hourglass_glass.gdshaderinc` | ガラス玉と砂(`draw_glass()`)。`HOOK_CAVITY`(砂の後ろ)/ `HOOK_FRONT`(砂の手前)でガラスの中へ描き足せる |
| `resources/shaders/hourglass/frame_parts.gdshaderinc` | 枠の部品(柱・輪・玉・板・受け金・目・象嵌・キャンバスの端で消える窓)と共通の色 |
| `resources/shaders/hourglass/art_main.gdshaderinc` | `fragment()`。`art_back()` → `draw_glass()` → `art_frame()` の順に重ねる |
| `assets/hourglasses/overrides/{art_key}/state_{full,falling,empty}.png` | 焼いた止めた絵(生成物だがcommitする。Webで焼けないため) |
| `tools/bake_hourglass_art.gd` | 全シェーダーを3状態で焼いて上へ書き出す。ウィンドウありで回す(headlessは描画しない) |

- シェーダーは `art_back()` / `art_frame()`(と使うなら `hook_cavity()`)を書き、最後に `hourglass_glass` と `art_main` を読む
- **砂の色と質感はシェーダーに書かず、uniform(`sand_color` / `sand_kind`)で外から渡す。**値は色違いの表
  (`HourglassTintTable`)のそのカードの行から取る。手札の光だまり(`HourglassArt.accent_color()`)・色違いの絵・
  シェーダーの絵の3つが同じ1行を見るため、色の出どころが1つに保てる(9章「いまの色を引き継ぐ」)
- 400x532 の矩形へ描く(基本の絵の落下中と同じ高さ)。座標は基本の絵と同じで、上へ19px広いぶんを天板の上の飾りに使う
- 外から渡すのは上の2つと `sand_top` / `sand_bottom` / `flow`(上向き=0.85/0/0、落下中=0.45/0.40/1、落ちきり=0/0.85/0)、
  `clock`(秒)、`look`(視線。各軸 -1〜1)

## 止めた絵(ビルド前に焼く)

- `tools/bake_hourglass_art.gd` が `clock` = 0・視線は中央で3状態を焼く。焼き直しは、シェーダーか共通の部品か表の色を変えたとき
- **焼き忘れを `tools/check.sh` が止める**:シェーダーがあるのに3枚が揃っていない、またはシェーダー・共通の部品より古いPNGがあれば失敗にする
- 取り込みは非可逆のWebP(画質は pck の増え方を見て決め、4.1節に書く)。99種×3状態を可逆で持つと数十MBになるため
- Web版の半分の解像度の扱いは `HourglassArt` の固有の絵と同じ(4.1節)

## 動く絵

止めた絵と同じシェーダーを `SubViewport` で描き続ける。**同じカード・同じ状態の駒で1枚を共有し**、直前のフレームで
引かれなかったものは描き直さない(`render_target_update_mode` を止める)。引く側は見えている間 `live_texture()` を毎フレーム呼ぶ
(戻り値は捨ててよい。`ViewportTexture` は中身が自分で更新されるので、駒・ページを描き直す必要は無い)。

| クラス | 責務 |
|---|---|
| `HourglassLive`(`scripts/logic/hourglass_live.gd`, staticのみ) | `live_texture(art_key, state)`。シェーダーが無いカードは `HourglassArt.texture()` を返す。時計と視線は `Main` の子の `Host` ノードの `_process` で進める |

- 引くのは `CardView` の場の表示(大きさと位置は止めた絵で決め、同じ矩形へ動く絵を貼る)と `AlmanacPage` の右のページだけ
- **シェーダーは初めて引かれたときにコンパイルされ、その間は止まる**(実測: 内蔵GPUのデスクトップで1本約0.7秒、Web版のChromeで数秒)。
  どの環境で動く絵を出すかは TODO の判断待ちの項目
- 重さ(実測。内蔵GPU・デスクトップ・vsyncなし):異なる12本を高さ224で描き続けて平均3〜4ms(基準0.6〜0.9ms)

## 廃止したカードスキンの返金(GameDesign.md 21章)

- `players/{uid}` の `owned_skins` に残っているidの数 × 500砂金を、`AccountService.refund_retired_skins()` がサインイン後のプロフィール読み込みの直後に返す。
  **残高の加算と `owned_skins` / `disabled_skins` / `enabled_skins` を空にする書き込みを1回の `commit()`(`updateTime` 前提)で行う**
  (二重に返さないため)。読み込みは `read_succeeded()` を確かめてから(Pitfalls)。競合は `grant()` と同じく数回やり直す
- 返したことは画面に出さない(残高が増えるだけ。#お知らせで案内する)
- `ShopCatalog.Kind.SKIN` は欠番として残す(enum は末尾にだけ足す。11章)
