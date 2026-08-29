#!/usr/bin/env python3
"""次に追加する砂時計をチラ見せするカード画像を作る。

    python tools/discord/build_teaser_card.py --id poison            … 全部見せる
    python tools/discord/build_teaser_card.py --id poison --tease    … 絵と名前を伏せる
    python tools/discord/build_teaser_card.py --name グレイン --cost 1 --total 3 --art sand

`data/cards/{id}.tres` を読むので、カードを足せばそのまま使える。まだ .tres が
無い砂時計は --name / --cost / --total / --text / --art で直接指定する。
色と数値の配置はゲーム内のカード(コスト=左上 / 総量=右下)に合わせている。
"""

import argparse
import re
from pathlib import Path

from PIL import Image, ImageDraw, ImageFont

SIZE = (420, 560)
FONT = Path("assets/fonts/ZenKakuGothicNew-Bold.ttf")
CARDS = Path("data/cards")
ART = Path("assets/hourglasses/processed")

SLATE_TOP = (26, 28, 36)
SLATE_BOTTOM = (61, 66, 79)
GLOW_AMBER = (217, 158, 56)
BRASS_HIGHLIGHT = (209, 179, 115)
BRASS_DARK = (84, 56, 41)
TEXT_OFFWHITE = (245, 240, 227)

KEYWORDS = {0: "守護", 1: "硝子", 2: "貫通", 3: "破壊", 4: "回復", 5: "2回攻撃", 6: "速落"}


def read_card(card_id: str) -> dict:
    text = (CARDS / f"{card_id}.tres").read_text(encoding="utf-8")

    def field(name: str, default: str = "") -> str:
        m = re.search(rf'^{name} = "?([^"\n]*)"?$', text, re.M)
        return m.group(1) if m else default

    kw = re.search(r"^keywords = Array\[int\]\(\[([^\]]*)\]\)", text, re.M)
    return {
        "name": field("display_name"),
        "cost": int(field("cost", "0")),
        "total": int(field("total_sand", "0")),
        "text": field("rules_text"),
        "keywords": [int(v) for v in kw.group(1).split(",") if v.strip()] if kw else [],
        "art": card_id,
    }


def panel() -> Image.Image:
    image = Image.new("RGBA", SIZE)
    draw = ImageDraw.Draw(image)
    for y in range(SIZE[1]):
        t = y / (SIZE[1] - 1)
        draw.line([(0, y), (SIZE[0], y)],
                  fill=tuple(int(a + (b - a) * t) for a, b in zip(SLATE_TOP, SLATE_BOTTOM)) + (255,))
    draw.rounded_rectangle([0, 0, SIZE[0] - 1, SIZE[1] - 1], 22, outline=BRASS_DARK, width=7)
    draw.rounded_rectangle([7, 7, SIZE[0] - 8, SIZE[1] - 8], 16, outline=BRASS_HIGHLIGHT, width=2)
    return image


def badge(draw, cx, cy, r, value, fill):
    draw.ellipse([cx - r, cy - r, cx + r, cy + r], fill=fill, outline=BRASS_DARK, width=4)
    font = ImageFont.truetype(str(FONT), int(r * 1.25))
    box = draw.textbbox((0, 0), value, font=font)
    draw.text((cx - (box[2] - box[0]) / 2 - box[0], cy - (box[3] - box[1]) / 2 - box[1]),
              value, font=font, fill=(28, 20, 14))


def main() -> None:
    p = argparse.ArgumentParser(description="砂時計のチラ見せカードを作る")
    p.add_argument("--id", help="data/cards/{id}.tres から読む")
    p.add_argument("--name"); p.add_argument("--cost", type=int); p.add_argument("--total", type=int)
    p.add_argument("--text", default=""); p.add_argument("--art", default="sand")
    p.add_argument("--tease", action="store_true", help="絵をシルエットにし、名前を伏せる")
    p.add_argument("--out", default="assets/mascot/teaser_card.png")
    args = p.parse_args()

    card = read_card(args.id) if args.id else {
        "name": args.name or "???", "cost": args.cost or 0, "total": args.total or 0,
        "text": args.text, "keywords": [], "art": args.art,
    }
    for key in ("name", "cost", "total", "text"):
        if getattr(args, key, None):
            card[key] = getattr(args, key)

    image = panel()
    art = Image.open(ART / card["art"] / "state_full.png").convert("RGBA")
    scale = 300 / art.height
    art = art.resize((int(art.width * scale), 300), Image.LANCZOS)
    if args.tease:
        # 形だけ残して塗り潰す。何が来るかは分からないが「大きさ」は伝わる
        art = Image.merge("RGBA", (*[Image.new("L", art.size, c) for c in (18, 20, 26)],
                                   art.split()[3].point(lambda a: int(a * 0.92))))
    image.alpha_composite(art, ((SIZE[0] - art.width) // 2, 116))

    draw = ImageDraw.Draw(image)
    name_font = ImageFont.truetype(str(FONT), 40)
    small = ImageFont.truetype(str(FONT), 25)

    label = "近日追加" if args.tease else "新しい砂時計"
    box = draw.textbbox((0, 0), label, font=small)
    draw.text(((SIZE[0] - (box[2] - box[0])) / 2, 40), label, font=small, fill=GLOW_AMBER)

    name = "？？？" if args.tease else card["name"]
    box = draw.textbbox((0, 0), name, font=name_font)
    draw.text(((SIZE[0] - (box[2] - box[0])) / 2, 438), name, font=name_font, fill=TEXT_OFFWHITE)

    words = [KEYWORDS.get(k, "?") for k in card["keywords"]]
    caption = "・".join(words) or (card["text"][:16] if card["text"] else "効果なし")
    box = draw.textbbox((0, 0), caption, font=small)
    draw.text(((SIZE[0] - (box[2] - box[0])) / 2, 492), caption, font=small, fill=(180, 178, 172))

    badge(draw, 62, 76, 40, str(card["cost"]), (238, 196, 96))   # コスト = 左上
    badge(draw, SIZE[0] - 62, SIZE[1] - 76, 40, str(card["total"]), (176, 178, 186))  # 総量 = 右下

    Path(args.out).parent.mkdir(parents=True, exist_ok=True)
    image.convert("RGB").save(args.out)
    print(f"書き出しました: {args.out}")


if __name__ == "__main__":
    main()
