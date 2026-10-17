# Verifică bucățile tăiate: Gemini (gemini-3.8-flash, cotă separată de TTS) transcrie fiecare clip și ascultă
# „i”-urile finale (în română scurte, nesilabice: fugi, toți, știi, vii). Un singur apel pentru tot grupul.
# Rulare: python3 tools/voice/check.py build/voice/*.home_1.ogg
import base64, json, sys, time, urllib.error, urllib.request
from pathlib import Path
sys.path.insert(0, str(Path(__file__).resolve().parents[1])); import cloud  # noqa: E401,E402

KEY = cloud.load_env()["GEMINI_API_KEY"]
MODELS = ["gemini-3.8-flash", "gemini-3.7-flash", "gemini-3.6-flash", "gemini-3.5-flash"]
PROMPT = """Ești regizor de dublaj pentru un joc pentru copii. Mai jos sunt {n} clipuri audio în limba română, numerotate.
Pentru fiecare clip răspunde într-un tablou JSON, în ordine, cu obiecte:
{{"clip": număr, "transcriere": "exact ce se aude, cuvânt cu cuvânt", "complet": true/false (replica începe și se termină curat, fără bucăți din altă replică și fără cuvinte tăiate), "i_final_lung": true/false (vreun cuvânt terminat în -i nesilabic, ca fugi/toți/știi/vii/ochelarii, e pronunțat cu un „i” lung, silabic, greșit), "pronuntie": 1-10, "expresivitate": 1-10, "defecte": "scurt"}}
Textele așteptate, în ordine: {expected}"""


def check(paths, expected):
    parts = []
    for i, p in enumerate(paths, 1):
        parts.append({"text": f"Clip {i}:"})
        parts.append({"inlineData": {"mimeType": "audio/ogg", "data": base64.b64encode(Path(p).read_bytes()).decode()}})
    prompt = PROMPT.format(n=len(paths), expected=json.dumps(expected, ensure_ascii=False))
    if expected is None:  # bucăți brute (aliniere): fără text așteptat, ca transcrierea să nu fie sugerată
        prompt = prompt.split("Textele așteptate")[0] + "Câmpul „complet” nu contează aici."
    parts.append({"text": prompt})
    body = {"contents": [{"parts": parts}], "generationConfig": {"responseMimeType": "application/json"}}
    # fiecare model are cota lui gratuită pe zi (20 de cereri): când una se termină, trecem la următorul
    for model in MODELS:
        for _ in range(4):
            req = urllib.request.Request(
                f"https://generativelanguage.googleapis.com/v1beta/models/{model}:generateContent",
                data=json.dumps(body).encode(), headers={"x-goog-api-key": KEY, "Content-Type": "application/json"})
            try:
                d = json.loads(urllib.request.urlopen(req, timeout=120).read())
                return json.loads(d["candidates"][0]["content"]["parts"][0]["text"])
            except urllib.error.HTTPError as e:
                msg = e.read().decode()
                if e.code == 429 and "PerDay" in msg:
                    break
                print("ERR", model, e.code, msg[:120].replace("\n", " "))
                if e.code in (429, 500, 503):
                    time.sleep(20)
                    continue
                break
    return None


if __name__ == "__main__":
    import re
    src = (Path(__file__).resolve().parents[2] / "src/shared/Strings/ro.luau").read_text()
    texts = dict(re.findall(r'\["(bunica\.[a-z0-9.]+)"\]\s*=\s*"([^"]*)"', src))
    paths = sys.argv[1:]
    expected = [texts[Path(p).name.rsplit(".", 2)[0]] for p in paths]
    for p, r in zip(paths, check(paths, expected) or []):
        print(Path(p).name, json.dumps(r, ensure_ascii=False))
