# BUNICA — Arhitectură și convenții

Designul e în `docs/GDD.md`. Progresul e în `docs/PROGRESS.md`.

## Principii

1. **Totul pe date.** Creaturile, raritățile, mutațiile, vremea, economia, upgrade-urile și produsele sunt tabele în `src/shared/Config`. Conținut nou = o intrare nouă, nu cod nou.
2. **Logica pură e separată de Roblox.** `src/shared/Domain` conține reguli fără instanțe și fără servicii Roblox: calcule de economie, creștere, mutații, reguli de furt, limitare de rată. Se testează headless cu Lune.
3. **Serverul are autoritate.** Inventarul, leii, furturile, loviturile de papuc și achizițiile se decid pe server. Clientul trimite doar intenții (vreau să plantez X în stratul N) și randează.
4. **Lumea se generează din cod.** Satul, ogrăzile, Bunica și creaturile placeholder sunt construite procedural. Modelele finale intră prin `modelId` din config, fără schimbări de cod.
5. **Vizualurile scumpe stau pe client.** Creșterea plantelor, animația creaturilor, efectele și vremea se randează local, din atribute replicate de server.

## Unelte

Gestionate cu Rokit (`rokit.toml`): Rojo, Lune, Selene, StyLua, luau-lsp.

| Comandă | Ce face |
| --- | --- |
| `lune run tests` | rulează toate testele (Config + Domain) |
| `selene src tests` | lint |
| `stylua src tests` | format (`--check` în verificări) |
| `rojo build -o build/bunica.rbxl` | construiește fișierul de place |
| `rojo serve` | sincronizare live cu Studio (plugin Rojo) |

Studio nu rulează pe Linux. Fișierul `.rbxl` se deschide în Studio pe Windows sau macOS, sau se folosește `rojo serve` din rețea.

## Structura

```
default.project.json          mapare Rojo
src/shared/   -> ReplicatedStorage.Shared
  Config/     date pure (tabele)
  Domain/     logică pură, testabilă cu Lune
  Net.luau    numele remote-urilor și accesul la ele
src/server/   -> ServerScriptService.Server
  init.server.luau            bootstrap: init() apoi start() pe fiecare serviciu
  Services/                   adaptoare Roblox (date, ogrăzi, furt, papuc, vreme, bazar, sezoane…)
  World/                      construcția lumii (VillageBuilder, SiteBuilder, Zones, DecorModels)
  Happenings/                 întâmplările ceasului satului (Kit + câte un modul pe întâmplare)
  Minigames/                  mini-jocurile (Props, RaceKit + câte un modul pe joc)
  Ai/                         mersul NPC-urilor (Walker), lupii
  Actors.luau, Busy.luau      Owner/Actor (jucători și boți), registrul celor ocupați într-un mini-joc
  Packages/                   biblioteci incluse (ProfileStore)
src/client/   -> StarterPlayer.StarterPlayerScripts.Client
  init.client.luau            bootstrap pentru controllere
  Controllers/                input, UI, efecte, randare locală
tests/        teste Lune (*.spec.luau) și harness-ul de rulare
```

## Satul viu (ceasul, mini-jocurile, piața, calendarul)

- **Ceasul satului** (`VillageClockService`): alege o întâmplare la 6–8 minute (`Domain/VillageClock.next`, cu istoric și filtru pe fază), o anunță cu 30 s înainte, apoi apelează `begin(ctx)` din modulul ei din `Happenings/`. Un modul primește trusa comună (`Happenings/Kit`: cel mai apropiat jucător, încetinire, puncte libere pe teren, figuri) și se termină singur sau la `stop`.
- **Mini-jocurile** (`MinigameService`): `register(def, module)`, apoi un ciclu fix: înscrierea la loc → numărătoarea → `module.run(match)` → podiumul. `match.score`, `match.finish` și `Domain/Minigame.rewards` decid premiile; jucătorii înscriși sunt marcați în `Busy`, deci nu pot fura și nu pot fi loviți de Bunica.
- **Bazarul** (`Domain/Market`, `MarketService`): oferta ține creatura în beciul vânzătorului, marcată `listed`; cumpărarea e atomică (leii și înregistrarea se mută în același apel). Orice cale care mută o creatură (vânzare, piedestal, schimb) refuză înregistrările marcate.
- **Calendarul** (`Domain/Seasons`, `SeasonService`): sărbătorile active ajung în `GameState.Holidays` (și anotimpul în `GameState.Season`); serviciile citesc steaguri simple (`GardenService.seasonFactor`, `RaidService.holiday`, `EconomyService.seasonalMultiplier`), deci nu depind de `SeasonService`. `SeasonService.force(list)` impune sărbători în teste.
- Toate trec prin abstracția Owner/Actor, deci se testează cu boți (`Actors.createBot`, `PlotService.assignBot`, `standIn = true`).

## Convenții de cod

- `--!strict` în fiecare modul.
- **Require-uri pe instanțe** (`require(script.Parent.X)`), ca în Roblox clasic. Harness-ul de teste din `tests/` emulează `script` peste sistemul de fișiere, așa că modulele din `Config` și `Domain` rulează identic în Lune.
- `Config` și `Domain` nu folosesc servicii Roblox (`game`, `workspace`, instanțe). Pot folosi tipuri de date (`Vector3`, `CFrame`), pe care harness-ul le injectează.
- Aleatoriul se injectează (`rng: () -> number`), ca testele să fie deterministe.
- Un serviciu e un modul cu `init()` (fără dependențe de alte servicii) și `start()` (poate folosi alte servicii).
- Identificatori în engleză, comentarii în română, texte afișate doar prin chei de localizare.

## Rețea

- `Shared/Net.luau` listează remote-urile. Serverul le creează în `ReplicatedStorage.Remotes`, clientul le așteaptă.
- Fiecare remote primit pe server trece prin limitare de rată (`Domain/RateLimiter`) și validare de tipuri și distanță.

## Date persistente

- ProfileStore (inclus în `src/server/Packages`) cu blocare pe sesiune.
- Schema profilului e în `Config/DataTemplate`. Orice câmp nou are valoare implicită, iar migrările sunt în `Domain/Migrations`.
- Creaturile au UID unic. La un furt, transferul se face în memorie între două profiluri active pe același server.

## Anti-exploit

- Validare pe server pentru plantare, furt, depunere și lovituri.
- Verificare de viteză în timpul furtului (teleport, speed hack anulează furtul).
- Limitare de rată pe fiecare remote.
- Clientul nu decide niciodată valori, monede sau rezultate.
