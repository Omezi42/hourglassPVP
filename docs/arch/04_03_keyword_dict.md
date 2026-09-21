# 4.3 キーワード辞書(GameDesign.md 17章)

| クラス | 責務 |
|---|---|
| `KeywordEntries`(`scripts/ui/keyword_entries.gd`, static) | 辞書の中身。語 → 表示名・説明・実演の `CardEffectPreview.Demo`・分類(常在 / トリガー)の対応表と並び順を1箇所へ持つ |
| `KeywordDictScreen`(`scripts/ui/keyword_dict_screen.gd`, Control) | 左=語の一覧 / 右=選んだ語の詳細。共通の `ScreenHeader` を使う |
| `KeywordEntryView`(`scripts/ui/keyword_entry_view.gd`, VBoxContainer) | 1語ぶんの表示(語 / 説明 / 実演 / その語を持つ砂時計)。**辞書画面の右カラムとポップの中身はどちらもこれ**で、同じ語を2箇所で別々に組み立てて片方だけ古くなる状態を防ぐ |
| `KeywordPopup`(`scripts/ui/keyword_popup.gd`, Control) | 詳細パネルから出す1語ぶんのモーダル。暗幕 + コンテンツパネルの既存パターン |

**`CardEnums` は「語と文を返す」既存の責務のまま変えない。**並び順・分類・実演の割り当ては
辞書側の関心であり、対局のロジックが読む語彙へ表示の都合を混ぜないため `KeywordEntries` が持つ。

**その語を持つ砂時計は表へ書かず、`CardLibrary` から実行時に集める**
(`KeywordEntries.cards_with()`)。カードを1枚追加したときに辞書を書き換える作業が
発生しないことが、データ駆動で運用する(1章)ための条件になる。

**トリガー(設置 / 反転 / 余砂)は `Keyword` とは別の enum のため、辞書の項目は
`{"kind": ..., "value": ...}` の形で持つ**。両者を1つの整数へ混ぜると、値が衝突していないことを
呼び出し側が知っている前提のコードになる。

**`CardDetailPanel` の効果欄は語ごとの行にする。**`Label` 1つへ全文を流し込む形をやめ、
1行を「語のボタン + 説明の `Label`」にした。ボタンは `keyword_pressed(entry)` を出すだけで、
**ポップ自体は画面側が持つ**(パネルは画面の上の小さなノードとして置かれ、そこへ全画面の
暗幕を持たせられないため)。

**語のボタンと実演を出すのは `interactive`(既定 true)のときだけで、これを持つのは
砂時計一覧だけ**(GameDesign.md 17章)。デッキ編集と対局画面は `interactive = false` で
使い、同じ行を「【語】 説明」の1つの `Label` として描き、`CardEffectPreview` を作らない。
**ホバーで出して外れたら消えるパネルの中に、押しに行く先を置いてはいけない。**
`show_card()` / `clear()` は `_preview` が null でも通るようにしてある。
効果の文は「余砂:カードを1枚引く」のように語を頭に持つため、【】で括って前へ出すときは
文の側の語を取り除く(`_strip_term()`。そのままだと語を2度読ませることになる)。

**`interactive = false` のパネルは、中身の高さぴったりまで縮める**(`_fit()`)。
そのために**効果の欄をスクロールで包まない**——包むと高さが中身から決まらなくなる。
幅は `compact_width` で渡す(既定は `COMPACT_SIZE.x`、対局画面は340px)。

**実演(`CardEffectPreview`)は語を直接指定して再生できるようにする**(`show_demo()`)。
既存の `show_card()` は `CardData` から台本の並びを組む入口であり、辞書は語がすでに
決まっているためその手前へ入る。
