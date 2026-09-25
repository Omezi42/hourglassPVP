"""効果音をすべてコードで合成し assets/sfx/ へ書き出す(GameDesign.md 9章)。

自作の音なのでライセンス管理が要らない。出力は 44.1kHz / 16bit / モノラルの WAV。
音量は種類ごとの目標ラウドネス(finish() の第3引数)へ揃える。乱数の種は音の名前から決めるため、
何度実行しても同じ音になり、1つを直しても他の音は変わらない。

    python tools/build_sfx.py
"""
import os
import zlib
import sys
import numpy as np
import soundfile as sf
from scipy import signal

SR = 44100
RNG = np.random.default_rng(42)
OUT = sys.argv[1] if len(sys.argv) > 1 else os.path.join(os.path.dirname(__file__), "..", "assets", "sfx")


def t_axis(dur):
    return np.arange(int(SR * dur)) / SR


def env(dur, attack, decay):
    t = t_axis(dur)
    a = np.clip(t / max(attack, 1e-4), 0, 1)
    a = np.sin(a * np.pi / 2) ** 2
    return a * np.exp(-t / decay)


def modal(dur, modes, attack=0.001):
    """減衰する正弦波の和。(周波数, 振幅, 減衰時定数) の並び。木・硝子・真鍮の打撃音の骨格。"""
    t = t_axis(dur)
    out = np.zeros_like(t)
    for f, a, d in modes:
        ph = RNG.uniform(0, 2 * np.pi)
        out += a * np.sin(2 * np.pi * f * t + ph) * np.exp(-t / d)
    return out * env(dur, attack, 1e9)


def sweep_sine(dur, f0, f1, decay, attack=0.002):
    t = t_axis(dur)
    f = f1 + (f0 - f1) * np.exp(-t / (dur / 4))
    ph = 2 * np.pi * np.cumsum(f) / SR
    return np.sin(ph) * env(dur, attack, decay)


def noise(dur, lo, hi, order=2):
    n = RNG.standard_normal(int(SR * dur))
    sos = signal.butter(order, [lo, hi], btype="band", fs=SR, output="sos")
    return signal.sosfilt(sos, n)


def lowpass(x, fc, order=2):
    return signal.sosfilt(signal.butter(order, fc, fs=SR, output="sos"), x)


def highpass(x, fc, order=2):
    return signal.sosfilt(signal.butter(order, fc, btype="high", fs=SR, output="sos"), x)


def pad(x, dur):
    n = int(SR * dur)
    return np.pad(x, (0, max(0, n - len(x))))[:n]


def at(buf, x, time):
    i = int(SR * time)
    end = min(len(buf), i + len(x))
    buf[i:end] += x[: end - i]
    return buf


def grains(dur, rate, lo, hi, grain_decay=0.004, shape=None):
    """砂粒・破片のような、まばらな小さな粒の連なり。shape は時間に対する密度。"""
    n = int(SR * dur)
    out = np.zeros(n)
    t = np.arange(n) / SR
    dens = shape(t) if shape else np.ones(n)
    prob = rate / SR * dens
    hits = np.nonzero(RNG.random(n) < prob)[0]
    g = int(SR * grain_decay * 6)
    gt = np.arange(g) / SR
    for h in hits:
        f = RNG.uniform(lo, hi)
        a = RNG.uniform(0.3, 1.0) * dens[h]
        piece = a * np.sin(2 * np.pi * f * gt) * np.exp(-gt / grain_decay)
        at(out, piece, h / SR)
    return out


def fade_tail(x, ms=15):
    n = int(SR * ms / 1000)
    x = x.copy()
    x[-n:] *= np.linspace(1, 0, n) ** 2
    return x


def loudness_db(x):
    """短時間(50ms)の最大RMS。低域の聞こえにくさを粗く補うため150Hzの高域通過を掛けて測る。"""
    y = highpass(x, 150)
    w = int(SR * 0.05)
    if len(y) <= w:
        return 20 * np.log10(np.sqrt((y ** 2).mean()) + 1e-12)
    ms = np.convolve(y ** 2, np.ones(w) / w, "valid")
    return 10 * np.log10(ms.max() + 1e-12)


def finish(name, make, target_db):
    global RNG
    RNG = np.random.default_rng(zlib.crc32(name.encode()))
    x = make()
    x = fade_tail(x - x.mean())
    x *= 10 ** ((target_db - loudness_db(x)) / 20)
    peak = np.abs(x).max()
    if peak > 0.89:  # -1dBFS を越えたら、音量より歪まないことを優先する
        x *= 0.89 / peak
    sf.write(os.path.join(OUT, name + ".wav"), x.astype(np.float32), SR, subtype="PCM_16")
    print(f"{name:14s} {len(x)/SR:5.2f}s  loud={loudness_db(x):6.1f}dB  peak={20*np.log10(np.abs(x).max()):5.1f}dB")


# ---- UI ----

def ui_hover():
    """木片に軽く触れた小さな「こつ」。低めで丸く、立ち上がりのクリック感を残さない。"""
    d = 0.06
    x = modal(d, [(620, 1.0, 0.020), (1480, 0.35, 0.010), (2610, 0.12, 0.006)], attack=0.003)
    return lowpass(x, 3000)


def click(d, modes, tick_amp, thump_amp):
    """音程感の無い短い打撃。高めの非整数倍の響き + 一瞬の雑音 + ごく短い低音の芯。"""
    x = modal(d, modes, attack=0.0004)
    tick = noise(0.008, 2500, 9000) * env(0.008, 0.0002, 0.0012)
    thump = modal(d, [(140, 1.0, 0.008)], attack=0.0006)
    return x + tick_amp * pad(tick, d) + thump_amp * thump


def ui_press():
    """釦を押し込み、留め金が掛かる「カチッ」の2段。音程を下げず響きを短く詰め、間延びさせない。"""
    d = 0.09
    x = np.zeros(int(SR * d))
    at(x, 0.45 * click(0.05, [(1900, 1, .006), (3300, .5, .004)], 0.6, 0.3), 0.0)
    at(x, click(0.07, [(2150, 1, .009), (3550, .55, .006), (5300, .25, .004)], 0.8, 0.5), 0.018)
    return lowpass(x, 11000)


# ---- 対局 ----

def glass_clink(d, base, amp=1.0, decay=0.25):
    ratios = [1.0, 2.32, 4.25, 6.63]
    return modal(d, [(base * r, amp * a, decay * k) for r, a, k in zip(ratios, [1, .5, .28, .12], [1, .6, .35, .2])])


def place():
    """砂時計を卓へ置く「ことん」。木の卓の鈍い胴鳴り + 硝子の小さな響き + こぼれる砂を少し。"""
    d = 0.5
    thud = sweep_sine(d, 150, 95, 0.06, attack=0.001)
    table = modal(d, [(310, 0.8, 0.06), (720, 0.4, 0.035), (1260, 0.2, 0.02)], attack=0.0008)
    glass = glass_clink(d, 2350, 0.12, 0.18)
    sand = grains(0.25, 900, 3000, 9000, 0.0015, shape=lambda t: np.exp(-t / 0.08))
    x = thud + table + glass + 0.15 * pad(sand, d)
    return lowpass(x, 9000)


def flip():
    """砂時計を返す。硝子が回る短い擦れ + 砂がさらさら流れ始める音 + 着地の小さな「こと」。"""
    d = 0.6
    x = np.zeros(int(SR * d))
    swirl = noise(0.22, 1200, 4500) * env(0.22, 0.12, 0.05)
    at(x, 0.35 * swirl, 0.0)
    sand = grains(0.45, 2600, 2500, 10000, 0.0012, shape=lambda t: np.clip(t / 0.08, 0, 1) * np.exp(-t / 0.18))
    at(x, 0.5 * sand, 0.05)
    at(x, 0.7 * modal(0.3, [(430, 1.0, 0.04), (1100, 0.4, 0.02)], attack=0.001), 0.17)
    at(x, 0.18 * glass_clink(0.35, 2800, 1.0, 0.12), 0.17)
    return lowpass(x, 11000)


def clash():
    """砂時計どうしがぶつかる「かきん」。2つの硝子が同時に鳴り、わずかにうなる。"""
    d = 0.75
    x = glass_clink(d, 1760, 1.0, 0.32) + glass_clink(d, 1810, 0.8, 0.28)
    hit = noise(0.03, 1500, 9000) * env(0.03, 0.0005, 0.005)
    body = sweep_sine(d, 220, 140, 0.05, attack=0.001)
    x = 0.55 * x + 0.5 * pad(hit, d) + 0.6 * body
    return lowpass(x, 10000)


def damage():
    """本体への打撃「どすっ」。重い低音と、鈍く割れる音。"""
    d = 0.5
    boom = sweep_sine(d, 120, 55, 0.11, attack=0.001)
    crunch = noise(0.12, 300, 2500) * env(0.12, 0.001, 0.03)
    crack = grains(0.12, 500, 1500, 4000, 0.003, shape=lambda t: np.exp(-t / 0.04))
    x = boom + 0.45 * pad(crunch, d) + 0.25 * pad(crack, d)
    return lowpass(x, 6000)


def shatter(d, lo, hi, rate, weight):
    x = np.zeros(int(SR * d))
    burst = noise(0.06, 1500, 12000) * env(0.06, 0.0005, 0.012)
    at(x, 0.5 * burst, 0.0)
    shards = grains(d, rate, lo, hi, 0.02, shape=lambda t: np.exp(-t / (d / 4)))
    at(x, 0.45 * shards, 0.004)
    if weight > 0:
        at(x, weight * sweep_sine(0.35, 110, 60, 0.07), 0.0)
    return x


def unit_break():
    """砂時計が割れて崩れる。低い衝撃 + 破片が散る音 + こぼれる砂。"""
    d = 1.0
    x = shatter(d, 1800, 7000, 90, 0.9)
    spill = grains(0.7, 1800, 2000, 9000, 0.0012, shape=lambda t: np.clip(t / 0.1, 0, 1) * np.exp(-t / 0.25))
    at(x, 0.35 * spill, 0.12)
    return lowpass(x, 11000)


def glass_break():
    """硝子の膜が割れる。高く軽い、澄んだ破片だけ。本体は無事なので低音を持たない。"""
    d = 0.6
    x = shatter(d, 3500, 11000, 70, 0.0)
    at(x, 0.25 * glass_clink(0.5, 3100, 1.0, 0.18), 0.0)
    return highpass(lowpass(x, 13000), 900)


def poison_melt():
    """毒砂で溶ける「じゅわっ」。膨らんでしぼむ泡立ちの擦れ + 弾ける小さな泡 + 低く沈む音。硝子の破片は持たない。"""
    d = 0.9
    x = np.zeros(int(SR * d))
    fizz = noise(d, 700, 4500) * env(d, 0.08, 0.22)
    at(x, 0.5 * fizz, 0.0)
    for i in range(9):
        pop = sweep_sine(0.04, 320 + 60 * i, 900 + 80 * i, 0.012, attack=0.001)
        at(x, RNG.uniform(0.25, 0.5) * pop, 0.05 + RNG.uniform(0, 0.6))
    at(x, 0.7 * sweep_sine(0.5, 240, 80, 0.12, attack=0.01), 0.04)
    return lowpass(x, 6000)


## 器が割れる位置(秒)。`HpVesselFx` の BURST_AT(0.4)× SHATTER_DURATION(0.8)に合わせる。
VESSEL_BURST_AT = 0.32


def vessel_shatter():
    """HPの器が砕ける。ぴし、ぴしぴしとひびが走り、割れて破片と砂が散る。駒の破壊より重く長い。"""
    d = 1.5
    x = np.zeros(int(SR * d))
    for i, time in enumerate([0.0, 0.12, 0.2, 0.25, 0.28, 0.305]):
        tick = noise(0.01, 2500, 10000) * env(0.01, 0.0002, 0.0015)
        ring = glass_clink(0.08, 2600 + 250 * i, 0.5, 0.03)
        at(x, (0.35 + 0.1 * i) * (pad(tick, 0.08) + ring), time)
    at(x, shatter(1.0, 1500, 9000, 120, 1.3), VESSEL_BURST_AT)
    at(x, 0.9 * sweep_sine(0.6, 95, 42, 0.16, attack=0.001), VESSEL_BURST_AT)
    spill = grains(0.8, 1500, 1800, 8000, 0.0012, shape=lambda t: np.clip(t / 0.1, 0, 1) * np.exp(-t / 0.3))
    at(x, 0.35 * spill, VESSEL_BURST_AT + 0.1)
    return lowpass(x, 11000)


def turn_end():
    """ターン終了。砂時計の砂がさらさらと落ちきる音。"""
    d = 0.9
    sand = grains(d, 3500, 2000, 9000, 0.0012,
                  shape=lambda t: np.clip(t / 0.15, 0, 1) * np.clip((d - t) / 0.4, 0, 1))
    hiss = noise(d, 3000, 9000) * np.clip(t_axis(d) / 0.15, 0, 1) * np.clip((d - t_axis(d)) / 0.4, 0, 1)
    return 0.8 * sand + 0.08 * hiss


# ---- ジングル(オルゴール風の鐘) ----

def bell(freq, dur, amp=1.0):
    parts = [(1.0, 1.0, 1.2), (2.0, 0.35, 0.5), (3.0, 0.12, 0.25), (4.07, 0.08, 0.12), (5.4, 0.04, 0.07)]
    x = modal(dur, [(freq * r, a, k) for r, a, k in parts], attack=0.002)
    return amp * x


def note(n):
    return 440.0 * 2 ** ((n - 69) / 12)


def jingle(seq, dur):
    x = np.zeros(int(SR * dur))
    for start, midi, amp, length in seq:
        at(x, bell(note(midi), length, amp), start)
    # 部屋の響きを少しだけ足す(短いディレイの重ね)
    wet = np.zeros_like(x)
    for delay, g in [(0.031, 0.25), (0.047, 0.2), (0.073, 0.15), (0.109, 0.1)]:
        i = int(SR * delay)
        wet[i:] += g * x[:-i]
    return lowpass(x + lowpass(wet, 4000), 9000)


def result_win():
    """2オクターブを駆け上がり、低音を支えにした和音で開き、高い粒がきらめいて消える。"""
    s = 0.085
    run = [72, 76, 79, 84, 88]
    seq = [(i * s, m, .75, 1.2) for i, m in enumerate(run)]
    top = len(run) * s
    seq += [(top, m, a, 2.4) for m, a in [(91, .9), (88, .55), (84, .55), (79, .4)]]
    seq += [(top, 48, .7, 2.6), (top, 60, .5, 2.4)]
    seq += [(top + 0.30 + i * 0.07, m, .28, 0.9) for i, m in enumerate([96, 100, 103, 108])]
    return jingle(seq, 3.1)


def result_lose():
    s = 0.2
    seq = [(0, 76, .8, 1.2), (s, 72, .75, 1.2), (2 * s, 69, .7, 1.4), (3 * s + 0.08, 64, .6, 2.0),
           (3 * s + 0.08, 57, .45, 2.0)]
    return jingle(seq, 2.6)


def turn_start():
    """自分の番が来た合図。控えめな2音の鐘。"""
    seq = [(0, 79, .8, 1.0), (0.09, 84, .9, 1.3)]
    return jingle(seq, 1.5)


if __name__ == "__main__":
    os.makedirs(OUT, exist_ok=True)
    finish("hover", ui_hover, -34)
    finish("press", ui_press, -22)
    finish("place", place, -19)
    finish("flip", flip, -21)
    finish("clash", clash, -18)
    finish("damage", damage, -17)
    finish("unit_break", unit_break, -18)
    finish("glass_break", glass_break, -20)
    finish("poison_melt", poison_melt, -19)
    finish("vessel_shatter", vessel_shatter, -16)
    finish("turn_end", turn_end, -26)
    finish("turn_start", turn_start, -22)
    finish("result_win", result_win, -16)
    finish("result_lose", result_lose, -19)
