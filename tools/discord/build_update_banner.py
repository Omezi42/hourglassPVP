#!/usr/bin/env python3
"""更新のお知らせに添えるバナーを作る。

    python tools/discord/build_update_banner.py 2026.08.30
    python tools/discord/build_update_banner.py 2026.08.30 --subtitle "対局の演出を作り直しました"

色は scripts/ui/styles/ui_palette.gd と同じ値を使う。ゲームの画面と地続きに
見せるため、単色ではなくグラデーション＋グレインを掛ける(UIをコードで描く
方針と同じ考え方)。すなえるの絵は tools/build_mascot.py の出力を読む。
"""

import argparse
import random
from pathlib import Path

from PIL import Image, ImageDraw, ImageFont

SIZE = (960, 320)
FONT = Path("assets/fonts/ZenKakuGothicNew-Bold.ttf")
MASCOT = Path("assets/mascot/mascot.png")
OUT = Path("assets/mascot/update_banner.png")

# ui_palette.gd の値をそのまま持ってくる
SLATE_TOP = (26, 28, 36)
SLATE_BOTTOM = (61, 66, 79)
GLOW_AMBER = (217, 158, 56)
BRASS_HIGHLIGHT = (209, 179, 115)
BRASS_DARK = (84, 56, 41)
TEXT_OFFWHITE = (245, 240, 227)


def background() -> Image.Image:
    image = Image.new("RGB", SIZE)
    draw = ImageDraw.Draw(image)
    for y in range(SIZE[1]):
        t = y / (SIZE[1] - 1)
        draw.line(
            [(0, y), (SIZE[0], y)],
            fill=tuple(int(a + (b - a) * t) for a, b in zip(SLATE_TOP, SLATE_BOTTOM)),
        )
    # グレイン。無地のままだと平坦でチープに見える
    rng = random.Random(42)
    noise = Image.new("L", (SIZE[0] // 2, SIZE[1] // 2))
    noise.putdata([rng.randint(0, 255) for _ in range(noise.width * noise.height)])
    image = Image.blend(image, Image.merge("RGB", [noise.resize(SIZE)] * 3), 0.055)
    return image.convert("RGBA")


def frame(image: Image.Image) -> None:
    draw = ImageDraw.Draw(image)
    draw.rectangle([0, 0, SIZE[0] - 1, SIZE[1] - 1], outline=BRASS_DARK, width=6)
    draw.rectangle([6, 6, SIZE[0] - 7, SIZE[1] - 7], outline=BRASS_HIGHLIGHT, width=2)


def main() -> None:
    parser = argparse.ArgumentParser(description="更新のお知らせ用のバナーを作る")
    parser.add_argument("version", help="表示するバージョン(例 2026.08.30)")
    parser.add_argument("--subtitle", default="", help="1行の添え書き")
    parser.add_argument("--out", default=str(OUT))
    args = parser.parse_args()

    image = background()

    mascot = Image.open(MASCOT).convert("RGBA")
    scale = (SIZE[1] - 44) / mascot.height
    mascot = mascot.resize((int(mascot.width * scale), int(mascot.height * scale)), Image.LANCZOS)
    image.alpha_composite(mascot, (34, (SIZE[1] - mascot.height) // 2))

    draw = ImageDraw.Draw(image)
    x = 34 + mascot.width + 30
    title = ImageFont.truetype(str(FONT), 68)
    version = ImageFont.truetype(str(FONT), 44)
    small = ImageFont.truetype(str(FONT), 26)

    # 位置は決め打ちにせず、実際の文字の高さから積み上げる(重なりを防ぐ)
    def put(text, font, fill, top, gap=0):
        draw.text((x, top), text, font=font, fill=fill)
        return top + (draw.textbbox((x, top), text, font=font)[3] - top) + gap

    y = 40
    y = put("砂時計アリーナ", small, GLOW_AMBER, y, gap=10)
    y = put("アップデート", title, TEXT_OFFWHITE, y, gap=16)
    draw.line([(x, y), (SIZE[0] - 48, y)], fill=BRASS_DARK, width=2)
    y = put(args.version, version, GLOW_AMBER, y + 14, gap=10)
    if args.subtitle:
        put(args.subtitle, small, (178, 176, 170), y)

    frame(image)
    Path(args.out).parent.mkdir(parents=True, exist_ok=True)
    image.convert("RGB").save(args.out)
    print(f"書き出しました: {args.out}")


if __name__ == "__main__":
    main()
