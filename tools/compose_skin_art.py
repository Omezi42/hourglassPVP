"""カードスキンの絵を、原本のガラスと砂に生成した枠を重ねて3状態ぶん作る(Architecture.md 10.19節)。

  python tools/compose_skin_art.py template <out.png>
      生成の入力にする雛形を書き出す。原本(上向き)のガラスの内側を緑一色の穴にし、背景をマゼンタにしたもの
  python tools/compose_skin_art.py compose <generated.jpg> <skin_id>
      雛形を元に描かせた絵(マゼンタ背景・緑の穴)から枠だけを抜き、穴の位置と大きさで原本へ合わせて
      assets/hourglasses/skins/<skin_id>/state_{upright,falling,fallen}.png を書く

ガラスと砂は原本そのものを使うため、どのスキンでもガラス玉の大きさ・位置・砂の量は基本の絵と一致し、
枠は3状態で同一になる。キャンバスの高さは落下中の原本(532)に揃える——盤面は3状態で最も高い
キャンバスを基準に縮めるため、高さが違うと基本の絵と縮尺がずれる。
"""

import os
import sys

import numpy as np
from PIL import Image
from scipy import ndimage

MASTER = "assets/hourglasses/master"
SKINS = "assets/hourglasses/skins"
BASE_W = 400
CANVAS_H = 532
UPRIGHT_H = 513
MARGIN = 2
HOLE_GROW = 5  # ガラスの輪郭線まで穴に含める
TEMPLATE_SCALE = 2
STATES = [("full", "state_upright"), ("falling", "state_falling"), ("empty", "state_fallen")]


def _glass(state):
    region = np.asarray(Image.open(f"{MASTER}/region_state_{state}.png").convert("RGBA"))
    return region[..., 2] > 127


def write_template(out_path):
    art = np.asarray(Image.open(f"{MASTER}/state_full.png").convert("RGBA")).astype(np.float32)
    alpha = art[..., 3:4] / 255.0
    magenta = np.array([255, 0, 255], np.float32)
    rgb = (art[..., :3] * alpha + magenta * (1 - alpha)).astype(np.uint8)
    rgb[ndimage.binary_dilation(_glass("full"), iterations=HOLE_GROW)] = (0, 255, 0)
    img = Image.fromarray(rgb)
    img.resize((img.width * TEMPLATE_SCALE, img.height * TEMPLATE_SCALE), Image.NEAREST).save(out_path)


def _key(path):
    """マゼンタの背景と緑の穴を透明にした枠の絵と、穴の外接矩形を返す。"""
    a = np.asarray(Image.open(path).convert("RGB")).astype(np.float32)
    r, g, b = a[..., 0], a[..., 1], a[..., 2]
    mag = np.clip(((r + b) / 2 - g - 60) / 80, 0, 1) * np.clip((np.minimum(r, b) - 120) / 60, 0, 1)
    hole = (g > 180) & (r < 140) & (b < 140)
    lab, n = ndimage.label(hole)
    hole = ndimage.binary_fill_holes(lab == 1 + np.argmax(ndimage.sum(hole, lab, range(1, n + 1))))
    # 緑抜きは穴の周りだけに効かせる(緑の装飾を消さない)
    grn = np.clip((g - np.maximum(r, b) - 60) / 80, 0, 1) * ndimage.binary_dilation(hole, iterations=8)
    r2 = np.where(mag > 0, np.minimum(r, np.maximum(g, (r + g) / 2)), r)
    b2 = np.where(mag > 0, np.minimum(b, np.maximum(g, (b + g) / 2)), b)
    g2 = np.where(grn > 0, np.minimum(g, np.maximum(r2, b2)), g)
    rgba = np.dstack([r2, g2, b2, (1 - mag) * (1 - grn) * 255]).clip(0, 255).astype(np.uint8)
    ys, xs = np.where(hole)
    return Image.fromarray(rgba), (xs.min(), xs.max() + 1, ys.min(), ys.max() + 1)


def compose(gen_path, skin_id):
    glass = _glass("full")
    ys, xs = np.where(ndimage.binary_dilation(glass, iterations=HOLE_GROW))
    mx0, mx1, my0, my1 = xs.min(), xs.max() + 1, ys.min(), ys.max() + 1
    frame_src, (gx0, gx1, gy0, gy1) = _key(gen_path)
    sx, sy = (mx1 - mx0) / (gx1 - gx0), (my1 - my0) / (gy1 - gy0)
    frame_src = frame_src.resize((round(frame_src.width * sx), round(frame_src.height * sy)), Image.LANCZOS)
    top_pad = CANVAS_H - UPRIGHT_H
    ox, oy = mx0 - gx0 * sx, my0 - gy0 * sy + top_pad

    opaque = np.asarray(frame_src)[..., 3] > 40
    lab, n = ndimage.label(opaque)
    sizes = ndimage.sum(opaque, lab, range(1, n + 1))
    opaque = np.isin(lab, 1 + np.where(sizes >= sizes.max() * 0.002)[0])
    yy, xx = np.where(opaque)
    top, bot = yy.min() + oy, yy.max() + oy
    # 下へはみ出す分は持ち上げ、それでも上下に収まらなければ全体を一様に縮める
    lift = max(0, bot - (CANVAS_H - 1 - MARGIN))
    fit = 1.0
    if top - lift < MARGIN:
        fit = min(1.0, (CANVAS_H - 1 - 2 * MARGIN) / (bot - top))
    half = max(BASE_W / 2 - (xx.min() + ox), xx.max() + ox - BASE_W / 2)
    canvas_w = max(BASE_W, int(np.ceil(half * fit + MARGIN)) * 2)
    big_w = max(canvas_w, int(np.ceil(half + MARGIN)) * 2)
    big_h = int(np.ceil(bot - top)) + 2 * MARGIN + 2
    shift_x, shift_y = (big_w - BASE_W) / 2, MARGIN - top
    frame = Image.new("RGBA", (big_w, big_h))
    frame.paste(frame_src, (round(ox + shift_x), round(oy + shift_y)))

    out_dir = f"{SKINS}/{skin_id}"
    os.makedirs(out_dir, exist_ok=True)
    gy, gx = np.where(glass)
    for state, name in STATES:
        src = np.asarray(Image.open(f"{MASTER}/state_{state}.png").convert("RGBA")).copy()
        state_glass = _glass(state)
        src[~ndimage.binary_dilation(state_glass, iterations=HOLE_GROW)] = 0
        y2, x2 = np.where(state_glass)
        dx = (gx.min() + gx.max()) / 2 - (x2.min() + x2.max()) / 2 + shift_x
        dy = gy.max() - y2.max() + top_pad + shift_y
        big = Image.new("RGBA", (big_w, big_h))
        big.paste(Image.fromarray(src), (round(dx), round(dy)))
        big.alpha_composite(frame)
        big = big.resize((round(big_w * fit), round(big_h * fit)), Image.LANCZOS)
        bottom = min(bot - lift, CANVAS_H - 1 - MARGIN)
        py = max(round(bottom - (bot + shift_y) * fit), round(MARGIN - MARGIN * fit))
        out = Image.new("RGBA", (canvas_w, CANVAS_H))
        out.paste(big, (round((canvas_w - big_w * fit) / 2), py), big)
        out.save(f"{out_dir}/{name}.png", optimize=True)
    print(f"{skin_id}: canvas {canvas_w}x{CANVAS_H}, glass scale {fit:.3f}")


if __name__ == "__main__":
    if len(sys.argv) == 3 and sys.argv[1] == "template":
        write_template(sys.argv[2])
    elif len(sys.argv) == 4 and sys.argv[1] == "compose":
        compose(sys.argv[2], sys.argv[3])
    else:
        sys.exit(__doc__)
