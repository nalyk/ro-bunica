# Replicile Bunicii în grupuri (o cerere = mai multe replici, tăiate apoi pe pauze). Vezi docs/VOICE.md.
# Plan gratuit: 10 cereri/zi pe gemini-3.8-flash-tts; SDK-ul se blochează fără eroare când cota e epuizată,
# deci fiecare cerere are un timeout dur, iar cota se verifică înainte cu `quota`.
# Rulare: <venv cu google-genai>=2.25>/bin/python tools/voice/batch.py quota | gen GRUP TAKE | split GRUP TAKE
import base64, json, re, subprocess, sys, urllib.error, urllib.request
from concurrent.futures import ThreadPoolExecutor, TimeoutError as Timeout
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(ROOT / "tools"))
sys.path.insert(0, str(ROOT / "tools/voice"))
import cloud  # noqa: E402

KEY = cloud.load_env()["GEMINI_API_KEY"]
OUT = ROOT / "build/voice"
VOICE = json.load(open(ROOT / "art/voice/voices.json"))["B"]

# Grupuri după emoție: aceeași indicație de regie (style) pentru toate replicile din grup
GROUPS = {
    "alarm": (
        ["bunica.wake.1", "bunica.wake.2", "bunica.wake.3", "bunica.signature", "bunica.rage.1", "bunica.rage.2"],
        "A comic cartoon grandma who just caught a thief in her garden: loud, outraged, energetic battle cries, "
        "shouting each line. Leave a clear two-second silence between lines.",
    ),
    "taunt": (
        ["bunica.hit.1", "bunica.hit.2", "bunica.hit.3", "bunica.hit.4", "bunica.miss.1", "bunica.miss.2"],
        "A comic cartoon grandma throwing her slipper at a thief: triumphant, cheeky and teasing, cackling a little. "
        "Leave a clear two-second silence between lines.",
    ),
    "home": (
        ["bunica.spot.1", "bunica.spot.2", "bunica.spot.3", "bunica.miss.3",
         "bunica.welcome.1", "bunica.welcome.2", "bunica.dawn.1", "bunica.dawn.2"],
        "A cartoon grandma: the first three lines suspicious, squinting and muttering; the fourth flustered, "
        "searching for her glasses; the last four warm, cheerful and loving to her grandchild. "
        "Leave a clear two-second silence between lines.",
    ),
    # a doua șansă pentru replicile care au ieșit greșit în grupurile de mai sus
    "fix": (
        ["bunica.wake.2", "bunica.wake.3", "bunica.rage.2", "bunica.signature"],
        "A comic cartoon grandma who just caught a thief in her garden: loud, outraged, energetic, shouting each "
        "line clearly and completely, starting each line crisply. Romanian final i in words like fugi and toți is "
        "very short and whispered, never a full long vowel. Leave a clear two-second silence between lines.",
    ),
}


def texts() -> dict:
    src = (ROOT / "src/shared/Strings/ro.luau").read_text()
    return dict(re.findall(r'\["(bunica\.[a-z0-9.]+)"\]\s*=\s*"([^"]*)"', src))


def quota() -> bool:
    body = {"contents": [{"parts": [{"text": "Da."}]}], "generationConfig": {"responseModalities": ["AUDIO"],
            "speechConfig": {"voiceConfig": {"prebuiltVoiceConfig": {"voiceName": "Kore"}}}}}
    req = urllib.request.Request(
        "https://generativelanguage.googleapis.com/v1beta/models/gemini-3.8-flash-tts:generateContent",
        data=json.dumps(body).encode(), headers={"x-goog-api-key": KEY, "Content-Type": "application/json"})
    try:
        urllib.request.urlopen(req, timeout=60).read()
        return True
    except urllib.error.HTTPError as e:
        print("cota:", e.code, e.read()[:300].decode())
        return False


def gen(group: str, take: int):
    from google import genai
    keys, style = GROUPS[group]
    t = texts()
    script = "\n\n".join(t[k] for k in keys)
    client = genai.Client(api_key=KEY)

    def call():
        return client.interactions.create(
            model="gemini-3.8-flash-tts",
            input=[{"type": "user_input", "content": [{"type": "text", "text": script,
                    "annotations": [{"type": "speech_metadata", "style": style}]}]}],
            response_format={"type": "audio"},
            generation_config={"speech_config": [{"voice": VOICE}]})

    pool = ThreadPoolExecutor(1)
    try:
        it = pool.submit(call).result(timeout=180)
    except Timeout:
        print("timeout (cota epuizată?)")
        import os
        os._exit(2)
    data = base64.b64decode(it.output_audio.data)
    OUT.mkdir(parents=True, exist_ok=True)
    wav = OUT / f"{group}_{take}.wav"
    if data[:4] == b"RIFF":
        wav.write_bytes(data)
    else:
        raw = OUT / f"{group}_{take}.raw"
        raw.write_bytes(data)
        subprocess.run(["ffmpeg", "-y", "-loglevel", "error", "-f", "s16le", "-ar", "24000", "-ac", "1",
                        "-i", str(raw), str(wav)], check=True)
    print(wav)


def silences(wav: Path, noise="-38dB", dur=0.45):
    err = subprocess.run(["ffmpeg", "-i", str(wav), "-af", f"silencedetect=noise={noise}:d={dur}", "-f", "null", "-"],
                         capture_output=True, text=True).stderr
    starts = [float(x) for x in re.findall(r"silence_start: ([\d.]+)", err)]
    ends = [float(x) for x in re.findall(r"silence_end: ([\d.]+)", err)]
    h, m, sec = re.search(r"Duration: (\d+):(\d+):([\d.]+)", err).groups()
    total = 3600 * int(h) + 60 * int(m) + float(sec)
    return list(zip(starts, ends)), total


def export(wav: Path, start: float, end: float, out: Path):
    # tăiere, liniștea de la capete scoasă, loudnorm -14 LUFS, OGG mono 48 kHz
    af = ("silenceremove=start_periods=1:start_threshold=-55dB:start_silence=0.06,"
          "areverse,silenceremove=start_periods=1:start_threshold=-55dB:start_silence=0.12,areverse,"
          "afade=t=in:d=0.01,areverse,afade=t=in:d=0.03,areverse,"
          "loudnorm=I=-14:TP=-1.5:LRA=11,aresample=48000")
    subprocess.run(["ffmpeg", "-y", "-loglevel", "error", "-i", str(wav), "-ss", f"{start:.3f}", "-to", f"{end:.3f}",
                    "-af", af, "-ac", "1", "-c:a", "libvorbis", "-q:a", "6", str(out)], check=True)


def split(group: str, take: int):
    keys, _ = GROUPS[group]
    wav = OUT / f"{group}_{take}.wav"
    # cele mai lungi n-1 pauze despart replicile (pauzele scurte din interiorul unei replici rămân)
    for noise, dur in [(n, d) for d in (0.45, 0.3, 0.2) for n in ("-38dB", "-34dB", "-42dB", "-30dB")]:
        sil, total = silences(wav, noise, dur)
        inner = [s for s in sil if s[0] > 0.05 and s[1] < total - 0.05]
        if len(inner) >= len(keys) - 1:
            break
    else:
        print("prea puține pauze:", len(inner), "pentru", len(keys))
        return
    cuts = sorted(sorted(inner, key=lambda s: s[1] - s[0], reverse=True)[: len(keys) - 1])
    bounds = [0.0] + [(a + b) / 2 for a, b in cuts] + [total]
    for i, key in enumerate(keys):
        out = OUT / f"{key}.{group}_{take}.ogg"
        export(wav, bounds[i], bounds[i + 1], out)
        print(out.name, f"{bounds[i + 1] - bounds[i]:.2f}s")


def norm(text: str) -> str:
    return " ".join(re.sub(r"[^a-zăâîșț ]", "", text.lower().replace("-", " ")).split())


def align(group: str, take: int, noise="-30dB", dur=0.15):
    """Taie la toate pauzele, transcrie bucățile (check.py), apoi le grupează în replici prin programare
    dinamică după asemănarea textului: Bunica face uneori pauze și în interiorul unei replici."""
    import difflib
    import check
    keys, _ = GROUPS[group]
    t = texts()
    wav = OUT / f"{group}_{take}.wav"
    sil, total = silences(wav, noise, dur)
    inner = [s for s in sil if s[0] > 0.05 and s[1] < total - 0.05]
    # tăietura mai aproape de sfârșitul replicii dinainte: consoanele moi de la început („St-”, „A-”) sunt
    # mai slabe decât pragul și ar fi tăiate la mijlocul pauzei
    bounds = [0.0] + [a + min(0.06, (b - a) / 3) for a, b in inner] + [total]
    segs = []
    for i in range(len(bounds) - 1):
        seg = OUT / f"seg_{group}_{take}_{i}.ogg"
        subprocess.run(["ffmpeg", "-y", "-loglevel", "error", "-i", str(wav), "-ss", f"{bounds[i]:.3f}",
                        "-to", f"{bounds[i + 1]:.3f}", "-c:a", "libvorbis", str(seg)], check=True)
        segs.append(seg)
    heard = [r["transcriere"] for r in check.check(segs, None)]
    print("bucăți:", heard)
    n, m = len(keys), len(heard)

    def sim(line, a, b):
        return difflib.SequenceMatcher(None, norm(t[keys[line]]), norm(" ".join(heard[a:b]))).ratio()

    # best[i][j]: scorul maxim pentru primele i replici pe primele j bucăți; o bucată fără replică
    # (râs, respirație) poate rămâne pe dinafară cu scor 0
    NEG = -1e9
    best = [[NEG] * (m + 1) for _ in range(n + 1)]
    back = {}
    best[0][0] = 0
    for i in range(n + 1):
        for j in range(m + 1):
            if best[i][j] == NEG:
                continue
            if j < m and best[i][j] > best[i][j + 1]:
                best[i][j + 1], back[(i, j + 1)] = best[i][j], (i, j, False)
            if i < n:
                for k in range(j + 1, m + 1):
                    score = best[i][j] + sim(i, j, k)
                    if score > best[i + 1][k]:
                        best[i + 1][k], back[(i + 1, k)] = score, (i, j, True)
    spans, i, j = [], n, m
    while (i, j) != (0, 0):
        pi, pj, used = back[(i, j)]
        if used:
            spans.append((pi, pj, j))
        i, j = pi, pj
    for line, a, b in sorted(spans):
        score = sim(line, a, b)
        out = OUT / f"{keys[line]}.{group}_{take}.ogg"
        export(wav, bounds[a], bounds[b], out)
        print(f"{out.name} {bounds[b] - bounds[a]:.2f}s potrivire {score:.2f}: {' '.join(heard[a:b])}")
    for seg in segs:
        seg.unlink()


if __name__ == "__main__":
    cmd = sys.argv[1]
    if cmd == "align":
        align(sys.argv[2], int(sys.argv[3]))
    elif cmd == "quota":
        print("OK" if quota() else "EPUIZATĂ")
    elif cmd == "gen":
        gen(sys.argv[2], int(sys.argv[3]))
    elif cmd == "split":
        split(sys.argv[2], int(sys.argv[3]))
