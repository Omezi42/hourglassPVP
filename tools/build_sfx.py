"""効果音をコードで合成し assets/sfx/ へ書き出す(GameDesign.md 9章)。

出す・反転・攻撃・被弾・破壊・ターン終了などの手応えの音は、CC0の実録音(tools/sfx_sources/、
出所は assets/CREDITS.md)を芯にして合成音を重ねる。合成だけでは木や硝子の手触りが薄いため。
出力は 44.1kHz / 16bit / ステレオの WAV(左右の差は部屋の響きだけで、音の本体は中央に置く)。

音は「励振(何がどう当たったか) → 共鳴(何が鳴るか) → 部屋」の順に組む。
正弦波を直接足すのではなく、叩いた力の形(撥の硬さ)を共鳴フィルタへ通すため、
硬く当たれば高い響きまで鳴り、柔らかく当たれば丸くなるという差が自然に出る。
素材(木の卓・硝子・真鍮・オルゴールの櫛歯)は、それぞれ物理的な倍音比を持たせる。

音量は種類ごとの目標ラウドネス(finish() の第3引数)へ揃える。乱数の種は音の名前から
決めるため、何度実行しても同じ音になり、1つを直しても他の音は変わらない。

    python tools/build_sfx.py [出力先]
"""
import os
import sys
import zlib
from math import gcd
import numpy as np
import soundfile as sf
from scipy import signal

SR = 44100
RNG = np.random.default_rng(42)
OUT = sys.argv[1] if len(sys.argv) > 1 else os.path.join(os.path.dirname(__file__), "..", "assets", "sfx")
SOURCES = os.path.join(os.path.dirname(__file__), "sfx_sources")

# 素材ごとの倍音比。木の板は両端自由の梁、オルゴールの櫛歯は片持ち梁の理論値、
# 硝子は薄い殻の実測に近い値、真鍮の小鈴は手鈴の部分音(短3度の tierce を含む)。
WOOD = [1.0, 2.756, 5.404, 8.933]
GLASS = [1.0, 2.32, 4.25, 6.63, 9.38]
BRASS = [1.0, 1.19, 1.5, 2.0, 2.51, 3.01, 4.15]
TINE = [1.0, 6.267, 17.55]


def n_of(dur):
    return int(SR * dur)


def t_axis(dur):
    return np.arange(n_of(dur)) / SR


def at(buf, x, time, gain=1.0):
    i = int(SR * time)
    end = min(len(buf), i + len(x))
    if end > i:
        buf[i:end] += gain * x[: end - i]
    return buf


def pad(x, dur):
    n = n_of(dur)
    return np.pad(x, (0, max(0, n - len(x))))[:n]


def lowpass(x, fc, order=2):
    return signal.sosfilt(signal.butter(order, fc, fs=SR, output="sos"), x)


def highpass(x, fc, order=2):
    return signal.sosfilt(signal.butter(order, fc, btype="high", fs=SR, output="sos"), x)


def bandpass(x, lo, hi, order=2):
    return signal.sosfilt(signal.butter(order, [lo, hi], btype="band", fs=SR, output="sos"), x)


# ---- 実録音 ----

def rec(file, start=0.0, dur=None, fade_in=0.003, fade_out=0.05):
    """tools/sfx_sources/ の録音を、モノラル・44.1kHzにして [start, start+dur) を切り出す(最大振幅1)。"""
    x, sr = sf.read(os.path.join(SOURCES, file), always_2d=True)
    x = x.mean(axis=1)
    if sr != SR:
        g = gcd(sr, SR)
        x = signal.resample_poly(x, SR // g, sr // g)
    x = x[int(SR * start):]
    if dur is not None:
        x = pad(x, dur)
    x = x.copy()
    n_in, n_out = max(1, int(SR * fade_in)), max(1, int(SR * fade_out))
    x[:n_in] *= np.linspace(0, 1, n_in)
    x[-n_out:] *= np.linspace(1, 0, n_out) ** 2
    return x / (np.abs(x).max() + 1e-9)


def layer(base, x, rel_db, time=0.0):
    """x を base の音量から rel_db だけ下げた(上げた)大きさで、time 秒の位置へ重ねる。"""
    x = x * 10 ** ((loudness_db(base) + rel_db - loudness_db(x)) / 20)
    end = int(SR * time) + len(x)
    if end > len(base):
        base = np.pad(base, (0, end - len(base)))
    return at(base, x, time)


# ---- 励振 ----

def mallet(width):
    """撥が当たる力の形(面積1)。幅が狭い(硬い)ほど高い響きまで鳴らす。"""
    n = max(2, int(SR * width))
    m = 0.5 - 0.5 * np.cos(2 * np.pi * (np.arange(n) + 0.5) / n)
    return m / m.sum()


def scrape(dur, lo, hi):
    """接触の擦れ。硬い物どうしの当たりに一瞬の雑音を添える。"""
    return bandpass(RNG.standard_normal(n_of(dur)), lo, hi) * np.exp(-t_axis(dur) / (dur / 5))


def contact(dur, grit, grit_band):
    """当たった瞬間の擦れ。共鳴を通さず、そのまま表へ出す。"""
    if grit <= 0:
        return np.zeros(n_of(dur))
    g = scrape(0.012, *grit_band)
    return pad(grit * 0.5 * g / (np.abs(g).max() + 1e-9), dur)


# ---- 共鳴 ----

def resonate(exc, modes):
    """(周波数, 振幅, 減衰時定数) の共鳴フィルタの並びへ励振を通す。"""
    out = np.zeros_like(exc)
    for f, a, d in modes:
        if f >= SR * 0.45:
            continue
        w = 2 * np.pi * f / SR
        r = np.exp(-1.0 / (d * SR))
        out += a * signal.lfilter([np.sin(w)], [1, -2 * r * np.cos(w), r * r], exc)
    return out


def material(f0, ratios, amps, decay, damping, detune=0.006, pair_hz=0.0):
    """倍音比から共鳴の並びを作る。高い倍音ほど damping の冪で早く減衰する。
    pair_hz > 0 なら各倍音をわずかにずれた2本にし、硝子や鈴らしいうなりを持たせる。"""
    modes = []
    for r, a in zip(ratios, amps):
        f = f0 * r * (1 + RNG.uniform(-detune, detune))
        d = decay / r ** damping
        if pair_hz > 0:
            split = pair_hz * r ** 0.5
            modes += [(f - split / 2, a * 0.6, d), (f + split / 2, a * 0.5, d * 0.9)]
        else:
            modes.append((f, a, d))
    return modes


def wood(f0, decay):
    return material(f0, WOOD, [1.0, 0.45, 0.2, 0.08], decay, 1.1)


def glass(f0, decay):
    return material(f0, GLASS, [1.0, 0.55, 0.3, 0.16, 0.07], decay, 0.55, detune=0.004, pair_hz=1.6)


def brass(f0, decay):
    return material(f0, BRASS, [0.35, 0.18, 0.4, 1.0, 0.3, 0.25, 0.12], decay, 0.45, detune=0.002, pair_hz=0.9)


def strike(dur, modes, width, grit=0.0, grit_band=(2000, 9000)):
    return resonate(pad(mallet(width), dur), modes) + contact(dur, grit, grit_band)


# ---- 砂と破片 ----

def sand(dur, rate, lo, hi, shape, bands=7):
    """砂粒の流れ。まばらな打点を、高さの違う狭い帯域へ振り分けて鳴らす。
    粒ごとに違う高さで短く鳴るため、雑音を削っただけの「しゃー」にならず、さらさらと聞こえる。"""
    n = n_of(dur)
    t = np.arange(n) / SR
    dens = shape(t)
    hits = RNG.random(n) < rate / SR * dens
    amps = np.where(hits, RNG.uniform(0.2, 1.0, n) * np.sqrt(np.maximum(dens, 0)), 0.0)
    which = RNG.integers(0, bands, n)
    centers = np.geomspace(lo, hi, bands)
    out = np.zeros(n)
    for b, fc in enumerate(centers):
        train = np.where(which == b, amps, 0.0)
        out += signal.lfilter(*_reson(fc, 6.0), train)
    return out


def _reson(fc, q):
    w = 2 * np.pi * fc / SR
    r = np.exp(-w / (2 * q))
    return [np.sin(w)], [1, -2 * r * np.cos(w), r * r]


def shards(dur, count, lo, hi, spread, decay=(0.015, 0.05)):
    """散る硝子片。1片ごとに高さの違う小さな硝子を鳴らし、跳ねながら間遠になる。"""
    x = np.zeros(n_of(dur))
    for _ in range(count):
        time = RNG.exponential(spread)
        if time >= dur - 0.05:
            continue
        f = np.exp(RNG.uniform(np.log(lo), np.log(hi)))
        d = RNG.uniform(*decay)
        piece = strike(0.15, material(f, GLASS[:3], [1, .5, .2], d, 0.6, detune=0.02), 0.00015)
        at(x, piece, time, RNG.uniform(0.25, 1.0) * np.exp(-time / (spread * 2)))
    return x


def thump(dur, f0, f1, decay, width=0.004):
    """重い物が当たる低い胴鳴り。当たった直後に少し高く、すぐ沈む。"""
    t = t_axis(dur)
    f = f1 + (f0 - f1) * np.exp(-t / 0.03)
    ph = 2 * np.pi * np.cumsum(f) / SR
    a = np.clip(t / width, 0, 1)
    return np.sin(ph) * a * np.exp(-t / decay)


def bubbles(dur, count, lo, hi, shape_peak):
    """泡が弾ける音。泡は弾けながら高さが上がる(Minnaert 共鳴)。"""
    x = np.zeros(n_of(dur))
    for _ in range(count):
        time = abs(RNG.normal(shape_peak, dur / 4))
        if time >= dur - 0.06:
            continue
        f0 = np.exp(RNG.uniform(np.log(lo), np.log(hi)))
        d = 0.012 + 3.0 / f0
        t = t_axis(0.06)
        f = f0 * (1 + 0.9 * t / d * 0.1)
        ph = 2 * np.pi * np.cumsum(f) / SR
        piece = np.sin(ph) * np.exp(-t / d) * np.clip(t / 0.0008, 0, 1)
        at(x, piece, time, RNG.uniform(0.3, 1.0))
    return x


# ---- 部屋 ----

ROOM_SEED = 7


def room_ir(rt60, dur):
    """小さな書斎ほどの部屋の響き(左右別の減衰する雑音)。高域ほど早く消える。"""
    rng = np.random.default_rng(ROOM_SEED)
    t = t_axis(dur)
    decay = np.exp(-6.91 * t / rt60)
    ir = []
    for _ in range(2):
        bright = rng.standard_normal(len(t)) * np.exp(-6.91 * t / (rt60 * 0.45))
        dark = lowpass(rng.standard_normal(len(t)), 2500) * decay
        ch = 0.5 * bright + dark
        for delay, g in [(0.011, 0.5), (0.017, 0.35), (0.023, 0.3), (0.031, 0.22)]:
            ch[int(SR * delay * rng.uniform(0.85, 1.15))] += g * 6
        ch[: int(SR * 0.006)] = 0
        ir.append(highpass(ch, 180) / np.sqrt((ch ** 2).sum()))
    return ir


ROOM = None


def roomify(x, wet):
    """中央の乾いた音に、左右へ広がる部屋の響きを wet の量だけ足してステレオにする。"""
    global ROOM
    if ROOM is None:
        ROOM = room_ir(0.45, 0.7)
    tail = n_of(0.5) if wet > 0 else 0
    dry = np.pad(x, (0, tail))
    if wet <= 0:
        return np.stack([dry, dry])
    chans = [dry + wet * signal.fftconvolve(dry, ir)[: len(dry)] * 3.0 for ir in ROOM]
    return np.stack(chans)


# ---- 仕上げ ----

def fade_tail(x, ms=40):
    n = int(SR * ms / 1000)
    x = x.copy()
    x[..., -n:] *= np.linspace(1, 0, n) ** 2
    return x


def trim_silence(x, floor_db=-70):
    level = np.abs(x).max(axis=0)
    above = np.nonzero(level > 10 ** (floor_db / 20) * level.max())[0]
    end = min(x.shape[1], above[-1] + n_of(0.03)) if len(above) else x.shape[1]
    return x[:, :end]


def loudness_db(x):
    """短時間(50ms)の最大RMS。低域の聞こえにくさを粗く補うため150Hzの高域通過を掛けて測る。"""
    y = highpass(x.mean(axis=0) if x.ndim == 2 else x, 150)
    w = int(SR * 0.05)
    if len(y) <= w:
        return 20 * np.log10(np.sqrt((y ** 2).mean()) + 1e-12)
    ms = np.convolve(y ** 2, np.ones(w) / w, "valid")
    return 10 * np.log10(ms.max() + 1e-12)


def finish(name, make, target_db, wet):
    global RNG
    RNG = np.random.default_rng(zlib.crc32(name.encode()))
    x = make()
    x = highpass(x - x.mean(), 40)
    x = fade_tail(trim_silence(roomify(x, wet)))
    x *= 10 ** ((target_db - loudness_db(x)) / 20)
    peak = np.abs(x).max()
    if peak > 0.89:  # -1dBFS を越えたら、音量より歪まないことを優先する
        x *= 0.89 / peak
    sf.write(os.path.join(OUT, name + ".wav"), x.T.astype(np.float32), SR, subtype="PCM_16")
    print(f"{name:14s} {x.shape[1]/SR:5.2f}s  loud={loudness_db(x):6.1f}dB  peak={20*np.log10(np.abs(x).max()):5.1f}dB")


# ---- UI ----

def ui_hover():
    """木片に指先が触れた小さな「とっ」。柔らかく当てて高い響きを出さない。"""
    d = 0.07
    return lowpass(strike(d, wood(1150, 0.018), 0.0011), 4000)


def ui_press():
    """真鍮の留め金が掛かる「かちっ」。録音の留め金に、合成の押し込みの当たりと澄んだ鳴りを重ねる。"""
    d = 0.12
    x = np.zeros(n_of(d))
    at(x, strike(0.05, wood(1700, 0.008), 0.0004, 0.4, (3000, 9000)), 0.0, 1.0)
    latch = strike(0.1, brass(1600, 0.035), 0.0002, 0.6, (3000, 10000))
    at(x, latch, 0.016)
    return lowpass(layer(rec("metalLatch.ogg", 0.025, 0.2), x, -2), 12000)


# ---- 対局 ----

def place():
    """砂時計を木の卓へ置く「ことん」。硝子の器を木の卓へ置いた録音を芯に、卓の胴鳴り、
    一度だけの小さな跳ね返り、中の砂が揺れて落ち着く音を重ねる。"""
    d = 0.6
    x = np.zeros(n_of(d))
    table = strike(d, wood(210, 0.09), 0.003)
    body = thump(d, 160, 105, 0.06)
    clink = strike(d, glass(2150, 0.22), 0.0006)
    at(x, table + 0.6 * body + 0.45 * clink, 0.0)
    at(x, 0.25 * strike(0.3, wood(230, 0.05), 0.002) + 0.12 * strike(0.3, glass(2150, 0.15), 0.0006), 0.032)
    settle = sand(0.3, 1200, 2500, 9000, lambda t: np.exp(-t / 0.07))
    at(x, settle, 0.01, 0.6)
    return lowpass(layer(rec("fs454222_kyles.mp3", 0.0, 0.39, fade_out=0.08), x, -3), 10000)


def flip():
    """砂時計を返す。小さな砂時計を返す録音(持ち替えの擦れ、着地、砂が流れ始める)を芯に、
    合成の着地と砂を薄く重ねる。録音の着地は landing の位置に来るよう切り出す。"""
    d = 0.85
    x = np.zeros(n_of(d))
    swish_len = 0.2
    t = t_axis(swish_len)
    swish = bandpass(RNG.standard_normal(len(t)), 700, 3200) * np.sin(np.pi * t / swish_len) ** 2
    at(x, swish, 0.0, 0.35)
    landing = 0.17
    at(x, 0.7 * strike(0.4, wood(320, 0.05), 0.002) + 0.5 * strike(0.4, glass(2600, 0.18), 0.0005), landing)
    flow = sand(0.6, 2600, 2200, 9500,
                lambda t: np.clip(t / 0.06, 0, 1) * (0.35 + 0.65 * np.exp(-t / 0.12)) * np.clip((0.6 - t) / 0.3, 0, 1))
    at(x, flow, landing + 0.02, 0.4)
    real = rec("fs625655_el_boss.mp3", 0.62 - landing, d, fade_in=0.04, fade_out=0.3)
    return lowpass(layer(real, x, -5), 11000)


def clash():
    """砂時計どうしがぶつかる「かきん」。2つのワイングラスが当たる録音に、合成の硝子のうなり、
    真鍮の枠、低い胴鳴りを重ねる。"""
    d = 1.0
    a = strike(d, glass(1640, 0.42), 0.00025, 0.5, (2500, 11000))
    b = strike(d, glass(1730, 0.36), 0.00025)
    frame = strike(d, brass(780, 0.12), 0.0003)
    body = thump(d, 230, 140, 0.05)
    debris = sand(0.4, 1500, 2500, 9000, lambda t: np.exp(-t / 0.08))
    synth = a + 0.8 * b + 0.5 * frame + 0.5 * body + 0.4 * pad(debris, d)
    real = rec("fs178178_lmr9.mp3", 0.0, d, fade_out=0.3)
    real = layer(real, rec("fs761135_wasserbjorn.mp3", 0.88, d, fade_out=0.3), -4)
    return lowpass(layer(real, synth, -3), 12000)


def damage():
    """本体への重い打撃「どすっ」。重い打撃の録音を芯に、低い胴鳴りと、砂の詰まった袋が潰れるような
    砂の噴き出しを重ねる。"""
    d = 0.65
    boom = thump(d, 120, 52, 0.13, width=0.002)
    hit = strike(d, wood(140, 0.06), 0.005, 0.3, (300, 2500))
    burst = sand(0.25, 7000, 500, 5000, lambda t: np.exp(-t / 0.04))
    synth = boom + 0.6 * hit + 0.25 * pad(burst, d)
    real = layer(rec("impactPunch_heavy_000.ogg", 0.0, d), rec("impactSoft_heavy_000.ogg", 0.0, d), -4)
    return lowpass(layer(real, synth, -2), 7000)


def unit_break():
    """砂時計が割れて崩れる。小さな硝子の器が割れる録音を芯に、低い衝撃、散って跳ねる硝子片、
    こぼれ出る砂を重ねる。"""
    d = 1.2
    x = np.zeros(n_of(d))
    crack = strike(0.4, glass(1900, 0.06), 0.0001, 1.0, (2500, 12000))
    at(x, crack, 0.0, 0.8)
    at(x, shards(d, 38, 2200, 8500, 0.12), 0.006, 0.6)
    at(x, thump(0.4, 110, 60, 0.07), 0.0, 0.9)
    spill = sand(0.8, 3000, 1800, 9000, lambda t: np.clip(t / 0.06, 0, 1) * np.exp(-t / 0.22))
    at(x, spill, 0.08, 0.45)
    real = rec("fs320167_joshs.mp3", 0.33, d, fade_out=0.4)
    return lowpass(layer(real, x, -3), 12000)


def glass_break():
    """硝子の膜が割れる。薄い硝子が「ぱりん」と割れる録音に合成の破片を重ねた、高く軽い音だけ。
    本体は無事なので低音を持たない。"""
    d = 0.8
    x = np.zeros(n_of(d))
    at(x, strike(0.6, glass(3100, 0.2), 0.00012, 1.0, (4000, 13000)), 0.0, 0.6)
    at(x, shards(d, 26, 4200, 11000, 0.09, decay=(0.01, 0.035)), 0.004, 0.55)
    real = rec("fs221528_unfa.mp3", 0.29, d, fade_out=0.25)
    return highpass(lowpass(layer(real, x, -5), 14000), 1200)


def poison_melt():
    """毒砂で溶ける「じゅわっ」。膨らんでしぼむ泡立ちと、低く沈んでいく音。硝子の破片は持たない。"""
    d = 1.1
    t = t_axis(d)
    swell = np.clip(t / 0.1, 0, 1) * np.exp(-t / 0.3)
    fizz = bandpass(RNG.standard_normal(len(t)), 900, 5000) * swell
    pops = bubbles(d, 55, 350, 1600, 0.2)
    sink = thump(d, 230, 70, 0.22, width=0.02)
    return lowpass(0.18 * fizz + 0.6 * pops + 0.6 * sink, 7000)


## 器が割れる位置(秒)。`HpVesselFx` の BURST_AT(0.4)× SHATTER_DURATION(0.8)に合わせる。
VESSEL_BURST_AT = 0.32


def vessel_shatter():
    """HPの器が砕ける。ぴし、ぴしぴしとひびが走り、割れて破片と砂が散る。駒の破壊より重く長い。
    割れる瞬間には硝子が割れる録音を重ねる。"""
    d = 2.0
    x = np.zeros(n_of(d))
    for i, time in enumerate([0.0, 0.12, 0.2, 0.25, 0.28, 0.305]):
        tick = strike(0.12, glass(2500 + 230 * i, 0.03), 0.0001, 1.2, (4000, 12000))
        at(x, tick, time, 0.3 + 0.08 * i)
    at(x, strike(0.6, glass(1500, 0.08), 0.0001, 1.0, (2000, 12000)), VESSEL_BURST_AT)
    at(x, shards(1.4, 70, 1600, 9000, 0.16), VESSEL_BURST_AT + 0.005, 0.75)
    at(x, thump(0.8, 95, 40, 0.2, width=0.002), VESSEL_BURST_AT, 1.2)
    spill = sand(1.2, 3200, 1600, 8500, lambda t: np.clip(t / 0.08, 0, 1) * np.exp(-t / 0.35))
    at(x, spill, VESSEL_BURST_AT + 0.06, 0.55)
    burst = rec("fs249549_FngerSounds.mp3", 1.04, d - VESSEL_BURST_AT, fade_out=0.4)
    return lowpass(layer(x, burst, 0, VESSEL_BURST_AT), 12000)


def turn_end():
    """ターン終了。砂時計の砂がさらさらと落ち、最後の数粒で落ちきる。
    砂時計の砂が落ちきるところの録音に、合成の最後の数粒を重ねる。"""
    d = 1.0
    stream = sand(d, 5000, 1800, 8500,
                  lambda t: np.clip(t / 0.12, 0, 1) * np.clip((0.75 - t) / 0.35, 0, 1) ** 1.5)
    last = sand(d, 60, 2500, 7000, lambda t: ((t > 0.6) & (t < 0.95)).astype(float))
    real = rec("fs825859_Vrymaa.mp3", 15.35, d, fade_in=0.12, fade_out=0.15)
    return layer(real, stream + 2.0 * last, -6)


# ---- 合図とジングル ----

def note(n):
    return 440.0 * 2 ** ((n - 69) / 12)


def hand_bell(midi, dur, amp=1.0):
    """真鍮の小鈴。鈴らしい短3度(tierce)の部分音と、ゆっくりしたうなりを持つ。"""
    return amp * strike(dur, brass(note(midi) / 2.0, 1.6), 0.0004)


def music_box(midi, dur, amp=1.0):
    """オルゴールの櫛歯。弾く爪の小さな当たりと、片持ち梁の高い倍音が早く消える響き。"""
    f = note(midi)
    modes = material(f, TINE, [1.0, 0.22, 0.05], 1.5 * (440 / f) ** 0.3, 1.0, detune=0.0, pair_hz=0.5)
    return amp * strike(dur, modes, 0.0002, 0.15, (5000, 12000))


def sequence(voice, seq, dur):
    x = np.zeros(n_of(dur))
    for start, midi, amp, length in seq:
        at(x, voice(midi, length, amp), start)
    return x


def box_body(x):
    """オルゴールの木箱の鳴り。低めの胴の響きを少しだけ重ねる。"""
    body = signal.fftconvolve(x, strike(0.12, wood(330, 0.025), 0.0002))[: len(x)]
    return x + 0.15 * body / (np.abs(body).max() + 1e-9) * np.abs(x).max()


def turn_start():
    """自分の番が来た合図。真鍮の小鈴を2つ、上へ向けて鳴らす。"""
    return sequence(hand_bell, [(0, 79, .75, 1.6), (0.11, 84, 1.0, 1.9)], 2.0)


def result_win():
    """オルゴールが2オクターブを駆け上がり、低音を支えにした和音で開き、高い粒がきらめいて消える。"""
    s = 0.085
    run = [72, 76, 79, 84, 88]
    seq = [(i * s, m, .7, 1.4) for i, m in enumerate(run)]
    top = len(run) * s
    seq += [(top + 0.012 * k, m, a, 2.6) for k, (m, a) in enumerate([(91, .9), (88, .55), (84, .55), (79, .45)])]
    seq += [(top, 48, .8, 2.8), (top, 60, .55, 2.6)]
    seq += [(top + 0.30 + i * 0.075, m, .3, 1.1) for i, m in enumerate([96, 100, 103, 108])]
    return box_body(sequence(music_box, seq, 3.4))


def result_lose():
    """オルゴールが静かに下り、短調の和音で止まる。ねじが切れかけたように少し間延びする。"""
    seq = [(0, 76, .8, 1.4), (0.21, 72, .75, 1.4), (0.44, 69, .7, 1.6), (0.73, 64, .6, 2.2),
           (0.73, 57, .5, 2.2), (0.75, 45, .5, 2.4)]
    return box_body(sequence(music_box, seq, 3.0))


## 対局開始の鐘が鳴る位置(秒)。`CardMatchStartCurtain.TITLE_IN` の文字が出る頃に合わせる。
MATCH_START_TOLL_AT = 0.2


def match_start():
    """対局開始。砂が吹き上がり、文字が出るところで低い鐘と高い鈴が重なって長く響く。"""
    d = 2.4
    x = np.zeros(n_of(d))
    rush = sand(0.5, 6000, 1500, 9000, lambda t: np.clip(t / 0.18, 0, 1) * np.exp(-np.clip(t - 0.18, 0, None) / 0.12))
    at(x, rush, 0.0, 0.7)
    at(x, strike(2.1, brass(note(45), 1.3), 0.0008, 0.3, (1500, 6000)), MATCH_START_TOLL_AT, 0.9)
    at(x, hand_bell(79, 1.8, 0.45), MATCH_START_TOLL_AT + 0.02)
    at(x, hand_bell(86, 1.6, 0.35), MATCH_START_TOLL_AT + 0.09)
    at(x, sand(1.2, 40, 2500, 7500, lambda t: np.exp(-t / 0.5)), MATCH_START_TOLL_AT + 0.05, 1.5)
    return lowpass(x, 10000)


def turn_order():
    """マリガン前の先手・後手の表示。真鍮の小鈴を1つ、柔らかく。"""
    return hand_bell(74, 1.4, 0.8)


# ---- カードの演出(登場とコスト6以上の効果だけ。打点は scripts/ui/signature/moves/ の定数に合わせる) ----

## クロノスが落ちきる位置(秒)。`CardUnitFx` の重い着地の尺に合わせる。
CHRONOS_LAND_AT = 0.38
## 歯車の輪が回りきって噛み合う位置(秒)。`chronos_entrance.gd` の SPIN の終わりに合わせる。
CHRONOS_LOCK_AT = 0.98


def sig_chronos():
    """クロノスの登場。高くから重く落ちる「どしん」、真鍮の歯車が回る「かたかた」、噛み合って止まる「がちん」。"""
    d = 1.6
    x = np.zeros(n_of(d))
    at(x, thump(0.9, 90, 38, 0.25, width=0.002), CHRONOS_LAND_AT, 1.3)
    at(x, strike(0.6, wood(150, 0.12), 0.004), CHRONOS_LAND_AT, 0.8)
    at(x, strike(0.6, glass(1900, 0.2), 0.0005), CHRONOS_LAND_AT, 0.25)
    dust = sand(0.4, 2500, 1500, 7000, lambda t: np.exp(-t / 0.1))
    at(x, dust, CHRONOS_LAND_AT + 0.01, 0.4)
    ticks = 9
    for i in range(ticks):
        time = CHRONOS_LAND_AT + 0.1 + (CHRONOS_LOCK_AT - CHRONOS_LAND_AT - 0.14) * i / (ticks - 1)
        at(x, strike(0.08, brass(2300 + 40 * (i % 2), 0.02), 0.0002, 0.5, (3000, 9000)), time, 0.22)
    at(x, strike(0.7, brass(420, 0.3), 0.0004, 0.6, (2000, 8000)), CHRONOS_LOCK_AT, 0.9)
    at(x, thump(0.3, 180, 110, 0.05), CHRONOS_LOCK_AT, 0.4)
    x = layer(x, rec("impactWood_heavy_000.ogg"), -4, CHRONOS_LAND_AT)
    x = layer(x, rec("impactMetal_heavy_001.ogg"), -6, CHRONOS_LOCK_AT)
    return lowpass(x, 11000)


## 鐘が鳴る位置(秒)。`clocktower_effect.gd` の鐘の振りの頂点に合わせる。
CLOCKTOWER_TOLL_AT = 0.16


def sig_clocktower():
    """クロックタワーの鐘「ごーん」。低い青銅の鐘が長く唸り、波紋の間ずっと響く。"""
    d = 2.4
    x = np.zeros(n_of(d))
    bell = strike(d, brass(note(45), 1.4), 0.0008, 0.3, (1500, 6000))
    hum = strike(d, brass(note(33), 2.0), 0.002)
    at(x, bell + 0.5 * hum, CLOCKTOWER_TOLL_AT)
    return lowpass(x, 8000)


# ---- 登場の演出の音(打点は各 `*_entrance.gd` の定数に合わせる) ----
# 登場の音は置く音の代わりに鳴る(card_match_sound.gd)ため、どれも着地に置く音を持ち、その上へ
# カードごとの動きの音を重ねる。重ねる音の大きさは着地の音からの dB で書く。

## 駒が台座へ落ちきる位置(秒)。`CardUnitFx.LAND_DURATION` / `HEAVY_LAND_DURATION`。
LAND_AT = 0.26
HEAVY_LAND_AT = CHRONOS_LAND_AT
## 風切りの録音(13本入り)の各1本の頭(秒)。
WHOOSH_STARTS = [0.22, 1.27, 2.27, 3.42]


def pitch(x, ratio):
    """高さを ratio 倍にする(長さは 1/ratio 倍になる)。"""
    if ratio == 1.0:
        return x
    return signal.resample_poly(x, 100, int(round(100 * ratio)))


def whoosh(i=0, ratio=1.0):
    """短い風切り。"""
    return pitch(rec("fs427979_Kinoton.mp3", WHOOSH_STARTS[i], 0.45, fade_out=0.15), ratio)


def grind(ratio=1.0):
    """石が擦れてせり上がる「ごり」。"""
    return pitch(rec("fs743262_qubodup.mp3", 0.0, 0.39, fade_in=0.03, fade_out=0.1), ratio)


def tink(f, decay=0.4, dur=1.0):
    """硝子の小さな「ちん」。"""
    return strike(dur, glass(f, decay), 0.0002)


def chime(freqs, step, decay=0.35):
    """硝子の粒を step 秒おきに順に鳴らす(きらめき・光が走る)。"""
    x = np.zeros(n_of(step * len(freqs) + 1.0))
    for i, f in enumerate(freqs):
        at(x, tink(f, decay), step * i, 1.0 - 0.4 * i / max(1, len(freqs) - 1))
    return x


def landing(d, heavy=False):
    """登場の土台:着地の位置に置く音。重い登場は、木の重い当たりと低い地鳴りを足す。"""
    x = np.zeros(n_of(d))
    t = HEAVY_LAND_AT if heavy else LAND_AT
    at(x, place(), t)
    if heavy:
        x = layer(x, rec("impactWood_heavy_000.ogg"), -2, t)
        x = layer(x, thump(0.9, 90, 38, 0.25, width=0.002), -1, t)
    return x


def sig_freeze():
    """フリーズ:氷が駒を這い上がる「ぴしぴし」、頭の上で結晶がきらめく。"""
    climb = 0.28
    x = landing(1.3)
    x = layer(x, rec("fs206156_ahill86.mp3", 0.25, climb + 0.05, fade_out=0.06), -5, LAND_AT + 0.01)
    return layer(x, chime([3300, 4400, 5200], 0.06, 0.5), -7, LAND_AT + climb)


def sig_relic():
    """レリック:石の箱がせり上がり、蓋がきしんで開き、光の粒が抜けていく。"""
    rise, lid = 0.24, 0.2
    x = landing(1.4)
    x = layer(x, grind(1.1), -6, LAND_AT)
    x = layer(x, rec("creak3.ogg", 0.0, 0.34), -9, LAND_AT + rise - 0.06)
    mote = sequence(music_box, [(0.0, 84, .7, 1.0), (0.07, 88, .6, 1.0), (0.14, 91, .5, 1.2)], 1.4)
    return layer(x, mote, -11, LAND_AT + rise + lid)


def sig_middle():
    """ミドル:台座の縁に紫の粒が5つ灯り、渦を巻いて吸い込まれ、駒が一度低く脈打つ。"""
    light, swirl = 0.22, 0.42
    x = landing(1.5)
    x = layer(x, chime([2400, 2700, 3000, 3300, 3600], light / 5, 0.25), -12, LAND_AT)
    x = layer(x, whoosh(1, 0.7), -10, LAND_AT + light)
    pulse = thump(0.5, 140, 70, 0.12, width=0.01) + 0.3 * pad(bubbles(0.5, 12, 300, 900, 0.05), 0.5)
    return layer(x, pulse, -5, LAND_AT + light + swirl)


def sig_phase():
    """フェイズ:左右から刃が2枚走り、頭上で×に交差して「しゃきん」と閃く。"""
    slash = 0.3
    x = landing(1.2)
    x = layer(x, rec("drawKnife1.ogg"), -7, LAND_AT)
    x = layer(x, rec("drawKnife2.ogg"), -8, LAND_AT + 0.05)
    flash = strike(0.8, brass(2400, 0.4), 0.0002, 0.6, (4000, 11000))
    return layer(x, flash, -5, LAND_AT + slash)


def sig_grain():
    """グレイン:砂粒が3粒ぽつぽつと落ち、台座で小さく跳ねる。"""
    gap, fall = 0.14, 0.2
    x = landing(1.2)
    for i in range(3):
        puff = sand(0.12, 900, 2500, 8000, lambda t: np.exp(-t / 0.03))
        tick = strike(0.2, wood(2200 + 250 * i, 0.02), 0.0003) + 0.4 * pad(puff, 0.2)
        x = layer(x, tick, -9, LAND_AT + gap * i + fall)
    return x


def sig_dash():
    """ダッシュ:着地の直前に風が走り抜け、足元から砂埃が後ろへ流れる。"""
    dust = 0.42
    x = landing(1.2)
    x = layer(x, whoosh(2, 1.15), -2, LAND_AT - 0.17)
    skid = sand(dust, 3500, 1500, 8000, lambda t: np.clip(t / 0.03, 0, 1) * np.exp(-t / 0.13))
    return layer(x, skid, -8, LAND_AT + 0.02)


def sig_shield():
    """シールド:盾がせり上がり、縁を光が一周して真鍮の盾が澄んで鳴る。"""
    rise = 0.24
    x = landing(1.6)
    x = layer(x, whoosh(3, 1.3), -11, LAND_AT)
    ring = strike(1.2, brass(880, 0.7), 0.0004, 0.3, (3000, 9000))
    return layer(x, ring, -4, LAND_AT + rise)


def sig_sand():
    """サンド:着地と同時に砂の波紋が広がり、縁から砂がさらさらとこぼれる。"""
    spill = 0.4
    x = landing(1.1)
    flow = rec("fs825859_Vrymaa.mp3", 5.0, spill + 0.1, fade_in=0.02, fade_out=0.15)
    return layer(x, flow, -3, LAND_AT + 0.01)


def sig_watcher():
    """ワッチャー:目の紋が低い響きとともに開き、左右を見渡してから閉じる。"""
    opening, look = 0.2, 0.44
    x = landing(1.6)
    x = layer(x, strike(1.2, brass(note(50), 1.0), 0.003), -8, LAND_AT)
    x = layer(x, whoosh(0, 0.6), -13, LAND_AT + opening)
    x = layer(x, whoosh(1, 0.6), -13, LAND_AT + opening + look / 2)
    return layer(x, strike(0.2, wood(900, 0.03), 0.002), -12, LAND_AT + opening + look)


def sig_glass():
    """グラス:駒の表面を光の筋が走り、肩で星が「きらん」と瞬く。"""
    sweep = 0.3
    x = landing(1.3)
    x = layer(x, chime([2600, 3100, 3700, 4400], sweep / 4, 0.2), -10, LAND_AT)
    return layer(x, tink(5200, 0.6), -3, LAND_AT + sweep)


def sig_vamp():
    """ヴァンプ:コウモリが2匹、羽ばたきながら左右へ飛び去る。"""
    fly, flaps, lag = 0.62, 4, 0.08
    x = landing(1.3)
    flap = rec("cloth4.ogg", 0.04, 0.12, fade_out=0.04)
    for bat in range(2):
        for k in range(flaps):
            x = layer(x, flap, -6 - 2.5 * k - 2 * bat, LAND_AT + lag * bat + fly / flaps * k)
    return x


def sig_drill():
    """ドリル:錐が唸りを上げて回り、真下へ突き下ろされて石くずが散る。"""
    hover, plunge = 0.14, 0.18
    x = landing(1.4)
    d = hover + plunge
    t = t_axis(d)
    f = 180 + 520 * (t / d) ** 2
    buzz = signal.sawtooth(2 * np.pi * np.cumsum(f) / SR)
    whir = buzz * (0.6 + 0.4 * np.sin(2 * np.pi * 38 * t)) * np.clip(t / 0.04, 0, 1)
    x = layer(x, bandpass(whir, 300, 3000), -10, LAND_AT)
    return layer(x, rec("impactMining_000.ogg", 0.0, 0.7), -2, LAND_AT + d)


def sig_lance():
    """ランス:長い槍が一直線に突き抜ける「ひゅっ」と、穂先の金属の擦れ。"""
    x = landing(1.0)
    x = layer(x, whoosh(3, 1.25), 0, LAND_AT - 0.03)
    return layer(x, rec("drawKnife3.ogg", 0.05, 0.4), -9, LAND_AT + 0.02)


def sig_twin():
    """ツイン:左右に同じ音の残像が2つ鳴り、寄り合って1つに重なる。"""
    split, merge = 0.16, 0.36
    f = note(84)
    x = landing(1.4)
    x = layer(x, tink(f, 0.3) + tink(f * 1.03, 0.3), -9, LAND_AT)
    x = layer(x, whoosh(2, 1.4), -13, LAND_AT + split)
    return layer(x, tink(f, 0.8) + tink(f * 1.002, 0.8), -5, LAND_AT + split + merge)


def sig_lock():
    """ロック:南京錠が現れ、掛け金が「かちり」と閉まる。"""
    appear, snap = 0.14, 0.1
    x = landing(1.1)
    x = layer(x, strike(0.3, brass(2600, 0.06), 0.0002), -12, LAND_AT)
    x = layer(x, rec("metalLatch.ogg", 0.025, 0.2), 0, LAND_AT + appear + snap - 0.01)
    return layer(x, tink(4200, 0.4), -12, LAND_AT + appear + snap + 0.03)


def sig_gate():
    """ゲート:石の門柱がせり上がり、横木が「ごとん」と渡って、また沈む。"""
    rise, lintel, hold = 0.22, 0.12, 0.16
    x = landing(1.5)
    x = layer(x, grind(1.0), -5, LAND_AT)
    x = layer(x, rec("impactMining_000.ogg", 0.0, 0.5), -4, LAND_AT + rise + lintel)
    return layer(x, grind(0.8), -9, LAND_AT + rise + lintel + hold)


def sig_poison():
    """ポイズン:紫の泡が3つぶくぶくと立ちのぼり、順にはじける。"""
    rise, lag = 0.34, 0.1
    x = landing(1.3)
    x = layer(x, bubbles(0.6, 30, 250, 900, 0.2), -7, LAND_AT)
    for i in range(3):
        pop = bubbles(0.15, 4, 700 + 200 * i, 1500 + 200 * i, 0.01) + 0.4 * pad(scrape(0.03, 2000, 7000), 0.15)
        x = layer(x, pop, -7, LAND_AT + lag * i + rise)
    return x


def sig_guard():
    """ガード:大きな盾が降りて卓に「どすん」と突き立ち、縁がきらりと光る。"""
    drop = 0.2
    x = landing(1.3)
    x = layer(x, whoosh(1, 0.9), -8, LAND_AT - 0.04)
    x = layer(x, rec("impactMetal_heavy_001.ogg"), 0, LAND_AT + drop)
    x = layer(x, rec("impactWood_heavy_000.ogg"), -4, LAND_AT + drop)
    return layer(x, tink(3000, 0.5), -13, LAND_AT + drop + 0.08)


def sig_mirror():
    """ミラー:鏡が立ち、鏡面を光がよぎって、反射光が高く「きん」と跳ね返る。"""
    appear, sweep = 0.14, 0.22
    x = landing(1.4)
    x = layer(x, tink(2000, 0.3), -11, LAND_AT)
    x = layer(x, chime([3000, 3500, 4000], sweep / 3, 0.2), -11, LAND_AT + appear)
    x = layer(x, tink(4800, 0.6), -3, LAND_AT + appear + sweep)
    return layer(x, tink(4800 * 1.5, 0.4), -12, LAND_AT + appear + sweep + 0.08)


def sig_wall():
    """ウォール:重く落ちて、足元の石畳に「ばりばり」とひびが走る。"""
    crack = 0.3
    x = landing(1.3, heavy=True)
    cracks = np.zeros(n_of(crack + 0.2))
    for _ in range(14):
        piece = strike(0.1, wood(RNG.uniform(900, 1700), 0.012), 0.0001, 0.8, (2000, 7000))
        at(cracks, piece, crack * RNG.uniform(0.0, 1.0) ** 1.4, RNG.uniform(0.4, 1.0))
    x = layer(x, cracks, -6, HEAVY_LAND_AT + 0.02)
    return layer(x, grind(0.7), -12, HEAVY_LAND_AT + 0.02)


def sig_bypass():
    """抜け道:光る小道がうねりながら伸びていく上り音階と、先に灯る矢じりの「ちん」。"""
    grow = 0.42
    x = landing(1.4)
    steps = [72, 74, 76, 79, 81, 84]
    run = sequence(music_box, [(grow / len(steps) * i, m, .6, 0.8) for i, m in enumerate(steps)], 1.3)
    x = layer(x, run, -11, LAND_AT)
    return layer(x, tink(3600, 0.5), -5, LAND_AT + grow)


def sig_colossus():
    """コロッサス:重く落ちて地響きが2度うねり、砕けた石の欠片が跳ねる。"""
    quake = 0.5
    x = landing(1.5, heavy=True)
    x = layer(x, thump(1.0, 70, 32, 0.35, width=0.01), -7, HEAVY_LAND_AT + 0.02)
    x = layer(x, thump(0.8, 60, 30, 0.3, width=0.02), -10, HEAVY_LAND_AT + quake * 0.2)
    chips = np.zeros(n_of(quake + 0.3))
    for _ in range(10):
        piece = strike(0.1, wood(RNG.uniform(1500, 2600), 0.015), 0.0002)
        at(chips, piece, RNG.uniform(0.05, quake), RNG.uniform(0.3, 1.0))
    return layer(x, chips, -9, HEAVY_LAND_AT)


# ---- コスト6以上の効果の演出の音(結果の音は進行役が着弾で鳴らすため、届くまでだけを鳴らす) ----

def sig_obelisk():
    """オベリスク:石の尖塔がせり上がり、先端から光線が「きゅん」と放たれる。"""
    rise = 0.22
    x = pad(grind(1.0), 1.2)
    beam = layer(whoosh(0, 1.6), chime([3500, 4200, 5000], 0.04, 0.2), -6)
    return layer(x, beam, 0, rise)


def sig_tower():
    """タワー:投石機の腕がきしんで振り上がり、「がこん」と石を放って、石が風を切って飛ぶ。"""
    appear, fling = 0.12, 0.14
    x = pad(rec("creak1.ogg", 0.12, 0.3), 1.2)
    x = layer(x, pitch(rec("impactWood_heavy_000.ogg"), 1.4), 2, appear + fling)
    return layer(x, whoosh(2, 0.7), -4, appear + fling + 0.02)


def sig_anchor():
    """アンカー:錨が鎖を鳴らして沈み、「がん」と食い込んで、金色の響きが味方へ広がる。"""
    sink = 0.26
    x = pad(rec("fs637356_kyles.mp3", 0.55, sink + 0.05, fade_out=0.05), 1.4)
    x = layer(x, rec("impactMetal_heavy_001.ogg"), 3, sink)
    x = layer(x, thump(0.5, 110, 55, 0.12), 0, sink)
    return layer(x, hand_bell(74, 1.0, 1.0), -4, sink + 0.04)


SIGNATURES = [
    sig_freeze, sig_relic, sig_middle, sig_phase, sig_grain, sig_dash, sig_shield, sig_sand,
    sig_watcher, sig_glass, sig_vamp, sig_drill, sig_lance, sig_twin, sig_lock, sig_gate,
    sig_poison, sig_guard, sig_mirror, sig_wall, sig_bypass, sig_colossus,
    sig_obelisk, sig_tower, sig_anchor,
]


if __name__ == "__main__":
    os.makedirs(OUT, exist_ok=True)
    finish("hover", ui_hover, -34, 0.0)
    finish("press", ui_press, -22, 0.04)
    finish("place", place, -19, 0.12)
    finish("flip", flip, -21, 0.12)
    finish("clash", clash, -18, 0.16)
    finish("damage", damage, -17, 0.10)
    finish("unit_break", unit_break, -18, 0.16)
    finish("glass_break", glass_break, -20, 0.16)
    finish("poison_melt", poison_melt, -19, 0.12)
    finish("vessel_shatter", vessel_shatter, -16, 0.2)
    finish("turn_end", turn_end, -26, 0.10)
    finish("turn_start", turn_start, -22, 0.18)
    finish("result_win", result_win, -16, 0.2)
    finish("result_lose", result_lose, -19, 0.2)
    finish("sig_chronos", sig_chronos, -17, 0.18)
    finish("sig_clocktower", sig_clocktower, -18, 0.25)
    finish("match_start", match_start, -18, 0.22)
    finish("turn_order", turn_order, -24, 0.18)
    for make in SIGNATURES:
        finish(make.__name__, make, -18, 0.18)
