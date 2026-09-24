class_name PortalInfo
extends RefCounted
## unityroom以外の配信先(itch.io・PLiCy)で動いているかの判定(Architecture.md 4.6節)。
## 自前の起動部(`tools/make_portal.py`)が `window.hourglassPortal = true` を立てる。

const FLAG_EXPRESSION := "window.hourglassPortal === true"


static func is_portal() -> bool:
	if not OS.has_feature("web"):
		return false
	return bool(JavaScriptBridge.eval(FLAG_EXPRESSION))
