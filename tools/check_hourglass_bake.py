"""コード描画の砂時計の焼き忘れを見つける(Architecture.md 10.19節)。

シェーダーがあるのにPNGが揃っていない、または焼いたときの元(共通の部品・そのカードのシェーダー・
共通のガラス・表のそのカードの行)と今が違うなら失敗にする。ハッシュの求め方は
tools/bake_hourglass_art.gd の source_hash() と同じ。直すには `bake_hourglass_art.gd` を回す。
"""

import hashlib
import json
import os
import re
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
SHADERS = os.path.join(ROOT, "resources", "shaders")
OVERRIDES = os.path.join(ROOT, "assets", "hourglasses", "overrides")
MANIFEST = os.path.join(ROOT, "tools", "hourglass_bake_manifest.json")
TABLE = os.path.join(ROOT, "data", "hourglass_tints.tres")
COMMON = ["hourglass_lib.gdshaderinc", "hourglass_glass.gdshaderinc", "frame_parts.gdshaderinc", "art_main.gdshaderinc"]
STATES = ["full", "falling", "empty"]


def read_text(path):
    with open(path, encoding="utf-8", newline="") as f:
        return f.read().replace("\r", "")


def table_row(art_key):
    prefix = '"%s": {' % art_key
    for line in read_text(TABLE).split("\n"):
        if line.startswith(prefix):
            return line.strip()
    return ""


def glass_name(art_key):
    m = re.search(r'"texture": "(\w+)"', table_row(art_key))
    return m.group(1) if m else "sand"


def source_hash(art_key):
    paths = [os.path.join(SHADERS, "hourglass", name) for name in COMMON]
    paths.append(os.path.join(SHADERS, "hourglasses", art_key + ".gdshader"))
    paths.append(os.path.join(SHADERS, "hourglass", "glass_%s.gdshader" % glass_name(art_key)))
    h = hashlib.sha256()
    for path in paths:
        h.update(read_text(path).encode("utf-8"))
    h.update(table_row(art_key).encode("utf-8"))
    return h.hexdigest()


def main():
    manifest = {}
    if os.path.exists(MANIFEST):
        with open(MANIFEST, encoding="utf-8") as f:
            manifest = json.load(f)
    problems = []
    art_keys = sorted(f[:-9] for f in os.listdir(os.path.join(SHADERS, "hourglasses")) if f.endswith(".gdshader"))
    for art_key in art_keys:
        folder = os.path.join(OVERRIDES, art_key)
        missing = [
            "%s_%s.png" % (kind, state)
            for kind in ("state", "frame")
            for state in STATES
            if not os.path.exists(os.path.join(folder, "%s_%s.png" % (kind, state)))
        ]
        if missing:
            problems.append("%s: 焼いた絵が無い (%s)" % (art_key, ", ".join(missing)))
        elif manifest.get(art_key) != source_hash(art_key):
            problems.append("%s: シェーダー・共通の部品・表の色や質感が焼いたときと違う" % art_key)
    for problem in problems:
        print(problem)
    if problems:
        print("bake_hourglass_art.gd を回して焼き直す(Architecture.md 10.19節)")
        return 1
    print("ok (%d)" % len(art_keys))
    return 0


if __name__ == "__main__":
    sys.exit(main())
