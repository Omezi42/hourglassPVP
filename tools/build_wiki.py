"""攻略サイト(GameDesign.md 32章 / Architecture.md 10.21節)を build/wiki/ へ組み立てる。

wiki/ のソースを写し、functions/data/cards.json と card_art の画像(WebP へ変換)、プレイヤーのアイコン、ログイン用の設定を足す。
--sample DIR を渡すと、DIR の public_stats の JSON を sample/ へ写す(手元で ?sample を付けて確かめる用)。
"""

import argparse
import json
import re
import shutil
from pathlib import Path

from PIL import Image

ROOT = Path(__file__).resolve().parent.parent
SOURCE = ROOT / "wiki"
OUT = ROOT / "build" / "wiki"
CARDS_JSON = ROOT / "functions" / "data" / "cards.json"
CARD_ART = ROOT / "functions" / "data" / "card_art"
# ゲームが pck に入れて配っている公開の Web API キー。サイトのログインが同じ認証を使う。
FIREBASE_CONFIG = ROOT / "data" / "firebase_config.tres"
# プレイヤーのアイコン(id → res:// のパス)と称号の表示名。共有リプレイの埋め込み画像が icons/{id}.webp を、
# ランキングのページがアイコンと data/profile.json の称号を読む。
PROFILE_LIBRARY = ROOT / "scripts" / "data" / "user_profile_library.gd"
TITLE_ENTRY = re.compile(r'"(\w+)":\s*\{\s*"name":\s*"[^"]*",\s*"display":\s*"([^"]*)"')
ICON_ENTRY = re.compile(r'"(\w+)":\s*\{\s*"name":\s*"[^"]*",\s*"path":\s*"res://([^"]+)"')
# card_art(720x400)のうち、砂時計・砂術の絵が描かれている左の枠。
THUMB_BOX = (28, 86, 250, 376)
WEBP_QUALITY = 82


def build(sample_dir):
    if OUT.exists():
        shutil.rmtree(OUT)
    shutil.copytree(SOURCE, OUT, ignore=shutil.ignore_patterns(".gdignore"))
    cards = json.loads(CARDS_JSON.read_text(encoding="utf-8"))["cards"]
    art_dir = OUT / "art"
    art_dir.mkdir()
    for card in cards:
        source = CARD_ART / ("%s.png" % card["id"])
        card["has_art"] = source.exists()
        if not card["has_art"]:
            continue
        with Image.open(source) as image:
            image = image.convert("RGB")
            image.save(art_dir / ("%s.webp" % card["id"]), quality=WEBP_QUALITY)
            image.crop(THUMB_BOX).save(art_dir / ("%s_thumb.webp" % card["id"]), quality=WEBP_QUALITY)
    export_icons()
    data_dir = OUT / "data"
    data_dir.mkdir()
    (data_dir / "cards.json").write_text(json.dumps({"cards": cards}, ensure_ascii=False), encoding="utf-8")
    api_key = re.search(r'api_key = "([^"]+)"', FIREBASE_CONFIG.read_text(encoding="utf-8")).group(1)
    titles = dict(TITLE_ENTRY.findall(PROFILE_LIBRARY.read_text(encoding="utf-8")))
    (data_dir / "profile.json").write_text(json.dumps({"titles": titles}, ensure_ascii=False), encoding="utf-8")
    (data_dir / "config.json").write_text(json.dumps({"apiKey": api_key}), encoding="utf-8")
    if sample_dir:
        shutil.copytree(sample_dir, OUT / "sample")
    print("wiki built: %d cards -> %s" % (len(cards), OUT))


def export_icons():
    icon_dir = OUT / "icons"
    icon_dir.mkdir()
    for icon_id, res_path in ICON_ENTRY.findall(PROFILE_LIBRARY.read_text(encoding="utf-8")):
        with Image.open(ROOT / res_path) as image:
            image.convert("RGBA").save(icon_dir / ("%s.webp" % icon_id), quality=WEBP_QUALITY)


if __name__ == "__main__":
    parser = argparse.ArgumentParser()
    parser.add_argument("--sample", type=Path, default=None)
    build(parser.parse_args().sample)
