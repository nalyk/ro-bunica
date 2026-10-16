# Sunetul BUNICA: „Satul e o orchestră”

Început pe 2026-10-16. Muzica și efectele sunt făcute de la zero, fără mostre din librării și fără
modele cu licență necomercială. Cerința omului: nimic predefinit sau generalist. Bugetul: 0 $.

## Ideea

Jocul nu pornește o piesă de fundal. **Un dirijor din client cântă taraful satului live**, după ce se
întâmplă în joc:

- **Straturi sincronizate.** Zi, noapte, pericol și urmărire au aceeași grilă (120 BPM, 2/4, buclă de
  16 măsuri = 16 s). Pornesc în același moment de mixer și rămân sincrone. Starea jocului le deschide
  sau închide volumul, cu un fade de 1,2 s.
- **Hora care se încinge.** Hora are tempo propriu, care crește cu numărul de dansatori
  (120 → 132 → 144 → 156). Tempoul se schimbă exact la capătul buclei, ca la o horă adevărată.
- **Efectele cad pe ritm și sunt în tonalitate.** Fiecare efect e programat cu `AudioPlayer:Play(atTime)`
  pe următoarea șaisprezecime (ceasul mixerului, precizie de eșantion). Întârzierea maximă e de 90 ms,
  ca jucătorul să nu simtă un decalaj. Efectele pot fi transpuse pe acordul curent (`harmonize`).
  Toate sunt în Re, tonalitatea muzicii.
- **PLEOSC!, semnătura jocului.** Plesnitură de piele, bufnitură, „flap” de cauciuc și drâmbă comică.
  Sună mereu identic, ca să devină recognoscibil (meme).

## Arhitectura

```
tools/audio/synth.py      instrumente prin sinteză fizică: țambal (3 coarde, Karplus-Strong cu allpass,
                          acordaj < 1 cent), cobză, contrabas (cu „palmă”), acordeon (musette),
                          nai, dobă (membrană Bessel), drâmbă (formant mobil), lemn, clopoțel
tools/audio/phrase.py     melodie frazată ca la lăutar: contur continuu de ton, glissando, mordente,
                          triluri, vibrato; vioara (arcuș cu stick-slip, sacâz, corp cu „dealul podului”),
                          naiul, acordeonul
tools/audio/score.py      partitura ca date: „Hora din ogradă” (originală, mod românesc minor
                          D E F G# A B C), armonia pe măsuri, straturile și vocile principale
tools/audio/performer.py  interpretul: swing de horă, accente, umanizare, strum, mix, EQ, reverberație
tools/audio/sfx.py        efectele sonore (UI, papuc, recompense, ambianță), sintetizate și acordate în Re
tools/audio/atlas.py      ATLASUL: toate sunetele într-un singur fișier OGG cu regiuni numite
                          → src/shared/Config/AudioAtlas.luau (generat)
tools/audio/critic.py     Gemini ascultă un fișier și îl critică (JSON/text); cota modelului text
tools/assets.py           încărcare Open Cloud + assets.lock.json (fără reîncărcarea fișierelor neschimbate)
src/shared/Domain/MusicClock.luau  grila, măsura, acordul curent, cuantizarea (testat)
src/shared/Domain/MusicState.luau  ce straturi cântă din starea jocului (testat)
src/client/Controllers/Music.luau  dirijorul: graf audio nou (AudioPlayer → AudioFader → AudioDeviceOutput),
                          straturile, hora pe două playere care se alternează, 16 voci pentru efecte
```

**De ce un atlas:** audio nu se poate actualiza pe loc (fiecare încărcare e un asset nou), contul
neverificat are o limită de încărcări pe lună, iar clientul descarcă un singur fișier.
`PlaybackRegion`/`LoopRegion` cântă o regiune din atlas. Straturile se randează pe două bucle și se
păstrează a doua: coada reverberației din bucla anterioară e inclusă, deci bucla se leagă perfect.

**Semnale din joc:** `Alarm` → `Music.alarm()`, stratul de pericol; aruncarea proprie →
`Music.chase()`, urmărirea; `Hit` în apropiere → `Music.cue("pleosc")`; fazele zi/noapte prin
`GameState.Phase`; hora prin atributul `Dancing`; orice buton → `tap`.

## Ce am învățat

- **API-uri cheie:** `SoundService:GetMixerTime()` și `AudioPlayer:Play(atTime)`/`Stop(atTime)`/
  `Cancel(id)` dau programare la precizie de eșantion. `PlaybackRegion`/`LoopRegion` sunt în
  secunde. `AudioWindSynthesizer` există ca instanță (vânt procedural); încă nu e folosit.
- **Ceasul mixerului poate fi negativ.** În Studio sub Wine, `GetMixerTime()` a întors ≈ -2³² + 202 s.
  Codul folosește doar diferențe de timp, iar valorile inițiale sunt `-math.huge`, niciodată `0`.
- Verificat în Studio (playtest 22/22): straturile sincrone la 1 ms, PLEOSC! programat la +72 ms,
  noaptea comută stratul. Atlasul (asset 94705666578776) a fost aprobat de moderare în câteva minute.
- Când un fader și un player au același nume, `FindFirstChild` îl ia pe primul: nume distincte
  (`Fader_x`, `Player_x`).
- **Criticul AI** (Gemini ascultă) e util, dar zgomotos: inventează uneori detalii (o drâmbă care
  nu exista, „cuantizare 100%” deși exista umanizare). Contează doar observațiile care se repetă.
  Cota modelului `gemini-3.8-flash` pe planul gratuit se termină repede.
- **Generatoare muzicale:** Lyria (Google) nu are cotă gratuită. Suno, Udio, Stable Audio și
  ElevenLabs au planuri gratuite doar necomerciale. **ACE-Step 1.5** (cod MIT) are un demo pe
  Hugging Face cu cotă anonimă foarte mică și rulează local pe procesor doar în bfloat16
  (modificare în `init_service_orchestrator.py`, linia cu `torch.float32`). În float32 îi trebuie
  ~9 GB și sistemul îl oprește. Folosirea lui: „cover” al stratului nostru (melodia și structura
  noastră, timbre realiste). Rezultatul intră în atlas din `art/audio/stems/<strat>_<bpm>.wav`.

## Pașii următori

1. Verificare în Studio: încărcarea atlasului, sincronizarea straturilor, `Play(atTime)`, regiunile.
2. Calitate: vioara și naiul încă sună sintetic (critica AI a dat 4–5,5 din 10 la autenticitate).
   De încercat: re-instrumentare cu ACE-Step, mai multe ornamente, ambianțe.
3. Ambianța în lume: greieri, vânt, ploaie, ca emițătoare 3D.
4. Efectele de UI în tot UI-ul (deschidere/închidere panouri, monede, recompense pe raritate).
