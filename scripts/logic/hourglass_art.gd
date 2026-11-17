class_name HourglassArt
extends RefCounted
## 砂時計の絵を配る(Architecture.md 4.1節)。
##
## 絵はカードごとに1本のシェーダー(`resources/shaders/hourglasses/{id}.gdshader`)で描き、
## `tools/bake_hourglass_art.gd` が3状態を半分の大きさのPNGへ焼いておく。ここはそれを読んで返すだけ。
## `SoundBank` と同じ「Autoloadを使わずstaticで持つ」流儀。

enum State { UPRIGHT, FALLING, FALLEN }

const STATE_FILES: Array[String] = ["state_full", "state_falling", "state_empty"]
const ART_DIR := "res://assets/hourglasses/overrides"
const TABLE_PATH := "res://data/hourglass_sands.tres"
## 表の `texture` の値(先頭の空文字が既定のさらさら)。共通のガラスのシェーダーを選ぶ。
const TEXTURES: Array[String] = ["", "grain", "liquid", "crystal", "glow", "stardust"]
## 表に無いid(砂術など)の砂の色。看板のカード(サンド)と同じ。
const DEFAULT_SAND := Color(0.93, 0.66, 0.24, 1.0)

static var _table: HourglassSandTable = null
static var _textures: Dictionary = {}


## その絵の1状態。焼いた絵が無いid(砂術)は null。
static func texture(art_id: String, state: int) -> Texture2D:
	var key := "%s|%d" % [art_id, state]
	if _textures.has(key):
		return _textures[key]
	var path := "%s/%s/%s.png" % [ART_DIR, art_id, STATE_FILES[state]]
	var found: Texture2D = load(path) if ResourceLoader.exists(path) else null
	_textures[key] = found
	return found


## その絵の砂の色(手札の窓の光だまりなどに使う)。
static func accent_color(art_id: String) -> Color:
	_load_table()
	if _table != null and _table.has(art_id):
		return _table.sand_of(art_id)
	return DEFAULT_SAND


## その絵の砂の質感の名前(無ければ空文字=さらさら)。コード描画の共通のガラスを選ぶ。
static func texture_name(art_id: String) -> String:
	_load_table()
	return _table.texture_of(art_id) if _table != null else ""


static func _load_table() -> void:
	if _table == null:
		_table = load(TABLE_PATH)
