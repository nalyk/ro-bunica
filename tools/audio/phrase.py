"""Melodie frazată, ca la un lăutar: o singură linie continuă de ton (legato), nu note separate.

Contur de frecvență cu: glissando de jos pe unele note, mordente, triluri pe notele lungi,
vibrato care crește pe notă. Instrumente: vioara lăutărească (arcuș + corp), naiul (aer), acordeonul.
"""

import numpy as np
from scipy import signal

from synth import RNG, SR, midi_hz


def contour(notes, bpm, swing=0.06, seed=0):
    """notes: [(midi, optimi)] → (frecvență pe eșantion, amplitudine pe eșantion, momentele notelor)."""
    rng = np.random.default_rng(seed)
    e = 30 / bpm
    durs = []
    for i, (m, d) in enumerate(notes):
        # swing de horă: optimea a doua din fiecare pătrime puțin întârziată
        durs.append(d * e)
    starts = np.concatenate([[0], np.cumsum(durs)])
    total = starts[-1] + 0.4
    n = int(total * SR)
    midi_curve = np.zeros(n)
    amp = np.zeros(n)
    onsets = []
    t = np.arange(n) / SR
    for i, (m, d) in enumerate(notes):
        s = starts[i] + (swing * e if (round(starts[i] / e) % 2 == 1) else 0)
        end = starts[i + 1] + (swing * e if i + 1 < len(notes) and (round(starts[i + 1] / e) % 2 == 1) else 0)
        a, b = int(s * SR), int(end * SR)
        seg = t[a:b] - s
        L = max(end - s, 1e-3)
        curve = np.full(b - a, float(m))
        prev = notes[i - 1][0] if i else m
        r = rng.random()
        if i and abs(m - prev) >= 3 and r < 0.6:  # glissando de la nota anterioară
            g = min(0.06, L * 0.4)
            curve += (prev - m) * np.clip(1 - seg / g, 0, 1) ** 2
        elif r < 0.22 and L > 0.18:  # mordent: notă vecină de sus, scurtă
            k = (seg > 0.0) & (seg < 0.045)
            curve[k] += 1 if m % 12 in (4, 9, 11) else 2
        if L > 0.45 and rng.random() < 0.5:  # tril pe notă lungă, spre final
            k = seg > L * 0.45
            curve[k] += (np.sin(2 * np.pi * 11 * seg[k]) > 0) * (1 if m % 12 in (4, 9) else 2)
        else:  # vibrato care crește
            depth = np.clip((seg - 0.12) / 0.25, 0, 1) * 0.18
            curve += depth * np.sin(2 * np.pi * 6.2 * seg)
        midi_curve[a:b] = curve
        # articulație: atac rapid, mică scădere la schimbarea arcușului
        art = np.clip(seg / 0.025, 0, 1) * (1 - 0.25 * np.clip(1 - (L - seg) / 0.05, 0, 1))
        accent = 1.0 if round(starts[i] / e) % 4 == 0 else (0.82 if round(starts[i] / e) % 2 == 0 else 0.7)
        amp[a:b] = np.maximum(amp[a:b], art * accent)
        onsets.append(s)
    # finalul frazei: coada notei se stinge
    last = int(starts[-1] * SR)
    amp[last:] = amp[last - 1] * np.exp(-np.arange(n - last) / SR * 12) if last > 0 else 0
    midi_curve[last:] = midi_curve[last - 1]
    # netezire (degetele nu sar instantaneu)
    k = int(0.006 * SR)
    midi_curve = np.convolve(midi_curve, np.ones(k) / k, mode="same")
    amp = np.convolve(amp, np.ones(k) / k, mode="same")
    return midi_hz(midi_curve), amp, onsets


def _additive_saw(freq, harmonics=40, tilt=1.0):
    phase = 2 * np.pi * np.cumsum(freq) / SR
    y = np.zeros_like(freq)
    fmax = freq.max()
    for h in range(1, harmonics + 1):
        if h * fmax > SR / 2.3:
            break
        y += np.sin(h * phase) / h**tilt
    return y


def vioara(notes, bpm, vel=1.0, seed=0):
    """Vioara lăutărească: undă de arcuș (dinte de fierăstrău) + zgomot de arcuș + corpul viorii."""
    f, amp, onsets = contour(notes, bpm, seed=seed)
    n = len(f)
    # stick-slip: arcușul nu e perfect periodic — mică instabilitate de perioadă și de amplitudine
    jit = signal.lfilter([0.01], [1, -0.99], RNG.normal(0, 1, n))
    f = f * (1 + 0.0025 * jit / (np.abs(jit).max() + 1e-9))
    shimmer = 1 + 0.06 * signal.lfilter([0.02], [1, -0.98], RNG.normal(0, 1, n)) / 0.2
    saw = _additive_saw(f, 48, 1.0) * shimmer
    t = np.arange(n) / SR
    rosin = np.zeros(n)
    for s0 in onsets:  # „scârțâitul” sacâzului la atacul arcușului
        k = (t >= s0) & (t < s0 + 0.06)
        rosin[k] = RNG.normal(0, 1, k.sum()) * np.exp(-(t[k] - s0) * 45)
    b, a = signal.butter(2, [1200 / (SR / 2), 7000 / (SR / 2)], "band")
    bow = RNG.normal(0, 1, n) * 0.05 * (0.4 + amp)
    x = saw + signal.lfilter(b, a, bow + rosin * 0.5)
    body = np.zeros_like(x)
    # moduri de corp ale viorii + „dealul podului” (2–3 kHz) care dă strălucirea fără nazalitate
    for fc, q, g in [(275, 8, 0.8), (430, 9, 0.9), (550, 7, 0.5), (900, 4, 0.35), (1300, 5, 0.3),
                     (2200, 2.2, 0.75), (2900, 2.5, 0.55), (4200, 3, 0.25)]:
        bb, aa = signal.iirpeak(fc / (SR / 2), q)
        body += g * signal.lfilter(bb, aa, x)
    y = 0.08 * x + body
    bb, aa = signal.butter(2, 6500 / (SR / 2))
    y = signal.lfilter(bb, aa, y)
    return (y * amp * vel * 0.32).astype(np.float32)


def nai_frazat(notes, bpm, vel=1.0, seed=0):
    f, amp, onsets = contour(notes, bpm, seed=seed + 1)
    phase = 2 * np.pi * np.cumsum(f) / SR
    tone = np.sin(phase) + 0.18 * np.sin(2 * phase) + 0.07 * np.sin(3 * phase)
    noise = RNG.normal(0, 1, len(f))
    breath = np.zeros_like(noise)
    blk = 512
    for i in range(0, len(f), blk):  # aerul urmărește tonul (filtru mobil)
        bb, aa = signal.iirpeak(min(f[i] * 1.0, SR / 2.3) / (SR / 2), 4)
        breath[i : i + blk] = signal.lfilter(bb, aa, noise[i : i + blk])
    t = np.arange(len(f)) / SR
    chiff = np.zeros_like(f)
    for s in onsets:  # „ciuf” de atac: suflu scurt la începutul notei
        k = (t >= s) & (t < s + 0.05)
        chiff[k] = RNG.normal(0, 1, k.sum()) * np.exp(-(t[k] - s) * 70)
    bb, aa = signal.butter(2, [1500 / (SR / 2), 8000 / (SR / 2)], "band")
    y = tone * 0.8 + breath * 0.45 + signal.lfilter(bb, aa, chiff) * 0.6
    return (y * amp * vel * 0.42).astype(np.float32)


def acordeon_frazat(notes, bpm, vel=1.0, seed=0, musette=12):
    f, amp, _ = contour(notes, bpm, seed=seed + 2)
    y = (_additive_saw(f, 24, 0.85) + 0.7 * _additive_saw(f * 2 ** (musette / 1200), 24, 0.85)
         + 0.7 * _additive_saw(f * 2 ** (-musette / 1200), 24, 0.85))
    b, a = signal.butter(2, [250 / (SR / 2), 4000 / (SR / 2)], "band")
    return (signal.lfilter(b, a, y) * amp * vel * 0.16).astype(np.float32)
