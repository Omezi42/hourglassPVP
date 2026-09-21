# 10.19 カードスキン(GameDesign.md 31章)

**絵を引く口を1つ足し、描画側は変えない。**砂時計の絵は `CardData.icon_upright` 等の
getter が `HourglassArt.texture(art_key(), state)` を返す形で12箇所から読まれており
(`CardView` / `AlmanacPage` / `CardDeckShelf` / `CardDeckListScreen` / `ReplayListCard` /
`WorkshopStockItem` / `CardDetailPanel` 等)、ここへスキンの判定を挟めば
「そのカードの絵を出すすべての場所で使う」(31章)が1箇所で成立する。

| クラス | 責務 |
|---|---|
| `SkinLibrary`(`scripts/data/skin_library.gd`, staticのみ) | スキンの定義(id・対象カードid・表示名・手札の窓の光だまりの色・価格)。`PlaymatLibrary` と同じ流儀。絵は `assets/hourglasses/skins/{skin_id}/state_{upright,falling,fallen}.png` を読む |
| `CardSkins`(`scripts/logic/card_skins.gd`, staticのみ) | 「いま誰の視点で、どのカードにどのスキンが効いているか」を答える。`texture(card, state, viewer)` / `accent_color(card, viewer)` の2つが入口 |

## 視点(`CardSkins.Viewer`)

スキンは持ち主ごとに違うため、絵を引く側が**誰のカードを描いているか**を渡す。

| Viewer | 使う設定 | 使う場所 |
|---|---|---|
| `SELF`(既定) | `AccountService.owned_skin_ids()` − `disabled_skin_ids()` | 手札・自分の場の駒・図鑑・デッキ編集・墓地・デッキ表・一覧の代表アイコン |
| `OPPONENT` | `fetch_profile()` で受け取った相手の `owned_skins` / `disabled_skins` | 対局中の相手の場の駒 |
| `NONE` | 常に元の絵 | CPUの駒・リプレイ・観戦・ルール画面・画面の見かた・Discord用のカード画像 |

- **`CardData.icon_*` の getter は `SELF` で `CardSkins.texture()` を呼ぶ形へ変える。**
  ほとんどの画面は自分のカードしか描かないため、既定を `SELF` にすれば既存の呼び出し
  12箇所はそのまま動く。`CardData` 自体は Resource で持ち主を知らないが、
  「既定は自分の視点」という決めごとを getter が代表するだけであり、Resource を
  書き換えるわけではない(11章「`.tres` から読んだ `CardData` を書き換えない」には触れない)
- **`CardView` に `skin_viewer` プロパティ(既定 `SELF`)を持たせ、`_fit_art()` の絵の
  取得だけを `CardSkins.texture(card, state, skin_viewer)` に変える。**
  `CardMatchScreen._refresh_row()` が相手の列へ `OPPONENT`、`_interactive == false`
  (再生・観戦)とCPU戦の相手の列へ `NONE` を入れる。`RuleStage` / `ScreenGuideStage` /
  `DiscordCardArt` が作る `CardView` は `NONE`。`CardUnitFx.play_break()` は
  `CardData` ではなく `CardView` が解決済みのテクスチャを受け取る形へ変える
  (崩落の破片がスキンの絵と別物になるのを防ぐ)
- **手札の窓の光だまりは `HandCardPaint` が `CardSkins.accent_color(card, viewer)` を
  引く。**スキンが効いていなければ従来の `HourglassArt.accent_color()` を返す
- **相手の設定は `CardMatchOnline` が `fetch_profile()` の直後に
  `CardSkins.set_opponent(owned, disabled)` で渡し、`_reset_for_new_match()` が消す**
  (プレイマットと同じ場所・同じ寿命)。`fetch_profile()` は `owned_skins` /
  `disabled_skins` も返す

## 所有と設定(`players/{uid}`)

| フィールド | 型 | 内容 |
|---|---|---|
| `owned_skins` | Array[String] | 買ったスキンのid |
| `disabled_skins` | Array[String] | OFFにしたスキンのid。**ONの一覧ではなくOFFの一覧で持つ**——既定がONのため、購入時に所有と設定の2箇所を書かずに済む |

- `ShopCatalog.Kind` へ `SKIN` を**末尾に**足し(11章)、`items()` は `SkinLibrary.all()` を
  並べる。購入は `AccountService.purchase()` の既存の流儀のまま `owned_skins` へ追加する。
  `owns()` / `_owned_key()` に分岐を1つ足す
- `AccountService.set_skin_enabled(client, skin_id, enabled)` が `disabled_skins` を
  `updateTime` 前提の `commit()` で書く(`emote_slots` の書き方と同じ)。
  **未サインインでは切り替えられない**(ショップの購入と同じ理由。設定を手元だけで
  持つと次に通信した時点で戻る)。プレイマットと同じく
  `AccountStore.load_local_customization()` にも写して、起動直後の描画が
  通信を待たずに済むようにする

## 画面

- **図鑑(`AlmanacPage`)**:`SkinLibrary.skin_for_card(card.id)` が存在し、かつ所有して
  いるときだけ、絵の下に「スキン ON / OFF」の切り替えを出す。絵は `CardData.icon_*`
  経由で既にスキン込みになるため、裏返し(`_flipped`)の描画は変えない
- **ショップ(`ShopItemCard`)**:`Kind.SKIN` の品目は3状態の絵を横に並べて出す
  (`SkinLibrary.texture(skin_id, state)` を直に読む。所有・ON/OFFに関わらず品を見せる
  ため `CardSkins` は通さない)。対象カード名とスキン名を添える
- **アカウント画面は触らない**(31章のとおり設定場所は図鑑)

## 取り込みと配布

- 絵は `assets/hourglasses/skins/{skin_id}/` へ3状態を置き、砂時計と同じく非可逆
  (WebP、`lossy_quality=0.85`)で取り込む。取り込みの正規化(3分割・倍率)は
  `add-hourglass` Skill の手順をそのまま使う。`overrides/`(基本の絵の差し替え)とは
  ディレクトリを分ける——役目が違い、混ぜると「どのカードが差し替え済みか」が読めなくなる
- **1枚あたりpckが数十KB増える。**合計20枚を超えるあたりで、BGMと同じ
  「実行時にjsDelivrから取りに行く」方式(4.1.6節)へ移すかを判断する。
  その場合 `SkinLibrary` が絵の出どころを1箇所で切り替えられるよう、
  読む口は最初から `SkinLibrary.texture()` に閉じておく
