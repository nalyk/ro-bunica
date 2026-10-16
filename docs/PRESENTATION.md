# BUNICA — Modele, UI/UX, sunet (planul de prezentare)

Scris pe 2026-10-16, după cercetarea din aceeași zi (trei agenți: 3D, UI/UX, audio în Roblox 2026).
Ținta: prezentarea să ajungă la nivelul gameplay-ului. Copilul trebuie să recunoască BUNICA dintr-o
captură de 1 secundă de pe TikTok și dintr-un sunet de 1 secundă.

## Ce am aflat (cu impact asupra deciziilor)

### Modele
- **EditableMesh / EditableImage**: merg în jocuri publicate doar după bifarea „Allow Mesh / Image APIs”
  și cu creator verificat prin act de identitate, 13+. Nu se replică. Bugetul de memorie pe client e
  nedocumentat (cineva a dat de el la ~8 mesh-uri). Un fir de pe DevForum spune că jocul se limitează
  la 13+, dar informația e disputată, iar pentru un joc de copii riscul e prea mare. **Nu le folosim
  pentru arta de bază.**
- **GenerationService / Cube**: e generare la runtime pentru conținut făcut de jucători (5 pe minut),
  nu un flux pentru arta jocului. Generarea din Studio Assistant are doar interfață grafică.
- **Open Cloud Assets API**: încarcă modele FBX, glTF sau GLB (GLB-ul cu culori pe vertecși intră corect)
  și imagini PNG. Sunetul are limita de 2.000 de încărcări pe 30 de zile cu cont verificat (100 fără).
  **Cheia API are nevoie de permisiunea „assets” (citire și scriere).** Cheia actuală n-o are
  (verificat: `PERMISSION_DENIED`).
- La runtime, serverul folosește `InsertService:LoadAsset(id)` pe asset-urile proprii. Șabloanele stau
  în ServerStorage și se clonează. Replicarea e normală și nu cere act de identitate.
- **Aspectul hiturilor**: forme rotunde, puține poligoane, culori plate. Efectul „wow” vine din
  **mutații** (curcubeu, auriu, strălucire), din efectele de raritate (particule, Highlight) și din
  animația de „respirație”. Roblox nu are shadere proprii, așa că aspectul de desen animat se face
  din culori plate plus contur (`Highlight`; din 2025 pot fi până la 255).
- **Iluminarea**: `LightingStyle` + `PrioritizeLightingQuality` (au înlocuit `Technology`), plus
  Atmosphere, ColorCorrection, Bloom și SunRays.
- **Buget mobil**: 500–3.000 de triunghiuri per creatură, 200–1.500 per obiect, texturi de cel mult 256²
  (la noi: niciuna, doar culori pe vertecși).

### UI/UX
- **Stilurile UI** (StyleSheet, StyleRule, tokeni ca atribute, teme) sunt în beta, dar se pot publica
  în jocuri live din ianuarie 2026. Sunt disponibile și: Flex layout, UIDragDetector, Path2D,
  UIStroke cu contur interior, `PreferredInput` (atingere, gamepad sau tastatură) și `ScreenInsets`.
- **Accesibilitate**: `PreferredTextSize`, `ReducedMotionEnabled`, `PreferredTransparency`. Nu există
  un API pentru daltonism, deci raritatea se arată prin culoare **și** formă.
- **Traducerea automată Roblox nu are română**, iar fonturile proprii nu se pot încărca. Acoperirea
  pentru ș, ț și chirilice nu e documentată pentru niciun font, așa că **o testăm în Studio înainte
  să alegem fontul**.
- Imaginile (Decal/Image) nu se pot actualiza pe loc: fiecare versiune nouă e un asset nou, ținut
  într-un fișier „lock”.
- Ținte de atingere de cel puțin 48 px, butoane poziționate față de butonul de săritură, HUD
  în `CoreUISafeInsets`.

### Sunet
- **API-ul audio nou** (AudioPlayer → Wire → AudioEmitter/AudioFader → AudioDeviceOutput) e acum
  standardul din documentație. Efectele disponibile: EQ, Compressor (ducking), Reverb, PitchShifter
  și altele. Simularea acustică (ocluzie) e încă beta doar în Studio.
- **Muzica adaptivă** se face din 3–4 straturi (stems) sincronizate, cu volumele mutate între fadere
  după starea jocului.
- **AudioTextToSpeech** e live, dar **nu are română**. Are spaniolă, portugheză, engleză și altele,
  cu voci generice. E bun pentru personaje minore în ES/PT/EN, **nu pentru Bunica**.
- **Licențe**: MusicGen, XTTS și F5-TTS sunt necomerciale, deci excluse. Piper `ro_RO-mihai` e CC0.
  Kokoro (Apache) are pt-BR și es slabe.
- **Melodii moldovenești din domeniul public**: Karol Mikuli, *48 Airs nationaux roumains*
  (1855–1863, IMSLP), din repertoriul lăutarului Nicolae Picu. Facem aranjamente proprii.
  Înregistrările și aranjamentele moderne sunt protejate.
- **Ce devine viral**: un sunet-semnătură scurt, mereu identic, pe care un copil îl poate imita, și
  o replică vocală care ajunge meme.

## Direcția artistică (decizie)

**„Desen animat de sat”**: siluete rotunde și moi, culori calde și saturate, contur maro-închis (nu
negru) pe personaje, ochi mari cu strălucire. Lumea are motive moldovenești reale: case albastre cu
prispă și stâlpi sculptați, gard de nuiele, fântână cu cumpănă, motivul de ie pe UI.

Paleta (tokeni comuni pentru UI și lume):

| Token | Hex | Rol |
|---|---|---|
| `paper` | #FFF4DE | panouri, pânză |
| `ink` | #3A2218 | contururi |
| `ie-red` | #D7263D | acțiune principală |
| `wheat` | #F2B33D | monedă, aur |
| `vine` | #4BAE4F | creștere, OK |
| `sky` | #3FA7E0 | zi, info |
| `plum` | #6B3FA0 | noapte, rar |

## Fluxul de producție

```
art/lib/kit.py              trusa Blender (blob/metaball, tub, ochi, finish, GLB, previzualizare)
art/<categorie>/<nume>.py   un script per model; rulat fără interfață
tools/art.py                construiește tot: GLB + PNG + planșă de contact + verificări (triunghiuri, înălțime, pivot)
tools/assets.py             încarcă prin Open Cloud (Model/Image/Audio), așteaptă moderarea,
                            scrie assets.lock.json și src/shared/Config/AssetIds.luau (generat)
Server: AssetService        LoadAsset → șabloane în ServerStorage; dacă lipsește un id → placeholderul procedural
```

Testele Lune și e2e rămân independente de asset-uri: lipsa unui id cade pe placeholder.
Am verificat că Blender 4.3 fără interfață generează, exportă GLB și randează cu contur
(primul personaj, Cartofel Agent: 3.000 de triunghiuri, ~3 s).

**Regulă de conținut**: la fiecare model verific că nicio formă nu poate fi citită ca gest sau simbol
urât. Primul personaj avea un deget ridicat și l-am scos.

## Pașii

### P1. Fluxul de asset-uri
`tools/art.py`, `tools/assets.py`, `AssetIds.luau`, `AssetService` pe server, fallback pe placeholder,
planșa de contact. **Blocat parțial** de permisiunea „assets” a cheii API (construcția locală merge
și fără ea).

### P2. Modele
1. **Cele 17 creaturi**, fiecare cu personalitate (siluetă, obiect-semn, expresie). Animație procedurală
   de respirație și țopăit pe client.
2. **Mutațiile ca spectacol**: Auriu (metal + sclipiri), Curcubeu (culoare care curge), Papucită
   (un papuc mic lipit de cap), Noapte (strălucire). Fără texturi, din Highlight, particule și material.
3. **Bunica**: cap, broboadă, ochelari, șorț și papuc, ca MeshPart-uri prinse de rig-ul R15, ca să
   meargă pozele procedurale existente.
4. **Hoțomanul**: mască, sac și mers furișat.
5. **Satul**: casa albastră cu prispă, gardul de nuiele, fântâna cu cumpănă, vatra, piedestalele,
   straturile, copacii (nuc, vișin), floarea-soarelui.
6. **Lumina pe faze**: zi caldă, apus portocaliu, noapte albastră cu lună, iar „Bunica se supără” are
   cer roșiatic.

### P3. UI/UX
1. **Sistemul de design**: un modul de tokeni (paleta de mai sus), componente (Button, Panel cu bordură
   de ie, Toast, Counter cu numărătoare, ProgressRing și PriceTag deasupra obiectelor, cadranul
   zi/noapte), mișcare cu resorturi (snappy, bouncy, gentle) care devine instantanee când
   `ReducedMotionEnabled` e activ.
2. **Iconițe** generate ca SVG din cod, apoi PNG, apoi încărcate (fără text în imagini).
3. **HUD minimal**: banii în stânga sus, cadranul zi/noapte și vremea sus la centru, 4 iconițe în
   stânga, butoanele contextuale lângă butonul de săritură.
4. **Recompense vizibile**: monede care zboară spre contor, contorul se turtește și apoi crește,
   raritatea arătată prin culoare **și** formă, fereastră de recompensă cu raze.
5. **Intrări**: `PreferredInput` schimbă glifele și aranjarea, navigarea cu gamepad e completă, iar
   textele suportă cu 30–40% mai mult pentru ES, PT și RU.
6. **Testul de font** pentru „ș ț ă î â ȘȚ / Бабушка ёЖ” în Studio, pe fiecare font candidat.

### P4. Sunet
1. **Graful audio nou**: fader principal, plus fadere pentru muzică, SFX, voce și ambianță. Ducking:
   muzica scade sub vocea Bunicii.
2. **Muzica adaptivă**: 4 straturi din aranjamente proprii pe melodii Mikuli (zi: cobză și fluier;
   noapte: bâzâit și greieri; hoț prezent: percuție; urmărire: tempo mai rapid). Generate din Python
   (MIDI → sinteză), normalizate la -16 LUFS.
3. **Hora**: aceeași melodie în 3 niveluri de intensitate, iar tempoul crește cu numărul de dansatori.
4. **PLEOSC!, sunetul-semnătură**: plesnitură, chițăit de cauciuc și „boing”, mereu același, cu o pauză
   de 0,15 s și muzica coborâtă.
5. **SFX procedurale** (sinteză în stil sfxr, în numpy), plus straturi CC0, normalizate. Un sunet
   pentru fiecare clasă de interacțiune UI: atingere, confirmare, eroare, recompensă, raritate.
6. **Ambianța din emițătoare**: cocoș în zori, câini noaptea, fântâna, găini; ploaia și vântul ca
   straturi de vreme; reverb în casă și în pivniță.
7. **Vocea Bunicii**: cel mai bine e o voce reală, înregistrată cu acord scris (cele 30–50 de replici
   sunt deja scrise). Ca soluție de rezervă: Piper RO prelucrat, plus interjecții fără limbă
   („hm!”, „aoleu!”, „hai!”). Roblox TTS servește doar pentru crainicul ES/PT/EN.

### P5. Verificare
Planșe de contact pentru toate modelele și capturi din playtest-ul din Studio la fiecare pas. E2E
și playtest rămân verzi, iar sunetul se verifică prin AudioAnalyzer (nivel, sincronizarea
straturilor) și prin spectrograme.

## Ce trebuie de la om
1. **Permisiunea „assets” (Read + Write) pe cheia API**: Creator Dashboard → Open Cloud → API Keys →
   cheia existentă → Add API System → „Assets” → Read și Write. Valoarea cheii nu se schimbă.
2. Opțional: **verificarea contului prin act de identitate** (limita de încărcări audio crește de la
   100 la 2.000 pe lună).
3. Opțional, dar e diferența dintre „bun” și „de neuitat”: **o voce reală pentru Bunica**.
