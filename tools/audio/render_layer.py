"""Randează un singur strat (cu vocea principală frazată) pe N bucle → WAV stereo 44,1 kHz."""

import sys

import numpy as np
from scipy.io import wavfile

import performer as P
import score as S
import synth

name, loops, bpm, out = sys.argv[1], int(sys.argv[2]), float(sys.argv[3]), sys.argv[4]
mix = P.Mix(64 * 30 / bpm * loops + 2)
P.perform(mix, S.LAYERS[name](), 0.0, bpm, loops=loops)
P.perform_leads(mix, S.LEADS[name], 0.0, bpm, loops=loops)
n = int(64 * 30 / bpm * loops * synth.SR)
stereo = P.master(mix.buf[:, :n])
wavfile.write(out, synth.SR, (stereo.T * 32767).astype(np.int16))
