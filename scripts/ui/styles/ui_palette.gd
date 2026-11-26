class_name UiPalette
extends RefCounted
## UIの言語の単一情報源(GameDesign.md 9章「共通のレイアウト規約」)。
## 夜の天文台に置いた真鍮の計器: 地は夜の藍、線は真鍮、光るのは砂だけ。
## 色・文字の段・余白の刻み・動きの尺を定数で持ち、ロジックは持たない。

# ---- 夜の藍(地と面)。数字が大きいほど暗い ----
## 輪郭と影の最も暗い藍。
const INK_950 := Color(0.02, 0.025, 0.05)
const INK_900 := Color(0.035, 0.045, 0.085)
const INK_800 := Color(0.06, 0.075, 0.135)
const INK_700 := Color(0.09, 0.115, 0.20)
const INK_600 := Color(0.14, 0.175, 0.29)
const INK_500 := Color(0.22, 0.27, 0.42)
## メニューのモーダルの暗幕(対局の重ねは `CardMatchLayout.OVERLAY_DIM_ALPHA` で一段濃い)。
const MODAL_DIM := Color(INK_900, 0.72)

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

# ---- レアリティ(GameDesign.md 9章「レアリティ」。白銀・青・紫・橙金) ----
const RARITY_COMMON := Color(0.86, 0.88, 0.92)
const RARITY_RARE := Color(0.38, 0.64, 1.0)
const RARITY_EPIC := Color(0.72, 0.44, 1.0)
const RARITY_LEGEND := Color(1.0, 0.62, 0.18)
## 開封の裏の地(藍)と、レジェンドの静止で敷く薄い青の膜。
const CARD_BACK_TOP := Color(0.12, 0.15, 0.30)
const CARD_BACK_BOTTOM := Color(0.06, 0.07, 0.16)
const STILL_FILM := Color(0.80, 0.90, 1.0)
const GLASS_TINT := Color(0.55, 0.66, 0.88)
const SEAL_WAX := Color(0.62, 0.12, 0.12)
## 背水の刻の演出(GameDesign.md 9章)。共通の燠火(赤橙の火の粉・灼けた縁)と、各札の道具の素材。
const EMBER := Color(1.0, 0.46, 0.16)
const EMBER_DEEP := Color(0.78, 0.14, 0.06)
const STEEL := Color(0.80, 0.84, 0.90)
const SMOKE := Color(0.80, 0.78, 0.82)
const WAX := Color(0.97, 0.91, 0.78)
const HORN := Color(0.90, 0.82, 0.66)
const SHIELD_PAINT := Color(0.30, 0.56, 0.32)
const BASALT := Color(0.36, 0.36, 0.40)
const BRONZE := Color(0.82, 0.58, 0.32)
const TIDE := Color(0.20, 0.40, 0.58)
const FOAM := Color(0.86, 0.94, 1.0)
## 烈砂の刻の演出(GameDesign.md 9章)。共通の駆ける火(明るい橙の炎・赤い尾)と、風・各札の道具の素材。
const FLAME := Color(1.0, 0.60, 0.12)
const FLAME_RED := Color(0.92, 0.24, 0.08)
const WIND := Color(0.96, 0.93, 0.84)
const DAWN := Color(0.86, 0.94, 1.0)
const SIGNAL_RED := Color(0.86, 0.20, 0.16)
const DUST := Color(0.90, 0.80, 0.62)
const BIRCH := Color(0.90, 0.79, 0.60)
const FLINT := Color(0.52, 0.54, 0.62)
const FEATHER_RED := Color(0.84, 0.22, 0.18)
## 早鐘の刻の演出(GameDesign.md 9章)。共通の音の輪(真鍮の弧に朝空の芯)と、朝焼け・各札の道具の素材。
const TOLL_BRASS := Color(0.96, 0.78, 0.40)
const MORNING_SKY := Color(0.60, 0.80, 1.0)
const DAYBREAK := Color(1.0, 0.74, 0.50)
const COPPER := Color(0.86, 0.48, 0.30)
const STEAM := Color(0.95, 0.97, 1.0)
const LACQUER_RED := Color(0.74, 0.18, 0.14)
const NIGHT_VEIL := Color(0.22, 0.24, 0.40)
## 払拭の型(`EmblemStrikeFx` の DRAIN)のくすんだ輪と、そこへ向かう筋の色。
const DRAIN_INK := Color(0.2, 0.18, 0.22)
const DRAIN_TRAIL := Color(0.58, 0.56, 0.62)

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
