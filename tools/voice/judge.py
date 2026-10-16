# Vocea Bunicii prin Gemini TTS (plan gratuit: 10 cereri/zi pe gemini-3.8-flash-tts). Vezi docs/VOICE.md.
# Rulează cu un venv care are google-genai>=2.25; cheia GEMINI_API_KEY vine din .env.cloud.
import sys, json, base64, urllib.request, urllib.error, subprocess, time
sys.path.insert(0, str(__import__('pathlib').Path(__file__).resolve().parents[1])); import cloud
k=cloud.load_env()["GEMINI_API_KEY"]
PROMPT="""Ești regizor de dublaj pentru un joc pentru copii. Ascultă clipul audio (limba română).
Răspunde DOAR cu JSON: {"transcriere": "exact ce se aude", "citeste_indicatiile": true/false (dacă se aud cu voce tare indicații de regie sau descrierea personajului), "varsta_aparenta": număr, "gen": "f/m", "timbru": "scurt", "pronuntie_romana": 1-10, "accent": "românesc standard / moldovenesc / străin", "emotii_jucate": 1-10, "sternut_real": true/false, "ras_real": true/false, "potrivire_bunica_desen_animat": 1-10, "defecte": "scurt"}"""
def judge(path, model="gemini-3.8-flash"):
    wav=open(path,"rb").read()
    body={"contents":[{"parts":[{"inlineData":{"mimeType":"audio/wav","data":base64.b64encode(wav).decode()}},{"text":PROMPT}]}],
          "generationConfig":{"responseMimeType":"application/json"}}
    for i in range(6):
        r=urllib.request.Request(f"https://generativelanguage.googleapis.com/v1beta/models/{model}:generateContent",
          data=json.dumps(body).encode(),headers={"x-goog-api-key":k,"Content-Type":"application/json"})
        try: d=json.loads(urllib.request.urlopen(r).read()); return d["candidates"][0]["content"]["parts"][0]["text"]
        except urllib.error.HTTPError as e:
            m=e.read()[:200].decode(); print("ERR",e.code,m[:150]); 
            if e.code in (429,500,503): time.sleep(20); continue
            return None
if __name__=="__main__":
    for p in sys.argv[1:]: print(p, judge(p), flush=True)
