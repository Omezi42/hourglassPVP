"""砂時計の絵は全種が1枚(sand)の色違いである。
各idを sand から作るための色変換の数値を求め、現行のPNGと突き合わせて誤差を報告する。

変換1段ぶんの定義(1画素ごとに独立):
    s < threshold の画素は触らない(無彩色のガラスと輪郭を色付けしないため)
    h' = h + hue
    s' = clamp(max(s * sat + sat_bias, floor), 0, 1)
    v' = clamp(v * value + value_bias, 0, 1)

sand から直接作られた40種は tint_hourglass_icons.gd が持つ数値がそのまま正解になる。
元絵とされていた9種(shield/dash/sword/echo/eye/mirror/wall/judge/king)だけは
作られた経緯の記録が無いため、現行のPNGから逆算する。
それらを親に持つ8種は「逆算した1段目 + 既知の2段目」として合成する。

使い方:
    python tools/fit_hourglass_tints.py            … 当てはめと誤差の報告
    python tools/fit_hourglass_tints.py --write    … tools/hourglass_tints.json へ書き出す
"""

import json
import os
import re
import sys

import numpy as np
from PIL import Image

PROCESSED = "assets/hourglasses/processed"
TINT_SCRIPT = "tools/tint_hourglass_icons.gd"
MASTER = "sand"
STATES = ["state_full", "state_falling", "state_empty"]
IDENTITY = {"hue": 0.0, "sat": 1.0, "sat_bias": 0.0, "floor": 0.0, "value": 1.0, "value_bias": 0.0, "threshold": 0.0}


def load_rgba(card_id, state):
    path = os.path.join(PROCESSED, card_id, state + ".png")
    return np.asarray(Image.open(path).convert("RGBA"), dtype=np.float64) / 255.0


def rgb_to_hsv(rgb):
    r, g, b = rgb[..., 0], rgb[..., 1], rgb[..., 2]
    mx = rgb[..., :3].max(axis=-1)
    mn = rgb[..., :3].min(axis=-1)
    d = mx - mn
    h = np.zeros_like(mx)
    m = d > 1e-12
    rm = m & (mx == r)
    gm = m & (mx == g) & ~rm
    bm = m & ~rm & ~gm
    h[rm] = ((g[rm] - b[rm]) / d[rm]) % 6.0
    h[gm] = (b[gm] - r[gm]) / d[gm] + 2.0
    h[bm] = (r[bm] - g[bm]) / d[bm] + 4.0
    h /= 6.0
    s = np.where(mx > 0, d / np.maximum(mx, 1e-12), 0.0)
    return h, s, mx


def hsv_to_rgb(h, s, v):
    i = np.floor(h * 6.0)
    f = h * 6.0 - i
    p = v * (1.0 - s)
    q = v * (1.0 - f * s)
    t = v * (1.0 - (1.0 - f) * s)
    i = (i % 6).astype(int)
    return np.stack(
        [
            np.choose(i, [v, q, p, p, t, v]),
            np.choose(i, [t, v, v, q, p, p]),
            np.choose(i, [p, p, t, v, v, q]),
        ],
        axis=-1,
    )


def apply_step(h, s, v, p):
    touched = s >= p["threshold"]
    s2 = np.where(touched, np.clip(np.maximum(s * p["sat"] + p["sat_bias"], p["floor"]), 0.0, 1.0), s)
    v2 = np.where(touched, np.clip(v * p["value"] + p["value_bias"], 0.0, 1.0), v)
    h2 = np.where(touched, (h + p["hue"]) % 1.0, h)
    return h2, s2, v2


def apply_chain(h, s, v, chain):
    for step in chain:
        h, s, v = apply_step(h, s, v, step)
    return h, s, v


def known_variants():
    """tint_hourglass_icons.gd の VARIANTS をそのまま読む(数値を二重に持たないため)。"""
    text = open(TINT_SCRIPT, encoding="utf-8").read()
    body = text.split("const VARIANTS: Array = [", 1)[1].split("\n]", 1)[0]
    out = {}
    for line in body.splitlines():
        m = re.match(r'\s*\["([^"]+)", "([^"]+)", ([\d.]+), ([\d.]+), ([\d.]+), ([\d.]+)\]', line)
        if not m:
            continue
        new_id, src, hue, sat, threshold, floor = m.groups()
        out[new_id] = (
            src,
            {
                "hue": float(hue),
                "sat": float(sat),
                "sat_bias": 0.0,
                "floor": float(floor),
                "value": 1.0,
                "value_bias": 0.0,
                "threshold": float(threshold),
            },
        )
    return out


def fit_step(card_id):
    """sand → card_id を1段の変換として逆算する。"""
    src = load_rgba(MASTER, "state_full")
    dst = load_rgba(card_id, "state_full")
    mask = (src[..., 3] > 0.99) & (dst[..., 3] > 0.99)
    h1, s1, v1 = (a[mask] for a in rgb_to_hsv(src))
    target = dst[..., :3][mask]
    step = max(1, h1.size // 5000)
    h1, s1, v1, target = h1[::step], s1[::step], v1[::step], target[::step]

    best = None
    for threshold in (0.02, 0.04, 0.08, 0.12, 0.18):
        colored = s1 >= threshold
        if colored.sum() < 100:
            continue
        dh = ((rgb_to_hsv(dst)[0][mask][::step][colored] - h1[colored]) % 1.0) * 2.0 * np.pi
        p = dict(IDENTITY)
        p["threshold"] = threshold
        p["hue"] = float((np.arctan2(np.sin(dh).mean(), np.cos(dh).mean()) / (2.0 * np.pi)) % 1.0)

        def err_of(cand):
            hh, ss, vv = apply_step(h1, s1, v1, cand)
            return float(np.abs(hsv_to_rgb(hh, ss, vv) - target).mean())

        span = {"hue": 0.06, "sat": 0.5, "sat_bias": 0.2, "floor": 0.3, "value": 0.3, "value_bias": 0.15}
        for round_index in range(7):
            shrink = 0.5**round_index
            for name in ("hue", "sat", "value", "sat_bias", "value_bias", "floor"):
                grid = np.linspace(p[name] - span[name] * shrink, p[name] + span[name] * shrink, 17)
                scores = []
                for g in grid:
                    cand = dict(p)
                    cand[name] = float(g)
                    scores.append(err_of(cand))
                p[name] = float(grid[int(np.argmin(scores))])
                if name == "hue":
                    p["hue"] %= 1.0
                if name == "floor":
                    p["floor"] = max(0.0, p["floor"])
        score = err_of(p)
        if best is None or score < best[0]:
            best = (score, p)
    return best[1]


def verify(card_id, chain):
    worst_mean = 0.0
    worst_max = 0.0
    for state in STATES:
        src = load_rgba(MASTER, state)
        dst = load_rgba(card_id, state)
        h1, s1, v1 = rgb_to_hsv(src)
        got = hsv_to_rgb(*apply_chain(h1, s1, v1, chain))
        mask = (src[..., 3] > 0.99) & (dst[..., 3] > 0.99)
        err = np.abs(got - dst[..., :3])[mask]
        worst_mean = max(worst_mean, float(err.mean() * 255.0))
        worst_max = max(worst_max, float(err.max() * 255.0))
    return worst_mean, worst_max


def main():
    ids = sorted(d for d in os.listdir(PROCESSED) if os.path.isdir(os.path.join(PROCESSED, d)))
    variants = known_variants()
    bases = [i for i in ids if i != MASTER and i not in variants]

    chains = {MASTER: []}
    for base in bases:
        chains[base] = [fit_step(base)]
    for _ in range(3):  # 親が先に決まるまで畳む
        for card_id, (src, step) in variants.items():
            if src in chains and card_id not in chains:
                chains[card_id] = chains[src] + [step]

    rows = []
    for card_id in ids:
        if card_id == MASTER:
            continue
        mean_err, max_err = verify(card_id, chains[card_id])
        kind = "逆算" if card_id in bases else ("既知" if len(chains[card_id]) == 1 else "合成")
        rows.append((card_id, kind, len(chains[card_id]), mean_err, max_err))

    rows.sort(key=lambda r: -r[3])
    print("%-9s %-4s %2s | %8s %8s" % ("id", "由来", "段", "平均誤差", "最大誤差"))
    for card_id, kind, depth, mean_err, max_err in rows:
        print("%-9s %-4s %2d | %8.2f %8.2f" % (card_id, kind, depth, mean_err, max_err))
    print("\n最悪の平均誤差 %.2f / 255   最悪の最大誤差 %.2f / 255" % (max(r[3] for r in rows), max(r[4] for r in rows)))

    if "--write" in sys.argv:
        flat = {}
        for card_id, chain in chains.items():
            src = load_rgba(MASTER, "state_full")
            flat[card_id] = chain
        with open("tools/hourglass_tints.json", "w", encoding="utf-8") as f:
            json.dump(flat, f, ensure_ascii=False, indent=2, sort_keys=True)
        print("書き出しました: tools/hourglass_tints.json")


if __name__ == "__main__":
    main()
