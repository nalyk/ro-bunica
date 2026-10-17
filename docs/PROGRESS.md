# BUNICA — Progres

Ultima actualizare: 2026-10-17

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

## Pașii 1–6 din VISION (gata) (aprobați 2026-10-12; pasul 7 doar la cerere)

Fiecare pas: logică în `Domain` + teste Lune, servicii, client, teste e2e în cloud, scenariu în playtest, GDD actualizat, commit + push.

- [x] **1. Primul minut** — `TutorialService`: la ~25 s după intrare (după eclozarea creaturii de start) vine hoțul NPC „Hoțomanul” pe drum, intră pe poartă, ridică o copie vizuală a creaturii (datele nu se ating; originalul ascuns cu `CreatureService.setHidden`). Hoțul e intrus forțat (`RaidService.forceIntruder`) și ziua. Aim assist (`Domain/AimAssist`): aruncarea în raza de 25 studs de hoț e redirecționată spre el. Fallback după 15 s: Bunica aruncă sigur. Clientul primește `Tutorial` (indiciu mare, mână animată, săgeată). Profil: `tutorialThiefDone`.
- [x] **2. Lovitura de papuc** — client: înghețarea camerei 0,07 s, FOV punch, shake, flash, text comic „PLEOSC!” la impact, sunete ProSoundEffects (lovitură, țipăt de hoț în zbor, căzătură), haptic (pcall). Server: ragdoll pentru boți. „Lovitura nopții”: cea mai lungă lovitură e reluată cu încetinitorul la răsărit (`Replay`), cu banner și anunț. Valorile în `Config/Juice`.
- [x] **3. Bunica-vedetă** — `Config/BunicaLines` (replici pe evenimente, RO/EN, `soundId` opțional pentru vocea înregistrată), bule de dialog, replica semnătură „Fugi, că vine Bunica!”. Client: animații procedurale pe Motor6D pe stări (doarme, bănuitoare, ochește, aruncă, sărbătorește, furioasă, veghează) și față desenată pe cap (ochelari rotunzi, sprâncene, gură pe stări).
- [x] **4. Familia și Hora** — `Domain/Family`: prietenii Roblox de pe server formează familii (max 4), cu ogrăzi alăturate. Membrii nu-și fură între ei, apără orice ogradă din familie cu papucul, iar Bunica îi consideră „acasă”. `Domain/Ritual` + `HoraService`: vatra satului (cerc pe drum, cu fântână); 3+ jucători care dansează 4 s cheamă Culesul de aur sau Curcubeul pentru server, cu cooldown 20 min. Buton „Horă” și dans procedural.
- [x] **5. Furt corect** — max 2 furturi de la aceeași victimă pe noapte (apoi scut până dimineață), recompensă în lei pentru apărare (0,5 × prețul creaturii salvate), statistica „Apărări” în clasament.
- [x] **6. Ritmul săptămânal** — `Config/LiveEvents` + `Domain/LiveEvents`: „Bunica se supără” sâmbăta 16:00–17:00 UTC (o oră înaintea update-ului de la 17:00): ploaie de papuci peste hoți, vremea exclusivă „Supărarea Bunicii” cu mutația „Papucită”, sămânță exclusivă rotativă pe săptămână, disponibilă doar online. Creștere offline a plantelor (plafon 8 h).

Rezultate pașii 1–2 (2026-10-12): e2e cloud 16/16, playtest Studio 19/19 (scena tutorialului jucată de clientul real, sunete încărcate, reluarea nopții). Găsite în playtest: jucătorul rămânea la spawn-ul satului (CharacterAdded vine înainte de parentare; jucătorii intrați înainte de pornirea serverului nu aveau handler) → reparat cu RespawnLocation pe ogradă + așteptare + reîncercări; camera nu arăta hoțul → cadru cinematic + săgeată la marginea ecranului. `tools/playtest.sh` face și capturi la comandă (`[PLAYTEST] SNAP <nume>`).

Rezultate pasul 3: e2e 17/17, playtest 19/19 (fața desenată, replică de lovitură, prim-plan în captură). Reparat: efectele de cameră își restaurau „starea anterioară” și se blocau reciproc → toate revin la `Custom`, iar hit-stop-ul nu rulează peste o secvență cinematică. `tools/playtest.sh` ascunde ferestrele blocate de Wine (dialogul 646×130 și pătratele 100×100).

Rezultate pasul 4: e2e 20/20, playtest 20/20 (Hora jucată de clientul real cu doi boți; captură cu toți trei dansând). Descoperiri importante:
- **Avatar Joint Upgrade:** rig-urile Roblox folosesc acum `AnimationConstraint`, nu `Motor6D`; pozele locale de pe client nu au efect pe ele. Rig-urile create de server (Bunica, boți) sunt convertite în `Motor6D` (`Ai/Rig.useMotors`); jucătorul dansează cu animația „dance” din scriptul lui Animate (se replică singură). Modulul `Controllers/Joints` lucrează cu ambele tipuri.
- **StreamingEnabled:** articulațiile și părțile sosesc după model → controllerele completează ce lipsește și caută periodic.
- **Iluminare:** Studio migrează automat „Compatibility” și blochează playtest-ul cu un dialog → `Lighting.Technology = ShadowMap` în toate proiectele.
- Agentul de playtest iese din ogradă pe poartă (`leaveHome`), deci nu se mai blochează în colțul gardului.

Rezultate pasul 5: e2e 22/22 (două furturi complete, al treilea refuzat, resetare dimineața; recompensa exactă), playtest 20/20 (notificarea recompensei și coloana „Papuci” pe clientul real).

Rezultate pasul 6: e2e 25/25 (vremea și sămânța exclusivă, papucii din cer îl prind pe hoț, oprirea), playtest 21/21 (pastila din HUD, sămânța exclusivă în taraba clientului, captură cu anunțurile).

## După pașii 1–6

- Pasul 7 (Configs/Experiments, funnel AnalyticsService, Server Authority) — doar la cererea omului.
- Vocea reală a Bunicii: înregistrări (ideal o bunică reală) + încărcare de asset-uri (cheia actuală nu are dreptul `asset:write`).
- Texte ES, PT-BR, RU scrise de mână; modelele finale prin `modelId`; Ungheni ca decor (GDD §19).

## Prezentare: modele, UI/UX, sunet (din 2026-10-16)

Planul și cercetarea: `docs/PRESENTATION.md`. Pașii P1–P5:

- [ ] P1 Fluxul de asset-uri (`art/`, `tools/art.py`, `tools/assets.py`, `AssetIds.luau`, încărcare pe server cu fallback). Începutul: `art/lib/kit.py` și primul personaj (`art/creatures/cartofel_agent.py`), verificate în Blender 4.3 fără interfață.
- [~] P2 Modele: 16 creaturi și Bunica sculptate (concept Codex → TRELLIS.2 → Roblox), în joc și verificate (e2e 27/27, playtest 23/23). Satul sculptat e în joc: casa, poarta, tăblița, fântâna cu cumpănă în vatră, beciul, nucii, vișinii, floarea-soarelui, gardul de nuiele, piedestalele-buștean și rafturile de vitrină (ultimele trei la ~3k triunghiuri). Modelele sunt doar vizuale, puse de `placeArt` peste piesele vechi, care rămân coliziuni invizibile; piedestalele blocate estompează modelul (legătura `Art`). Hoțomanul sculptat e în tutorial (rig propriu cu picioare, mers procedural pe client, verificat în playtest: merge, tălpile pe drum). Mămăligator e refăcut (40k decimat local, soclul tăiat). Brânzoi v2 (pori fini, culoare corectată) și Mărțișorel (seed 23) sunt refăcute; toate cele 17 creaturi sunt sculptate. Straturile sculptate (concept v2 cu brazde netede: firimiturile fine făceau CuMesh să pice; 6k din 40k) sunt în joc; estomparea pieselor blocate e comună (`World/ArtFade`). Satul e complet sculptat. Optimizare pentru telefoane: decorul repetat în fiecare ogradă e decimat din nivelul de 40k (beci 6k, tăbliță 2,5k, floarea-soarelui 6k, nuci și vișini 8k), fără pierderi vizibile, iar șabloanele de 19k nefolosite (gard, piedestal, raft) au fost scoase; ~290k triunghiuri de decor pe ogradă, față de ~430k. `StreamingEnabled` rămâne de evaluat separat (schimbă comportamentul clientului). Proiectilele sunt sculptate: papucul roșu cu pompon (concept v2 neted, 6k; la 2,5k textura se rupe) și făcălețul (2,5k), sudate pe rădăcina invizibilă a proiectilului (`EffectsController.dressProjectile`), verificate în playtest (galeria „proiectile”, textură pe fiecare piesă). Reparat: coloana „Papuci” din clasament rămânea cu o apărare în urmă (statistica creștea după notificarea ascultătorilor).
- [ ] P2 (rest) Modele (17 creaturi, mutații ca spectacol, Bunica, Hoțomanul, satul, lumina pe faze).
- [~] P3 UI/UX: sistem de design (Theme, Motion, butoane „de jucărie”, panouri cu panglică), HUD nou, notificări, iconițe Codex, Nunito, lumină cinematică (SkyCycle/LightingDirector). Taraba și beciul au miniaturi 3D ale creaturilor (`CreaturePreview`, cu mărimea și mutația reale), construite doar când se schimbă lista; texte cu mărime uniformă (`UI.capText`); panourile stau deasupra HUD-ului. Gamepad (`GamepadController`): R2 aruncă prin ținta de deasupra centrului, L1 făcălețul, Y furia, X taraba, D-pad sus beciul, D-pad jos hora, B închide panoul; glifele platformei pe butoanele HUD (cu text de rezervă), selecția UI sare în panou; verificat în playtest (fără controller fizic).
- [ ] P3 (rest) UI/UX (tokeni, componente, mișcare cu resorturi, iconițe, HUD, gamepad, test de font).
- [~] P4 Sunet: taraf sintetizat, atlas audio (asset 94705666578776), dirijor adaptiv și efecte pe ritm, verificate în Studio (22/22). Detalii și pași în `docs/AUDIO.md`. Rămân: calitatea timbrelor (ACE-Step), ambianța 3D, efectele în tot UI-ul, vocea.
- [ ] P4 (rest) Sunet (graful audio nou, muzică adaptivă din melodii Mikuli, PLEOSC!, SFX, ambianță, vocea Bunicii).
- [ ] P5 Verificare (planșe de contact, capturi de playtest, e2e).

Permisiunea „assets” a fost adăugată pe 2026-10-16; încărcarea și `InsertService:LoadAsset` sunt verificate (detalii în PRESENTATION.md).
Vocea Bunicii: `docs/VOICE.md` (Gemini TTS gratuit, 4 voci proiectate în `art/voice/voices.json`, replici în `art/voice/takes/`; buget maximum 2 $, o singură dată). Omul a ales vocea B; replicile RO sunt gata și în joc (2026-10-17). Următorul pas: EN, ES, PT.

## Planul de terminare (`docs/PLAN_FINAL.md`)

- [x] 1. Îmbunătățiri pe lei (2026-10-17): `Config/Upgrades` + `Domain/Upgrades` (testat), `UpgradeService`, panoul „Ograda” (buton în HUD, D-pad dreapta pe gamepad), 5 iconițe noi. Piedestale (până la 20), straturi (până la 10), beci (+10), papuci (3 → 5), reîncărcare mai rapidă, Grivei (încetinește hoții din ogradă; modificatori de viteză comuni în RaidService, deci nu se calcă cu încetinirea de cărat), Bunica mai ageră. Grivei e sculptat (concept „jucărie netedă” → TRELLIS, 19k), stă în fața prispei și sare când latră. Verificat: unit, e2e 29/29, playtest 26/26.
- [x] 2. Vânzări pe Robux (2026-10-17): 5 permise create în Creator Dashboard și puse în vânzare (VIP Bunica 299, 2× lei 199, Papucul de Aur 149, Beci mare 99, Grădinar 149) și 4 produse (Pungă de lei 25, Sac de lei 99, Ladă de lei 249, Îngrășământ fermecat 29), toate cu iconițe generate (`tools/store_icons.py`), prețuri fixe (fără Managed Pricing). `Config/Monetization`, `Domain/Monetization` (testat), `MonetizationService` (ProcessReceipt idempotent, chitanțele în profil, salvare imediată), magazinul din joc (butonul „+” de pe bani), Papucul de Aur vizibil în zbor. Verificat: unit, e2e 30/30, playtest 27/27. Tot în 2026-10-17, la cererea explicită a omului, s-au creat și ultimele trei produse: Fresh Seeds 19 (`ShopService.restockFor`: o tragere nouă îmbinată cu stocul rămas, `Shop.merge`), Golden Harvest 99 și Rainbow Weather 199 (vreme pentru tot serverul, cu anunț). Verificat: e2e 32/32, playtest 28/28. Vocea Bunicii nu se auzea în jocul live (asset-urile audio fără permisiunea Use pentru joc): permisiunea dată pentru toate 20, bun venitul mutat după ecranul de încărcare, muzica coborâtă cât vorbește Bunica (docs/VOICE.md).
- [ ] - [x] 3. Măsurători (2026-10-17): `Server/Analytics` (AnalyticsService, protejat cu pcall) + `MetricsService`. Funnel-ul primelor minute în 9 pași (intrare, sămânța de start, hoțul din tutorial, prima sămânță cumpărată, primul plantat, prima noapte, prima îmbunătățire, primul furt, prima apărare), o dată pe profil (`profile.funnel`). Fluxurile de lei: surse (venit agregat pe minut, vânzare, apărare, offline, pachete Robux) și cheltuieli (semințe, îmbunătățiri). Evenimente: Steal, Defend, Robux_<cheie>. Se văd în Creator Dashboard → Analytics.
- [x] 4. Revenire și social (2026-10-17): „Darul Bunicii”, recompensă zilnică pe serie de 7 zile (`Domain/Daily`, testat; ziua 7 dă o sămânță rară), vine după hoțul din primul minut; butonul „Cheamă prieteni” (SocialService, +10% lei pe prieten); coloana din stânga se micșorează pe ecrane joase; un singur panou deschis odată. Verificat: e2e 31/31, playtest 28/28. Insigne (`Server/Badges`, create în Dashboard cu imagini generate): First Creature, Sneaky Neighbour, PLEOSC!, Legend of the Village, acordate la eclozare, furt, apărare și creatură legendară. Hora Dancer (horă reușită, `HoraService`) și First Million (1.000.000 de lei, `EconomyService.addLei`) create gratuit pe 2026-10-17 și legate; toate cele 6 insigne sunt active.
- [~] 5. Sunet și voce: ambianța satului (`AmbienceController`: vânt ziua, greieri noaptea, ploaie la Rain/Hail, trecere lină; verificată în playtest). **Vocea Bunicii în română e în joc (2026-10-17):** cele 20 de replici, vocea B, `art/voice/ro/`, -14 LUFS, legate în `BunicaLines.voice.ro` (id + durată), redate de pe capul Bunicii; bula stă cât vocea, iar serverul nu întrerupe o replică lungă. Verificat în playtest (vocea se încarcă). Rămân: vocea în EN/ES/PT (zilele următoare, aceeași voce), efectele în tot UI-ul.
- [ ] - [~] 6. Performanță și finisaj: decorul mic și repetat nu mai aruncă umbre (`ArtService.SHADOWLESS`). `StreamingEnabled` rămâne oprit: satul (8 ogrăzi, ~400×200 studs) încape oricum în raza implicită de streaming, deci n-ar descărca nimic, dar ar adăuga riscul ca modele încă neîncărcate să lipsească pe client.

## Retenția (2026-10-17), după evaluarea sinceră a jocului

Designul și motivele sunt în `docs/superpowers/specs/2026-10-17-retentie-design.md`; GDD-ul e actualizat (§9, §12, §12a, §12c0, §12c1).

- [x] **1. Serverul de 8:** `serverSize` era 50, iar jucătorii 9–50 erau dați afară („Serverul e plin”). L-am setat la 8 din Creator Dashboard (place → Access → Maximum Visitor Count); API-ul public arată `maxPlayers: 8`.
- [x] **2. Familie sau Rivali:**
  - profilul are `familyMode`; `Family.bonded` și `Family.canSwitch` sunt testate;
  - `FamilyService.setMode` (remote `FamilyMode`) merge doar ziua, cu o pauză de 10 s între schimbări;
  - butonul din HUD apare cât e un prieten pe server, iar prietenii primesc o notificare care explică alegerea.
- [x] **3. Ziua de 4 minute** (era de 6); noaptea rămâne de 3.
- [x] **4. Vecinii fură și ei:**
  - `Config/NpcThieves`, `Domain/NpcThieves` (testat) și `NpcThiefService`; hoțul e un bot cu regulile din RaidService;
  - traseul prin sat e făcut cu pathfinding (`Walker.pathTo`), iar timpul de cărat se calculează din distanță;
  - hoțul vine de la vecinul cel mai apropiat, iar creatura furată ajunge pe piedestalul vecinului.
- [x] **5. Caietul Bunicii:**
  - `Config/Notebook`, `Domain/Collection`, `Domain/Quests` și `Domain/Rebirth`, toate testate;
  - `NotebookService` primește evenimentele prin `Server/Progress` (plantat, eclozat, cumpărat, furat, apărat, vândut, horă, mutație, creatură obținută);
  - pe client, `NotebookPanel` are trei file;
  - venitul include renașterile și pragurile colecției (`EconomyService.multiplier`);
  - Rețeta Secretă vine ca sămânță la 50 de descoperiri.
- [x] **6. Schimburile:**
  - `Config/Trade` și `Domain/Trade` (testat: oferte, acceptări, validare, execuție totul-sau-nimic);
  - `TradeService` lucrează pe proprietari de ogrăzi, deci și boții de test pot face schimburi;
  - pe client, `TradePanel` are butonul „Schimb”, lista de jucători, cererea Da/Nu și fereastra cu valorile.
- **Iconițe noi:** `notebook` și `trade`. `tools/icons.py upload [nume]` urcă acum doar ce lipsește sau ce e cerut, pentru că decuparea nu e deterministă și altfel s-ar fi dublat asset-urile.
- **Revizuirea independentă de cod** a găsit 3 probleme:
  - un „Accept” repetat în numărătoare putea executa schimbul de două ori, adică leii se mutau de două ori. Acum: `done` și gărzi în `accept`;
  - un motiv de eșec greșit, din cauza precedenței `if … else` cu virgula;
  - recompensele colecției se puteau cultiva prin schimburi cu conturi noi. Acum creaturile primite la schimb nu intră în Caiet.
- **Găsite în playtest și reparate:**
  - hoțul vecin renunța după câteva replanificări; acum persistă până la termen, cu timpul de cărat calculat din distanță;
  - creatura furată ajungea în beciul vecinului (piedestale pline), de unde nu se mai putea fura înapoi. Acum vecinul își face loc pe un piedestal;
  - eticheta butoanelor cu ZIndex era acoperită de buza 3D (`UI.button`);
  - cererea de schimb rămânea peste fereastra de schimb.
- **Verificat:** 144 de teste unitare, e2e 40/40 și playtest 34/34. Pașii noi din playtest:
  - Familie/Rivali;
  - vecinul hoț doborât cu papucul;
  - vecinul hoț care duce Epicul acasă, apoi furtul înapoi pe căile reale;
  - Caietul cu răsplata unei treburi;
  - schimbul real între jucător și un bot;
  - renașterea.
- **Live:** versiunea 79 (commit 5c49ce7); CI verde.
- **E2E independent de oră:** Runner-ul oprește programul evenimentului de sâmbătă (`LiveEventService.setScheduled(false)`). Între 16:00 și 17:00 UTC, ploaia de papuci dobora boții de test.

## Lansare publică (2026-10-16)

- Jocul e public: https://www.roblox.com/games/5300295145 („Don't Steal from Bunica!”, gen Simulation / Incremental Simulator). Pagina: descriere EN și RO, iconița (Bunica cu papucul), două imagini (afiș + toate creaturile) pe prima pagină și pe pagina jocului, titlul și imaginile în română. Imaginile sunt compuse de `tools/store_art.py` din straturile ecranului de încărcare.
- Ecranul de încărcare (`src/first`, ReplicatedFirst): satul la apus, benzi de cusătură care curg, logo-ul care cade cu turtire și lucire, Bunica, Hoțomanul care se furișează și ia papucul („PLEOSC!”), bara „cusută” cu papucul pe vârf, sfaturi, perdele brodate la final; progres real (modelele din `ArtTemplates`, personajul), minim 4,5 s, maxim 40 s; respectă Reduced Motion. Straturile: `tools/loading.py build|upload`.
- Cheia `bunica-ci` are acum și `universe` (read/write), datastores, ordered datastores și messaging; vizibilitatea s-a pus prin API. Numele locului cere `universe.place:write`; s-a făcut din Creator Dashboard.
- Publicul e „16+ și prieteni de încredere”: pentru sub 16 ani Roblox cere 250 de jucători activi sau o taxă rambursabilă de 1.000 Robux (nu plătim fără acordul omului).

## Decizii luate

- Titlul public (2026-10-16): „Don't Steal from Bunica!” (RO: „Nu fura de la Bunica!”). Omul îl setează în Creator Dashboard când face locul public; cheia API nu are `universe:write`.
- Ograda există doar cât proprietarul e pe server; papucul îl aruncă proprietarul; Bunica NPC apără slab când lipsește proprietarul.
- Creatura cărată rămâne în profilul proprietarului până la depunere (anti-duplicare).
- Furturi doar noaptea; scut de 60 s după furt; protecție 20 min pentru jucători noi.
- Fazele, costurile și echipa din brief-urile externe nu se aplică (proiect solo, la scară mare).
