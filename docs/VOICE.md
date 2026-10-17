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

## Replicile RO (gata, 2026-10-17)

Vocea B, aleasă de om. Cele 20 de replici din `BunicaLines` sunt în `art/voice/ro/` (OGG mono 48 kHz, -14 LUFS),
încărcate prin `tools/assets.py` (`voice_ro_*` în `assets.lock.json`) și legate în `BunicaLines.voice.ro`.
Semnătura „Fugi, că vine Bunica!” e înregistrarea pe care omul a ascultat-o și a aprobat-o (`L_B_fugi`).

Fluxul (`tools/voice/batch.py`, `tools/voice/check.py`):

1. `batch.py quota` verifică cota TTS printr-un apel REST (costă o cerere).
2. `batch.py gen GRUP TAKE`: o cerere pentru un grup de 4–8 replici cu aceeași emoție (`style`), cu timeout dur.
3. `batch.py align GRUP TAKE`: taie la toate pauzele de peste 0,15 s, transcrie bucățile cu Gemini și le grupează
   în replici prin programare dinamică după asemănarea textului. Tăierea doar după „cele mai lungi n-1 pauze”
   greșește, pentru că Bunica face pauze și în interiorul replicilor („Văd eu… tot, să știi!”). Tăietura cade
   la 60 ms după sfârșitul vorbirii, altfel se pierd începuturile moi („St-” din „Stai”, „A-” din „Acum”).
4. `check.py`: transcriere fără text sugerat și „-i” final lung. Cu textul așteptat în prompt, evaluatorul e prea
   îngăduitor (a aprobat un „Fugi” cu „i” lung).
5. Loudnorm într-o singură trecere ratează ținta pe clipuri scurte (-12,5…-19,4 LUFS); câștig exact măsurat cu
   `ebur128`, repetat de 3 ori, plus `alimiter`, le aduce pe toate la -14 ±0,3.

Cote gratuite pe zi: TTS 10 cereri; evaluatorul are 20 de cereri pe model, iar `check.py` trece singur la
`gemini-3.7-flash`, `3.6-flash`, `3.5-flash` când se termină una. Pe 2026-10-17 s-au folosit 10 cereri TTS.

„Na-ți-o bună!” a ieșit stâlcit în ambele variante („Noapte bună”, „Na! Lecție bună!”), așa că replica a devenit
„Las' că-ți arăt eu!” (la fel ca textul englez, „Oh, you'll get it now!”).

## Permisiunea jocului pentru audio (lecția din 2026-10-17)

Vocile au mers în Studio, dar în jocul live nu s-a auzit nimic. În raportul de erori (Monitoring → Error report)
era „Failed to load sound: User is not authorized to access Asset”, de la versiunea 63. Audio încărcat prin Open
Cloud e privat, iar jocul trebuie să primească permisiunea Use pentru fiecare fișier. Studio o dă singur doar când
publici din el, iar noi publicăm prin Open Cloud. Pașii sunt în antetul `tools/assets.py`. Toate cele 20 de replici RO
au acum `HasPermission` (verificat cu `check-permissions`). Tot atunci: bun venitul pornește abia după ecranul de
încărcare (remote-ul `Greeted`), iar muzica coboară cât vorbește o Bunica aflată la mai puțin de 80 de studs de cameră.
Verificat prin înregistrarea sunetului din Studio (PulseAudio, `parec --monitor-stream`) și corelație cu clipurile:
bun venitul se aude la 7,6 s după ecranul de încărcare, cu corelația 0,95.

## Pașii următori

1. EN, ES și PT cu aceeași voce, câte o limbă pe zi (cota zilnică), în `art/voice/<limbă>/` și
   `BunicaLines.voice.<limbă>`. Până atunci, jucătorii din alte limbi aud vocea în română, cu bula tradusă.
2. Mai multe replici pe evenimente noi (horă, furt reușit, mutații), când apar.
