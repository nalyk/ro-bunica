# Vocea Bunicii prin Gemini TTS (plan gratuit: 10 cereri/zi pe gemini-3.8-flash-tts). Vezi docs/VOICE.md.
# Rulează cu un venv care are google-genai>=2.25; cheia GEMINI_API_KEY vine din .env.cloud.
import base64, json, os, sys, time
sys.path.insert(0, str(__import__('pathlib').Path(__file__).resolve().parents[1])); import cloud
from google import genai
client = genai.Client(api_key=cloud.load_env()["GEMINI_API_KEY"])
DESIGNS = {
 "A": "A feisty, cheerful 75-year-old village grandmother from rural Moldova, with a raspy, crackly but loud old voice and a thick rustic Moldovan accent.",
 "B": "A tiny, energetic 80-year-old cartoon grandma from a Moldovan village: high, creaky, wobbly old-lady voice, quick and comically grumpy, with a strong rural Moldovan accent.",
 "C": "A warm but bossy 70-year-old Moldovan countryside grandmother with a deep, husky, smoky voice, slow and theatrical, with a regional Moldovan Romanian accent.",
 "D": "An animated-film grandmother character, about 78, from a village in Bessarabia: crackly, nasal, wise and mischievous elderly female voice with a soft-spoken Moldovan lilt that bursts into loud scolding.",
}
ids = {}
for key, desc in DESIGNS.items():
    for i in range(5):
        try:
            v = client.voices.create(store=True, voice={"model": "gemini-3.8-flash-tts", "type": "prompted",
                "display_name": f"Bunica-{key}", "gender": "female", "language_code": "ro-RO", "prompted": {"input": desc}})
            break
        except Exception as e:
            print(key, "ERR", str(e)[:200], flush=True); time.sleep(20)
    else:
        continue
    ids[key] = v.id
    if v.sample_audio and v.sample_audio.data:
        open(f"design_{key}_sample.wav", "wb").write(base64.b64decode(v.sample_audio.data))
    print(key, v.id, flush=True)
json.dump(ids, open(str(__import__("pathlib").Path(__file__).resolve().parents[2] / "art/voice/voices.json"), "w"), indent=1)
