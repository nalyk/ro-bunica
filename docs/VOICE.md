# Vocea Bunicii (Gemini TTS)

Început pe 2026-10-16. Decizia: **Gemini 3.8 Flash TTS cu voce proiectată** (Voice Design), pe
**planul gratuit**, în proiectul Google AI Studio `bunica-voce`, fără card atașat.
Cheia este `GEMINI_API_KEY` din `.env.cloud`, care nu se comite.

## Bugetul (regula omului)

**Maximum 2 $, plătiți o singură dată, pentru toată vocea.** Planul gratuit costă 0 $. Pe proiectul
`bunica-voce` nu se activează facturare și nu se apasă „Set up billing / prepay”. Rezervă: ElevenLabs
Starter, 1 $ prima lună, anulat imediat. Promoția trebuie confirmată la abonare. Gemini plătit cere o
plată în avans de minimum 5 $, deci e exclus.

## Ce știm despre API (verificat)

- **Cota gratuită: 10 cereri pe zi** pentru `gemini-3.8-flash-tts`
  (`generate_content_free_tier_requests`). Se resetează la miezul nopții, ora Pacificului.
  O cerere poate conține mai multe replici, deci le grupăm și apoi tăiem pe pauze.
  Modelul de evaluare (`gemini-3.8-flash`) are cota lui separată.
- **Proiectarea vocii**: `client.voices.create(store=True, voice={model, type:"prompted", gender,
  language_code:"ro-RO", prompted:{input}})`, cu SDK-ul `google-genai>=2.25`. Întoarce un id
  `voice_…` și o mostră WAV. Vocile salvate se păstrează 1 an, maximum 200 per proiect.
  Descrierea se scrie în engleză (ce e permanent: vârstă, timbru, accent). Una dintre descrieri a fost
  respinsă o dată de filtrul de siguranță, apoi a trecut la reîncercare.
- **Sinteza cu vocea proiectată**: `client.interactions.create(model="gemini-3.8-flash-tts", …,
  annotations=[{type:"speech_metadata", style:"…"}], generation_config={speech_config:[{voice:id}]})`.
  **Când cota e epuizată, apelul SDK se blochează** în reîncercări, fără eroare. Pune timeout
  și verifică întâi cota cu un apel REST.
- Vocea proiectată merge doar cu `gemini-3.8-flash-tts`. Pe `-lite-tts` dă „No matching speaker voice”.
- Apelul REST simplu (`generateContent` + `prebuiltVoiceConfig`) **citește cu voce tare indicațiile de
  regie** puse în text. De aceea emoția se dă separat, în `style`, cu vocile proiectate.
- Răspunsul REST e `audio/wav`. Prima versiune a scripturilor îl trata ca PCM brut; acum
  `lines.py` verifică antetul `RIFF`.

## Vocile proiectate (`art/voice/voices.json`)

| Cheie | Descriere (rezumat) | Note |
|---|---|---|
| A | bunică de 75 de ani, veselă și aprigă, voce răgușită, puternică, accent rustic moldovenesc | 4 replici generate. **„Fugi” cu „i” final lung, greșit** (omul a observat) |
| B | bunică de desen animat, 80 de ani, voce subțire, scârțâită, iute, comic de morocănoasă | „Fugi, că vine Bunica!” **pronunțat corect** |
| C | bunică de 70 de ani, caldă dar autoritară, voce groasă, teatrală | doar mostra de proiectare |
| D | bunică de film animat din Basarabia, 78 de ani, voce nazală, șugubeață, izbucnește în ceartă | doar mostra de proiectare |

Mostrele și replicile sunt în `art/voice/takes/*.ogg`.

## Ce am învățat despre pronunție

- **„-i” final scurt (nesilabic).** În română, „fugi”, „hoți”, „pleci”, „dormi” se termină cu un „i”
  abia șoptit. TTS-ul îl lungește uneori („fu-giii”). Fiecare replică se ascultă, sau o întrebăm pe
  Gemini, în mod explicit, despre „i”-urile finale. Generăm 3–4 variante și o alegem pe cea corectă.
- Accentul iese românesc standard, chiar dacă cerem „moldovenesc”. Încă nu e rezolvat. De încercat:
  descrierea mai precisă a trăsăturilor (de exemplu „e” deschis, „ș” moale) și alegerea vocii după
  ureche.
- Strănutul și râsul ies „jucate”, nu naturale. Se pot completa cu SFX separate.
- Evaluarea automată (`tools/voice/judge.py`, Gemini ascultă clipul și dă note în JSON) e utilă pentru
  transcriere și pentru a detecta indicații citite cu voce tare, dar decizia finală o ia urechea omului.

## Pașii următori

1. Când se resetează cota: audiția vocilor B, C și D cu aceleași 4 replici, grupate în 1–2 cereri.
   Omul alege vocea.
2. Cele ~50 de replici RO (`src/shared/Config/BunicaLines.luau`), grupate câte 5–8 pe cerere, 3 variante
   fiecare. Selecția: Gemini ca evaluator (transcriere, „-i” final), apoi urechea omului.
3. Post-procesare: tăiere pe pauze, `loudnorm` la -14 LUFS, OGG mono 48 kHz, încărcare prin Open Cloud
   (permisiunea „assets” e activă) și id-urile în config.
4. EN, ES și PT cu aceeași voce proiectată, în zilele următoare (cota zilnică).
