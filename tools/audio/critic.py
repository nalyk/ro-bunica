"""Critic audio: Gemini ascultă un fișier și răspunde ca un producător (JSON). Folosește cota modelului text."""

import base64
import json
import pathlib
import sys
import time
import urllib.error
import urllib.request

sys.path.insert(0, str(pathlib.Path(__file__).resolve().parents[1]))
import cloud  # noqa: E402

KEY = cloud.load_env()["GEMINI_API_KEY"]


def critique(path, prompt, model="gemini-3.8-flash"):
    data = base64.b64encode(open(path, "rb").read()).decode()
    mime = "audio/mp3" if path.endswith(".mp3") else "audio/wav"
    body = {"contents": [{"parts": [{"inlineData": {"mimeType": mime, "data": data}}, {"text": prompt}]}]}
    for _ in range(8):
        req = urllib.request.Request(
            f"https://generativelanguage.googleapis.com/v1beta/models/{model}:generateContent",
            data=json.dumps(body).encode(), headers={"x-goog-api-key": KEY, "Content-Type": "application/json"})
        try:
            with urllib.request.urlopen(req, timeout=180) as r:
                d = json.loads(r.read())
            return d["candidates"][0]["content"]["parts"][0]["text"]
        except urllib.error.HTTPError as e:
            msg = e.read()[:300].decode()
            print("ERR", e.code, msg[:160], file=sys.stderr)
            if e.code in (429, 500, 503):
                time.sleep(25)
                continue
            return None
    return None


if __name__ == "__main__":
    print(critique(sys.argv[1], sys.argv[2]))
