class_name PortalInfo
extends RefCounted
## unityroom以外の配信先(itch.io・PLiCy)で動いているかの判定(Architecture.md 4.6節)。
## 自前の起動部(`tools/make_portal.py`)が `window.hourglassPortal = true` を立てる。

const FLAG_EXPRESSION := "window.hourglassPortal === true"
## itch.io / PLiCy は起動部をiframeで開くため、ホスト名と参照元(親ページ)の両方を見る。
const PLACE_EXPRESSION := "(window.location.hostname + ' ' + document.referrer).toLowerCase()"
const SITE_DESKTOP := "desktop"
const SITE_UNITYROOM := "unityroom"
const SITE_OTHER := "other"
## 起動部のときの見分け方(含む文字列 → 配信先)。
const PORTAL_MARKS := {"itch": "itch", "hwcdn": "itch", "plicy": "plicy"}


static func is_portal() -> bool:
	if not OS.has_feature("web"):
		return false
	return bool(JavaScriptBridge.eval(FLAG_EXPRESSION))


## 通過数を配信先ごとに分けるための名前(GameDesign.md 22章)。
static func site() -> String:
	if not OS.has_feature("web"):
		return SITE_DESKTOP
	if not is_portal():
		return SITE_UNITYROOM
	return site_from_place(str(JavaScriptBridge.eval(PLACE_EXPRESSION)))


static func site_from_place(place: String) -> String:
	for mark: String in PORTAL_MARKS:
		if place.contains(mark):
			return PORTAL_MARKS[mark]
	return SITE_OTHER
