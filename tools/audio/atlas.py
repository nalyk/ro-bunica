"""Atlasul audio: toate sunetele jocului într-un singur fișier, cu regiuni numite.

De ce: o singură încărcare (audio nu se poate actualiza, iar contul are o limită lunară), o singură
descărcare pe client. Jocul cântă o regiune cu AudioPlayer.PlaybackRegion + Play(atTime).

Straturile muzicale se randează pe 2 bucle și se păstrează a doua: coada reverberației din bucla
anterioară e inclusă, deci bucla se leagă perfect cu ea însăși.

  python3 atlas.py <director-ieșire>   → atlas.ogg, atlas.json, src/shared/Config/AudioAtlas.luau
"""

import json
import os
import subprocess
import sys

import numpy as np
from scipy.io import wavfile

import performer as P
import score as S
import sfx
import synth
from synth import SR

ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
GAP = 0.35  # liniște între regiuni (PlaybackRegion nu „sângerează” în vecini)
HORA_TEMPOS = (120, 132, 144, 156)
OVERRIDES = os.path.join(ROOT, "art", "audio", "stems")  # stem-uri recântate (ACE-Step), dacă există


def layer_loop(name, bpm):
    override = os.path.join(OVERRIDES, f"{name}_{bpm}.wav")
    loop_n = int(round(64 * 30 / bpm * SR))
    if os.path.exists(override):
        sr, data = wavfile.read(override)
        assert sr == SR, override
        y = data.astype(np.float32).T / 32768.0
        if y.ndim == 1:
            y = np.stack([y, y])
        return y[:, :loop_n]
    mix = P.Mix(64 * 30 / bpm * 2 + 2)
    P.perform(mix, S.LAYERS[name](), 0.0, bpm, loops=2)
    P.perform_leads(mix, S.LEADS[name], 0.0, bpm, loops=2)
    stereo = P.master(mix.buf[:, : 2 * loop_n + SR], target_peak=0.8)
    return stereo[:, loop_n : 2 * loop_n]


def mono_to_stereo(y, peak=0.85):
    y = y / (np.abs(y).max() + 1e-9) * peak
    return np.stack([y, y]).astype(np.float32)


def build(out_dir):
    clips = {}
    for name in ("zi", "noapte", "pericol", "urmarire"):
        clips[f"music.{name}"] = (layer_loop(name, 120), {"loop": True, "bpm": 120, "layer": name})
    for bpm in HORA_TEMPOS:
        clips[f"music.hora.{bpm}"] = (layer_loop("hora", bpm), {"loop": True, "bpm": bpm, "layer": "hora"})
    for name, fn in sfx.SFX.items():
        loop = name in ("crickets", "wind", "rain")
        clips[f"sfx.{name}"] = (mono_to_stereo(fn(), 0.6 if loop else 0.85), {"loop": loop})
    gap = np.zeros((2, int(GAP * SR)), np.float32)
    parts, regions, t = [], {}, 0.0
    for key, (y, meta) in clips.items():
        regions[key] = {"start": round(t, 4), "length": round(y.shape[1] / SR, 4), **meta}
        parts += [y, gap]
        t += y.shape[1] / SR + GAP
    atlas = np.concatenate(parts, axis=1)
    os.makedirs(out_dir, exist_ok=True)
    wav = os.path.join(out_dir, "atlas.wav")
    wavfile.write(wav, SR, (np.clip(atlas, -1, 1).T * 32767).astype(np.int16))
    ogg = os.path.join(out_dir, "atlas.ogg")
    subprocess.run(["ffmpeg", "-y", "-loglevel", "error", "-i", wav, "-c:a", "libvorbis", "-q:a", "5", ogg], check=True)
    manifest = {"length": round(t, 3), "harmony": [h[0] - 38 for h in S.HARMONY], "regions": regions}
    with open(os.path.join(out_dir, "atlas.json"), "w") as handle:
        json.dump(manifest, handle, indent=1)
    return ogg, manifest


def write_luau(manifest, asset_id):
    lines = ["--!strict", "-- GENERAT de tools/audio/atlas.py — nu edita de mână.",
             "-- Atlasul audio: un singur asset cu regiuni numite (secunde).", "",
             "export type Region = { start: number, length: number, loop: boolean?, bpm: number?, layer: string? }",
             "", "return {", f"\tassetId = {asset_id or 0},", f"\tlength = {manifest['length']},",
             f"\t-- fundamentala acordului pe fiecare măsură, în semitonuri față de Re",
             "\tharmony = { " + ", ".join(str(x) for x in manifest["harmony"]) + " },", "\tregions = {"]
    for key, r in manifest["regions"].items():
        extra = "".join(f", {k} = {json.dumps(v) if not isinstance(v, bool) else str(v).lower()}"
                        for k, v in r.items() if k not in ("start", "length"))
        lines.append(f'\t\t["{key}"] = {{ start = {r["start"]}, length = {r["length"]}{extra} }},')
    lines += ["\t} :: { [string]: Region },", "}", ""]
    path = os.path.join(ROOT, "src", "shared", "Config", "AudioAtlas.luau")
    with open(path, "w") as handle:
        handle.write("\n".join(lines))
    return path


if __name__ == "__main__":
    ogg, manifest = build(sys.argv[1])
    lock_path = os.path.join(ROOT, "assets.lock.json")
    lock = json.load(open(lock_path)) if os.path.exists(lock_path) else {}
    print(write_luau(manifest, (lock.get("audio.atlas") or {}).get("id")))
    print("atlas", round(manifest["length"], 1), "s,", os.path.getsize(ogg) // 1024, "KB")
