#!/usr/bin/env python3
"""マスコットの絵を、既存の砂時計のイラストへ描き足して作る。

新しく絵を起こさず `assets/hourglasses/processed/sand/state_full.png` を土台に
使うため、ゲーム内の見た目とマスコットが必ず一致する。描き足すのは
「羽・天使の輪・顔」の3つだけで、いずれも手続き的に描く(UIをコードで描く
方針と同じ考え方)。

    python tools/build_mascot.py

出力: assets/mascot/mascot.png (透過) と mascot_avatar.png (Discord用の正方形)
"""

from pathlib import Path

from PIL import Image, ImageDraw, ImageFilter

BASE = Path("assets/hourglasses/processed/sand/state_full.png")
OUT_DIR = Path("assets/mascot")

# 描画はアンチエイリアスのため4倍で行い、最後に縮小する(PILの描画にAAが無いため)
SS = 4
CANVAS = (840, 640)
# 砂時計(400x513)を置く位置。左右は羽、上は輪のための余白。
BASE_POS = (220, 105)

INK = (42, 30, 24, 255)  # 元絵の輪郭と同系の濃い茶
WING_FILL = (255, 253, 247, 255)
WING_EDGE = (92, 64, 45, 255)  # 元絵と同じ太く濃い輪郭に合わせる
HALO_GOLD = (232, 184, 75, 255)
HALO_CORE = (247, 223, 150, 255)
BLUSH = (240, 150, 138, 105)


def _ellipse(draw, cx, cy, rx, ry, fill=None, outline=None, width=1):
    draw.ellipse(
        [(cx - rx) * SS, (cy - ry) * SS, (cx + rx) * SS, (cy + ry) * SS],
        fill=fill,
        outline=outline,
        width=width * SS,
    )


def _layer():
    return Image.new("RGBA", (CANVAS[0] * SS, CANVAS[1] * SS), (0, 0, 0, 0))


def _rot_ellipse(layer, cx, cy, rx, ry, angle):
    """傾けた羽根を1枚描く。PILの描画は回転できないため、別レイヤーで回して貼る。"""
    pad = 24
    w, h = int(rx * 2 * SS) + pad * 2, int(ry * 2 * SS) + pad * 2
    tmp = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    ImageDraw.Draw(tmp).ellipse(
        [pad, pad, w - pad, h - pad], fill=WING_FILL, outline=WING_EDGE, width=4 * SS
    )
    tmp = tmp.rotate(angle, resample=Image.BICUBIC, expand=True)
    layer.alpha_composite(tmp, (int(cx * SS - tmp.width / 2), int(cy * SS - tmp.height / 2)))


def draw_wings() -> Image.Image:
    """砂時計の後ろへ回す羽。羽根を外へ向かって扇状に広げる。"""
    layer = _layer()
    cx = CANVAS[0] / 2
    # (中心からの横のずれ, 縦位置, 横半径, 縦半径, 傾き)
    feathers = [
        (118, 300, 96, 40, 16),
        (156, 244, 90, 36, 32),
        (180, 184, 76, 31, 48),
        (190, 130, 58, 25, 64),
    ]
    for side in (-1, 1):
        for dx, cy, rx, ry, angle in feathers:
            _rot_ellipse(layer, cx + side * dx, cy, rx, ry, angle * side)
    return layer


def draw_halo() -> Image.Image:
    layer = _layer()
    draw = ImageDraw.Draw(layer)
    cx, cy = CANVAS[0] / 2, 58
    _ellipse(draw, cx, cy, 78, 21, outline=HALO_GOLD, width=13)
    _ellipse(draw, cx, cy, 78, 21, outline=HALO_CORE, width=5)
    return layer


def draw_face() -> Image.Image:
    """下のガラス玉に顔を置く。低い位置に目があるほど幼く見える。

    口は描かない。目とほっぺだけのほうが表情が固定されず、砂時計という
    物体のままでいられる。
    """
    layer = _layer()
    draw = ImageDraw.Draw(layer)
    cx, cy = CANVAS[0] / 2, 452

    for side in (-1, 1):
        ex = cx + side * 44
        _ellipse(draw, ex, cy, 17, 21, fill=INK)
        _ellipse(draw, ex - 5, cy - 7, 5.5, 6.5, fill=(255, 255, 255, 255))
        _ellipse(draw, cx + side * 88, cy + 20, 20, 12, fill=BLUSH)

    return layer


def main() -> None:
    base = Image.open(BASE).convert("RGBA")
    canvas = Image.new("RGBA", CANVAS, (0, 0, 0, 0))

    wings = draw_wings().resize(CANVAS, Image.LANCZOS)
    canvas.alpha_composite(wings)
    canvas.alpha_composite(base, BASE_POS)
    for layer in (draw_halo(), draw_face()):
        canvas.alpha_composite(layer.resize(CANVAS, Image.LANCZOS))

    OUT_DIR.mkdir(parents=True, exist_ok=True)
    canvas.save(OUT_DIR / "mascot.png")

    # Discordのアイコンは円形に切り抜かれる。羽の先が欠けないよう内接円へ収める。
    side = 512
    fit = 0.94
    scale = min(side * fit / CANVAS[0], side * fit / CANVAS[1])
    small = canvas.resize((int(CANVAS[0] * scale), int(CANVAS[1] * scale)), Image.LANCZOS)
    avatar = Image.new("RGBA", (side, side), (0, 0, 0, 0))
    avatar.alpha_composite(small, ((side - small.width) // 2, (side - small.height) // 2))
    avatar.save(OUT_DIR / "mascot_avatar.png")

    # 円形に切ったときの見え方を確認するための控え(投稿には使わない)
    mask = Image.new("L", (side, side), 0)
    ImageDraw.Draw(mask).ellipse([0, 0, side - 1, side - 1], fill=255)
    preview = Image.new("RGBA", (side, side), (54, 57, 63, 255))
    preview.paste(avatar, (0, 0), avatar)
    preview.putalpha(mask)
    preview.save(OUT_DIR / "mascot_avatar_circle_preview.png")

    print(f"書き出しました: {OUT_DIR/'mascot.png'} / {OUT_DIR/'mascot_avatar.png'}")


if __name__ == "__main__":
    main()
