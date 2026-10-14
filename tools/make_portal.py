"""itch.io・PLiCy・アプリ版(PWA)向けの起動部と、Cloudflare Pages へ上げる pck 一式を作る(Architecture.md 4.6節)。

使い方: python tools/make_portal.py <build/web> <build_id> <engine_version>
出力:   build/portal/ と build/portal.zip(起動部・pck を含まない)
        build/app/    (アプリ版。GitHub Pages の sunadokei-arena-app へ上げる起動部)
        build/pages/(index-{build_id}.pck・latest.json・_headers)
アイコン(tools/app/icon-*.png)は icon.svg から次で書き出したものを置いてある:
        magick -background none -density 1200 icon.svg -resize 192x192 tools/app/icon-192.png
"""

import json
import os
import shutil
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
APP_SRC = ROOT / "tools" / "app"
PAGES_ORIGIN = os.environ.get("PORTAL_PAGES_ORIGIN", "https://sunadokei-arena.pages.dev/")
PORTAL_EXCLUDE = {"index.pck", "index.html"}
APP_ICONS = ("icon-192.png", "icon-512.png")

HEADERS = """/latest.json
  Access-Control-Allow-Origin: *
  Cache-Control: no-store

/*.pck
  Access-Control-Allow-Origin: *
  Cache-Control: public, max-age=31536000, immutable
"""

LOADER = """
window.hourglassPortal = true;
const PORTAL_ORIGIN = %(origin)s;
const PORTAL_ENGINE = %(engine)s;
const PORTAL_MSG_FAILED = %(failed)s;
const PORTAL_MSG_OUTDATED = %(outdated)s;
function portalLatest() {
	return fetch(PORTAL_ORIGIN + 'latest.json', { cache: 'no-store' })
		.then((r) => (r.ok ? r.json() : Promise.reject(new Error())))
		.catch(() => Promise.reject(new Error(PORTAL_MSG_FAILED)))
		.then((latest) => (latest.engine === PORTAL_ENGINE ? latest : Promise.reject(new Error(PORTAL_MSG_OUTDATED))));
}
%(extra)s"""

PORTAL_MESSAGES = {
    "failed": "ゲームを読み込めませんでした。\nページを再読み込みしてください。",
    "outdated": "このページの版が古くなっています。\nunityroom版で遊んでください。\nhttps://unityroom.com/games/sunadokei_arena",
}
APP_MESSAGES = {
    "failed": "通信できません。\n通信できる場所で、開き直してください。",
    "outdated": "アプリを開き直してください。",
}
APP_EXTRA = "if ('serviceWorker' in navigator) navigator.serviceWorker.register('sw.js');\n"
APP_HEAD = """<link rel="manifest" href="manifest.webmanifest">
<link rel="apple-touch-icon" href="icon-192.png">
<meta name="apple-mobile-web-app-capable" content="yes">
<meta name="theme-color" content="#363d52">
</head>"""

START_OLD = "\t\tengine.startGame({\n"
START_NEW = """\t\tportalLatest().then((latest) => engine.startGame({
\t\t\t'mainPack': PORTAL_ORIGIN + latest.pck,
\t\t\t'fileSizes': Object.assign({}, GODOT_CONFIG['fileSizes'], { [PORTAL_ORIGIN + latest.pck]: latest.size }),
"""
THEN_OLD = "\t\t}).then(() => {\n\t\t\tsetStatusMode('hidden');"
THEN_NEW = "\t\t})).then(() => {\n\t\t\tsetStatusMode('hidden');"
CONFIG_ANCHOR = "const GODOT_CONFIG = "


def replace_once(text: str, old: str, new: str) -> str:
    if text.count(old) != 1:
        sys.exit(f"make_portal: index.html の想定箇所が見つからない: {old[:40]!r}")
    return text.replace(old, new)


def make_loader(html: str, engine: str, messages: dict, extra: str = "") -> str:
    loader = LOADER % {
        "origin": json.dumps(PAGES_ORIGIN),
        "engine": json.dumps(engine),
        "failed": json.dumps(messages["failed"], ensure_ascii=False),
        "outdated": json.dumps(messages["outdated"], ensure_ascii=False),
        "extra": extra,
    }
    html = replace_once(html, CONFIG_ANCHOR, loader + CONFIG_ANCHOR)
    html = replace_once(html, START_OLD, START_NEW)
    return replace_once(html, THEN_OLD, THEN_NEW)


def copy_engine_files(web: Path, out: Path) -> None:
    for f in web.iterdir():
        if f.is_file() and f.name not in PORTAL_EXCLUDE:
            shutil.copy2(f, out / f.name)


def make_portal(web: Path, root: Path, engine: str) -> None:
    portal = root / "portal"
    shutil.rmtree(portal, ignore_errors=True)
    portal.mkdir(parents=True)
    copy_engine_files(web, portal)
    html = (web / "index.html").read_text(encoding="utf-8")
    (portal / "index.html").write_text(make_loader(html, engine, PORTAL_MESSAGES), encoding="utf-8", newline="\n")
    shutil.make_archive(str(root / "portal"), "zip", portal)


def make_app(web: Path, root: Path, engine: str) -> None:
    app = root / "app"
    shutil.rmtree(app, ignore_errors=True)
    app.mkdir(parents=True)
    copy_engine_files(web, app)
    html = (web / "index.html").read_text(encoding="utf-8")
    html = make_loader(html, engine, APP_MESSAGES, APP_EXTRA)
    html = replace_once(html, "</head>", APP_HEAD)
    (app / "index.html").write_text(html, encoding="utf-8", newline="\n")
    shutil.copy2(APP_SRC / "manifest.webmanifest", app / "manifest.webmanifest")
    shutil.copy2(APP_SRC / "offline.html", app / "offline.html")
    for icon in APP_ICONS:
        shutil.copy2(APP_SRC / icon, app / icon)
    sw = (APP_SRC / "sw.js").read_text(encoding="utf-8").replace("__ENGINE__", json.dumps(engine))
    (app / "sw.js").write_text(sw, encoding="utf-8", newline="\n")


def make_pages(web: Path, root: Path, build_id: str, engine: str) -> None:
    pages = root / "pages"
    shutil.rmtree(pages, ignore_errors=True)
    pages.mkdir(parents=True)
    pck_name = f"index-{build_id}.pck"
    shutil.copy2(web / "index.pck", pages / pck_name)
    latest = {"build": build_id, "pck": pck_name, "size": (web / "index.pck").stat().st_size, "engine": engine}
    (pages / "latest.json").write_text(json.dumps(latest), encoding="utf-8")
    (pages / "_headers").write_text(HEADERS, encoding="utf-8", newline="\n")
    print(f"portal: {root / 'portal.zip'} / app: {root / 'app'} / pages: {pck_name}")


def main() -> None:
    web, build_id, engine = Path(sys.argv[1]), sys.argv[2], sys.argv[3]
    root = web.parent
    make_portal(web, root, engine)
    make_app(web, root, engine)
    make_pages(web, root, build_id, engine)


if __name__ == "__main__":
    main()
