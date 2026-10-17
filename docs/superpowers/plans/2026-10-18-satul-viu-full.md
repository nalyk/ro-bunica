# Satul viu, varianta completă: plan de implementare

> **Pentru agenți:** sub-skill obligatoriu: superpowers:executing-plans (varianta Native, aleasă de agent: omul a cerut execuție autonomă, fără întrebări). Pașii folosesc căsuțe (`- [ ]`).

**Scop:** pachetul C complet din `docs/RESEARCH_SAT_VIU.md`, cu tot ce cuprinde:
- satul de vale (L4), cu teren, pârâu și locuri-jucărie;
- viața ambientală;
- ceasul satului cu întâmplările;
- 14 mini-jocuri;
- furtul fără lacrimi;
- drumurile paralele spre statut (decor, îngrijire, titluri, hibrizi, Discoteca);
- socialul fără chat;
- bazarul;
- sezoanele;
- limbile RU, ES și PT;
- modelele sculptate pentru locurile noi;
- performanța pe telefon.

**Arhitectura (convențiile din `docs/ARCHITECTURE.md`):**
- regulile pure stau în `src/shared/Domain/*` și au teste Lune;
- datele stau în `src/shared/Config/*`;
- serviciile de server au `init`/`start`;
- clientul randează din atribute și remote-uri;
- serverul are autoritate;
- fiecare remote are rate limit;
- geometria tactilă trece prin `HudLayout`;
- mesajele trec prin `NoticeQueue`.

**Tehnologii:** Luau (strict), Rojo, Lune, Selene, StyLua, luau-lsp, Roblox Terrain API, Blender (headless), Codex image_gen, TRELLIS.2 (ai-esempla), Open Cloud.

**Specificația:** `docs/RESEARCH_SAT_VIU.md` (§2–§10). Designul jocului: `docs/GDD.md`.

## Constrângeri globale

- **Tradiția e aromă:** testul „e mișto pentru un copil de 10 ani din 2026?”; cultura e mecanică, nu lecție.
- **Echitatea satului:** CV-ul expunerii la raid (distanța medie pe drum între porți) ≤ 0,10 și max/min ≤ 1,25, măsurate pe graful drumurilor real.
- **Excluse:** biserica e doar reper și clopot; troițele sunt doar decor; fără cimitir, fără alcool (must în loc de vin), fără simboluri politice, fără „furatul miresei”.
- **Telefon:** nimic interactiv în zona joystick-ului sau peste săritură; ținte de atingere ≥ 44 px; text ≥ 11 px.
- **Fără pay-to-win, fără loot box plătit, fără FOMO pe Robux.** Întâmplările și mini-jocurile nu se cumpără.
- **Mini-jocurile** trebuie să meargă cu 2–8 jucători și să aibă rol pentru un copil de 7 ani și unul de 14. Cine e eliminat rămâne activ (fantomă sau ajutor).
- **Performanța:** ≤ 650k triunghiuri vizibile în zona aglomerată pe telefon (bugetul Roblox); decorul fără coliziune și fără CastShadow.
- **Texte:** chei în RO și EN, plus RU, ES și PT scrise de mână. Testul `Strings.spec` acoperă toate cheile, pentru toate limbile.
- **Procedura după fiecare sarcină verificată:**
  - `./tools.sh`, `python3 tools/cloud.py e2e`, `tools/playtest.sh`;
  - commit cu tot (`git add -A`), mesaj în română, terminat cu linia Claude-Session;
  - `git push origin main`;
  - `python3 tools/cloud.py publish-live build/bunica.rbxl`;
  - CI urmărit până trece;
  - `docs/PROGRESS.md` actualizat.
- **Audio nou:** permisiunea Use pentru universe 1855994157 (Dashboard). Verificată cu check-permissions.

## Zone de revizuit (ce testele directe ar rata)

1. **Server cu 1 jucător:** ceasul, întâmplările și mini-jocurile trebuie să pornească și să se încheie fără blocaje. NPC-urile umplu rolurile sau mini-jocul nu se propune. Test: `VillageClock.next` cu 1 jucător nu propune un mini-joc cu `minPlayers > 1`.
2. **Jucătorul pleacă în mijlocul unui mini-joc sau al unei întâmplări:** meciul continuă sau se încheie curat, fără recompense duble și fără obiecte rămase în lume. Test: e2e `MinigameService` scoate un bot în timpul rundei.
3. **Noapte cu furt în timpul unui mini-joc:** cine e în mini-joc nu poate fi jefuit și nu poate jefui. Test: `Raid.canSteal` primește `inMinigame`.
4. **Schimbarea așezării sparge serviciile care foloseau geometria veche:** Tutorial, NpcThief, Slipper (poarta), Upgrade (Grivei), Hora (centrul), playtest (`roadPoint`). Test: e2e-urile existente rulează pe satul nou, iar `VillageLayout.spec` verifică porțile legate de graf.
5. **Telefonul cu HUD-ul nou:** butoanele mini-jocurilor, ale decorului și roata de mesaje. Test: auditul de telefon (pasul 15l) extins la fiecare UI nou.

---

## M1. Furtul fără lacrimi

### Sarcina 1: Creaturile de suflet (F1)

**Fișiere:**
- Creare: `src/shared/Domain/Soul.luau`, `tests/Soul.spec.luau`, `src/server/Services/SoulService.luau`
- Modificare: `Config/DataTemplate.luau` (CreatureRecord `soul: boolean?`), `Domain/Raid.luau` (`StealContext.creatureIsSoul`, motivul `"Soul"`), `Domain/NpcThieves.luau` (`pickTarget` sare peste suflete), `Domain/Trade.luau` (sufletele nu se schimbă: `"Soul"`), `Net.luau` (`SetSoul`), `CellarPanel.luau` (butonul inimă), `WorldController.luau` (inima deasupra creaturii), stringuri

**Interfețe:**
- `Soul.MAX = 3`
- `Soul.count(profile): number`
- `Soul.canSet(profile, uid: string, on: boolean): (boolean, string?)`, cu motivele `"Max"` și `"Missing"`
- `Soul.set(profile, uid, on): boolean`
- Remote `SetSoul(uid: string, on: boolean)`

**Pași:**
- [ ] Testele:
  - maximum 3;
  - al patrulea întoarce `"Max"`;
  - scoaterea eliberează locul;
  - `Raid.canSteal` cu `creatureIsSoul=true` întoarce `"Soul"`;
  - `NpcThieves.pickTarget` ignoră sufletul;
  - `Trade.checkOffer` cu un suflet întoarce `"Soul"`.
- [ ] Rulează `lune run tests`: pică.
- [ ] Implementează și leagă (RaidService trimite `creatureIsSoul`; notificare `notify.Soul` pentru hoț).
- [ ] e2e: botul nu poate porni furtul pe un suflet.
- [ ] Playtest: inima din beci; captură.
- [ ] Commit.

### Sarcina 2: Răzbunarea (F2)

**Fișiere:**
- Creare: `src/shared/Domain/Revenge.luau`, `tests/Revenge.spec.luau`, `src/server/Services/RevengeService.luau`, `src/client/Controllers/RevengeController.luau`
- Modificare: `RaidService.luau` (după `complete`: `RevengeService.mark`), `Net.luau` (`Revenge` S→C), stringuri, `Config/Notices.luau` (`notify.Revenge*` urgent)

**Interfețe:**
- `Revenge.new(): Marks`
- `Revenge.mark(marks, victimId, thiefId, uid, untilTime)`
- `Revenge.claim(marks, thiefOfClaim, uid, now): boolean`
- `Revenge.bonus(sellPrice): number` (50%)
- La răsărit: `Revenge.clear(marks)`

**Pași:**
- [ ] Testele:
  - marcajul expiră;
  - furtul înapoi al aceluiași uid de către victimă dă bonus o singură dată;
  - un alt jucător nu ia bonusul.
- [ ] Implementează.
- [ ] Clientul afișează o săgeată spre hoț și un banner urgent.
- [ ] e2e: botul A fură de la B, B fură înapoi și primește bonusul.
- [ ] Commit.

### Sarcina 3: Avertizare la schimburi dezechilibrate

**Fișiere:** `Domain/Trade.luau`, `tests/Trade.spec.luau`, `TradePanel.luau`, stringuri.

**Interfețe:** `Trade.lopsided(mine: number, theirs: number): boolean`. Adevărat când partea mai mare e ≥ 3× cealaltă și diferența e ≥ 500 lei.

**Pași:**
- [ ] Testele cu valorile date.
- [ ] Bannerul de avertizare apare în fereastra de schimb, pe partea care pierde.
- [ ] Commit.

---

## M2. Satul de vale

### Sarcina 4: `Domain/VillageLayout` (geometria satului, pură)

**Fișiere:** creare `src/shared/Config/Village.luau`, `src/shared/Domain/VillageLayout.luau`, `tests/VillageLayout.spec.luau`.

**Interfețe:**
- `VillageLayout.build(): Layout`. Determinist; doar cosmeticul ia seed separat.
- `Layout`:
  - `roads: { { name: string, points: {Vector3}, width: number } }`
  - `plots: { { index: number, cframe: CFrame, gate: Vector3, lane: string, variant: number, mirrored: boolean } }` (8)
  - `hub: CFrame`
  - `river: {Vector3}`
  - `bridges: { CFrame }`
  - `shortcuts: { { name: string, points: {Vector3} } }`
  - `sites: { [string]: CFrame }`, cu cheile: centru, magazin, statie, discoteca, terenScoala, iaz, livada, lanPorumb, via, stana, moara, biserica, codru, gara, bazar, bucatarie, claie
- `VillageLayout.fairness(layout): { exposureCV: number, exposureMaxMin: number, hubCV: number }`. Dijkstra pe graful drumurilor plus scurtături.
- `VillageLayout.contains(plot, position): boolean`

**Forma (din `tools/research/layouts.py`, L4):**
- drumul mare urmează pârâul;
- ulița de deal e paralelă;
- legături la capete și prin centru;
- 4 ogrăzi pe drumul mare, 4 pe ulița de deal;
- 3 scurtături: puntea, spărtura din vie, poteca din livadă;
- ogrăzile urmează tangenta drumului, cu o abatere ≤ 7°.

**Pași:**
- [ ] Testele:
  - 8 ogrăzi;
  - fără suprapuneri (OBB + 6 studs);
  - `exposureCV ≤ 0.10`, `exposureMaxMin ≤ 1.25`;
  - fiecare poartă la ≤ 14 studs de un drum;
  - fiecare loc din `sites` în afara ogrăzilor și la ≥ 20 studs de pârâu;
  - același rezultat la două apeluri.
- [ ] Implementează. Pozițiile se ajustează din config până trec testele de echitate.
- [ ] Commit.

### Sarcina 5: Terenul, drumurile, pârâul (VillageBuilder)

**Fișiere:**
- Creare: `src/server/World/VillageBuilder.luau`
- Modificare: `WorldBuilder.luau` (`build()` folosește `VillageLayout`; `plotCFrame` dispare; `buildHearth` la `hub`), `Config/Hora.luau` (`center` = hub din `Config/Village`), `Config/World.luau`

**Interfețe:**
- `VillageBuilder.build(layout, parent: Folder)`:
  - Terrain: valea plană la y=0, dealuri cu `FillBall`/`FillWedge`, pârâul cu `Enum.Material.Water` pe un canal de 1,5 studs, iazul;
  - drumurile: părți Sand/Ground segmentate de-a lungul polilinilor, lățime din layout;
  - podurile și puntea.
- `WorldBuilder.build(): { PlotGeometry }`. Rămâne interfața pentru PlotService.

**Pași:**
- [ ] Toate e2e-urile existente trec pe satul nou. Repară Tutorial (`roadPoint` după poartă), NpcThief, Slipper, Upgrade, Hora.
- [ ] Playtest:
  - `roadPoint` din helperii playtest calculat din poartă;
  - capturi: valea de sus, ulița, centrul.
- [ ] Commit.

### Sarcina 6: Case variate, aceeași valoare

**Fișiere:** `WorldBuilder.luau` (`buildPlot` primește `variant` și `mirrored`), `Config/Village.luau` (`variants`: culorile porții și ale tâmplăriei, oglindirea, poziția copacilor), `tests/VillageLayout.spec.luau`.

**Interfețe:** `VillageLayout.variantFor(index: number, seed: number): { gateColor: Color3, trimColor: Color3, mirrored: boolean, treeSet: number }`. Gameplay-ul identic pe toate variantele.

**Pași:**
- [ ] Test: piedestalele și straturile au aceleași poziții locale indiferent de variantă (oglindirea e doar vizuală).
- [ ] Implementează.
- [ ] Captură cu 8 ogrăzi diferite.
- [ ] Commit.

### Sarcina 7: Centrul și reperele

**Fișiere:** creare `src/server/World/SiteBuilder.luau`; modificare `VillageBuilder.luau`.

**Interfețe:** `SiteBuilder.build(sites, parent)` construiește:
- centrul: fântâna, avizierul, banca, zona fără bătaie (atributul `NoFight` pe un Part-zonă);
- magazinul;
- stația cu mozaic;
- Discoteca (Casa de cultură, interior cu ring de dans);
- terenul școlii (teren de oina, porți);
- iazul (mal, stuf, debarcader);
- livada (5 cireși + căsuța mătușii);
- lanul de porumb (labirint, generat din grilă cu seed fix);
- via (rânduri pe deal);
- stâna (țarc, colibă);
- moara (pe deal, cu pale animate pe client);
- biserica (pe deal, `LevelOfDetail` SLIM, clopot);
- marginea codrului;
- gara și linia;
- bazarul (8 tarabe);
- bucătăria de vară (cuptor);
- claia de fân.

Pentru fiecare: modelul sculptat dacă `ArtLibrary.has`, altfel forma procedurală.

**Pași:**
- [ ] e2e: fiecare cheie din `sites` are un model în `Workspace.Village.Sites`.
- [ ] Zona `NoFight`: `SlipperService` nu aruncă și nu lovește acolo (test e2e).
- [ ] Playtest: o captură pe loc.
- [ ] Commit.

### Sarcina 8: Decorul procedural (Poisson) și viața ambientală

**Fișiere:**
- Creare: `src/shared/Domain/Scatter.luau`, `tests/Scatter.spec.luau`, `src/client/Controllers/AmbientLifeController.luau`, `src/shared/Config/Ambient.luau`
- Modificare: `VillageBuilder.luau`

**Interfețe:**
- `Scatter.poisson(area: {min: Vector2, max: Vector2}, radius: number, mask: (Vector2) -> boolean, rng): {Vector2}`
- `AmbientLifeController`: gâște în stol pe ulița lor, găini în ogrăzi, câini la porți (lătrat în lanț la un hoț noaptea, atributul `Barking`), 3 săteni pe trasee fixe, berze pe stâlpi, rufe. Toate pe client, CFrame, fără coliziuni.

**Pași:**
- [ ] Testele:
  - distanța minimă respectată;
  - masca exclude drumurile și ogrăzile;
  - determinist cu seed.
- [ ] Implementează.
- [ ] Captură.
- [ ] Commit.

### Sarcina 9: Rutiera

**Fișiere:** creare `src/server/Services/RutieraService.luau`, `src/client/Controllers/RutieraController.luau`, `Config/Rutiera.luau`.

**Interfețe:**
- Atributele `RutieraAt` (progresul pe circuit, 0–1) și `RutieraNext`.
- `RutieraService.board(player)` lipește jucătorul de vehicul.
- `RutieraService.alight(player, stopName)`.
- Remote `Rutiera("board"|"alight", stop?)`.
- Opriri: centru și câte una pentru fiecare ogradă.
- Un circuit durează 150 s. Vehiculul e animat de server, cu CFrame pe drumuri; pasagerii sunt sudați.

**Pași:**
- [ ] e2e: botul urcă și ajunge la oprirea cerută.
- [ ] Playtest: jucătorul urcă și coboară la centru.
- [ ] Commit.

### Sarcina 10: Performanța

**Fișiere:**
- Modificare: `default.project.json` (Workspace: `StreamingEnabled=true`, `ModelStreamingMode`, `StreamingTargetRadius=1024`), `WorldBuilder`/`VillageBuilder` (ogrăzile `ModelStreamingMode=Atomic`; reperele `LevelOfDetail=SLIM` și `Persistent`), `ArtService` (`RenderFidelity=Automatic`, `CollisionFidelity=Box`)
- Creare: `tests/e2e/94_Budget.spec.luau`

**Interfețe:** `ArtAssets[key].tris` (deja în `.json`); `ArtLibrary.triangles(model): number` din metadate.

**Pași:**
- [ ] e2e:
  - suma triunghiurilor decorului pe ogradă ≤ 120k;
  - pe tot satul ≤ 1,2M;
  - decor fără CanCollide/CastShadow.
- [ ] Clientul tolerează streaming-ul (controllerele așteaptă modelele). Playtest complet.
- [ ] Commit.

---

## M3. Ceasul satului și întâmplările

### Sarcina 11: Ceasul satului (cadrul)

**Fișiere:**
- Creare: `src/shared/Config/Happenings.luau`, `src/shared/Domain/VillageClock.luau`, `tests/VillageClock.spec.luau`, `src/server/Services/VillageClockService.luau`, `src/server/Happenings/` (un modul pentru fiecare întâmplare), `src/client/Controllers/HappeningController.luau`
- Modificare: `Net.luau` (`Happening` S→C, `HappeningAction` C→S), stringuri, `Config/Notices.luau` (`happening.*` = urgent)

**Interfețe:**
- `Happening = { id: string, phase: "Day" | "Night" | "Any", weight: number, warnSeconds: number, durationSeconds: number, minPlayers: number, cooldownSeconds: number, location: string }`
- `VillageClock.next(now: number, phase: string, players: number, history: { [string]: number }, rng): (string?, number)`. Întoarce id-ul și momentul pornirii; intervalul e între 360 și 480 s.
- `VillageClock.reward(participation: boolean, placement: number?): number`. Lei per participare.
- Modulul unei întâmplări: `{ start(ctx): (), action(ctx, player, payload): (), stop(ctx): { [Player]: number } }`. `ctx` conține: `site: CFrame`, `endsAt`, `players`, `give(owner, lei)`.
- Clientul: banner „În 30 s: …”, săgeată spre loc, cronometru. Totul trece prin `HudLayout` și `NoticeQueue`.

**Pași:**
- [ ] Testele:
  - nu repetă aceeași întâmplare de două ori la rând;
  - respectă faza și `minPlayers`;
  - cooldown-ul e respectat;
  - cu 1 jucător alege doar întâmplări cu `minPlayers ≤ 1`.
- [ ] Implementează. Maximum o întâmplare activă odată.
- [ ] Commit.

### Sarcina 12: Gâștele au scăpate și Ploaia de cireșe

**Fișiere:** `Happenings/Gaste.luau`, `Happenings/Cirese.luau`, `Config/Happenings.luau`, clientul pentru efecte.

**Gâștele:**
- 12 gâște NPC (server, mișcare simplă) rătăcesc prin sat;
- atingi o gâscă (ProximityPrompt sau coliziune) și o duci la țarcul din centru;
- 30 de lei pe gâscă;
- ciupitul dă un recul mic.

**Cireșele:**
- livada aruncă 40 de cireșe (obiecte pe sol);
- le aduni prin atingere;
- mătușa Mărioara (NPC) urmărește cel mai apropiat culegător, iar atingerea ei îl amețește 1 s (urzicile);
- 5 lei pe cireașă.

**Pași:**
- [ ] e2e: pornire forțată, un bot strânge, recompensă, oprire curată (zero obiecte rămase).
- [ ] Playtest: captură.
- [ ] Commit.

### Sarcina 13: Rutiera aduce un negustor și Trece o nuntă

**Fișiere:** `Happenings/Negustor.luau`, `Happenings/Nunta.luau`.

**Negustorul:**
- coboară din rutieră la centru;
- ofertă: 3 semințe rare cu preț redus;
- primii 3 jucători ajunși pot cumpăra câte una;
- folosește `ShopService.offer(player, seedId, price)`, interfață nouă.

**Nunta:**
- un cortegiu NPC (mire, mireasă, lăutari) parcurge drumul mare;
- jucătorii care intră în hora din jurul lui (raza 10) primesc confetti și 1 lei/s cât dansează (maximum 60 s);
- muzica de nuntă trece prin Music.

**Pași:**
- [ ] e2e.
- [ ] Playtest.
- [ ] Commit.

### Sarcina 14: Ceața (noaptea)

**Fișiere:** `Happenings/Ceata.luau`, `LightingDirector.luau` (densitatea ceții pe client).

**Mecanica:** 60 s de vizibilitate mică. Bunica NPC vede la jumătate din distanță (`BunicaService.setSight(multiplier)`, interfață nouă).

**Pași:**
- [ ] e2e: `setSight` se aplică și revine.
- [ ] Commit.

### Sarcina 15: Lupii la stână (co-op contra serverului)

**Fișiere:**
- Creare: `Happenings/Lupi.luau`, `src/server/Ai/WolfAi.luau`
- Modificare: `SlipperService` (lupii sunt ținte valide: `SlipperService.registerTarget(model, onHit)`, interfață nouă)

**Mecanica:**
- 6 lupi vin din codru spre stână;
- jucătorii îi lovesc cu papucul (2 lovituri gonesc un lup);
- dacă 3 lupi ajung în țarc, oile fug: eșec, cu un consolare mic;
- recompensa e împărțită după participare;
- funcționează și solo: cu 1 jucător vin 3 lupi.

**Pași:**
- [ ] Teste Domain: numărul de lupi după numărul de jucători și împărțirea recompensei.
- [ ] e2e cu boți aruncători.
- [ ] Playtest.
- [ ] Commit.

### Sarcina 16: Muma Pădurii și Trenul de la Ungheni

**Fișiere:** `Happenings/MumaPadurii.luau`, `Happenings/Tren.luau`.

**Muma Pădurii:**
- noaptea, rar (pondere 1);
- mini-boss cu 40 de puncte de viață, comic: râde și aruncă cu conuri lente, ușor de evitat;
- iese din codru și pleacă după 120 s;
- un papuc scade 1 punct, făcălețul 3;
- cine o alungă ia o sămânță rară (Epic).

**Trenul:**
- maximum o dată pe oră, pornit de ceas;
- trenul vine pe linie, oprește 90 s la gară (schimbarea roților, animată);
- negustorul vinde o sămânță Legendară cu 50% reducere, câte una pentru fiecare jucător;
- linia taie drumul: un hoț prins pe linie e amețit.

**Pași:**
- [ ] e2e pentru amândouă.
- [ ] Captură.
- [ ] Commit.

---

## M4. Mini-jocurile

### Sarcina 17: Cadrul pentru mini-jocuri

**Fișiere:**
- Creare: `src/shared/Domain/Minigame.luau`, `tests/Minigame.spec.luau`, `src/shared/Config/Minigames.luau`, `src/server/Services/MinigameService.luau`, `src/server/Minigames/` (câte un modul pentru fiecare joc), `src/client/Controllers/MinigameController.luau`, `src/client/Minigames/` (partea de client a fiecărui joc)
- Modificare: `Domain/Raid.luau` (`StealContext.inMinigame` → motivul `"Busy"`), `SlipperService` (în arenă, papucul e al mini-jocului), `Net.luau` (`Minigame` S→C, `MinigameAction` C→S), `HudLayout` (dreptunghiul tabelei de scor)

**Interfețe:**
- `Config/Minigames`: `{ id, minPlayers, maxPlayers, durationSeconds, site: string, ages: string, rewards: { participation: number, placements: {number} } }`.
- `Minigame.rank(scores: { [number]: number }): { number }`. La egalitate, cine a ajuns primul.
- `Minigame.rewards(def, ranking, participants): { [number]: number }`. Fiecare participant primește ceva.
- `Minigame.ghost`: cine e eliminat devine spectator activ. Poate arunca confetti, poate „încuraja”, iar încurajările dau +5% punctaj echipei.
- Modulul server: `{ setup(match), tick(match, dt), action(match, player, payload), finish(match): { [number]: number } }`. `match` conține: `players`, `scores`, `arena: CFrame`, `endsAt`, `eliminate(p)`, `spawnProp(...)`, `cleanup`.
- Intrarea în joc:
  - prin ceasul satului, care propune jocul și deschide 20 s de înscriere la loc;
  - sau prin panoul „Mini-jocuri” (lista, cu „Intră” când ești aproape de loc).
- Clientul: numărătoare 3-2-1, tabela de scor (prin `HudLayout`), rezultatele cu podium și reacții.

**Pași:**
- [ ] Testele:
  - clasamentul și egalitățile;
  - toți participanții primesc ceva;
  - cine a plecat nu primește nimic;
  - `Raid.canSteal` cu `inMinigame` întoarce `"Busy"`.
- [ ] e2e cu un mini-joc de test:
  - doi boți, unul pleacă în mijlocul rundei;
  - finalul e curat: zero obiecte rămase, recompense o singură dată.
- [ ] Commit.

### Sarcina 18: Prinde cocoșul, Șotronul, Ciocnitul ouălor

**Fișiere:** `Minigames/Cocos.luau`, `Minigames/Sotron.luau`, `Minigames/Oua.luau` și partea lor de client, cu Domain pentru reguli: `Domain/EggDuel.luau` + test.

**Prinde cocoșul:**
- 2–8 jucători, 60 s;
- cocoșul NPC fuge de cel mai apropiat jucător (fuga cu ponderi), sare peste garduri mici;
- atingerea îl prinde, iar cocoșul reapare;
- 1 punct pentru fiecare prindere.

**Șotronul:**
- solo, înscriere liberă;
- 8 pătrate pe uliță, în ordine; secvența apare 2 s;
- greșeala oprește runda;
- recordul pe server apare pe avizier.

**Ciocnitul ouălor:**
- 1v1, 30 s;
- fiecare alege un ou din colecție;
- `EggDuel.resolve(eggA, eggB, rng): "A" | "B"`, cu tăria oului din raritate și o parte de noroc;
- ouăle câștigate devin colecție de cosmetice.

**Pași:**
- [ ] Testele Domain.
- [ ] e2e pentru fiecare.
- [ ] Playtest: captură pentru fiecare.
- [ ] Commit.

### Sarcina 19: Oina cu papuci

**Fișiere:** `Minigames/Oina.luau`, client, `Domain/Oina.luau` + test.

**Reguli:**
- 2 echipe (2v2 până la 4v4), 3 minute, pe terenul școlii;
- echipa la bătaie: un jucător lovește mingea (un click spre direcție) și aleargă pe culoar până la capăt și înapoi;
- echipa la prindere aruncă papuci după alergător;
- alergător lovit = scos din rundă (devine fantomă);
- cursă completă = 1 punct;
- schimbare la 90 s.

**Interfețe:**
- `Oina.score(state, event)`
- `Oina.swap(state)`
- Mingea și papucii folosesc `SlipperService.throwAs`, pe țintele mini-jocului.

**Pași:**
- [ ] Testele de reguli.
- [ ] e2e cu boți.
- [ ] Playtest cu captură.
- [ ] Commit.

### Sarcina 20: De-a v-ați ascunselea în porumb și Păcală se ascunde

**Fișiere:** `Minigames/Ascunselea.luau`, `Minigames/Pacala.luau`, clienții lor, `Domain/PropHunt.luau` + test.

**Ascunselea:**
- 1 căutător (Bunica legată la ochi: câmpul vizual e un con mic pe client); ceilalți se ascund 20 s în lanul de porumb;
- căutătorul atinge = prinde;
- ascunșii primesc puncte pentru fiecare 10 s nedescoperiți;
- prinșii devin fantome care fac „cucu” ca indiciu, glumeț.

**Păcală se ascunde:**
- ascunșii se transformă în obiecte din ogradă: găleată, oală, dovleac, butuc, claie (`PropHunt.disguises`);
- căutătorii aruncă papuci, iar o lovitură în obiectul greșit costă timp;
- ascunșii pot „râde” (sunet, +puncte, risc);
- 2–3 minute.

**Pași:**
- [ ] Testele de punctaj.
- [ ] e2e.
- [ ] Playtest.
- [ ] Commit.

### Sarcina 21: Cursa cu roaba și Obby-ul morii

**Fișiere:** `Minigames/Roaba.luau`, `Minigames/Moara.luau`, clienți.

**Cursa cu roaba:**
- 2–8 jucători, 90 s;
- coborâre pe deal pe un traseu cu porți;
- roaba e un vehicul simplu pe client (VehicleSeat), cu viteza verificată de server ca la anti-teleport;
- căderea în pârâu = reapariție la ultima poartă;
- ordinea la sosire = clasament.

**Obby-ul morii:**
- pale care se rotesc și platforme;
- cronometrul individual;
- recordul pe server.

**Pași:**
- [ ] e2e: porțile de control și anti-scurtătura.
- [ ] Playtest.
- [ ] Commit.

### Sarcina 22: Zdrobitul strugurilor, Hora-ritm, Discoteca

**Fișiere:** `Minigames/Struguri.luau`, `Minigames/Discoteca.luau`, `HoraService.luau` (modul ritm), clienți, `Domain/Rhythm.luau` + test.

**Interfețe:**
- `Rhythm.judge(beatTime, pressTime): "Perfect" | "Bun" | "Ratat"`
- `Rhythm.track(seed, bpm, seconds): {number}`

**Zdrobitul strugurilor:**
- 2–4 jucători în linuri, 60 s;
- apeși pe ritmul muzicii (cu ceasul muzical existent, `Music`);
- zdrobit = must.

**Hora-ritm:** pașii pe ritm, iar cercul perfect cheamă vremea rară (păstrează regulile Horei).

**Discoteca:**
- concurs de dans: 45 s de emote-uri libere, apoi vot de 15 s, cu 1–3 inimi pentru fiecare dansator;
- „Cea mai tare Bunică”: îmbraci Bunica din garderobă, apoi vot;
- fără chat, fără text liber.

**Pași:**
- [ ] Testele de ritm.
- [ ] e2e: votul.
- [ ] Playtest.
- [ ] Commit.

### Sarcina 23: Plăcintăria nebună și Țară, țară, vrem ostași

**Fișiere:** `Minigames/Placinte.luau`, `Minigames/Ostasi.luau`, clienți, `Domain/Recipe.luau` + test.

**Plăcintăria (co-op, 2–4 jucători, 2 minute, la bucătăria de vară):**
- comenzile vin pe bilețele: plăcintă cu brânză, cu varză, cu vișine;
- pașii: aluat, umplutură, cuptor, livrare;
- `Recipe.next(state)` și `Recipe.complete(order, steps)`;
- plăcintele livrate dau un bonus de creștere de 10 min (`GardenService.boost(owner, seconds, factor)`, interfață nouă).

**Țară, țară, vrem ostași:**
- 2 echipe (până la 4v4), lanțuri ținute de mână (constrângeri fizice);
- alergătorul rupe lanțul cu viteza (impuls peste prag), apoi ia un jucător în echipa lui;
- 2 minute.

**Pași:**
- [ ] Testele de rețete.
- [ ] e2e.
- [ ] Playtest.
- [ ] Commit.

### Sarcina 24: Pescuitul la iaz (activitate permanentă)

**Fișiere:**
- Creare: `src/shared/Config/Fish.luau`, `src/shared/Domain/Fishing.luau`, `tests/Fishing.spec.luau`, `src/server/Services/FishingService.luau`, `src/client/Controllers/FishingController.luau`
- Modificare: `Config/DataTemplate` (`fish: { [string]: number }`, recordurile)

**Mecanica:**
- arunci undița (din mal sau de pe debarcader);
- aștepți tremurul (2–8 s);
- tragi în ritm, cu bara de tensiune;
- prinzi „pești” de colecție (crapul-rachetă, știuca-ninja, broasca-DJ, cizma veche…) sau, rar, un ou de creatură;
- prinsul se vinde sau se folosește ca hrană (bonus la îngrijire);
- iarna, gheața.

**Interfețe:**
- `Fishing.roll(rng, weather, season): fishId`. Șansele sunt afișate în panou.
- `Fishing.reel(tension, input, dt): (tension, state)`

**Pași:**
- [ ] Testele: șansele însumează 1; bara de tensiune.
- [ ] e2e.
- [ ] Playtest: captură.
- [ ] Commit.

---

## M5. Drumurile paralele spre statut

### Sarcina 25: Decorul ogrăzii pe lei

**Fișiere:**
- Creare: `src/shared/Config/Decor.luau`, `src/shared/Domain/Decor.luau`, `tests/Decor.spec.luau`, `src/server/Services/DecorService.luau`, `src/client/Controllers/DecorPanel.luau`, `src/client/Controllers/DecorPlacer.luau`
- Modificare: `DataTemplate` (`decor: { { id: string, slot: string } }`, `ownedDecor`)

**Mecanica:**
- catalogul (20+ obiecte): flori, covor pe gard, culoarea porții, sperietoare, roabă, banca, felinare, ghiveci cu mușcate, rufe, cocor de lemn, butoaie, ulcioare;
- sloturi fixe pe ogradă (12): decorul nu blochează jocul și nu dă avantaj;
- cumpărare pe lei; așezare cu atingere pe slot.

**Interfețe:**
- `Decor.canPlace(profile, id, slot)`
- `Decor.price(id)`
- Remote-urile `BuyDecor(id)` și `PlaceDecor(id, slot)`

**Pași:**
- [ ] Testele: sloturile, prețul, că obiectul e deținut.
- [ ] e2e.
- [ ] Playtest: panoul pe telefon trece auditul.
- [ ] Commit.

### Sarcina 26: Garderoba Bunicii și titlurile

**Fișiere:** `Config/Outfits.luau` (6 ținute pe lei: de sărbătoare, de iarnă, de discotecă, de pescar, de grădinar, de hram), `Domain/Titles.luau` + test, `TitleService.luau`, deasupra numelui (`BillboardGui`), `BunicaController` (ținuta pe rig).

**Titlurile** se câștigă din statistici: „Hoțul satului”, „Papucul de aur”, „Pescarul”, „Dansatoarea”, „Colecționarul”, „Gospodina” (decor), „Prietenul satului” (ajutor). Se alege unul.

**Interfețe:**
- `Titles.earned(stats): {string}`
- Remote-ul `SetTitle(id)`

**Pași:**
- [ ] Testele: pragurile.
- [ ] e2e.
- [ ] Playtest.
- [ ] Commit.

### Sarcina 27: Îngrijirea creaturilor

**Fișiere:** `Domain/Care.luau` + test, `CareService.luau`, `WorldController` (mângâiere = ProximityPrompt pe creatura proprie, zâmbet sau inimioare), `DataTemplate` (`happiness` pe CreatureRecord).

**Mecanica:**
- fericirea scade încet (−1 pe oră de joc);
- hrana (pește, plăcintă, brânză) și mângâierea o cresc;
- o creatură fericită (≥ 80) dă +10% venit, iar o fericire mică nu penalizează;
- statistica e afișată.

**Interfețe:** `Care.multiplier(happiness)`, `Care.feed(record, food)`, `Care.pet(record, now)` (cooldown 30 s).

**Pași:**
- [ ] Testele.
- [ ] e2e.
- [ ] Commit.

### Sarcina 28: Hibrizii

**Fișiere:** `Domain/Hybrid.luau` + test, `GardenService` (la eclozare, șansa de hibrid când două straturi alăturate cresc creaturi de rarități ≥ Rar), `Config/HybridNames.luau` (silabe pentru fiecare creatură), `CreatureBuilder` (hibridul = corpul A + accesoriile lui B, colorat), `DataTemplate` (`hybridOf: {string}?`).

**Interfețe:**
- `Hybrid.chance(a, b): number` (2–8%)
- `Hybrid.name(a, b, seed): string` (de ex. „Plăcintonio-Turbo”)
- `Hybrid.income(a, b) = (a + b) × 0,75`
- Hibridul are o intrare separată în Caiet („hibrizi descoperiți”).

**Pași:**
- [ ] Testele: numele deterministe și pronunțabile (fără 3 consoane la rând), venitul.
- [ ] e2e: eclozare forțată.
- [ ] Captură.
- [ ] Commit.

### Sarcina 29: Caietul cu siluete și clasamentele de mini-jocuri

**Fișiere:** `NotebookPanel.luau` (creaturile nedescoperite cu siluetă și „?”; fila „Recorduri”: mini-jocurile, cu topul pe server și recordul personal), `MinigameService` (recordurile în profil), `DataTemplate` (`records`).

**Pași:**
- [ ] Testele Domain pentru recorduri (`Minigame.isRecord`).
- [ ] Playtest: fila pe telefon.
- [ ] Commit.

---

## M6. Social fără chat, bazarul, codurile

### Sarcina 30: Roata de mesaje rapide

**Fișiere:** `Config/QuickChat.luau` (12 mesaje și emote: „Hai la horă!”, „Ajutor!”, „Fugi!”, „Bravo!”, „Hoț la mine!”, „Schimbăm?”, „Hai la pescuit”, „Mulțumesc”, „Ha-ha”, „Vin acum”, „Ne vedem mâine”, „Bunica te vede!”), `QuickChatService.luau` (bula deasupra capului, rate limit), `QuickChatWheel.luau` (client; butonul prin `HudLayout`).

**Pași:**
- [ ] Testul: toate mesajele au text în 5 limbi.
- [ ] Playtest: auditul de telefon.
- [ ] Commit.

### Sarcina 31: Bazarul de duminică

**Fișiere:** `Domain/Market.luau` + test, `MarketService.luau`, `MarketPanel.luau`, `SiteBuilder` (8 tarabe).

**Mecanica:**
- închiriezi o tarabă (gratuit, una pe jucător) și pui până la 4 creaturi din beci, cu preț;
- ceilalți cumpără cu lei, iar transferul e atomic (ca `Trade.execute`);
- prețul minim e 25% din valoarea de vânzare (anti-spălare), maximul 10×;
- sufletele nu se pun la vânzare;
- duminica (UTC), bazarul e „mare”: tarabe în plus și NPC-uri care cumpără.

**Interfețe:** `Market.list(profile, uid, price)`, `Market.buy(seller, buyer, listingId)`.

**Pași:**
- [ ] Testele: atomicitatea, limitele, nimic de cumpărat după ce vânzătorul a plecat.
- [ ] e2e cu boți.
- [ ] Playtest.
- [ ] Commit.

### Sarcina 32: Codurile și alarma în lanț

**Fișiere:**
- `Config/Codes.luau` (coduri cu dată de expirare și recompensă), `CodeService.luau` (o singură folosire pe profil), o căsuță în panoul magazinului (tanti de la magazin);
- `RaidService` + `AmbientLifeController` (câinii vecinilor latră când un hoț care cară trece pe lângă ogradă, iar proprietarul primește o alarmă discretă), `Domain/ChainAlarm.luau` + test.

**Pași:**
- [ ] Testele: codul expirat, codul folosit, lanțul.
- [ ] e2e.
- [ ] Commit.

---

## M7. Sezoanele

### Sarcina 33: Calendarul sezonier

**Fișiere:** `Config/Seasons.luau`, `Domain/Seasons.luau` + test, `SeasonService.luau`, conținutul pe sezoane:

| Sezon | Când | Ce aduce |
|---|---|---|
| Mărțișor | 1–14 martie | șnurul legat de plantă dă un bonus de creștere |
| Paște | ortodox, calculat | ciocnitul ouălor dă ouă rare; vânătoarea de ouă în sat |
| Drăgaica | 20–27 iunie | coroane aruncate pe acoperiș, cu bonus dacă rămân sus |
| Culesul | 15 sept – 15 oct | zdrobitul strugurilor are pondere mare; știuletele roșu în lan |
| Hramul satului | o zi pe lună, pe server | casă deschisă: furtul oprit, vizite în ogrăzi, bonus la decor |
| Iarna | 15 dec – 14 ian | colinde (copiii merg din ogradă în ogradă: NPC-urile dau colaci), Capra și Ursul, măștile de Malanca |

Măștile de Malanca sunt o deghizare: Bunica NPC nu te recunoaște 30 s.

**Interfețe:**
- `Seasons.active(unixTime): { string }`
- `Seasons.orthodoxEaster(year): (month, day)` (algoritmul Meeus, iulian → gregorian)

**Pași:**
- [ ] Testele: Paștele ortodox 2026 = 12 aprilie, 2027 = 2 mai; ferestrele.
- [ ] e2e: sezon forțat.
- [ ] Playtest: Iarna și Paștele, forțate.
- [ ] Commit.

---

## M8. Limbile

### Sarcina 34: RU, ES și PT scrise de mână

**Fișiere:** `src/shared/Strings/ru.luau`, `es.luau`, `pt.luau`, `Strings/init.luau` (limbile), `tests/Strings.spec.luau` (fiecare cheie din `en` există în fiecare limbă).

**Pași:**
- [ ] Testul pică.
- [ ] Traducerile. Tonul e pentru copii; numele creaturilor se adaptează local (GDD: scrise de mână).
- [ ] Testul trece.
- [ ] Commit.

---

## M9. Modelele

### Sarcina 35: Conceptele și modelele locurilor noi

**Fișiere:** `art/concepts/world/*.png`, `art/concepts/characters/*.png`, `art/models.json`, `Config/ArtAssets.luau`, iar pentru obiectele simple, scripturi Blender în `tools/`.

**Lista:**
- clădiri: moara, biserica (reper), magazinul, stația cu mozaic, Casa de cultură, gara, taraba de bazar, cuptorul de vară, stâna cu colibă;
- obiecte: claia de fân, pătulul, sperietoarea, roaba, puntea, podul;
- personaje: rutiera (maxi-taxi), gâsca, găina, cocoșul, oaia, lupul, Muma Pădurii, 3 săteni, mătușa Mărioara, negustorul, mirii și lăutarii;
- vegetație: cireșul, butucul de vie, știuletele.

**Flux** (`docs/ART_PIPELINE.md`): concept Codex → QA → TRELLIS.2 → `post3d` → acoperiș/coajă reparat unde e cazul (skill-ul trellis2 #8) → Open Cloud. Lanul și rândurile de vie sunt procedurale, pentru instanțiere ieftină.

**Pași:**
- [ ] Conceptele, în loturi.
- [ ] TRELLIS, în loturi.
- [ ] Planșa de contact verificată vizual.
- [ ] Încărcarea; `SiteBuilder` și Happenings folosesc modelele.
- [ ] Commit pe loturi.

---

## M10. Platforma și verificarea finală

### Sarcina 36: Chestionarul de maturitate și Experience Events

**Pași:**
- [ ] Chestionarul de maturitate completat în Creator Dashboard, cu răspunsuri corecte (violență comică ușoară: Mild).
- [ ] Experience Events pentru update-ul de sâmbătă și pentru sezoane.
- [ ] Pașii care țin de om (ID, 2FA, Roblox Plus) sunt documentați în PROGRESS.

### Sarcina 37: Integrare, echilibru, documentație

**Pași:**
- [ ] Playtest-ul complet extins: fiecare loc, întâmplare și mini-joc, auditul de telefon, bugetul.
- [ ] e2e complet.
- [ ] Revizuire independentă de cod (subagent) pe economie, piață și mini-jocuri.
- [ ] Actualizat: GDD (secțiunile noi), PROGRESS, ARCHITECTURE (Happenings/Minigames), memoria.
- [ ] Publicare live; CI.
