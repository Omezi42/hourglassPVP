class_name UiPalette
extends RefCounted
## プロジェクト全体のUI色の単一情報源。BoardTable/BarPanelの既存アクセント色
## (琥珀 Color(0.85, 0.62, 0.22))と世界観を揃え、コード描画StyleBox群(CodedButtonStyle等)
## から参照する。定数のみを持ち、ロジックは持たない。
##
## BRASS_*は元画像(assets/buttons/processed/wide_text/normal.png、496x178)の左枠列(x=10)
## および上端帯(x=248)をPillowで実測した値に基づく(彩度低め・中〜暗トーンの「褪せた真鍮」)。
## 実測値(0-255): highlight(top peak, y=8)=(208,178,114) / light(y=17-26)≒(144,112,80) /
## mid(y=88, 中央)=(111,80,60) / dark(y=150, 最暗)=(84,56,42) / bounce(y=159, 下端の照り返し)=(92,65,48)

const BRASS_HIGHLIGHT := Color(0.82, 0.7, 0.45, 1.0)
const BRASS_LIGHT := Color(0.57, 0.44, 0.31, 1.0)
const BRASS_MID := Color(0.44, 0.31, 0.24, 1.0)
const BRASS_DARK := Color(0.33, 0.22, 0.16, 1.0)
const BRASS_BOUNCE := Color(0.36, 0.25, 0.19, 1.0)

## 押下(pressed)時の真鍮。実測(pressed.png, x=10列): mid(y=89)=(59,47,33) / dark(y=150,最暗)=(46,31,24)
const BRASS_PRESSED_MID := Color(0.23, 0.18, 0.13, 1.0)
const BRASS_PRESSED_DARK := Color(0.18, 0.13, 0.1, 1.0)

## 最外周の輪郭線
const OUTLINE_DARK := Color(0.12, 0.08, 0.04, 1.0)

## 中央パネル(通常時): スレート系の暗い青灰。上が暗く下が明るいグラデーションで凹んで見せる
const PANEL_SLATE_TOP := Color(0.1, 0.11, 0.14, 1.0)
const PANEL_SLATE_BOTTOM := Color(0.24, 0.26, 0.31, 1.0)

## 中央パネル(ホバー時): 琥珀〜橙に光る
const PANEL_AMBER_TOP := Color(0.55, 0.26, 0.03, 1.0)
const PANEL_AMBER_BOTTOM := Color(1.0, 0.78, 0.35, 1.0)

## 中央パネル(押下時): 実測(pressed.png中央列, y=35〜124)は(64,65,69)〜(60,61,65)程度の
## 暗いスレートで、通常時パネルに近い明るさ。黒つぶれしない範囲に留める
const PANEL_PRESSED_TOP := Color(0.15, 0.14, 0.15, 1.0)
const PANEL_PRESSED_BOTTOM := Color(0.27, 0.25, 0.24, 1.0)

## ホバー時の外周グロー・盤面装飾等で共通に使う琥珀アクセント(BoardTable/BarPanelと同値)
const GLOW_AMBER := Color(0.85, 0.62, 0.22, 1.0)

## 文字色
const TEXT_OFFWHITE := Color(0.96, 0.94, 0.89, 1.0)
const WARNING_RED := Color(0.85, 0.2, 0.18, 1.0)

## 棚板(ShelfPlank)用の木材色。旧shelf_plank.pngは彩度の高い明るいオレンジだったが、
## 真鍮(BRASS_*)・パネル(PANEL_SLATE_*)と同じ「落ち着いた」トーンへ揃えるため、
## 既存のDeckListCard背景(bg_color = Color(0.22, 0.14, 0.08))を基準にした暗く濁った
## 茶色でまとめる(フェーズ12 Q-4)。TOP=板の上面(最も明るい)、MID=中間・木口の上端、
## DARK=前面木口の最暗部
const WOOD_TOP := Color(0.34, 0.22, 0.13, 1.0)
const WOOD_MID := Color(0.22, 0.14, 0.09, 1.0)
const WOOD_DARK := Color(0.12, 0.08, 0.05, 1.0)

## 名札(CodedNameplateStyle)の凹んだテキスト面。他のCodedスタイルが使う
## PANEL_SLATE_*(青灰)ではなく、木材・真鍮と揃う暖色の焦げ茶にする
const NAMEPLATE_PANEL_TOP := Color(0.14, 0.09, 0.05, 1.0)
const NAMEPLATE_PANEL_BOTTOM := Color(0.26, 0.18, 0.11, 1.0)

## 無効(disabled)状態: 彩度を落としたうえで暗くする(明るさ寄せのlerpだと暗い元色ほど
## 明るくなってしまい「無効なのに目立つ」不具合になるため、必ず暗い方向のみへ寄せる)。
## まず色自身の輝度へDISABLED_DESATURATEの割合だけ寄せて彩度を落とし、続けて
## darkened(DISABLED_DARKEN)で暗くする(disabled.png実測値と近似することを確認済み)
const DISABLED_DESATURATE := 0.85
const DISABLED_DARKEN := 0.3

## BoardTable(盤面テーブル)/BarPanel(対局画面の上下バー)の下地色。CodedButtonStyle等の
## 「ボタン・パネル」系(BRASS_*/PANEL_SLATE_*)とは意匠の系統が異なる石・金属の面のため
## 個別に持つが、琥珀の縁取り・区切り線・装飾は他のコード描画UIと共通のGLOW_AMBERを
## 使う(フェーズ12 Q-6、元の値から変更なし)
const BOARD_TABLE_FILL := Color(0.13, 0.11, 0.14, 0.94)
const BAR_FILL_TOP := Color(0.17, 0.14, 0.18, 0.96)
const BAR_FILL_BOTTOM := Color(0.08, 0.07, 0.09, 0.98)
const BAR_EDGE_HIGHLIGHT := Color(0.96, 0.82, 0.5, 0.35)

## 駒の台座光のデフォルト色(イラストからアクセントカラーをサンプリングできない場合の
## フォールバック)。GLOW_AMBERより明るく黄味寄りの「砂」の色のため別定数として持つ
const PEDESTAL_DEFAULT_ACCENT := Color(0.9, 0.72, 0.34, 1.0)
