"""Interpretul de previzualizare: cântă partitura cu instrumentele sintetizate, cum o va face jocul.

Ce face un lăutar și facem și noi: notă de apogiatură pe unele note de melodie, ușoară umanizare
a timpului și intensității, strum la cobză, tempo care se poate accelera (hora).
"""

import functools

import numpy as np
from scipy import signal

import synth
from synth import SR

RNG = np.random.default_rng(11)
PAN = {"acc_chord": -0.3, "vioara": 0.0, "acordeon": -0.25, "accordion": -0.25, "cobza": 0.35, "bass": 0.0, "nai": -0.15, "tambal": 0.3, "tambal_roll": 0.3,
       "doba": 0.05, "lemn": 0.4, "clopotel": 0.2, "drimba": 0.0}
MELODIC = {"accordion", "nai", "tambal"}


@functools.lru_cache(maxsize=4096)
def voice(instr, note, eighths, vel_q, bpm_q):
    vel = vel_q / 20
    e = 30 / bpm_q
    if instr == "accordion":
        return synth.accordion(note, max(0.12, eighths * e * 0.95), vel)
    if instr == "nai":
        return synth.nai(note, eighths * e + 0.15, vel)
    if instr == "tambal":
        return synth.tambal(note, 2.0, vel)
    if instr == "tambal_roll":
        return synth.tambal_roll(note, eighths * e, vel=vel)
    if instr == "acc_chord":
        y = synth.accordion(note, 0.11, vel)
        hb, ha = signal.butter(2, 180 / (SR / 2), "high")
        return signal.lfilter(hb, ha, y).astype(np.float32)
    if instr == "cobza":
        return synth.cobza(note, 0.9, vel)
    if instr == "bass":
        return synth.bass(note, max(0.25, eighths * e), vel)
    if instr == "doba":
        pitch, snare = {0: (65, 0.0), 1: (95, 0.25), 2: (150, 0.7)}[note]
        return synth.doba(0.45, vel, pitch, snare)
    if instr == "lemn":
        return synth.lemn(880, 0.15, vel)
    if instr == "clopotel":
        return synth.clopotel(synth.midi_hz(note), 0.9, vel)
    if instr == "drimba":
        return synth.drimba(note, 0.9, vel)
    raise ValueError(instr)


class Mix:
    def __init__(self, seconds):
        self.buf = np.zeros((2, int(seconds * SR) + SR * 4), np.float32)

    def add(self, y, t, pan=0.0, gain=1.0):
        i = int(t * SR)
        if i < 0 or i >= self.buf.shape[1]:
            return
        n = min(len(y), self.buf.shape[1] - i)
        l, r = np.cos((pan + 1) * np.pi / 4), np.sin((pan + 1) * np.pi / 4)
        self.buf[0, i : i + n] += y[:n] * l * gain
        self.buf[1, i : i + n] += y[:n] * r * gain


def eighth_times(n, bpm0, bpm1):
    """Momentele de start ale fiecărei optimi, cu tempo care trece liniar de la bpm0 la bpm1."""
    bpm = np.linspace(bpm0, bpm1, n + 1)
    dur = 30 / bpm[:-1]
    return np.concatenate([[0], np.cumsum(dur)])


def perform(mix, events, t0, bpm0, bpm1=None, gain=1.0, loops=1, ornaments=True, length=64):
    bpm1 = bpm1 or bpm0
    total = length * loops
    times = eighth_times(total, bpm0, bpm1)
    for lp in range(loops):
        for start, instr, note, dur, vel in events:
            k = lp * length + start
            t = t0 + times[k] + RNG.normal(0, 0.006)
            if k % 2 == 1:  # swing de horă: contratimpul puțin întârziat
                t += 0.06 * (times[k + 1] - times[k])
            beat_accent = 1.0 if k % 4 == 0 else (0.85 if k % 2 == 0 else 0.75)
            bpm_here = bpm0 + (bpm1 - bpm0) * k / total
            v = float(np.clip(vel * beat_accent * RNG.normal(1, 0.1), 0.05, 1.2))
            if instr == "cobza":  # strum: notele acordului cad una după alta
                t += (note % 12) * 0.0025
            if ornaments and instr in MELODIC and RNG.random() < 0.18:
                grace = note + (2 if note % 12 in (2, 9) else 1)
                mix.add(voice(instr, grace, 1, int(v * 12), int(bpm_here)), t - 0.045, PAN[instr], gain * 0.6)
            mix.add(voice(instr, note, dur, int(v * 20), int(bpm_here)), t, PAN.get(instr, 0), gain)
    return t0 + times[-1]


def reverb(stereo, seconds=0.8, wet=0.12):
    """Reverberație sintetică de ogradă: zgomot care se stinge, cu înalte atenuate în timp."""
    n = int(seconds * SR)
    t = np.arange(n) / SR
    out = []
    for ch in range(2):
        ir = RNG.normal(0, 1, n) * np.exp(-t * 6.9 / seconds)
        b, a = signal.butter(1, 5000 / (SR / 2))
        ir = signal.lfilter(b, a, ir)
        ir[: int(0.012 * SR)] = 0  # pre-delay
        ir /= np.sqrt((ir**2).sum())
        out.append(signal.fftconvolve(stereo[ch], ir)[: stereo.shape[1]])
    return stereo * (1 - wet) + np.array(out) * wet * 2.2


def peq(x, fc, gain_db, q=1.0):
    A = 10 ** (gain_db / 40)
    w = 2 * np.pi * fc / SR
    al = np.sin(w) / (2 * q)
    b = [1 + al * A, -2 * np.cos(w), 1 - al * A]
    a = [1 + al / A, -2 * np.cos(w), 1 - al / A]
    return signal.lfilter(b, a, x)


def master(stereo, target_peak=0.89):
    stereo = np.array([peq(peq(ch, 3200, -4, 0.9), 90, 3, 0.8) for ch in stereo])
    stereo = reverb(stereo)
    # compresie blândă (lipire) + limitare
    env = np.maximum(np.abs(stereo[0]), np.abs(stereo[1]))
    env = signal.lfilter([0.002], [1, -0.998], env)
    gain = np.where(env > 0.35, (0.35 / np.maximum(env, 1e-9)) ** 0.4, 1.0)
    stereo = stereo * gain
    return stereo / (np.abs(stereo).max() + 1e-9) * target_peak


def perform_leads(mix, leads, t0, bpm, loops=1, gain=1.0, seed=0):
    import phrase
    import score as S

    fn = {"vioara": phrase.vioara, "nai": phrase.nai_frazat, "acordeon": phrase.acordeon_frazat}
    for lp in range(loops):
        for instr, octave, sparse, vel in leads:
            notes = S.melody_notes(octave, sparse)
            y = fn[instr](notes, bpm, vel, seed=seed + lp)
            mix.add(y, t0 + lp * 64 * 30 / bpm, PAN.get(instr, 0), gain)
