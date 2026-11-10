class_name UiPalette
extends RefCounted
## UIの言語の単一情報源(GameDesign.md 9章「共通のレイアウト規約」)。
## 夜の天文台に置いた真鍮の計器: 地は夜の藍、線は真鍮、光るのは砂だけ。
## 色・文字の段・余白の刻み・動きの尺を定数で持ち、ロジックは持たない。

# ---- 夜の藍(地と面)。数字が大きいほど暗い ----
const INK_900 := Color(0.035, 0.045, 0.085)
const INK_800 := Color(0.06, 0.075, 0.135)
const INK_700 := Color(0.09, 0.115, 0.20)
const INK_600 := Color(0.14, 0.175, 0.29)
const INK_500 := Color(0.22, 0.27, 0.42)

# ---- 真鍮(線と主の面) ----
const GOLD_HI := Color(1.0, 0.93, 0.72)
const GOLD := Color(0.90, 0.74, 0.42)
const BRASS := Color(0.68, 0.50, 0.23)
const BRASS_DEEP := Color(0.36, 0.24, 0.09)
## 真鍮の面に彫った字と、真鍮の外の暗い縁。
const BRASS_INK := Color(0.17, 0.10, 0.03)
## 真鍮の面の中ほどの2つの節(上の照りから下の沈みへ折れるところ)。
const GOLD_WARM := Color(0.98, 0.84, 0.52)
const GOLD_FOLD := Color(0.80, 0.62, 0.31)

# ---- 砂(進み・自分・いま) ----
const SAND_HI := Color(1.0, 0.86, 0.52)
const SAND := Color(0.96, 0.68, 0.24)
const SAND_DEEP := Color(0.78, 0.45, 0.12)

# ---- 意味の色(全画面で1つ) ----
const COST := Color(0.30, 0.60, 0.96)
const COST_DEEP := Color(0.10, 0.25, 0.58)
const HEALTH := Color(0.90, 0.30, 0.27)
const HEALTH_DEEP := Color(0.52, 0.10, 0.10)
const ATTACK := Color(0.97, 0.62, 0.18)
const ATTACK_DEEP := Color(0.62, 0.30, 0.04)
const GOOD := Color(0.45, 0.80, 0.52)
const FOE := Color(0.90, 0.36, 0.33)
const SELECT := Color(0.45, 0.82, 1.0)
## 取り返せない操作のボタンの字(赤い縁の内側で読める明るさ)。
const DANGER_TEXT := Color(1.0, 0.72, 0.68)

# ---- 文字 ----
const IVORY := Color(0.96, 0.93, 0.86)
const MUTED := Color(0.66, 0.66, 0.70)
const FAINT := Color(0.44, 0.46, 0.54)

# ---- 紙(カードの名前の帯と図鑑) ----
const PAPER := Color(0.93, 0.88, 0.76)
const PAPER_DEEP := Color(0.78, 0.70, 0.54)
const PAPER_INK := Color(0.16, 0.11, 0.06)

# ---- 文字の段(横の基準。縦は部品の拡大で目安を満たす) ----
const T_MICRO := 12
const T_SMALL := 14
const T_BODY := 16
const T_LEAD := 20
const T_HEAD := 26
const T_TITLE := 34
const T_HERO := 46

# ---- 余白の刻み ----
const S1 := 4.0
const S2 := 8.0
const S3 := 12.0
const S4 := 16.0
const S5 := 24.0
const S6 := 32.0

# ---- UIの部品が操作へ返す動きの尺(秒) ----
const DUR_PRESS := 0.09
const DUR_HOVER := 0.16
const DUR_SHOW := 0.24

# ---- 場所の絵(壁・棚)。5つの素材の外 ----
const WOOD_TOP := Color(0.34, 0.22, 0.13, 1.0)
const WOOD_MID := Color(0.22, 0.14, 0.09, 1.0)
const WOOD_DARK := Color(0.12, 0.08, 0.05, 1.0)

# ---- 無効の色変換(`UiPaint.disabled_tone()`) ----
const DISABLED_DESATURATE := 0.85
const DISABLED_DARKEN := 0.3

# ---- 古い名前。新しい色へ向けてあり、画面を入れ替えるたびに上の名前へ寄せて消す(TODO.md) ----
const BRASS_HIGHLIGHT := GOLD
const BRASS_LIGHT := GOLD_FOLD
const BRASS_MID := BRASS
const BRASS_DARK := BRASS_DEEP
const BRASS_BOUNCE := Color(0.45, 0.31, 0.13)
const BRASS_RIM_LIGHT := GOLD
const BRASS_PRESSED_MID := BRASS_DEEP
const BRASS_PRESSED_DARK := BRASS_INK
const OUTLINE_DARK := Color(0.02, 0.025, 0.05)
const PANEL_SLATE_TOP := INK_900
const PANEL_SLATE_BOTTOM := INK_700
const PANEL_AMBER_TOP := SAND_DEEP
const PANEL_AMBER_BOTTOM := SAND_HI
const PANEL_PRESSED_TOP := INK_900
const PANEL_PRESSED_BOTTOM := INK_800
const GLOW_AMBER := SAND
const TEXT_OFFWHITE := IVORY
const TEXT_MUTED := MUTED
const LOCK_PLATE := Color(0.035, 0.045, 0.085, 0.78)
const LOCK_BRASS := GOLD
const WARNING_RED := HEALTH
const NAMEPLATE_PANEL_TOP := INK_900
const NAMEPLATE_PANEL_BOTTOM := INK_700
const BOARD_TABLE_FILL := Color(0.06, 0.075, 0.135, 0.94)
const BAR_FILL_TOP := Color(0.09, 0.115, 0.20, 0.96)
const BAR_FILL_BOTTOM := Color(0.035, 0.045, 0.085, 0.98)
const BAR_EDGE_HIGHLIGHT := Color(0.90, 0.74, 0.42, 0.35)
const PEDESTAL_DEFAULT_ACCENT := SAND_HI
const FELT_NAVY_TOP := Color(0.13, 0.16, 0.30, 1.0)
const FELT_NAVY_BOTTOM := Color(0.07, 0.09, 0.19, 1.0)
const NAVY_PANEL_TOP := INK_700
const NAVY_PANEL_BOTTOM := INK_900
const NAVY_PANEL_PILE := INK_600
const ROUND_FILLED_TOP := GOLD_HI
const ROUND_FILLED_BOTTOM := BRASS
