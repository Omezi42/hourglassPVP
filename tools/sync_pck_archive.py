"""攻略サイトのリプレイ用に、今の Godot 本体で書き出した過去の版の pck を build/pages へ足す(Architecture.md 4.6節)。

使い方: python tools/sync_pck_archive.py <build/pages>
Pages はデプロイのたびにサイト全体を置き換えるため、残したい pck は毎回一緒に上げ直す。
手元の控え(build/pck_archive/)に無い版は、公開中の builds.json を見て Pages から取り戻す。
builds.json に載るのは、再生の入口(ReplayLaunch)を持つ版を書き出してから後の版だけ。
Godot 本体の版が違うもの(もう再生できないもの)は builds.json から外し、控えからも消す。
"""

import json
import shutil
import sys
import urllib.error
import urllib.request
from pathlib import Path

from make_portal import PAGES_ORIGIN

ROOT = Path(__file__).resolve().parent.parent
ARCHIVE = ROOT / "build" / "pck_archive"
TIMEOUT_SEC = 120
NOT_FOUND = 404
# Cloudflare は Python の既定の User-Agent を 403 で弾く。
HEADERS = {"User-Agent": "sunadokei-arena-deploy"}


def open_url(name: str):
    return urllib.request.urlopen(urllib.request.Request(PAGES_ORIGIN + name, headers=HEADERS), timeout=TIMEOUT_SEC)


def fetch_json(name: str) -> dict:
    """無ければ空。通信に失敗したら止める(過去の版を一覧から落として消さないため)。"""
    try:
        with open_url(name) as response:
            return json.load(response)
    except urllib.error.HTTPError as error:
        if error.code == NOT_FOUND:
            return {}
        sys.exit(f"sync_pck_archive: {name} を読めない({error.code})")
    except urllib.error.URLError as error:
        sys.exit(f"sync_pck_archive: {name} を読めない({error.reason})")


def live_builds(engine: str) -> dict:
    """公開中の版の一覧。builds.json が無い(版を残し始める前)なら空。"""
    listing = fetch_json("builds.json")
    return dict(listing.get("builds", {})) if listing.get("engine") == engine else {}


def ensure_archived(entry: dict) -> bool:
    path = ARCHIVE / entry["pck"]
    if path.exists() and path.stat().st_size == entry["size"]:
        return True
    try:
        with open_url(entry["pck"]) as response:
            path.write_bytes(response.read())
    except urllib.error.URLError:
        print(f"sync_pck_archive: {entry['pck']} を取り戻せなかった(この版は再生できなくなる)")
        return False
    return path.stat().st_size == entry["size"]


def main() -> None:
    pages = Path(sys.argv[1])
    current = json.loads((pages / "builds.json").read_text(encoding="utf-8"))
    engine = current["engine"]
    ARCHIVE.mkdir(parents=True, exist_ok=True)
    builds = live_builds(engine)
    builds.update(current["builds"])
    for entry in current["builds"].values():
        shutil.copy2(pages / entry["pck"], ARCHIVE / entry["pck"])
    kept = {build: entry for build, entry in builds.items() if ensure_archived(entry)}
    for build, entry in kept.items():
        if build not in current["builds"]:
            shutil.copy2(ARCHIVE / entry["pck"], pages / entry["pck"])
    names = {entry["pck"] for entry in kept.values()}
    for stale in ARCHIVE.glob("*.pck"):
        if stale.name not in names:
            stale.unlink()
    listing = {"engine": engine, "builds": kept}
    (pages / "builds.json").write_text(json.dumps(listing), encoding="utf-8")
    print(f"sync_pck_archive: {len(kept)} 版の pck を残す")


if __name__ == "__main__":
    main()
