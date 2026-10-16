"""Previzualizare: o „poveste” de ~90 s care arată cum se adaptează muzica la joc."""

import subprocess
import sys

import numpy as np
from scipy.io import wavfile

import performer as P
import score as S
import synth

out = sys.argv[1]
mix = P.Mix(110)
L = {k: f() for k, f in S.LAYERS.items()}
BAR = 2 * 60 / 120  # o măsură de 2/4 la 120 BPM


def section(names, t, bpm=120, gains=None, loops=1):
    end = t
    for name in names:
        g = (gains or {}).get(name, 1.0)
        end = P.perform(mix, L[name], t, bpm, gain=g, loops=loops)
        P.perform_leads(mix, S.LEADS[name], t, bpm, loops=loops, gain=g, seed=hash(name) % 100)
    return end


t = section(["zi"], 0.0)  # 1. ziua
t = section(["noapte"], t)  # 2. noaptea
t = section(["noapte", "pericol"], t, gains={"pericol": 0.85})  # 3. hoțul
# 4. urmărire, apoi PLEOSC!: stop-time comic — muzica tace 1/4 de măsură, papucul, apoi drâmba
chase_end = t + 6 * BAR
P.perform(mix, [e for e in L["urmarire"] if e[0] < 24], t, 120, gain=0.9)
P.perform(mix, [e for e in L["noapte"] if e[0] < 24], t, 120)
hit = chase_end
slap = synth.doba(0.35, 1.4, 50, 1.0)
slap[: int(0.12 * synth.SR)] += synth.lemn(420, 0.12, 1.2)[: int(0.12 * synth.SR)]
mix.add(slap, hit, 0, 1.3)
mix.add(synth.drimba(38, 1.1, 1.1), hit + 0.12, 0, 1.6)
mix.add(synth.tambal_roll(86, 0.45, vel=0.7), hit + 0.55, 0.3, 0.9)
t = hit + 2 * BAR
# 5. hora: tempoul urcă pe trepte, la fiecare buclă (ca jocul, cu fiecare dansator în plus)
# accelerando pe fraze de 4 măsuri (+6 BPM la fiecare), cu toaca marcând fiecare treaptă
bpm = 120
for rep in range(2):
    for ph in range(4):
        ev = [(s - ph * 16, i, n, d, v) for (s, i, n, d, v) in L["hora"] if ph * 16 <= s < ph * 16 + 16]
        t_end = P.perform(mix, ev, t, bpm, length=16)
        import phrase

        notes = S.melody_notes(0)
        acc, sel = 0, []
        for nn, dd in notes:
            if ph * 16 <= acc < ph * 16 + 16:
                sel.append((nn, dd))
            acc += dd
        mix.add(phrase.vioara(sel, bpm, 1.0, seed=ph + rep * 4), t, 0.0, 1.0)
        mix.add(phrase.acordeon_frazat([(nn - 12, dd) for nn, dd in sel], bpm, 0.5, seed=ph), t, -0.25, 1.0)
        mix.add(synth.lemn(1200, 0.12, 0.6), t, 0.4, 0.8)
        t = t_end
        bpm += 6
stereo = P.master(mix.buf[:, : int((t + 2) * synth.SR)])
wavfile.write(out + ".wav", synth.SR, (stereo.T * 32767).astype(np.int16))
subprocess.run(["ffmpeg", "-y", "-loglevel", "error", "-i", out + ".wav", "-b:a", "160k", out + ".mp3"])
print("durată", round(t, 1))
