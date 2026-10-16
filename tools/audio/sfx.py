"""Efectele sonore ale satului, sintetizate și acordate în Re (ca să cadă în armonia muzicii).

Fiecare efect e o funcție → mono float32. Jocul le cântă pe ritm (cuantizate la șaisprezecime).
"""

import numpy as np
from scipy import signal

import synth
from synth import RNG, SR


def _t(sec):
    return np.arange(int(sec * SR)) / SR


def _bp(x, lo, hi, order=2):
    b, a = signal.butter(order, [lo / (SR / 2), hi / (SR / 2)], "band")
    return signal.lfilter(b, a, x)


def _place(out, y, at, gain=1.0):
    i = int(at * SR)
    n = min(len(y), len(out) - i)
    out[i : i + n] += y[:n] * gain
    return out


def pleosc():
    """PLEOSC!: plesnitura de piele, bufnitura corpului, „flap”-ul de cauciuc, apoi drâmba comică."""
    out = np.zeros(int(1.6 * SR))
    t = _t(0.25)
    slap = _bp(RNG.normal(0, 1, len(t)), 900, 4200) * np.exp(-t * 55) * 1.4
    crack = RNG.normal(0, 1, len(t)) * np.exp(-t * 400) * 0.8
    thump = np.sin(2 * np.pi * np.cumsum(90 * (1 + 1.2 * np.exp(-t * 25))) / SR) * np.exp(-t * 14)
    flap = np.sin(2 * np.pi * np.cumsum(260 * np.exp(-t * 9)) / SR) * np.exp(-t * 20) * 0.6
    _place(out, slap + _bp(crack, 3000, 9000) + thump + flap, 0)
    _place(out, synth.drimba(38, 1.1, 1.0, sweep=(400, 2400, 600)), 0.12, 1.1)
    _place(out, synth.tambal(86, 0.8, 0.5), 0.12, 0.5)
    return out


def whoosh(dur=0.45):
    """Papucul zboară: zgomot cu filtru care urcă și coboară (efect Doppler)."""
    t = _t(dur)
    noise = RNG.normal(0, 1, len(t))
    fc = 600 + 2200 * np.sin(np.pi * t / dur) ** 2
    out = np.zeros_like(t)
    blk = 256
    for i in range(0, len(t), blk):
        b, a = signal.iirpeak(fc[i] / (SR / 2), 2.5)
        out[i : i + blk] = signal.lfilter(b, a, noise[i : i + blk])
    return out * np.sin(np.pi * t / dur) ** 1.5 * 0.9


def miss():
    """Ratare: papucul cade în iarbă — bufnitură moale și un „pfff” de acordeon dezamăgit."""
    out = np.zeros(int(0.9 * SR))
    t = _t(0.2)
    _place(out, _bp(RNG.normal(0, 1, len(t)), 150, 900) * np.exp(-t * 25), 0)
    _place(out, synth.accordion(49, 0.5, 0.6), 0.15, 0.7)  # do diez grav: „buhuhu”
    _place(out, synth.accordion(50, 0.35, 0.5), 0.15, 0.4)
    return out


def caught():
    """Hoțul e prins: țambal care coboară cromatic „vai-vai-vai” + drâmbă."""
    out = np.zeros(int(1.8 * SR))
    for i, m in enumerate([74, 73, 72, 71]):
        _place(out, synth.tambal(m, 1.0, 0.7), i * 0.16)
    _place(out, synth.drimba(38, 1.0, 0.9, sweep=(1800, 600, 300)), 0.62, 1.0)
    return out


def coin():
    out = np.zeros(int(0.8 * SR))
    _place(out, synth.clopotel(synth.midi_hz(93), 0.5, 0.8), 0)
    _place(out, synth.clopotel(synth.midi_hz(98), 0.7, 0.9), 0.07)
    return out


def tap():
    return synth.lemn(1180, 0.12, 0.9)


def confirm():
    out = np.zeros(int(0.9 * SR))
    _place(out, synth.cobza(69, 0.6, 0.9), 0)
    _place(out, synth.cobza(74, 0.8, 1.0), 0.08)
    return out


def error():
    out = np.zeros(int(0.6 * SR))
    _place(out, synth.accordion(51, 0.35, 0.8), 0)
    _place(out, synth.accordion(52, 0.35, 0.6), 0)
    return out


def open_panel():
    out = np.zeros(int(1.0 * SR))
    for i, m in enumerate([62, 65, 69, 74]):
        _place(out, synth.tambal(m, 0.9, 0.55), i * 0.035)
    return out


def close_panel():
    out = np.zeros(int(1.0 * SR))
    for i, m in enumerate([74, 69, 65, 62]):
        _place(out, synth.tambal(m, 0.9, 0.45), i * 0.035)
    return out


def reward(level=1):
    """Recompensă pe niveluri: 1 obișnuit, 2 rar, 3 legendar (rulada, naiul, clopoțeii)."""
    out = np.zeros(int(3.0 * SR))
    notes = [62, 65, 69, 74] + ([77, 81] if level >= 2 else [])
    for i, m in enumerate(notes):
        _place(out, synth.tambal(m, 1.6, 0.7), i * 0.07)
    if level >= 2:
        _place(out, synth.tambal_roll(86, 0.8, vel=0.5), len(notes) * 0.07, 0.6)
    if level >= 3:
        nai = synth.nai(86, 1.4, 0.8)
        _place(out, nai, 0.5, 0.9)
        for i in range(8):
            _place(out, synth.clopotel(synth.midi_hz(98 + [0, 3, 7, 12][i % 4]), 0.6, 0.5), 0.6 + i * 0.09)
    return out


def harvest_pop():
    t = _t(0.3)
    pop = np.sin(2 * np.pi * np.cumsum(300 + 900 * (1 - np.exp(-t * 30))) / SR) * np.exp(-t * 22)
    out = np.zeros(int(0.7 * SR))
    _place(out, pop * 0.8, 0)
    _place(out, synth.clopotel(synth.midi_hz(93), 0.5, 0.5), 0.05)
    return out


def plant():
    t = _t(0.25)
    dirt = _bp(RNG.normal(0, 1, len(t)), 200, 2500) * np.exp(-t * 18) * (1 + 0.5 * np.sin(2 * np.pi * 37 * t))
    out = np.zeros(int(0.5 * SR))
    _place(out, dirt * 0.7, 0)
    _place(out, synth.lemn(620, 0.12, 0.6), 0.1)
    return out


def alarm():
    """Alarma de hoț: acordeonul umflă un acord tensionat, doba bate de trei ori."""
    out = np.zeros(int(1.6 * SR))
    for m in (50, 56, 62, 68):
        _place(out, synth.accordion(m, 1.0, 0.6), 0)
    for i in range(3):
        _place(out, synth.doba(0.4, 1.0, 70, 0.4), 0.0 + i * 0.25)
    return out


def sneeze_sting():
    """Bunica strănută: acordeonul „inspiră” (crescendo), apoi plesnește un acord + țambal."""
    out = np.zeros(int(1.5 * SR))
    swell = synth.accordion(57, 0.6, 0.5) * np.linspace(0.1, 1, int(0.6 * SR))[: len(synth.accordion(57, 0.6, 0.5))]
    _place(out, swell, 0)
    for m in (50, 57, 62, 65):
        _place(out, synth.cobza(m, 0.6, 1.0), 0.6)
    _place(out, synth.doba(0.3, 1.1, 120, 0.8), 0.6)
    return out


def hora_clap():
    t = _t(0.12)
    return _bp(RNG.normal(0, 1, len(t)), 800, 3500) * (np.exp(-t * 60) + 0.5 * np.exp(-np.maximum(t - 0.012, 0) * 70)) * 0.9


def crickets(dur=8.0):
    """Greierii nopții (buclă): ciripituri amplitudine-modulate la ~4,4 kHz, câteva voci independente."""
    t = _t(dur)
    out = np.zeros_like(t)
    for k in range(5):
        f = 4200 + 400 * RNG.random()
        rate = 2.5 + 2 * RNG.random()
        pulses = (np.sin(2 * np.pi * rate * t + RNG.random() * 6) > 0.6).astype(float)
        chirp = np.sin(2 * np.pi * f * t) * (0.5 + 0.5 * np.sin(2 * np.pi * 45 * t)) * pulses
        out += chirp * (0.15 + 0.1 * RNG.random())
    fade = np.minimum(1, np.minimum(t, dur - t) / 0.3)
    return out * fade * 0.5


def wind(dur=8.0):
    t = _t(dur)
    noise = RNG.normal(0, 1, len(t))
    slow = 0.5 + 0.5 * np.sin(2 * np.pi * 0.13 * t) * np.sin(2 * np.pi * 0.07 * t + 1)
    out = _bp(noise, 150, 900) * (0.3 + 0.7 * slow)
    fade = np.minimum(1, np.minimum(t, dur - t) / 0.5)
    return out * fade * 0.5


def rain(dur=8.0):
    t = _t(dur)
    out = _bp(RNG.normal(0, 1, len(t)), 1500, 9000) * 0.25
    for _ in range(int(dur * 40)):  # picături
        at = RNG.random() * (dur - 0.05)
        tt = _t(0.03)
        drop = np.sin(2 * np.pi * (2000 + 3000 * RNG.random()) * tt) * np.exp(-tt * 200) * RNG.random()
        _place(out, drop * 0.6, at)
    fade = np.minimum(1, np.minimum(t, dur - t) / 0.3)
    return out * fade


SFX = {
    "pleosc": pleosc, "whoosh": whoosh, "miss": miss, "caught": caught, "coin": coin, "tap": tap,
    "confirm": confirm, "error": error, "open": open_panel, "close": close_panel,
    "reward1": lambda: reward(1), "reward2": lambda: reward(2), "reward3": lambda: reward(3),
    "harvest": harvest_pop, "plant": plant, "alarm": alarm, "sneeze": sneeze_sting, "clap": hora_clap,
    "crickets": crickets, "wind": wind, "rain": rain,
}
