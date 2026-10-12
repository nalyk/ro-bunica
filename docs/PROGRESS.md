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

## Testare e2e (în lucru)

- Nivel 1 (local): `./tools.sh`.
- Nivel 2 (motorul Roblox real, Open Cloud Luau Execution): `python3 tools/cloud.py e2e` construiește `test.project.json`, publică o versiune „Saved” pe place-ul de test (universe 1855994157, place 5300295145; versiunea live nu se schimbă) și rulează `tests/e2e/Runner`. În sesiune nu rulează fizica și nici scripturile place-ului, iar jucători nu există: testele pornesc serverul prin `Server/Boot` și (următorul pas) folosesc actori-bot.
  - **Blocaj:** cheia API din `.env.cloud` (`ROBLOX_API_KEY`). Crearea ei din browser a fost blocată de clasificatorul de siguranță al sesiunii; o creează omul (drepturi: universe-places write, luau-execution-sessions read + write, restricționată la experience-ul de test și la IP-ul 212.56.197.2).
- Nivel 3 (Studio prin Vinegar/Wine, izolat de desktop): **funcționează**. Pornire: `tmux new-session -d -s xvfb "Xvfb :99 -screen 0 1600x900x24 -nolisten tcp"`, apoi `tmux new-session -d -s studio "env DISPLAY=:99 flatpak run org.vinegarhq.Vinegar run"`. Obligatoriu `renderer = "D3D11"` în `~/.var/app/org.vinegarhq.Vinegar/config/vinegar/config.toml` (cu DXVK/Vulkan Studio crapă pe Xvfb). Capturi: `DISPLAY=:99 import -window root x.png`; input: `DISPLAY=:99 xdotool`. Nu folosi display-ul `:1` (desktopul omului, în uz).
  - **Blocaj:** login-ul în Studio (Quick sign-in cu cod) îl aprobă omul.

## Urmează

1. **Primul test în Studio (de făcut de om, pe Windows/macOS).** În Studio, ciclul zi/noapte merge de 4× mai repede, iar protecția jucătorilor noi e oprită. deschide `build/bunica.rbxl` sau `rojo serve` + pluginul Rojo. Activează „Enable Studio Access to API Services” pentru DataStore (altfel ProfileStore rulează în mod mock). Test cu 2 jucători: Test → Clients and Servers → 2 Players. Raportează erorile din Output.
2. Tutorialul ghidat din primele 10 minute (hoț NPC scriptat la 2:00, furt ghidat la vecin, mutație garantată).
3. Upgrade-uri pe lei (straturi, piedestale, beci, Grivei, cocoș, muniție) și UI-ul lor.
4. Monetizare: game passes, developer products, vremea cumpărată pentru server (`WeatherService.trigger`).
5. Analytics (AnalyticsService): funnel primele 10 minute, retenție, raiduri pe noapte, conversie.
6. Clasamente (OrderedDataStore) și gardul de laudă cu nume.
7. Texte RU, ES, PT-BR scrise de mână.
8. Sunete (lovitura de papuc, cocoș, noaptea) și modelele finale (Bunica, creaturi, papuc) prin `modelId`.
9. Ungheni ca decor (GDD §19), după confirmare; apoi evenimentul gării cu schimbarea ecartamentului.

## Decizii luate

- Ograda există doar cât proprietarul e pe server; papucul îl aruncă proprietarul; Bunica NPC apără slab când lipsește proprietarul.
- Creatura cărată rămâne în profilul proprietarului până la depunere (anti-duplicare).
- Furturi doar noaptea; scut de 60 s după furt; protecție 20 min pentru jucători noi.
- Fazele, costurile și echipa din brief-urile externe nu se aplică (proiect solo, la scară mare).
