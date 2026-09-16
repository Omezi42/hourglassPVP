class_name UiFonts
extends RefCounted
## プロジェクト全体のフォントの単一情報源。本文用(Zen Kaku Gothic New Bold、テーマの
## 既定フォント)に加えて、見出し専用の明朝体(Zen Old Mincho Black)を持つ。
##
## 見出し用は**タイトル・各画面の見出し・タブの大きな見出しだけ**に使う(Architecture.md
## 4章「フォントが1.66MB」の負債と同じ理由で、本文用は自由入力(デッキ名等)を通すため
## サブセット化できないが、見出し用は使う文字が固定されているため小さく絞ってある)。
##
## `assets/fonts/ZenOldMincho-Display.ttf` は見出しで実際に使う文字だけへ`pyftsubset`で
## 削った派生ファイル(詳細は `assets/CREDITS.md`)。**サブセットに無い文字を描画すると
## 何も表示されない**ため、`display_font()` は本文用フォントを `fallbacks` として設定して
## 返す。これにより、想定外の文字が見出しへ紛れ込んでも静かに本文書体へ戻るだけで済み、
## 文字化け(豆腐)にはならない。

const DISPLAY_FONT_PATH := "res://assets/fonts/ZenOldMincho-Display.ttf"

static var _display_font: Font
static var _display_font_loaded := false


## 見出し専用の明朝体。タイトルロゴ・`ScreenHeader`のタイトル・`HomeFrame`の見出し・
## `HomeTile`のうち主役(primary)の見出しに使う。読み込めなかった場合は本文用
## フォント(呼び出し側の既定フォント)をそのまま返すため、呼び出し側は null チェックを
## 気にせず使える。
static func display_font(fallback: Font) -> Font:
	if not _display_font_loaded:
		_display_font_loaded = true
		var loaded: Resource = load(DISPLAY_FONT_PATH)
		if loaded is Font:
			_display_font = loaded as Font
	if _display_font == null:
		return fallback
	if fallback != null:
		# 呼び出しのたびに違うfallbackを渡されても構わないよう、その都度差し替える。
		# サブセットに無い文字(絵文字・稀な記号等)をここで拾い、豆腐にしない。
		var chain: Array[Font] = [fallback]
		_display_font.fallbacks = chain
	return _display_font
