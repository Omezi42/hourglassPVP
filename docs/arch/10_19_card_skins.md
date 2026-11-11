# 10.19 カードスキン(GameDesign.md 31章)

**絵を引く口を1つ足し、描画側は変えない。**砂時計の絵は `CardData.icon_upright` 等の
getter が `HourglassArt.texture(art_key(), state)` を返す形で12箇所から読まれており
(`CardView` / `AlmanacPage` / `CardDeckShelf` / `CardDeckListScreen` /
`WorkshopStockItem` / `CardDetailPanel` 等)、ここへスキンの判定を挟めば
「そのカードの絵を出すすべての場所で使う」(31章)が1箇所で成立する。

| クラス | 責務 |
|---|---|
| `SkinLibrary`(`scripts/data/skin_library.gd`, staticのみ) | スキンの定義(id・対象カードid・表示名・手札の窓の光だまりの色・価格)。`PlaymatLibrary` と同じ流儀。見た目は `resources/shaders/skins/{skin_id}.gdshader`(下の「見た目のシェーダー」)。**`all()` は見た目のあるものだけを返す**(定義だけ先に入ったスキンを空の見本で売らないため) |
| `CardSkins`(`scripts/logic/card_skins.gd`, staticのみ) | 「いま誰の視点で、どのカードにどのスキンが効いているか」を答える。`texture(card, state, viewer)` / `live_texture(card, state, viewer)`(動く絵。スキンが効いていなければ `texture()` と同じ)/ `accent_color(card, viewer)` が入口。自分の解決結果は控えておき、所有・ON/OFFが変わったら `AccountService` が `invalidate()` する(毎フレームの描画から引かれ、所有の読み口はローカルのファイルまで見に行くため) |

## 視点(`CardSkins.Viewer`)

スキンは持ち主ごとに違うため、絵を引く側が**誰のカードを描いているか**を渡す。

| Viewer | 使う設定 | 使う場所 |
|---|---|---|
| `SELF`(既定) | `AccountService.owned_skin_ids()` − `disabled_skin_ids()` | 手札・自分の場の駒・図鑑・デッキ編集・墓地・デッキ表・一覧の代表アイコン |
| `OPPONENT` | `fetch_profile()` で受け取った相手の `owned_skins` / `disabled_skins` | 対局中の相手の場の駒 |
| `NONE` | 常に元の絵 | CPUの駒・リプレイ・ルール画面・画面の見かた・Discord用のカード画像 |

- **`CardData.icon_*` の getter は `SELF` で `CardSkins.texture()` を呼ぶ形へ変える。**
  ほとんどの画面は自分のカードしか描かないため、既定を `SELF` にすれば既存の呼び出し
  12箇所はそのまま動く。`CardData` 自体は Resource で持ち主を知らないが、
  「既定は自分の視点」という決めごとを getter が代表するだけであり、Resource を
  書き換えるわけではない(11章「`.tres` から読んだ `CardData` を書き換えない」には触れない)
- **`CardView` に `skin_viewer` プロパティ(既定 `SELF`)を持たせ、`_fit_art()` の絵の
  取得だけを `CardSkins.texture(card, state, skin_viewer)` に変える。**
  `CardMatchScreen.skin_viewer_for(side)` が場の列・手札・墓地の一覧(`CardPileViewer.open_pile()`)へ
  自分=`SELF` / 相手=`OPPONENT`、`_interactive == false`(再生)なら `NONE` を返す。
  CPU戦の相手は `CardSkins` に相手の設定が無いため `OPPONENT` のまま元の絵になる。`RuleStage` / `ScreenGuideStage` /
  `DiscordCardArt` が作る `CardView` は `NONE`。`CardUnitFx.play_break()` は
  `CardData` ではなく `CardView` が解決済みのテクスチャを受け取る形へ変える
  (崩落の破片がスキンの絵と別物になるのを防ぐ)
- **手札の窓の光だまりは `HandCardPaint` が `CardSkins.accent_color(card, viewer)` を
  引く。**スキンが効いていなければ `HourglassArt.accent_color()` を返す
- **相手の設定は `CardMatchOnline` が `fetch_profile()` の直後に
  `CardSkins.set_opponent(owned, disabled)` で渡し、`_reset_for_new_match()` が消す**
  (プレイマットと同じ場所・同じ寿命)。`fetch_profile()` は `owned_skins` /
  `disabled_skins` も返す

## 所有と設定(`players/{uid}`)

| フィールド | 型 | 内容 |
|---|---|---|
| `owned_skins` | Array[String] | 買ったスキンのid。**配布のスキンは書かない**(全員が持つため。`AccountService.owned_skin_ids()` が `SkinLibrary.free_ids()` を足して返す) |
| `disabled_skins` | Array[String] | OFFにした**買った**スキンのid。既定がONのため、購入時に所有と設定の2箇所を書かずに済む |
| `enabled_skins` | Array[String] | ONにした**配布の**スキンのid。配布のスキンは既定がOFFのため、こちらはONの一覧で持つ |

- 配布のスキンは `SkinLibrary` の定義で `"free": true`(価格0・ショップに並ばない)。
  ON/OFFの判定は `CardSkins._resolve(owned, disabled, enabled)` 1箇所が、配布かどうかで見る一覧を切り替える。
  相手の設定も `fetch_profile()` が3つの一覧を返し、同じ規則で解決する

- `ShopCatalog.Kind` へ `SKIN` を**末尾に**足し(11章)、`items()` は `SkinLibrary.all()` を
  並べる。購入は `AccountService.purchase()` の既存の流儀のまま `owned_skins` へ追加する。
  `owns()` / `_owned_key()` に分岐を1つ足す
- `AccountService.set_skin_enabled(client, skin_id, enabled)` が `disabled_skins`(配布なら `enabled_skins`)を
  `updateTime` 前提の `commit()` で書く。
  **未サインインでは切り替えられない**(ショップの購入と同じ理由。設定を手元だけで
  持つと次に通信した時点で戻る)。`AccountStore.save_local_skin_choices()` で控え、
  `load_local_customization()` が返すため、起動直後の描画が通信を待たずに済む

## 画面

- **図鑑(`AlmanacPage`)**:`SkinLibrary.skin_for_card(card.id)` が存在し、かつ所有して
  いるときだけ、絵の下に「スキン ON / OFF」の切り替えを出す。右のページの絵は `CardSkins.live_texture()` で引き
  (動く絵)、裏返し(`_flipped`)の描画は変えない
- **ショップ(`ShopItemCard`)**:`Kind.SKIN` の品目は3状態の絵を横に並べて出す
  (`SkinLibrary.live_texture(skin_id, state)` を直に読む。所有・ON/OFFに関わらず品を見せる
  ため `CardSkins` は通さない)。対象カード名とスキン名を添える
- **アカウント画面は触らない**(31章のとおり設定場所は図鑑)

## 見た目のシェーダー(GameDesign.md 31章「見た目の作り方」)

**1種=シェーダー1本。スキンを足すときは `resources/shaders/skins/{skin_id}.gdshader` を1本置き、
`SkinLibrary.SKINS` へ1行足すだけにする**(描画側も共通の部品も変えない)。

| ファイル(`resources/shaders/hourglass/`) | 中身 |
|---|---|
| `hourglass_lib.gdshaderinc` | uniform・定数・道具(距離関数・陰影・輪郭・砂の質感・`Px`) |
| `hourglass_glass.gdshaderinc` | ガラス玉と砂(`draw_glass()`)。スキンは `HOOK_CAVITY`(砂の後ろ)/ `HOOK_FRONT`(砂の手前)を定義してガラスの中へ描き足せる |
| `skin_parts.gdshaderinc` | 枠の部品(柱・輪・玉・板・受け金・目・板への象嵌・キャンバスの端で消える窓)と共通の色 |
| `skin_main.gdshaderinc` | `fragment()`。`skin_back()` → `draw_glass()` → `skin_frame()` の順に重ねる |

- スキンのシェーダーは `SKIN_SAND_COLOR` / `SKIN_SAND_KIND` を `#define` してから `hourglass_lib` を読み、
  `skin_back()` / `skin_frame()`(と使うなら `hook_cavity()`)を書き、最後に `hourglass_glass` と `skin_main` を読む。
  **砂の色と質感をシェーダー側に置くのは、スキンの追加で `skin_library.gd` の表の行以外を触らずに済ませるため**
- 400x532 の矩形へ貼る(基本の絵の落下中と同じ高さ。`CardView._art_reference()` が3状態で最も高いキャンバスを
  基準に縮めるため)。座標は本体と同じで、上へ19px広いぶんを天板の上の飾りに使える
- 外から渡すのは `sand_top` / `sand_bottom` / `flow`(3状態。上向き=0.85/0/0、落下中=0.45/0.40/1、落ちきり=0/0.85/0)、
  `clock`(秒)、`look`(視線。-1〜1)だけ

## 止めた絵と動く絵

| 入口 | 返すもの | 使う場所 |
|---|---|---|
| `SkinLibrary.texture(skin_id, state)` | シェーダーを3状態ぶん `SubViewport` で焼いた `ImageTexture`(`clock` 固定) | 手札・一覧・棚・墓地・デッキ表・Discord用の画像など、`CardSkins.texture()` を通るすべて |
| `SkinLibrary.live_texture(skin_id, state)` | スキン×状態ごとに1つの `SubViewport` が描き続ける `ViewportTexture` | 場の駒(`CardView` の場の表示)・ショップの見本・図鑑の右のページ |

- **焼き方は `HourglassArt` と同じ**(焼き上がる前は空の器を配り、焼けた時点で `set_image()` で中身を差し替える。
  Web版は半分の解像度)。止めた絵も `Texture2D` のため、`CardSkins.texture()` を通る呼び出しは変えない
- **動く絵は1体ごとに描かず、同じスキン・同じ状態の駒で1枚を共有する**(場に何体並んでも描く枚数が増えない)。
  `clock` は経過時間、`look` は画面中央からマウスの位置への向きを全スキン共通で渡す
- **直前のフレームで引かれなかった動く絵は描き直さない**(`render_target_update_mode` を止める)。解像度は場の駒の
  表示の2倍(Web版は1倍)
- `ViewportTexture` も `Texture2D` のため、`CardView` の場の表示は `_icon()` で引く口を `live_texture()` へ替えるだけで、
  反転・攻撃・砕ける演出はそのまま動く
- 重さの目安(内蔵GPU・デスクトップ版で実測):場の駒の大きさで1体あたり約0.06ms(基本の絵は約0.008ms)

## 画像のスキンからの置き換え

シェーダーが無いスキンは `assets/hourglasses/skins/{skin_id}/state_{upright,falling,fallen}.png` を読む
(画像で作った9種をコード描画へ置き換え終えるまでの経路)。置き換え終えたら画像と `tools/compose_skin_art.py` を消し、
この経路も消す。
