#!/usr/bin/env python3
"""更新のお知らせに添える「目玉コンテンツ紹介」画像を作る。

そのビルドで最も伝えたい追加コンテンツ(新カードセット・新ステージ等)を、
実際のカード画像(functions/data/card_art/{id}.png)と一緒に見せるための画像。
バナー(update_banner.png)が「何のバージョンか」を示すのに対し、
こちらは「具体的に何が増えたか」を見せる役目を持つ。両方を1回のお知らせに添える。

カード紹介の例:
    python tools/discord/build_spotlight.py \
        --title "カードセット「五砂の刻」" \
        --subtitle "総量5をねらうコンボ系5枚" \
        --cards middle phase key cycle crest \
        --out tools/discord/out/spotlight.png

カードが無い(ステージ追加など)場合は --cards を省略し、タイトルだけの
バナー的な画像として使う(ただし可能な限りカード画像を伴わせること。
文字だけの告知は目に留まりにくい)。

色は scripts/ui/styles/ui_palette.gd と同じ値を使い、build_update_banner.py と
地続きの見た目にする。カード画像は tools/export_discord_card_art.gd
(非ヘッドレス実行が必要)が焼くもので、無ければ先にそちらを実行すること。
"""

import argparse
from pathlib import Path

from PIL import Image, ImageDraw, ImageFont

FONT = Path("assets/fonts/ZenKakuGothicNew-Bold.ttf")
CARD_ART_DIR = Path("functions/data/card_art")
DEFAULT_OUT = Path("tools/discord/out/spotlight.png")

# ui_palette.gd と同じ値(build_update_banner.py と揃える)
SLATE_TOP = (26, 28, 36)
SLATE_BOTTOM = (61, 66, 79)
BRASS_HIGHLIGHT = (209, 179, 115)
BRASS_DARK = (84, 56, 41)
TEXT_OFFWHITE = (245, 240, 227)
GLOW_AMBER = (217, 158, 56)

CARD_SIZE = (300, 167)  # 720x400を5/12に縮小
CARD_GAP = 18
MARGIN = 36
HEADER_HEIGHT = 120


def background(size: tuple[int, int]) -> Image.Image:
    image = Image.new("RGB", size)
    draw = ImageDraw.Draw(image)
    for y in range(size[1]):
        t = y / max(size[1] - 1, 1)
        draw.line(
            [(0, y), (size[0], y)],
            fill=tuple(int(a + (b - a) * t) for a, b in zip(SLATE_TOP, SLATE_BOTTOM)),
        )
    return image.convert("RGBA")


def frame(image: Image.Image, width: int = 6) -> None:
    draw = ImageDraw.Draw(image)
    w, h = image.size
    draw.rectangle([0, 0, w - 1, h - 1], outline=BRASS_DARK, width=width)
    draw.rectangle(
        [width, width, w - 1 - width, h - 1 - width],
        outline=BRASS_HIGHLIGHT,
        width=2,
    )


def card_frame(image: Image.Image, box: tuple[int, int, int, int]) -> None:
    draw = ImageDraw.Draw(image)
    draw.rectangle(box, outline=GLOW_AMBER, width=3)


def main() -> None:
    parser = argparse.ArgumentParser(description="目玉コンテンツ紹介画像を作る")
    parser.add_argument("--title", required=True, help="見出し(例: カードセット「五砂の刻」)")
    parser.add_argument("--subtitle", default="", help="1行の添え書き")
    parser.add_argument("--cards", nargs="*", default=[], help="紹介するカードのid(最大5枚推奨)")
    parser.add_argument("--out", default=str(DEFAULT_OUT))
    args = parser.parse_args()

    cards = args.cards[:6]
    art_paths = []
    missing = []
    for card_id in cards:
        p = CARD_ART_DIR / f"{card_id}.png"
        if p.exists():
            art_paths.append((card_id, p))
        else:
            missing.append(card_id)
    if missing:
        print(f"警告: カード画像が見つからない ({', '.join(missing)})。"
              f" 先に tools/export_discord_card_art.gd を実行すること")

    cols = min(len(art_paths), 3) if art_paths else 1
    rows = -(-len(art_paths) // cols) if art_paths else 0
    grid_w = cols * CARD_SIZE[0] + (cols - 1) * CARD_GAP if art_paths else 0
    grid_h = rows * CARD_SIZE[1] + (rows - 1) * CARD_GAP if art_paths else 0

    width = max(grid_w + MARGIN * 2, 720)
    height = HEADER_HEIGHT + (grid_h + MARGIN if art_paths else MARGIN // 2) + MARGIN

    image = background((width, height))
    draw = ImageDraw.Draw(image)

    title_font = ImageFont.truetype(str(FONT), 44)
    subtitle_font = ImageFont.truetype(str(FONT), 24)

    top = 28
    draw.text((MARGIN, top), args.title, font=title_font, fill=TEXT_OFFWHITE)
    top += (draw.textbbox((MARGIN, top), args.title, font=title_font)[3] - top) + 8
    if args.subtitle:
        draw.text((MARGIN, top), args.subtitle, font=subtitle_font, fill=GLOW_AMBER)

    # カードを中央寄せで並べる
    grid_x = (width - grid_w) // 2
    grid_y = HEADER_HEIGHT
    for i, (card_id, path) in enumerate(art_paths):
        col = i % cols
        row = i // cols
        x = grid_x + col * (CARD_SIZE[0] + CARD_GAP)
        y = grid_y + row * (CARD_SIZE[1] + CARD_GAP)
        art = Image.open(path).convert("RGBA").resize(CARD_SIZE, Image.LANCZOS)
        image.alpha_composite(art, (x, y))
        card_frame(image, (x, y, x + CARD_SIZE[0] - 1, y + CARD_SIZE[1] - 1))

    frame(image)

    out_path = Path(args.out)
    out_path.parent.mkdir(parents=True, exist_ok=True)
    image.convert("RGB").save(out_path)
    print(f"書き出し: {out_path}")


if __name__ == "__main__":
    main()
