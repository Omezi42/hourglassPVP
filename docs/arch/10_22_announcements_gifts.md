# 10.22 お知らせとプレゼント(GameDesign.md 33章)

| クラス / データ | 責務 |
|---|---|
| `AnnouncementData`(`scripts/data/announcement_data.gd`) | 更新のお知らせ1回ぶん。`version`(「2026.10.29」)と `body`(#お知らせ に投稿した文面そのまま) |
| `data/announcements/{version}.tres` | 直近20回ぶん。**手で書かない**。`tools/discord/sync_announcements.py` が `tools/discord/drafts/update-*.md` から作り直す(古い回は消す) |
| `AnnouncementLibrary`(`scripts/data/announcement_library.gd`, static) | 回の一覧(新しい順)・読んでいない回の数・既読の記録(`user://announcements.json` に最後に開いた版だけ) |
| `AnnouncementText`(`scripts/data/announcement_text.gd`, static) | Discordの書き方を `RichTextLabel` のBBCodeへ変える。`**見出し**` の行は見出し、`- ` は行頭の点、`-# ` の行(リンク)は落とす。`[` は `[lb]` に逃がす |
| `GiftData`(`scripts/data/gift_data.gd`) | プレゼント1件。`id`・`title`・`description`・`kind`(`CARD_SET` / `CURRENCY`)・`set_id`・`amount`・`expires`(日本時間の「YYYY-MM-DD」。その日まで受け取れる。空なら期限なし) |
| `data/gifts/{id}.tres` | 配っているプレゼント。1件足すのは `.tres` を1個置くだけ |
| `GiftLibrary`(`scripts/data/gift_library.gd`, static) | プレゼントの一覧(期限内のもの)と、受け取っていない件数 |
| `GiftService`(`scripts/net/gift_service.gd`, static) | 受け取り。`players/{uid}.claimed_gifts`(Array[String])への追加と品の付与を**1回の `commit()`**で書く |
| `NoticeBoardPanel`(`scripts/ui/notice_board_panel.gd`) | ホームへ重ねるモーダル(`DailyMissionPanel` と同じ「暗幕 + `content_panel.tres`」)。タブ・お知らせの一覧と本文 |
| `NoticeGiftList`(`scripts/ui/notice_gift_list.gd`) | プレゼントのタブの中身(1件ごとの行と「受け取る」) |

- **お知らせもプレゼントもpckへ同梱し、Firestoreから読まない**(GameDesign.md 10章)。Firestoreのルールは変えない
  (`players/{uid}` は本人が書ける既存の規則に収まる)
- **既読は端末に持つ**(アカウントへ持たない)。読んだかどうかを取り違えても失うものが無く、書き込みを増やすほどの値打ちが無いため。
  記録が無い(はじめての起動)ときは、いちばん新しい回だけを読んでいない扱いにする
- **受け取りは `WelcomeDays.claim()` と同じ形**: 読む → `claimed_gifts` に無ければ品を足した値と一緒に `updateTime` を前提条件にして書く →
  競合したら読み直す。品と受け取りの印を別々に書くと、片方だけ通ったときに品か権利のどちらかが消える
  - 読み取りが失敗したら書かない(`AccountService.read_succeeded()`。Pitfalls.md)
  - 既に `owned_card_sets` にあるセット(別の経路で手に入れた)は、印だけ付けて受け取り済みにする
  - **未サインイン・通信失敗のときは退避しない**(`purchase()` と同じ。押せなくしておけば失うものが無い)
- カードセットのプレゼントは `CardSetLibrary` の価格0のセットを指す(10.8.1節。ショップに並ばず、CPUのデッキにも入らない)
- `CardSetLibrary.purchasable_ids()` は価格0を含まないため、はじめの7日の「セットを1つ選ぶ」にプレゼントのセットは出ない
- ヘッダーの「お知らせ」は `HomeScreen` が置く(ルールブックの左。紋章は `UiPaint.Emblem.LETTER`)。赤い丸は `HomeTile.draw_badge()`
  (件数0なら数を描かない)。ホームを出すたび(`refresh_account()`)とモーダルを閉じたときに描き直す

## 更新のお知らせの流れ(build-and-announce Skill)

下書きを仕上げる → `python tools/discord/sync_announcements.py` で `.tres` を作り直す → ビルド → 投稿、の順にする。
ビルドの後に下書きを書くと、その回のお知らせがその回のpckに入らない。

## 相手の手札へカードを加える効果(プレゼント。GameDesign.md 6章)

- `CardEnums.EffectType.ADD_CARD_TO_HAND`(末尾に追加)。`card_id` のカードを、`target` が指すプレイヤー
  (`OPPONENT_PLAYER` / `OWN_PLAYER`)の手札の末尾へ1枚加え、`hand_changed` を出す。山札は減らない
- 紋章の型は `DESCEND` を相手の情報帯(枠 -1)へ。CPUの見積もり(`CardCpuStrategy`)は0として扱う(相手に渡すのは撃つのにマナが要る1枚で、損得がほぼ釣り合うため)
