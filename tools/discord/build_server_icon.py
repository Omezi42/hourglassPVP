#!/usr/bin/env python3
"""Discordサーバーのアイコン(512x512)を作る。

    python tools/discord/build_server_icon.py

ホーム画面の背景に砂時計の絵を立てる。Discordは同じアイコンを円と角丸の両方で
切り抜くため、縁は描かず、絵は円の内側に収める。色は scripts/ui/styles/ui_palette.gd と同じ値。
"""

from pathlib import Path

from PIL import Image, ImageChops, ImageDraw, ImageFilter

SIZE = 512
BACKGROUND = Path("assets/backgrounds/processed/home/background.png")
HOURGLASS = Path("assets/hourglasses/master/state_falling.png")
OUT = Path("tools/discord/out/server_icon.png")

SLATE_TOP = (26, 28, 36)
GLOW_AMBER = (217, 158, 56)

# 背景を沈めて砂時計を浮かせる度合い
BACKGROUND_DIM = 0.35
GLOW_RADIUS = 170
GLOW_STRENGTH = 0.45
HOURGLASS_HEIGHT = 380
HOURGLASS_OFFSET_Y = 6
SHADOW_OFFSET = (6, 10)
SHADOW_OPACITY = 0.55
SHADOW_BLUR = 10


def background() -> Image.Image:
    bg = Image.open(BACKGROUND).convert("RGB")
    side = bg.height
    left = (bg.width - side) // 2
    image = bg.crop((left, 0, left + side, side)).resize((SIZE, SIZE), Image.LANCZOS)
    return Image.blend(image, Image.new("RGB", image.size, SLATE_TOP), BACKGROUND_DIM)


def glow(image: Image.Image) -> Image.Image:
    layer = Image.new("RGB", image.size)
    cx, cy = SIZE // 2, SIZE // 2 + HOURGLASS_OFFSET_Y * 3
    ImageDraw.Draw(layer).ellipse(
        [cx - GLOW_RADIUS, cy - GLOW_RADIUS, cx + GLOW_RADIUS, cy + GLOW_RADIUS],
        fill=GLOW_AMBER,
    )
    layer = layer.filter(ImageFilter.GaussianBlur(GLOW_RADIUS * 0.45))
    return ImageChops.add(image, Image.eval(layer, lambda v: int(v * GLOW_STRENGTH)))


def hourglass(image: Image.Image) -> Image.Image:
    src = Image.open(HOURGLASS).convert("RGBA")
    width = round(src.width * HOURGLASS_HEIGHT / src.height)
    src = src.resize((width, HOURGLASS_HEIGHT), Image.LANCZOS)
    x = (SIZE - width) // 2
    y = SIZE // 2 + HOURGLASS_OFFSET_Y - HOURGLASS_HEIGHT // 2
    base = image.convert("RGBA")
    shadow = Image.new("RGBA", base.size, (0, 0, 0, 0))
    alpha = src.split()[3].point(lambda a: int(a * SHADOW_OPACITY))
    shadow.paste((0, 0, 0, 255), (x + SHADOW_OFFSET[0], y + SHADOW_OFFSET[1]), alpha)
    base = Image.alpha_composite(base, shadow.filter(ImageFilter.GaussianBlur(SHADOW_BLUR)))
    base.alpha_composite(src, (x, y))
    return base.convert("RGB")


def main() -> None:
    image = hourglass(glow(background()))
    OUT.parent.mkdir(parents=True, exist_ok=True)
    image.save(OUT)
    print(OUT)


if __name__ == "__main__":
    main()
