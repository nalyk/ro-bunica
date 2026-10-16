# Vocea Bunicii prin Gemini TTS (plan gratuit: 10 cereri/zi pe gemini-3.8-flash-tts). Vezi docs/VOICE.md.
# Rulează cu un venv care are google-genai>=2.25; cheia GEMINI_API_KEY vine din .env.cloud.
import base64, json, sys, time, subprocess
sys.path.insert(0, str(__import__('pathlib').Path(__file__).resolve().parents[1])); import cloud
from google import genai
client = genai.Client(api_key=cloud.load_env()["GEMINI_API_KEY"])
LINES = [
 ("fugi", "Fugi, că vine Bunica!", "shouting a threatening but comic battle cry, cartoon style"),
 ("aoleu", "Aoleu, hoțomanul! Unde fugi cu cartoful meu?", "outraged, scolding loudly"),
 ("hapciu", "Hapciu! Hm... Cine-i acolo, în grădină?", "a big loud sneeze, then suspicious quiet muttering"),
 ("ras", "He-he-he! Așa-ți trebuie, pușlama!", "cackling with triumphant satisfaction"),
]
def say(voice, text, style, out):
    for i in range(6):
        try:
            it = client.interactions.create(model="gemini-3.8-flash-tts",
                input=[{"type": "user_input", "content": [{"type": "text", "text": text,
                    "annotations": [{"type": "speech_metadata", "style": style}]}]}],
                response_format={"type": "audio"},
                generation_config={"speech_config": [{"voice": voice}]})
            data = base64.b64decode(it.output_audio.data)
            mime = getattr(it.output_audio, "mime_type", None)
            raw = out + ".raw"; open(raw, "wb").write(data)
            if data[:4] == b"RIFF": subprocess.run(["cp", raw, out + ".wav"])
            else: subprocess.run(["ffmpeg","-y","-loglevel","error","-f","s16le","-ar","24000","-ac","1","-i",raw,out+".wav"])
            return mime
        except Exception as e:
            print("ERR", str(e)[:160], flush=True); time.sleep(25)
voices = json.load(open(str(__import__("pathlib").Path(__file__).resolve().parents[2] / "art/voice/voices.json")))
for key in sys.argv[1:] or voices:
    for name, text, style in LINES:
        m = say(voices[key], text, style, f"L_{key}_{name}")
        print(key, name, m, flush=True)
