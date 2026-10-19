# BUNICA — Progres

Ultima actualizare: 2026-10-19

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

## Interfața pe telefon (2026-10-17)

Designul e în `docs/superpowers/specs/2026-10-17-mobil-hud-design.md`, pornit de la două capturi de pe telefonul omului.

- [x] **Două așezări:** desktop și tactil, cu tactil = atingere fără mouse.
  - Geometria tactilă e în `Domain/HudLayout`. E testată pe 6 ecrane (iPhone SE, iPhone 14, Android mic, îngust și lat, tabletă): nimic interactiv în zona joystick-ului (stânga 40%, 2/3 de jos) sau peste săritură, totul în ecran, fără suprapuneri, butoane de minimum 44 px și notificări destul de late.
  - Săritura e citită la rulare din `TouchGui`; dacă lipsește, se folosește formula din TouchJump.
- [x] **Pe telefon:**
  - rândul de butoane sus-stânga: Semințe, Beci, Ograda, Caietul și „Mai mult” (Horă, Prieteni, Magazin);
  - banii și ziua sus-dreapta, la scara 0,62;
  - lângă săritură: Furia și Făcălețul rotunde, iar deasupra papucii și Nervii;
  - semințele într-o bandă derulabilă jos;
  - panourile la 94% × 90% din ecran;
  - notificările cu text fix, rupt pe rânduri.
- [x] **Pe desktop:**
  - cutia de apărare se lărgește pentru 4–5 papuci (bug-ul „Papuci: 3/3” tăiat) și are eticheta „Nervii Bunicii”;
  - coloana are „Prieteni” în loc de „Cheamă prieteni”;
  - notificările lungi nu mai sunt tăiate.
- [x] **Panoul „Prieteni”:** invitația, Familie sau Rivali și jucătorii de pe server cu „Schimb”. Înlocuiește butoanele plutitoare din versiunea 79, care se suprapuneau cu coloana.
- [x] **Root:** `UI.screen()` e acum un Frame „Root”. În playtest, `Layout.setOverride` îl micșorează la mărimea unui telefon. Pasul 15l auditează dreptunghiurile reale pe trei telefoane și face capturi.
- **Reparat în kit:** buza 3D a butoanelor acoperea textul când butonul avea ZIndex (`lip.ZIndex = 0`).
- [x] **Mesajele pe telefon (după feedback-ul omului: „acoperă ecranul”):**
  - Coada cu priorități e în `Domain/NoticeQueue`, iar importanța fiecărei chei în `Config/Notices`. Prioritățile:
    - urgent: hoțul, furtul, noaptea;
    - reward: reușitele tale;
    - hint: de ce n-a mers o acțiune; doar cel mai nou rămâne, expiră în 4 s;
    - ambient: ce fac alții; apare doar cu coada goală, expiră în 8 s;
    - quiet: confirmările din panouri.
  - Pe telefon e o singură capsulă sus, peste cer (`HudLayout.notice`), care nu primește atingeri.
    - Se vede un mesaj odată; urgentul îl întrerupe pe celălalt.
    - Mesajele identice se unesc („×3”), iar durata urmează timpul de citire și scade când așteaptă multe.
    - Confirmările din panouri nu apar, pentru că le arată deja monedele care zboară.
  - Pe desktop rămân două coloane, sus (cel mult 2) și jos (cel mult 3), cu aceeași coadă.
  - Verificat: 8 teste Lune, iar în playtest două rafale de 12 mesaje pe iPhone SE dau un singur mesaj pe ecran, alarma prima („×3”) și coada goală în 9 s.

## Cercetarea „Satul viu” (2026-10-18)

- Cercetarea e în `docs/RESEARCH_SAT_VIU.md`: opțiuni, nu plan aprobat. Surse:
  - 4 fluxuri pe web (satul moldovenesc, piața Roblox 2025–2026, copiii și jocul, așezări organice);
  - 3 sate reale măsurate în OpenStreetMap (`tools/research/osm_villages.py`);
  - 5 așezări modelate cu echitatea calculată pe graful drumurilor (`tools/research/layouts.py`);
  - 6 copii-tip simulați.
- **Recomandarea:** pachetul B (satul-jucărie) cu tradiția ca aromă:
  - valea cu două ulițe legate (expunerea la raid are CV 0,11, față de 0,17 acum);
  - 17 locuri-jucărie, din care 6 în B;
  - ceasul satului (o întâmplare la 6–8 minute);
  - 4 mini-jocuri;
  - creaturi de suflet și răzbunare (furtul fără lacrimi);
  - drumurile paralele spre statut.
- **Blocant de platformă:** publicul copiilor cere ID verificat, 2FA și Roblox Plus (de confirmat). Ține de om.
- **Următorul pas:** omul alege pachetul și ordinea (§8).

## Satul viu, pachetul C complet (2026-10-18)

Omul a cerut tot pachetul C din `docs/RESEARCH_SAT_VIU.md`, „full featured”. Planul: `docs/superpowers/plans/2026-10-18-satul-viu-full.md` (37 de sarcini). Execuția e în ledger-ul local `.superpowers/sdd/2026-10-18-satul-viu-full/progress.md` (ignorat de git), cu toate deciziile („Ruling”).

**Gata (sarcinile 1–24, commit-urile până la 87031a6):**
- **M1:** creaturile de suflet (cel mult 3, nu se fură, nu se schimbă); răzbunarea (hoțul vizibil până în zori, bonus la furtul înapoi); avertizarea la schimburi dezechilibrate.
- **M2, satul de vale:** `Domain/VillageLayout`, cu echitatea raidurilor testată (CV 0,084, max/min 1,22, niciun drum prin ogrăzi). Teren cu dealuri, pârâu și iaz cu apă reală, drumuri curbe, poduri, poteci dincolo de pârâu. Ogrăzi variate (porți vopsite prin masca de alfa a texturii, `tools/paint_mask.py`; 4 seturi de decor), cu aceleași poziții de joc. 17 locuri (`SiteBuilder`), cu centrul ca zonă fără bătaie. Decor Poisson. Viața satului pe client (gâște, găini, câini care latră în lanț noaptea, săteni, berze, rufe). Rutiera (traseu în opt, 150 s, oprire la fiecare ogradă). Streaming și bugetul de randare (decor ≤ 120k pe ogradă, ≤ 1,2M în sat; gardul, floarea-soarelui și straturile decimate).
- **M3, ceasul satului:** o întâmplare la 6–8 minute (`VillageClockService`), anunțată cu 30 s înainte, cu semn în lume și săgeată. Întâmplările: gâștele, ploaia de cireșe (cu mătușa Mărioara), negustorul cu rutiera, nunta (horă cu cortegiul), ceața (Bunicile văd la jumătate), lupii la stână (co-op), Muma Pădurii (mini-boss), trenul de la Ungheni.
- **M4, mini-jocurile (`MinigameService`):** înscriere la loc, numărătoare, tabela de scor (bandă sub mesaje), podium, fantome care încurajează. Jocurile: prinde cocoșul, șotronul, ciocnitul ouălor, oina cu papuci, ascunselea în porumb, Păcală se ascunde, cursa cu roaba, obby-ul morii, zdrobitul strugurilor, Discoteca (dans sau „Cea mai tare Bunică”, cu vot), plăcintăria (co-op, cu creștere mai rapidă), „Țară, țară, vrem ostași”. Plus hora pe ritm („cercul perfect” cheamă Curcubeul), pescuitul la iaz și recordurile pe avizierul din centru.
- **Verificare:** 250 de teste unitare, e2e 77/77 (în loturi paralele: o sarcină Open Cloud are cel mult 5 minute), playtest complet de peste 40 de pași (`PLAYTEST_UNTIL=<pas>` rulează doar până la un pas).

**Gata (sarcinile 25–33, commit-urile 519380e, 3b20012, c6c6c3b, dda2977):**
- **M5, statutul și grija:** decorul ogrăzii pe lei (22 de obiecte, 12 sloturi, așezare cu previzualizare); garderoba Bunicii (6 ținute) și titlurile (7, din statistici); îngrijirea creaturilor (fericire, hrană, mângâiere, +10% venit); hibrizii (nume pronunțabile, pălăria, (A + B) × 0,75, colecția lor); siluetele din Caiet și fila Recorduri.
- **M6, comunicarea și piața:** mesajele rapide (12, în 5 limbi, bula deasupra capului); bazarul (`Domain/Market`, `MarketService`, `MarketPanel`): tarabe, prețuri 25%–10× din valoare, creatura rămâne în beci marcată cât e la vânzare (nu se vinde, nu se mută, nu se schimbă), cumpărarea mută leii și creatura deodată, plecarea vânzătorului golește taraba, duminica 12 tarabe și negustori NPC; codurile tantii de la magazin (`Config/Codes`, o folosire pe profil, căsuța din magazin); alarma în lanț (câinii vecinilor latră la hoțul care cară, proprietarul află discret).
- **M7, calendarul (`Domain/Seasons`, `SeasonService`, `SeasonController`):** Paștele ortodox după Meeus (2026 = 12 aprilie, 2027 = 2 mai), Mărțișorul (straturi × 1,2), ouăle de Paște prin sat și ou încondeiat la ciocnit, coronița de Drăgaică, știuletele roșu la Cules (și strugurii propuși mai des), hramul satului (o zi pe lună, pe server: nu se fură, decorul dă venit), iarna: colinde la vecinii NPC, Capra și Ursul, masca de Malanca (Bunica nu te recunoaște 30 s), gheața pe iaz. `SeasonService.force` pentru teste.
- **Verificare:** 293 de teste unitare, e2e 90/90.

**Gata (sarcinile 34–35):**
- **M8, limbile:** rusă, spaniolă și portugheză (Brazilia) complete (508 texte fiecare, scrise de mână, cu nume locale pentru creaturi); testul cere fiecare cheie din engleză, cu aceleași argumente. Numele creaturii cu mutația în ordinea limbii (`fmt.creature`: în ES și PT adjectivul vine după nume).
- **M9, modelele satului:** 32 de concepte Codex (planșa în `art/concepts/world` și `art/concepts/village`), 31 de modele TRELLIS (Rutiera a rămas fără memorie pe GPU; reîncercată separat). Legate în `SiteBuilder` (magazinul, stația, moara, biserica fără cruce, gara, coliba stânii, tarabele, cuptorul, căpițele, pătulul, sperietoarea, butucii, cireșii, oile), în poduri (doar la vedere; podeaua veche, invizibilă, rămâne pentru mers), în figurile întâmplărilor (`Kit.SCULPTED`: negustorul, Mărioara, Muma Pădurii, mirii, lăutarii), în viața satului (gâște, găini, săteni), la lupi, gâștele întâmplării și cocoș (găina, mai mare, cu creastă și coadă: generatorul de imagini refuză cocoșii). Unde lipsește un model, rămâne construcția procedurală. Bugetul satului: 1,19M triunghiuri (≤ 1,2M).

**M10 (sarcinile 36–37):**
- Chestionarul de maturitate și Experience Events: răspunsurile și textele sunt în `docs/PLATFORM.md`; trimiterea le schimbă ce vede publicul, deci o face omul din Creator Dashboard.
- Review-ul final independent al ramurii (dfa57c0..3656e64): o problemă critică (NaN la vânzarea peștilor → lei NaN, cumpărături gratuite) și cinci importante (Secretele la bazar, mini-jocuri fără efort, refresh scump la bazar, tarabele rămase la 12, duplicare la preluarea sesiunii), toate reparate cu teste (commit bfdbe42; unit 299, e2e 91/91). Minorii amânați sunt în ledger: negustorul NPC nu actualizează clasamentul, renașterea lasă oferte moarte, actor recreat la ieșire, titlul „Dansatoarea” farmabil, ouăle de Paște reapar imediat, limitatoarele nu uită jucătorii.
- Rutiera a rămas procedurală (TRELLIS rămâne fără memorie pe acest concept); Casa de cultură procedurală (interiorul e folosit de Discotecă).

## Platforma Roblox la maximum (2026-10-18, pasul 7 deblocat)

Auditul e în `docs/RESEARCH_PLATFORMA.md`, planul și progresul în `docs/superpowers/plans/2026-10-18-platforma.md`.

- **Creștere:**
  - link-ul ogrăzii și invitația cu LaunchData (cine vine ajunge pe serverul gazdei și intră în familia ei);
  - recomandările („Gazda satului”, „Musafirul”); grupurile Roblox (party) devin familie;
  - „Vin și eu” la evenimente; clipul loviturii nopții;
  - notificările după plecare (plantele coapte, sâmbăta în sat, bazarul de duminică).
- **Grafică:** hărți normale coapte pe toate modelele (PBR complet în Roblox), texturi proprii pentru iarbă, drum și cărări (MaterialVariant), nori dinamici și vânt după vreme.
- **Live ops:**
  - 12 valori reglabile din Roblox Configs (papucul se poate testa A/B pe jucători);
  - analytics segmentat și funnel social; topul săptămânal din toate satele pe avizier;
  - anunțuri rare pe toate serverele; `cloud.py announce|live|ban|unban`.
- **Senzație:** textul crește după setarea jucătorului; Bunica își urmărește cu privirea vizitatorii.
- **Busola și harta satului:**
  - Busola-bandă sus (tactil: între butoane și bani; desktop: la centru, deasupra banilor), cu ograda, prietenii, întâmplarea, mini-jocul, rutiera și ținta, plus distanța sau numărătoarea.
  - Atinsă (sau tasta M) deschide harta brodată a satului. Atingi un loc și apare o potecă de puncte cusute pe pământ până acolo.
- **Grafică, ultimele piese:** SLIM pe locurile satului; texturile de teren aprobate.
- **Monetizare:** abonamentul „Grandma's Friends” (99 Robux pe lună, doar cosmetice; în review la Roblox).
- **Managed Pricing:** pornit pe permise. Pentru produse, verificările anti-arbitraj sunt în joc: nivelul de preț (`GetUsersPriceLevelsAsync`, citit la intrare de RegionPolicyService). Schimburile cer niveluri apropiate (toleranță 25/1000). La bazar leii nu urcă spre o regiune mai scumpă. Necunoscut = închis. Nivelul real măsurat: Moldova 400, global 1000.
- **Ce ține de om:**
  - reclamele cu recompensă, după 2.000 de vizitatori unici pe lună.
- **Notificările merg:** cheia e în Secrets („notifications”); trimiterea e verificată din Open Cloud.

## Politicile Roblox, chestionarul și grafica (2026-10-18, după pachetul C)

- **Politicile pe jucător:** `Domain/Policy` și `RegionPolicyService` (PolicyService, cerut la intrare; fără răspuns înseamnă restricționat). Magazinul ascunde produsele marcate `random` în `Config/Monetization` (lei, reînnoire, vreme, 2× lei) unde `ArePaidRandomItemsRestricted`. Schimburile și bazarul se închid unde `IsPaidItemTradingAllowed` e fals (verificat pe server; butoanele nu apar). Teste: `tests/Policy.spec.luau`, e2e `99_Policy`, playtest 3c (12 rânduri în magazin, 5 când e restricționat).
- **Chestionarul de maturitate:** răspunsurile în `docs/PLATFORM.md`, cu previzualizarea Mild. Atenție: „teme romantice: da” dă Restricted (18+).
- **Experience Events:** toate 7 publicate (Public) după refacerea graficii; datele în `docs/PLATFORM.md`. Sâmbăta și bazarul de duminică sunt create doar pentru 24–25 oct. (fără repetare în Dashboard): de recreat săptămânal.
- **Grafica refăcută pe fluxul complet** (concept Codex → decupare → TRELLIS → `art.py`; detalii și decizii în `docs/superpowers/plans/2026-10-18-grafica-satului.md`):
  - 21 de modele noi: salcâm, plop, măr, prun, stejar (coroane pline din `tools/tree_crown.py`), tufă, liliac, flori, stuf, stâlpul cu barză, școala, porumbul, ulucile, pontonul, lăița, căruța, sacii, lemnele, bucătăria de vară, rutiera nouă (RutieraV2); pietrele sunt procedurale (textura TRELLIS ieșea neagră).
  - `Domain/Vegetation`: aleea de salcâmi, plopii lângă calea ferată, livezile, pâlcurile, codrul, stuful, florile (698 de bucăți, 418 copaci, determinist).
  - Locurile îmbrăcate: Casa de cultură sculptată cu ringul afară, școala, iazul cu ponton, via cu butuci, lanul din segmente de porumb, moara/biserica/stâna mai mari, cu copaci, gard, lăițe, căruțe; gardul ogrăzilor din uluci.
  - Drumurile se văd în sfârșit (stăteau sub iarba netezită); amurgul și noaptea mai luminoase.
  - Bugetul: decorul unei ogrăzi ≤ 120k, densitatea locală ≤ 1M pe 200 studs (993k).
  - Verificare: galeria 1g (fiecare loc de aproape), e2e 92/92, playtest 48/48.

## Acoperișul casei (2026-10-18)

- **Problema** (raportată de om: acoperișurile „oribile” de jos, cu găuri la îmbinări): acoperișul TRELLIS era o coajă subțire, fără partea de jos. În Roblox, cu fețe pe o singură parte, se vedea cerul prin el; marginea era zdrențuită (13.707 margini deschise în model), iar între țiglă, grinzi și ziduri rămâneau goluri.
- **Reparația:** `tools/house_roof.py`, legat în `tools/art.py` prin `"roof": true`, taie acoperișul și hornul vechi și construiește acoperișul în patru ape din concept:
  - olane cu relief real, cu treaptă la fiecare rând, și coame din țiglă peste muchii și peste coamă;
  - un strat închis sub țigle, ca prin fante să se vadă umbră, nu cer;
  - scândura de streașină și tavanul de scânduri dedesubt (capetele grinzilor vechi ies prin el);
  - hornul alb cu căciulă de țiglă.
- **Rezultat:** 3 MeshPart-uri (body 9.401, roof 8.504, trim 138 triunghiuri), asset 80628472824283. Verificat cu randări cu backface culling și cu capturi din joc (pasul 15m: sub streașină, din colț, de sus; casa are piesele body, roof și trim). Playtest 36/36.

## Unde am rămas (2026-10-19, sesiune închisă)

- **Live:** commit 7acee96 (busola, harta, poteca), publicat; e2e 102/102, playtest 49/49, CI verde.
- **Procese oprite** la cererea omului: Studio (Vinegar/Wine), Xvfb `:99`, sesiunile tmux `studio` și `xvfb`. Pe ai-esempla nu rula nimic de-al nostru (vLLM rămâne neatins). Repornire playtest: `tmux new-session -d -s xvfb "Xvfb :99 -screen 0 1600x900x24 -nolisten tcp"`, apoi `tools/playtest.sh <dir>` (pornește Studio singur).
- **De făcut, în ordine:**
  1. Managed Pricing pe cele 7 produse: Creator Dashboard → Monetization → Managed Pricing → Manage items → produsele → Enable → „My experience implements the appropriate checks” (verificările sunt live din 1c28e12). Blocat doar de extensia Chrome deconectată.
  2. Starea abonamentului `EXP-4024965016297013811` (era „In Review/Inactive”).
  3. Evenimentele de sâmbătă și bazarul de duminică: de recreat săptămânal (după 24–25 oct.).
  4. Lustru pe hartă: etichetele locurilor se suprapun în centrul satului (grupul dens).
  5. Vocea Bunicii în EN/ES/PT (`docs/VOICE.md`).
  6. Ferestre luminoase noaptea: doar cu mască pictată de mână (masca automată din atlasul TRELLIS e nesigură).

## Creștere fără bani (2026-10-19, început, oprit de om)

- Omul: niciun ban pe reclame, Claude face tot; textele publice trec prin humanizer-trilingual. Live: 3 vizite, 0 jucători.
- Browserul: Reddit, Facebook, X, Instagram și YouTube Studio sunt blocate pentru agent; TikTok, Discord și DevForum nu sunt logate. Rămân Creator Dashboard (video și miniaturi pe pagină, textele paginii în PT/ES/RU, evenimentele săptămânale) și DevForum (prin SSO Roblox).
- Filmarea: Studio pe Xvfb randează software (~5 cadre/s) și umple memoria. Varianta cu GPU: sway headless + Xwayland `:0` (randare Intel directă, verificată). Înainte de pornire se închid toate procesele Wine, altfel Studio moștenește vechiul DISPLAY `:99`.
- Următorul pas: Studio pe `:0`, locul de filmare cu regizor cinematic, trailerul, 3 miniaturi, apoi Dashboard-ul.

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
