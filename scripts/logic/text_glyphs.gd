class_name TextGlyphs
extends RefCounted
## 同梱フォントが字形を持つ文字かどうかを答える(GameDesign.md 14章)。
##
## 絵文字・ハングル・アクセント付きのラテン文字・大半の記号は Zen Kaku Gothic New に
## 字形が無く、そのまま描くと豆腐(□)になる。**エディタ実行では別のフォントで代替されて
## 気づけず、書き出した版でだけ化ける**ため、入力を受け取る側で弾く。
##
## **対応する文字の一覧をここへ持たない。**表を持つと、フォントを差し替えたときに
## 黙って食い違う。フォント自身へ `has_char()` で問い合わせ、結果だけを覚えておく。

## `resources/theme/main_theme.tres` の `default_font` と同じもの。
const FONT_PATH := "res://assets/fonts/ZenKakuGothicNew-Bold.ttf"
## 字形が無い文字を表示するときの代わり。
const REPLACEMENT := "?"

static var _font: Font = null
## 文字コード -> 字形があるか。同じ文字を何度も問い合わせないために持つ。
static var _cache: Dictionary = {}


static func supports(code: int) -> bool:
	if _cache.has(code):
		return bool(_cache[code])
	var font := _load_font()
	# フォントを読めない状況(テスト等)では弾かない。名前を入力できなくなるより、
	# 化けるかもしれない文字が通るほうが害が小さい。
	var ok: bool = true if font == null else font.has_char(code)
	_cache[code] = ok
	return ok


## 文字列全体が表示できるか。
static func supports_text(text: String) -> bool:
	for i in text.length():
		if not supports(text.unicode_at(i)):
			return false
	return true


## 表示できない文字を取り除く(入力欄で使う)。
static func sanitize(text: String) -> String:
	var kept := ""
	for i in text.length():
		var code := text.unicode_at(i)
		if supports(code):
			kept += String.chr(code)
	return kept


## 表示できない文字を「?」へ置き換える(相手から届いた名前の表示で使う)。
static func replace_unsupported(text: String) -> String:
	var out := ""
	for i in text.length():
		var code := text.unicode_at(i)
		out += String.chr(code) if supports(code) else REPLACEMENT
	return out


static func _load_font() -> Font:
	if _font == null and ResourceLoader.exists(FONT_PATH):
		_font = load(FONT_PATH) as Font
	return _font
