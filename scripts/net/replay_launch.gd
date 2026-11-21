class_name ReplayLaunch
extends RefCounted
## 攻略サイトからリプレイを再生するための起動(GameDesign.md 32章、Architecture.md 10.21節)。
## サイトは起動部を `?replay=1&build={版}` で開き、記録を `postMessage` で渡す。起動部はそれを
## `window.hourglassReplay`(JSONの文字列)へ置いてからエンジンを起動する。
## デスクトップでは `-- --replay=記録.json` で同じ形の記録を読む(確かめるため)。
##
## 記録の形: `{deck_a, deck_b, seed, actions, view, players}`。`view` は手前に置く側("a"|"b")、
## `players` は `{a: {name, icon, title}, b: {...}}`。
## タイトルより先に読まれるため、他の class_name を参照しない。

const QUERY_EXPRESSION := "new URLSearchParams(window.location.search).has('replay')"
const RECORD_EXPRESSION := "window.hourglassReplay || ''"
const ARG_PREFIX := "--replay="

static var _cached: Variant = null


static func requested() -> bool:
	if OS.has_feature("web"):
		return bool(JavaScriptBridge.eval(QUERY_EXPRESSION))
	return not _arg_path().is_empty()


## 渡された記録。読めなければ空。
static func record() -> Dictionary:
	if _cached == null:
		_cached = _read()
	return _cached


static func _read() -> Dictionary:
	if not requested():
		return {}
	var text := ""
	if OS.has_feature("web"):
		text = str(JavaScriptBridge.eval(RECORD_EXPRESSION))
	else:
		text = FileAccess.get_file_as_string(_arg_path())
	var parsed: Variant = JSON.parse_string(text)
	if not parsed is Dictionary:
		return {}
	return _to_ints(parsed)


static func _arg_path() -> String:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with(ARG_PREFIX):
			return arg.trim_prefix(ARG_PREFIX)
	return ""


## JSONの数は小数で届く。棋譜の位置や種は整数として扱われるため、整数の値は整数へ戻す。
static func _to_ints(value: Variant) -> Variant:
	if value is float and value == floorf(value):
		return int(value)
	if value is Array:
		return (value as Array).map(_to_ints)
	if value is Dictionary:
		var out := {}
		for key: Variant in value:
			out[key] = _to_ints(value[key])
		return out
	return value
