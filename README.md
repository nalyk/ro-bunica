# BUNICA

Joc Roblox: crești creaturi trăsnite din mâncare, le furi pe ale prietenilor noaptea și îți aperi ograda cu papucul Bunicii.

Fiecare jucător are o ogradă într-un sat moldovenesc stilizat. Din semințe cresc creaturi (Cartofel Agent, Plăcintonio Bombardino, Mămăligator și altele), care aduc lei cât stau la vedere pe piedestal. Noaptea poți fura creaturile altora și le cari acasă, la beci, mai încet decât mergi de obicei. Proprietarul aruncă papucul, iar hoțul lovit scapă creatura și zboară spre poartă. Când proprietarul e plecat la furat, Bunica de pe prispă apără ograda singură, mai slab.

Designul complet e în [`docs/GDD.md`](docs/GDD.md).

## Stadiul

Primul loop jucabil e gata: creșterea, vremea și mutațiile, furtul, papucul, Bunica NPC, taraba cu semințe, beciul și venitul. Urmează tutorialul, upgrade-urile, monetizarea și modelele finale. Lista la zi e în [`docs/PROGRESS.md`](docs/PROGRESS.md).

Lumea, creaturile și Bunica sunt generate din cod, cu forme placeholder. Modelele finale se vor pune prin câmpul `modelId` din config, fără schimbări de cod.

## Cum e construit

Codul e Luau, sincronizat cu Studio prin [Rojo](https://rojo.space). Conținutul (creaturi, rarități, mutații, vreme, economie) stă în tabele în `src/shared/Config`. Regulile jocului care nu au nevoie de Roblox sunt în `src/shared/Domain` și se testează pe Linux cu [Lune](https://lune-org.github.io/docs). Serverul decide tot ce ține de lei, inventar și furturi. Clientul trimite doar intenții și desenează.

```
src/shared/    Config, Domain, rețea, texte (RO, EN), constructorul de creaturi
src/server/    serviciile jocului și generatorul satului
src/client/    HUD, taraba, beciul, ochitul papucului, efecte
tests/         teste Lune (*.spec.luau), e2e în motorul Roblox, playtest în Studio
tools/         cloud.py (Open Cloud), playtest.sh (Studio pe Linux)
```

Detaliile și convențiile de cod sunt în [`docs/ARCHITECTURE.md`](docs/ARCHITECTURE.md).

## Pornire

Uneltele se instalează cu [Rokit](https://github.com/rojo-rbx/rokit). Versiunile sunt fixate în `rokit.toml`.

```bash
rokit install
selene generate-roblox-std   # o singură dată, pentru lint
./tools.sh                   # teste, lint, format, tipuri, build
```

`./tools.sh` construiește `build/bunica.rbxl`, care se deschide în Roblox Studio. Pentru lucru live se folosește `rojo serve` cu pluginul Rojo din Studio.

## Teste

Sunt trei niveluri:

1. Local: `./tools.sh` rulează testele Lune pentru Config și Domain, Selene, StyLua, verificarea de tipuri cu luau-lsp și build-ul.
2. În motorul Roblox, prin Open Cloud: `python3 tools/cloud.py e2e` publică o versiune „Saved” a place-ului de test (versiunea live nu se schimbă) și rulează `tests/e2e` cu Luau Execution. În aceste sesiuni nu rulează fizica și nu există jucători, așa că testele folosesc boți pe server. Cheia API stă în `.env.cloud`, care nu intră în git.
3. Playtest în Studio: `tools/playtest.sh` pornește Studio (prin Vinegar, pe un display virtual), joacă scenariul din `tests/playtest` cu un jucător real și un jucător-bot și citește rezultatele din log.

## Licență

Toate drepturile rezervate; vezi [`LICENSE`](LICENSE). ProfileStore, inclus în `src/server/Packages`, e sub licența Apache 2.0.
