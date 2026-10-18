# Platforma Roblox: ce folosim și ce lăsăm pe masă (2026-10-18)

Întrebarea omului: folosim la maximum mecanica și infrastructura Roblox, pentru un joc state of the art? Răspunsul scurt: **nu**. Gameplay-ul e bogat (40 de servicii, 14 mini-jocuri, 9 întâmplări, satul viu). Partea de platformă e însă folosită ca în 2023: aproape nimic din ce împinge jucătorii înapoi în joc, nimic pentru reglaj live și o grafică fără PBR.

Metoda: inventarul codului (`grep` pe fiecare API, verificat manual) și două cercetări web pe documentația Roblox, DevForum și RDC 2025/2026. Statusurile sunt cele din octombrie 2026. Ce n-a putut fi confirmat e marcat „neverificat”.

## 1. Ce folosim deja bine

- **Date:** ProfileStore (sesiuni blocate prin MessagingService), migrații, DataStore.
- **Audio:** API-ul nou de audio (`AudioPlayer`, `AudioFader`) pentru muzica pe acorduri, cu precizie de eșantion. E calea recomandată de Roblox.
- **Rețea:** RemoteEvent-uri cu `RateLimiter` pe server (22 de servicii); validare pe server la papuc, la schimburi și în piață.
- **Politici:** `PolicyService` pe jucător, fără răspuns = restricționat. Analytics: funnel-ul primelor minute, evenimente economice și evenimente custom.
- **Lumină:** `Atmosphere`, `Bloom`, `ColorCorrection`, `SunRays`, ciclu zi/noapte (`SkyCycle`). Streaming cu `ModelStreamingMode` și `LevelOfDetail`.
- **Social de bază:** `PromptGameInvite`, `IsFriendsWithAsync` (familia), roata de chat rapid, insigne.
- **Senzație:** `HapticEffect`, hit-stop, ragdoll, reluarea celei mai bune aruncări, scuturarea camerei.
- **NPC:** `PathfindingService` (hoții, lupii, sătenii), rig-uri sculptate cu articulații procedurale.
- **Monetizare:** game pass-uri și produse cu prețuri citite din `GetProductInfo`, deja compatibil cu Managed Pricing.

## 2. Ce lipsește, după impact

### A. Creștere: semnalele algoritmului (cel mai mare câștig, cost mic)

Algoritmul din 2026 măsoară zilele de joc (D1, D2–7, D8–28), plecarea sub 60 s, play-through-ul și zilele de joc intenționat cu prietenii. Invitațiile, notificările și link-urile nu intră direct în clasament, dar aduc exact jucătorii care produc aceste semnale ([discovery](https://create.roblox.com/docs/discovery), [Home 2026](https://devforum.roblox.com/t/how-we-are-improving-home-this-year/4502571)).

| Funcție | Status | La noi | Ce ar face în BUNICA |
|---|---|---|---|
| `ExperienceNotificationService` + Open Cloud `UserNotification` | GA, 13+, 1/zi/jucător | lipsește | „Ți-a furat cineva prunele”, „Bazarul de duminică s-a deschis”, „Creatura ta a crescut”. Publicul nostru e 16+, deci toți sunt eligibili. Opt-in fără presiune ([docs](https://create.roblox.com/docs/production/promotion/experience-notifications)) |
| `SocialService:PromptLinkSharingAsync` + `ExperienceInviteOptions.LaunchData` | GA | invitație simplă, fără LaunchData; `GetJoinData` nu e citit | Link „vino în ograda mea”: prietenul intră direct în familia ta, pe serverul tău ([share links](https://devforum.roblox.com/t/introducing-the-share-link-api-deep-link-players-directly-into-the-action/3972678)) |
| Parties: `Player.PartyId`, `GetPlayersByPartyId` | GA | lipsește | Grupul (party) devine automat familie și ajunge pe același server |
| Custom Matchmaking (semnale custom) | GA din nov. 2025 | lipsește | Serverele se umplu după limbă, nivel și familie; serverele aproape goale primesc prioritate ([docs](https://create.roblox.com/docs/matchmaking/attributes-and-signals)) |
| `PromptRsvpToEventAsync` | GA | lipsește | Butonul „Vin și eu” în joc, pentru cele 7 Experience Events publicate azi |
| `CaptureService` (`StartVideoCaptureAsync`, `PromptShareCapture`) | GA, clip de 30 s | lipsește | Lovitura de papuc din reluare devine un clip partajat cu link de intrare. Pilonul „momentul de clip” din VISION ([docs](https://create.roblox.com/docs/reference/engine/classes/CaptureService)) |
| Thumbnail personalization + video de gameplay | GA (Dashboard) | o singură imagine | +8,5% play-through calificat în medie, după datele Roblox ([docs](https://create.roblox.com/docs/production/publishing/thumbnails)) |
| Friend Referral (în VISION) | GA | lipsește | Recompense cosmetice pentru cine aduce prieteni |

### B. Live ops: reglaj fără republicare (VISION pasul 7, cere acordul omului)

| Funcție | Status | La noi | Ce ar face |
|---|---|---|---|
| `ConfigService` (Configs) | GA, doar server, refresh live | lipsește | Reîncărcarea papucului, prețurile, intensitatea Bunicii, durata nopții, reglate din Dashboard ([docs](https://create.roblox.com/docs/production/configs)) |
| Experiments (A/B) | GA, 2 variante + control, 14–60 zile | lipsește | Teste pe un singur parametru o dată, cu D1/D7 măsurate de Roblox ([docs](https://create.roblox.com/docs/en-us/production/experiments.md)) |
| AnalyticsService: custom fields, mai multe funnel-uri | GA (10 funnel-uri, 3 câmpuri custom) | un funnel, fără câmpuri | Funnel-uri pentru familie, schimb și mini-jocuri; segmentare pe platformă și pe limbă |
| `MemoryStoreService` | GA | lipsește | Clasamente globale live (cel mai bun apărător al săptămânii), bazarul de duminică între servere, coadă pentru „Bunica se supără” pe toate serverele |
| `OrderedDataStore` | GA | lipsește | Clasamente persistente (sezoane) |
| `MessagingService` pentru jocul propriu-zis | GA | doar în ProfileStore | Anunțuri pe toate serverele, admin events sincronizate (ritmul săptămânal din VISION F) |
| Open Cloud `BanAsync` / user restrictions | GA | lipsește | Moderare fără republicare |

### C. Grafică: de la „TRELLIS cu albedo” la PBR

| Funcție | Status | La noi | Ce ar face |
|---|---|---|---|
| **Hărți normale coapte** (plasa de 40k → plasa redusă) | tehnică de pipeline; Roblox citește `NormalMap` în SurfaceAppearance | **lipsește**: `post3d.py` decimează și păstrează doar culoarea | Relieful țiglelor, al scândurilor și al scoarței apare înapoi pe modelele de 2–20k triunghiuri. Cel mai mare salt vizual per efort ([PBR](https://create.roblox.com/docs/en-us/art/modeling/surface-appearance)) |
| Roughness/metalness din TRELLIS | GA | aruncate | Apa din găleți, sticla, metalul și lutul lucios arată diferit sub soare |
| Emissive (`EmissiveMaskContent`, `EmissiveStrength`) | lansat primăvara 2026 (firul vechi zice „On Hold”, de testat) | lipsește | Ferestrele luminate noaptea, felinarele, discoteca ([roadmap](https://devforum.roblox.com/t/creator-roadmap-2026-spring-update/4625473)) |
| 4K Texture Streaming | lansat | texturi de 1024 | Detaliu de aproape pe PC; telefonul primește automat rezoluția mică |
| SLIM (înlocuiește `LevelOfDetail = StreamingMesh`) | v1 lansat | folosim varianta veche | Satul întreg vizibil de departe, ieftin ([SLIM](https://about.roblox.com/de/newsroom/2025/12/introducing-roblox-slim-scalable-lightweight-interactive-models)) |
| `MaterialVariant` pe teren | GA | iarba și pământul Roblox standard | Iarbă și pământ moldovenești (textura de câmp, drumul de țară); acum terenul e cel generic |
| `GlobalWind` + iarba animată | GA (Decoration nu se poate seta din scripturi) | iarba nu se vede în capturi | Iarba și frunzele mișcate de vânt; de verificat de ce `Decoration` nu apare |
| `Clouds` dinamice | GA | lipsește | Cer viu, nori de furtună pentru vremea rea |
| `Lighting.LightingStyle` / Future | Future cade singur pe ShadowMap pe telefoanele slabe (`LightingStyle` neverificat) | `ShadowMap` fix | Lumini locale cu umbre (felinare, discotecă) pe dispozitivele care pot |
| Animation Graphs + `IKControl` + `FaceControls` | GA (iulie 2026) | articulații procedurale proprii | Bunica privește jucătorul, picioarele stau pe pantă, fețe expresive ([DevForum](https://devforum.roblox.com/t/full-release-animation-graphs-create-complex-character-motion-visually/4739840)) |
| Acoustic Simulation | beta | lipsește | Ecoul din casa de cultură, sunetul înfundat din casă |

Terenul nou (Early Access, 64 de materiale, memorie cu 40–60% mai mică) nu se poate încă publica, deci așteptăm.

### D. Senzație și tehnică

- **Input Action System** (GA iunie 2026): butoane remapabile, același cod pentru atingere, gamepad și tastatură. Acum: `ContextActionService`/`UserInputService`.
- **UI Styling** (`StyleSheet`, tokenuri): tema din `Theme.luau` devine foaie de stil, cu mai puțin cod per panou.
- **`UnreliableRemoteEvent`** (≤ 900 B): pozițiile cosmetice (papucul în zbor, efectele) fără coadă de retransmisie. Pe telefon, cu rețea slabă, se simte.
- **Parallel Luau** (Actors): viața satului (gâște, găini, săteni, berze) și vegetația pe mai multe nuclee.
- **`DragDetector`**: roaba, căruța, ouăle, decorul ogrăzii trase cu degetul, cu fizică.
- **`GuiService.PreferredTextSize`**: textul crește pentru cine a cerut asta în setări.

### E. Monetizare (în liniile roșii din VISION)

- **Subscriptions** (`PromptSubscriptionPurchase`, GA, min. 49 Robux): „Abonamentul Bunicii”, cosmetice lunare și servere private. Fără presiune de timp.
- **Rewarded video ads** (GA, doar 13+; publicul nostru e 16+): un bonus opțional de lei pe zi. Cerințe: 2.000 de vizitatori unici pe lună, dezvoltator 13+ cu ID și 2FA. Linia roșie din VISION interzice reclamele doar sub 13 ani.
- **Managed Pricing** (GA iunie 2026): prețuri regionale (Moldova și România sunt piețe ieftine) și teste automate. Codul e deja pregătit, pentru că prețurile vin din `GetProductInfo`.
- **Servere private „satul tău”** (Roblox Plus, în VISION): de activat din Dashboard.

### F. AI în joc (cu rezerve)

- **`TextGenerator`** (beta, gratuit acum, filtrat de Roblox Guard): VISION spune „fără LLM”. Motivul era riscul și faptul că funcționează doar în engleză. Pe calea sigură ar putea genera variații scurte de replici ale Bunicii, nu conversație liberă (conversația lungă trece jocul în Restricted). Decizia e a omului.
- **`AudioTextToSpeech`** (GA, 300 de caractere, fără română): vocea Bunicii rămâne înregistrată (VOICE.md), deci nu ne folosește.
- **`GenerationService:GenerateModelAsync`** (4D, beta din feb. 2026, fără preț publicat): papuci și decor generate dintr-un meniu fix, fără text liber. Spectaculos, dar beta și nepersistent.

### G. Nu recomand acum

- **Server Authority** (GA iulie 2026): costă CPU pe server și impune limite (64 de atribute, 8 piste de animație). Pentru un joc social de 8 jucători nu merită; papucul e deja validat pe server.
- **Mesh Streaming** cu LOD îmbunătățit: are buguri deschise (plase blocate pe LOD-ul cel mai mic).
- **Terenul Early Access**: nu se poate publica.

## 3. Ordinea propusă

1. **Creștere (A):** link-uri cu LaunchData + party → familie, notificări, RSVP, clipul papucului cu `PromptShareCapture`, apoi cele 2–3 thumbnail-uri și video. Cost: câteva zile. Efect: tocmai semnalele pe care le măsoară algoritmul.
2. **Grafică PBR (C):** hărți normale și roughness coapte în `post3d`, emissive noaptea, MaterialVariant pentru iarbă și drum, GlobalWind și nori, SLIM. Se refolosește tot pipeline-ul existent.
3. **Live ops (B), cu acordul omului pentru pasul 7:** Configs, Experiments, clasamente globale (MemoryStore + OrderedDataStore), anunțuri între servere.
4. **Senzație (D):** Input Action System, `UnreliableRemoteEvent`, `DragDetector`, Animation Graphs + IK pentru Bunica.
5. **Monetizare (E):** Managed Pricing (aproape gratis), abonament, reclame opționale.
6. **AI (F):** doar dacă omul ridică linia roșie „fără LLM”.

## 4. Ce nu știm

- Dacă importul GLB creează singur un SurfaceAppearance complet din hărțile PBR, sau trebuie redenumite cu sufixe (`_Normal`, `_Rough`). De testat pe un model.
- `Lighting.LightingStyle` înlocuiește `Technology`? Doar o sursă neoficială o spune.
- Emissive: roadmap-ul îl dă lansat, firul DevForum zice „On Hold”.
- Cât costă `TextGenerator` și 4D după beta.
