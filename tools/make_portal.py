"""itch.io・PLiCy 向けの起動部と、Cloudflare Pages へ上げる pck 一式を作る(Architecture.md 4.6節)。

使い方: python tools/make_portal.py <build/web> <build_id> <engine_version>
出力:   build/portal/ と build/portal.zip(起動部・pck を含まない)
        build/pages/(index-{build_id}.pck・latest.json・_headers)
"""

import json
import os
import shutil
import sys
from pathlib import Path

PAGES_ORIGIN = os.environ.get("PORTAL_PAGES_ORIGIN", "https://sunadokei-arena.pages.dev/")
PORTAL_EXCLUDE = {"index.pck", "index.html"}

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
const PORTAL_MSG_FAILED = 'ゲームを読み込めませんでした。\\nページを再読み込みしてください。';
const PORTAL_MSG_OUTDATED = 'このページの版が古くなっています。\\nunityroom版で遊んでください。\\nhttps://unityroom.com/games/sunadokei_arena';
function portalLatest() {
	return fetch(PORTAL_ORIGIN + 'latest.json', { cache: 'no-store' })
		.then((r) => (r.ok ? r.json() : Promise.reject(new Error())))
		.catch(() => Promise.reject(new Error(PORTAL_MSG_FAILED)))
		.then((latest) => (latest.engine === PORTAL_ENGINE ? latest : Promise.reject(new Error(PORTAL_MSG_OUTDATED))));
}
"""

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


def make_loader(html: str, engine: str) -> str:
    loader = LOADER % {"origin": json.dumps(PAGES_ORIGIN), "engine": json.dumps(engine)}
    html = replace_once(html, CONFIG_ANCHOR, loader + CONFIG_ANCHOR)
    html = replace_once(html, START_OLD, START_NEW)
    return replace_once(html, THEN_OLD, THEN_NEW)


def main() -> None:
    web, build_id, engine = Path(sys.argv[1]), sys.argv[2], sys.argv[3]
    root = web.parent
    portal, pages = root / "portal", root / "pages"
    for d in (portal, pages):
        shutil.rmtree(d, ignore_errors=True)
        d.mkdir(parents=True)

    for f in web.iterdir():
        if f.is_file() and f.name not in PORTAL_EXCLUDE:
            shutil.copy2(f, portal / f.name)
    html = (web / "index.html").read_text(encoding="utf-8")
    (portal / "index.html").write_text(make_loader(html, engine), encoding="utf-8", newline="\n")
    shutil.make_archive(str(root / "portal"), "zip", portal)

    pck_name = f"index-{build_id}.pck"
    shutil.copy2(web / "index.pck", pages / pck_name)
    latest = {"build": build_id, "pck": pck_name, "size": (web / "index.pck").stat().st_size, "engine": engine}
    (pages / "latest.json").write_text(json.dumps(latest), encoding="utf-8")
    (pages / "_headers").write_text(HEADERS, encoding="utf-8", newline="\n")
    print(f"portal: {root / 'portal.zip'} / pages: {pck_name}")


if __name__ == "__main__":
    main()
