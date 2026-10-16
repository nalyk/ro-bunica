"""Sinteză fizică pentru instrumentele satului (fără mostre, fără SoundFont-uri: totul e calculat).

Instrumente: țambal (coarde lovite, 3 coarde pe notă), cobză (ciupită), contrabas (pizzicato),
acordeon (ancii cu „musette”), nai (aer + armonice), dobă (membrană modală), drâmbă (jaw harp),
lemn (toacă/clopot de lemn), clopoțel (moduri neperiodice).
Toate întorc mono float32 la SR; mixajul și reverberația sunt în mix.py.
"""

import numpy as np
from scipy import signal

SR = 44100
RNG = np.random.default_rng(7)


def midi_hz(m):
    return 440.0 * 2 ** ((m - 69) / 12)


def env_adsr(n, a=0.005, d=0.1, s=0.7, r=0.1, hold=None):
    a_n, d_n, r_n = int(a * SR), int(d * SR), int(r * SR)
    hold_n = n - a_n - d_n - r_n if hold is None else int(hold * SR)
    hold_n = max(hold_n, 0)
    e = np.concatenate([np.linspace(0, 1, a_n, endpoint=False), np.linspace(1, s, d_n, endpoint=False),
                        np.full(hold_n, s), np.linspace(s, 0, r_n)])
    return np.pad(e, (0, max(0, n - len(e))))[:n]


def _ks(freq, dur, excitation, decay=0.996, bright=0.5):
    """Karplus-Strong cu întârziere fracționară (allpass) — acordaj exact la orice înălțime."""
    n = int(dur * SR)
    period = SR / freq - (1 - bright)  # filtrul trece-jos din buclă întârzie cu (1 - bright) eșantioane
    N = int(np.floor(period))
    frac = period - N
    c = (1 - frac) / (1 + frac)  # allpass de ordinul 1
    # buclă: H(z) = g * z^-N * lowpass(z) * allpass(z)
    # lowpass = (bright + (1-bright) z^-1) (bright=0.5 => medie clasică)
    lp = np.array([bright, 1 - bright])
    ap_b = np.array([c, 1.0])
    ap_a = np.array([1.0, c])
    loop_num = decay * np.convolve(lp, ap_b)  # înmulțit cu z^-N
    den = np.zeros(N + len(loop_num))
    den[:2] += ap_a
    den[N : N + len(loop_num)] -= loop_num
    x = np.zeros(n)
    x[: len(excitation)] = excitation[: n]
    y = signal.lfilter(ap_a, den, x)
    return y


def _burst(freq, kind="pluck", width=None):
    p = int(SR / freq)
    b = RNG.uniform(-1, 1, p)
    if kind == "hammer":  # ciocănel: mai strălucitor, scurt
        b = signal.lfilter([1, -0.6], [1], b)
    elif kind == "soft":
        b = signal.lfilter([0.5, 0.5], [1], b)
    return b


def tambal(m, dur=2.5, vel=1.0):
    """Țambal: trei coarde ușor dezacordate, lovite cu ciocănelul; sustain lung, metalic."""
    f = midi_hz(m)
    out = np.zeros(int(dur * SR))
    for cents in (-3.5, 0, 4.0):
        ff = f * 2 ** (cents / 1200)
        out += _ks(ff, dur, _burst(ff, "hammer") * vel, decay=0.9985 - 0.00002 * (m - 50), bright=0.62)
    # zgomotul ciocănelului
    click = RNG.uniform(-1, 1, 220) * np.exp(-np.linspace(0, 8, 220)) * 0.25 * vel
    out[:220] += signal.lfilter([1, -0.9], [1], click)
    return (out / 3).astype(np.float32)


def tambal_roll(m, dur=1.2, rate=16, vel=0.7):
    """Tremolo de țambal (rulada), semnătura stilului lăutăresc."""
    out = np.zeros(int((dur + 1.5) * SR))
    t = 0.0
    k = 0
    while t < dur:
        v = vel * (0.75 + 0.25 * (k % 2)) * (0.9 + 0.2 * RNG.random())
        note = tambal(m, 1.5, v)
        i = int(t * SR)
        out[i : i + len(note)] += note[: len(out) - i]
        t += 1 / rate * (0.95 + 0.1 * RNG.random())
        k += 1
    return out.astype(np.float32)


def cobza(m, dur=1.2, vel=1.0):
    """Cobză: coarde dublate ciupite cu pana (atac uscat), cutie de rezonanță scurtă, fără coada chitarei."""
    f = midi_hz(m)
    n = int(dur * SR)
    out = np.zeros(n)
    for cents in (-6, 5):  # coarde dublate, ușor dezacordate (zornăitul specific)
        ff = f * 2 ** (cents / 1200)
        exc = _burst(ff, "hammer")[: max(8, int(SR / ff * 0.6))] * vel
        out += _ks(ff, dur, exc, decay=0.990, bright=0.58)
    t = np.arange(n) / SR
    pick = RNG.normal(0, 1, n) * np.exp(-t * 400) * 0.35 * vel
    b, a = signal.butter(2, [2000 / (SR / 2), 8000 / (SR / 2)], "band")
    out += signal.lfilter(b, a, pick)
    body = np.zeros(n)
    for fc, q, g in [(190, 5, 0.5), (390, 6, 0.4), (1800, 3, 0.2)]:
        bb, aa = signal.iirpeak(fc / (SR / 2), q)
        body += g * signal.lfilter(bb, aa, out)
    out = out + body
    hb, ha = signal.butter(2, 160 / (SR / 2), "high")
    return (signal.lfilter(hb, ha, out) / 2 * np.exp(-t * 2.5)).astype(np.float32)


def bass(m, dur=0.6, vel=1.0):
    f = midi_hz(m)
    y = _ks(f, dur, _burst(f, "soft") * vel, decay=0.993, bright=0.5)
    y *= env_adsr(len(y), 0.002, 0.05, 1.0, min(0.15, dur / 3))
    b, a = signal.butter(2, 900 / (SR / 2))
    y = signal.lfilter(b, a, y * 1.6)
    # palma pe coardă și lemnul instrumentului
    n = len(y)
    t = np.arange(n) / SR
    thump = np.sin(2 * np.pi * f * t) * np.exp(-t * 18) * 0.5 + np.sin(2 * np.pi * 2 * f * t) * np.exp(-t * 30) * 0.2
    slap = RNG.normal(0, 1, n) * np.exp(-t * 300) * 0.12
    bb, aa = signal.iirpeak(140 / (SR / 2), 3)
    return (y + thump * vel + signal.lfilter(bb, aa, slap) * vel).astype(np.float32)


def _reed(f, n, harmonics=24):
    t = np.arange(n) / SR
    y = np.zeros(n)
    for h in range(1, harmonics + 1):
        if f * h > SR / 2.2:
            break
        amp = 1 / h ** 0.9 * (1.25 if h % 2 else 0.85)  # ancia: puțin mai multe armonice impare
        y += amp * np.sin(2 * np.pi * f * h * t + RNG.random() * 6.28)
    return y


def accordion(m, dur=0.5, vel=1.0, musette=12):
    """Acordeon: 3 ancii (una acordată, două ±musette cenți) → „bătăi” calde, cu burduf."""
    n = int(dur * SR)
    f = midi_hz(m)
    y = _reed(f, n) + 0.7 * _reed(f * 2 ** (musette / 1200), n) + 0.7 * _reed(f * 2 ** (-musette / 1200), n)
    y += 0.35 * _reed(f / 2, n, 12)  # registru de bas (16')
    bellows = env_adsr(n, 0.03, 0.08, 0.85, 0.06) * (1 + 0.04 * np.sin(2 * np.pi * 5.2 * np.arange(n) / SR))
    # formanta cutiei
    b, a = signal.butter(2, [300 / (SR / 2), 4200 / (SR / 2)], "band")
    return (signal.lfilter(b, a, y * bellows) * 0.22 * vel).astype(np.float32)


def nai(m, dur=0.8, vel=1.0, vib=True):
    """Nai (fluier de pan): sinus cu puține armonice, aer filtrat, „chiff” la atac, vibrato întârziat."""
    n = int(dur * SR)
    t = np.arange(n) / SR
    f = midi_hz(m)
    vib_depth = np.clip((t - 0.25) / 0.3, 0, 1) * 0.012 if vib else 0
    phase = 2 * np.pi * np.cumsum(f * (1 + vib_depth * np.sin(2 * np.pi * 5.5 * t))) / SR
    tone = np.sin(phase) + 0.12 * np.sin(2 * phase) + 0.05 * np.sin(3 * phase)
    noise = RNG.normal(0, 1, n)
    b, a = signal.iirpeak(min(f, SR / 2.3) / (SR / 2), 6)
    breath = signal.lfilter(b, a, noise) * 0.35
    chiff = RNG.normal(0, 1, n) * np.exp(-t * 40) * 0.25
    e = env_adsr(n, 0.04, 0.1, 0.8, min(0.12, dur / 3))
    return ((tone + breath + chiff) * e * 0.5 * vel).astype(np.float32)


def doba(dur=0.5, vel=1.0, pitch=70, snare=0.0):
    """Dobă: membrană circulară (rapoarte Bessel), cu ușoară cădere de ton; opțional „sârmă”."""
    n = int(dur * SR)
    t = np.arange(n) / SR
    ratios = [1.0, 1.59, 2.14, 2.30, 2.65, 2.92]
    y = np.zeros(n)
    bend = 1 + 0.25 * np.exp(-t * 30)
    for i, r in enumerate(ratios):
        y += np.sin(2 * np.pi * np.cumsum(pitch * r * bend) / SR) * np.exp(-t * (6 + 9 * i)) / (1 + i)
    hit = RNG.normal(0, 1, n) * np.exp(-t * 60) * 0.3
    if snare:
        b, a = signal.butter(2, [1500 / (SR / 2), 7000 / (SR / 2)], "band")
        hit += signal.lfilter(b, a, RNG.normal(0, 1, n)) * np.exp(-t * 18) * snare
    return ((y + hit) * 0.6 * vel).astype(np.float32)


def lemn(pitch=900, dur=0.15, vel=1.0):
    """Toacă / clopot de lemn: moduri neperiodice, amortizare rapidă."""
    n = int(dur * SR)
    t = np.arange(n) / SR
    y = sum(np.sin(2 * np.pi * pitch * r * t) * np.exp(-t * d) * a
            for r, d, a in [(1, 45, 1), (2.76, 70, 0.4), (5.4, 110, 0.2)])
    return (y * vel * 0.7).astype(np.float32)


def clopotel(pitch=2100, dur=0.9, vel=1.0):
    n = int(dur * SR)
    t = np.arange(n) / SR
    y = sum(np.sin(2 * np.pi * pitch * r * t) * np.exp(-t * d) * a
            for r, d, a in [(1, 5, 1), (2.32, 8, 0.5), (4.25, 12, 0.3), (6.63, 20, 0.15)])
    return (y * vel * 0.5).astype(np.float32)


def drimba(m, dur=0.9, vel=1.0, sweep=(500, 2200, 700)):
    """Drâmbă: lamelă bâzâitoare (impulsuri) + gura ca filtru formantic care se mișcă → „boiiing”."""
    n = int(dur * SR)
    t = np.arange(n) / SR
    f = midi_hz(m)
    phase = (f * t) % 1.0
    buzz = np.where(phase < 0.08, 1.0, 0.0) - 0.08
    buzz *= np.exp(-t * 2.5)
    lo, hi, end = sweep
    fc = np.interp(t, [0, dur * 0.3, dur], [lo, hi, end])
    y = np.zeros(n)
    blk = 256
    zi = None
    for i in range(0, n, blk):
        b, a = signal.iirpeak(fc[i] / (SR / 2), 5)
        seg, zi = signal.lfilter(b, a, buzz[i : i + blk], zi=zi if zi is not None else signal.lfilter_zi(b, a) * 0)
        y[i : i + blk] = seg
    return (y * vel * 1.4).astype(np.float32)
