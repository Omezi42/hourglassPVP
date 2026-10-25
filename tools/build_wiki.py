"""攻略サイト(GameDesign.md 32章 / Architecture.md 10.21節)を build/wiki/ へ組み立てる。

wiki/ のソースを写し、functions/data/cards.json と card_art の画像(WebP へ変換)を足す。
--sample DIR を渡すと、DIR の public_stats の JSON を sample/ へ写す(手元で ?sample を付けて確かめる用)。
"""

import argparse
import json
import shutil
from pathlib import Path

from PIL import Image

ROOT = Path(__file__).resolve().parent.parent
SOURCE = ROOT / "wiki"
OUT = ROOT / "build" / "wiki"
CARDS_JSON = ROOT / "functions" / "data" / "cards.json"
CARD_ART = ROOT / "functions" / "data" / "card_art"
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
    data_dir = OUT / "data"
    data_dir.mkdir()
    (data_dir / "cards.json").write_text(json.dumps({"cards": cards}, ensure_ascii=False), encoding="utf-8")
    if sample_dir:
        shutil.copytree(sample_dir, OUT / "sample")
    print("wiki built: %d cards -> %s" % (len(cards), OUT))


if __name__ == "__main__":
    parser = argparse.ArgumentParser()
    parser.add_argument("--sample", type=Path, default=None)
    build(parser.parse_args().sample)
