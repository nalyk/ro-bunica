# BUNICA — Progres

Ultima actualizare: 2026-10-12

## Făcut

- [x] GDD v2 (`docs/GDD.md`): PvP cu papucul aruncat de proprietar, ogrăzi doar cât ești pe server, Bunica NPC ca apărare de bază, piețe BR/LATAM/EE, 5 limbi.
- [x] Arhitectura (`docs/ARCHITECTURE.md`).
- [x] Unelte prin Rokit: Rojo 7.7.1, Lune 0.11.0, Selene 0.32.0, StyLua 2.6.0, luau-lsp 1.70.1.

- [x] Scheletul proiectului: `default.project.json`, Selene (`selene generate-roblox-std` generează `roblox.yml`), StyLua, harness de teste Lune (`tests/init.luau`).
- [x] Config: rarități, creaturi (15), mutații, mărimi, vreme, economie, zi/noapte, apărare, furt, lume, schema profilului.
- [x] Domain + teste (64): Random, Economy, Mutation, Growth, Shop, DayNight, RateLimiter, Slipper, Raid, Inventory, Migrations.

- [x] Shared: `Net` (remote-uri), `GameState` (atribute replicate), `Strings` (RO + EN; RU/ES/PT cad pe EN până se scriu de mână), `Visual/CreatureBuilder` (placeholder procedural).
- [x] Server: WorldBuilder (sat cu 8 ogrăzi), DataService (ProfileStore), PlotService (ogrăzi + vecini NPC), StateService, CreatureService, DayNightService, WeatherService, GardenService, RaidService (furt anti-duplicare), EconomyService (venit, prieteni, offline, vânzare, beci), ShopService, SlipperService (proiectile pe server, Nervi, făcăleț), BunicaService (stări, bănuială, alarmă, Furia Bunicii).
- [x] `./tools.sh` = teste + lint + format + tipuri (luau-lsp) + build.

- [x] Client: ClientState (stare + traducere), UI kit brodat, HUD (lei, zi/noapte, vreme, papuci, Nervi, făcăleț, Furie, bara de semințe), ShopPanel, CellarPanel, SlipperController (click/atingere → aruncare), WorldController (etichete și animație creaturi, plante, prompt-uri, lumină, vreme), EffectsController (zbor papuc cu urmă roșie, lovituri, shake, recul, avertismentul Bunicii), NotifyController.
- [x] `./tools.sh` verde: 68 teste, lint, format, tipuri, build `build/bunica.rbxl`.

- [x] Review independent pentru erori de runtime; reparate: prompt-urile de furt lipsă pe ogrăzile NPC la pornire, remote-ul `ClientReady` (starea și stocul retrimise după ce clientul ascultă), modelul-fantomă când proprietarul pleacă în timpul unui furt, buclele de server protejate cu `pcall`, pivotul creaturilor pe centrul cutiei.

## Testare e2e

- Nivel 1 (local): `./tools.sh`.
- Nivel 2 (motorul Roblox real, Open Cloud Luau Execution): `python3 tools/cloud.py e2e` construiește `test.project.json`, publică o versiune „Saved” pe place-ul de test (universe 1855994157, place 5300295145; versiunea live nu se schimbă) și rulează `tests/e2e/Runner`. În sesiune nu rulează fizica și nici scripturile place-ului, iar jucători nu există: testele pornesc serverul prin `Server/Boot` și (următorul pas) folosesc actori-bot.
  - Cheia API e în `.env.cloud` (ignorat de git). **Rezultat: 14/14 teste e2e trec în motorul Roblox.** Au găsit 3 bug-uri reale: Bunica nu vedea piedestalele (raza 35 → 60), ograda botului eliminat nu revenea la NPC, creaturile pluteau (WorldPivot ignorat cu PrimaryPart → `CreatureBuilder.placeOn`).
- Nivel 3 (Studio prin Vinegar/Wine, izolat de desktop): **funcționează**. Pornire: `tmux new-session -d -s xvfb "Xvfb :99 -screen 0 1600x900x24 -nolisten tcp"`, apoi `tmux new-session -d -s studio "env DISPLAY=:99 flatpak run org.vinegarhq.Vinegar run"`. Obligatoriu `renderer = "D3D11"` în `~/.var/app/org.vinegarhq.Vinegar/config/vinegar/config.toml` (cu DXVK/Vulkan Studio crapă pe Xvfb). Capturi: `DISPLAY=:99 import -window root x.png`; input: `DISPLAY=:99 xdotool`. Nu folosi display-ul `:1` (desktopul omului, în uz).
  - Login făcut (Quick sign-in aprobat de om, persistă în prefix). Place-urile se copiază în `~/.var/app/org.vinegarhq.Vinegar/data/places/` (sandbox-ul flatpak nu vede `~/gits`; acces read-only la `build/` adăugat prin `flatpak override`, activ după restartul Studio). Output-ul jocului: Window → Output.
  - Primul playtest în Studio (2026-10-12): jocul pornește fără erori; HUD, zi/noapte, creaturi, Bunica, sămânța de start eclozează. Reparat: emoji 🩴 lipsă din fontul Roblox → text localizat; etichetele creaturilor vizibile doar până la 30 studs.

- Playtest automat cu jucător real + jucător-bot (`tools/playtest.sh`, scenariul în `tests/playtest`): **16/16** pe 2026-10-12. Pașii: eclozare, venit, taraba, cumpărare, plantare prin prompt, creștere, noapte (HUD + lumină), furt de la NPC, depunere, botul lovit de papuc (alarmă, Nervi, efecte), furt reușit al botului (notificare, scut), scutul, vânzare, beci, Bunica NPC, zero erori de script.
  - Găsite și reparate în playtest: camera intra în Bunica (spawn mutat în mijlocul ogrăzii), basmaua acoperea fața Bunicii, timer 0:00 la faza forțată, jucătorii se agățau în grila de piedestale (piedestale coborâte la 0,6 studs; varianta fără coliziune arunca jucătorul în aer).
  - Deschis: în pasul 15, drumul spre `roadPoint(npcPlots[3])` se blochează constant la 54 studs de țintă (pathfinding „Success”, dar personajul nu înaintează). De investigat ce obiect blochează.
  - Studio rulează un proces per place (`-task EditFile -localPlaceFile ...`); scriptul pornește Studio direct cu place-ul și închide instanța veche.

## În lucru: pașii 1–6 din VISION (aprobați 2026-10-12; pasul 7 doar la cerere)

Fiecare pas: logică în `Domain` + teste Lune, servicii, client, teste e2e în cloud, scenariu în playtest, GDD actualizat, commit + push.

- [x] **1. Primul minut** — `TutorialService`: la ~25 s după intrare (după eclozarea creaturii de start) vine hoțul NPC „Hoțomanul” pe drum, intră pe poartă, ridică o copie vizuală a creaturii (datele nu se ating; originalul ascuns cu `CreatureService.setHidden`). Hoțul e intrus forțat (`RaidService.forceIntruder`) și ziua. Aim assist (`Domain/AimAssist`): aruncarea în raza de 25 studs de hoț e redirecționată spre el. Fallback după 15 s: Bunica aruncă sigur. Clientul primește `Tutorial` (indiciu mare, mână animată, săgeată). Profil: `tutorialThiefDone`.
- [x] **2. Lovitura de papuc** — client: înghețarea camerei 0,07 s, FOV punch, shake, flash, text comic „PLEOSC!” la impact, sunete ProSoundEffects (lovitură, țipăt de hoț în zbor, căzătură), haptic (pcall). Server: ragdoll pentru boți. „Lovitura nopții”: cea mai lungă lovitură e reluată cu încetinitorul la răsărit (`Replay`), cu banner și anunț. Valorile în `Config/Juice`.
- [x] **3. Bunica-vedetă** — `Config/BunicaLines` (replici pe evenimente, RO/EN, `soundId` opțional pentru vocea înregistrată), bule de dialog, replica semnătură „Fugi, că vine Bunica!”. Client: animații procedurale pe Motor6D pe stări (doarme, bănuitoare, ochește, aruncă, sărbătorește, furioasă, veghează) și față desenată pe cap (ochelari rotunzi, sprâncene, gură pe stări).
- [x] **4. Familia și Hora** — `Domain/Family`: prietenii Roblox de pe server formează familii (max 4), cu ogrăzi alăturate. Membrii nu-și fură între ei, apără orice ogradă din familie cu papucul, iar Bunica îi consideră „acasă”. `Domain/Ritual` + `HoraService`: vatra satului (cerc pe drum, cu fântână); 3+ jucători care dansează 4 s cheamă Culesul de aur sau Curcubeul pentru server, cu cooldown 20 min. Buton „Horă” și dans procedural.
- [ ] **5. Furt corect** — max 2 furturi de la aceeași victimă pe noapte (apoi scut până dimineață), recompensă în lei pentru apărare (0,5 × prețul creaturii salvate), statistica „Apărări” în clasament.
- [ ] **6. Ritmul săptămânal** — `Config/LiveEvents` + `Domain/LiveEvents`: „Bunica se supără” sâmbăta 16:00–17:00 UTC (o oră înaintea update-ului de la 17:00): ploaie de papuci peste hoți, vremea exclusivă „Supărarea Bunicii” cu mutația „Papucită”, sămânță exclusivă rotativă pe săptămână, disponibilă doar online. Creștere offline a plantelor (plafon 8 h).

Rezultate pașii 1–2 (2026-10-12): e2e cloud 16/16, playtest Studio 19/19 (scena tutorialului jucată de clientul real, sunete încărcate, reluarea nopții). Găsite în playtest: jucătorul rămânea la spawn-ul satului (CharacterAdded vine înainte de parentare; jucătorii intrați înainte de pornirea serverului nu aveau handler) → reparat cu RespawnLocation pe ogradă + așteptare + reîncercări; camera nu arăta hoțul → cadru cinematic + săgeată la marginea ecranului. `tools/playtest.sh` face și capturi la comandă (`[PLAYTEST] SNAP <nume>`).

Rezultate pasul 3: e2e 17/17, playtest 19/19 (fața desenată, replică de lovitură, prim-plan în captură). Reparat: efectele de cameră își restaurau „starea anterioară” și se blocau reciproc → toate revin la `Custom`, iar hit-stop-ul nu rulează peste o secvență cinematică. `tools/playtest.sh` ascunde ferestrele blocate de Wine (dialogul 646×130 și pătratele 100×100).

Rezultate pasul 4: e2e 20/20, playtest 20/20 (Hora jucată de clientul real cu doi boți; captură cu toți trei dansând). Descoperiri importante:
- **Avatar Joint Upgrade:** rig-urile Roblox folosesc acum `AnimationConstraint`, nu `Motor6D`; pozele locale de pe client nu au efect pe ele. Rig-urile create de server (Bunica, boți) sunt convertite în `Motor6D` (`Ai/Rig.useMotors`); jucătorul dansează cu animația „dance” din scriptul lui Animate (se replică singură). Modulul `Controllers/Joints` lucrează cu ambele tipuri.
- **StreamingEnabled:** articulațiile și părțile sosesc după model → controllerele completează ce lipsește și caută periodic.
- **Iluminare:** Studio migrează automat „Compatibility” și blochează playtest-ul cu un dialog → `Lighting.Technology = ShadowMap` în toate proiectele.
- Agentul de playtest iese din ogradă pe poartă (`leaveHome`), deci nu se mai blochează în colțul gardului.

## După pașii 1–6

- Pasul 7 (Configs/Experiments, funnel AnalyticsService, Server Authority) — doar la cererea omului.
- Vocea reală a Bunicii: înregistrări (ideal o bunică reală) + încărcare de asset-uri (cheia actuală nu are dreptul `asset:write`).
- Texte ES, PT-BR, RU scrise de mână; modelele finale prin `modelId`; Ungheni ca decor (GDD §19).

## Decizii luate

- Ograda există doar cât proprietarul e pe server; papucul îl aruncă proprietarul; Bunica NPC apără slab când lipsește proprietarul.
- Creatura cărată rămâne în profilul proprietarului până la depunere (anti-duplicare).
- Furturi doar noaptea; scut de 60 s după furt; protecție 20 min pentru jucători noi.
- Fazele, costurile și echipa din brief-urile externe nu se aplică (proiect solo, la scară mare).
