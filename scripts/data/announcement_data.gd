class_name AnnouncementData
extends Resource
## 更新のお知らせ1回ぶん(GameDesign.md 33章)。`data/announcements/{version}.tres`。
## 手で書かず、`tools/discord/sync_announcements.py` が #お知らせ の下書きから作り直す。

## 版の日付(「2026.10.29」。同じ日の2回目は「2026.10.13-2」)。
@export var version: String = ""
## #お知らせ に投稿した文面そのまま(Discordの書き方。`AnnouncementText` が画面用に変える)。
@export_multiline var body: String = ""
