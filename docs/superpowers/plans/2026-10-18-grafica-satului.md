# Refacerea graficii satului (2026-10-18)

Cerința omului: „All the new graphics … is horrible!”, apoi „refă grafica pe fluxul complet, nu te opri pentru întrebări, tu decide, nu contează efortul”.

## Diagnosticul (capturi din joc, pasul de playtest 1g „Galeria satului”)

Modelele TRELLIS arată bine în randări, dar în joc:
1. Peisajul e gol: locurile stau izolate în câmpii verzi uniforme; copacii și tufele sunt bile procedurale (o tufă-bilă uriașă blochează vederi).
2. Locuri procedurale urâte: Casa de cultură (roz, coloane plate), școala (cutie albă), stuful iazului (bețe), lanul de porumb (ziduri plate), via (bile verzi), rutiera (cutie galbenă).
3. Gardul ogrăzilor (GardLow, nuiele decimate) arată ca un morman roșu zimțat.
4. Modelele bune (moara, biserica, stâna) sunt mici și fără context (fără potecă, gard, copaci, obiecte).
5. Amurgul și noaptea sunt prea roșii și întunecate.

## Fluxul

Concept Codex (`tools/concepts.py world <Cheie>`, brief în `art/world/BRIEFS.md`) → `tools/cutout.py` → `ai-esempla:~/trellis2/work/in/site/` → TRELLIS (`batch.sh`, Ollama descărcat cu `keepfree_all.sh`) → `art/models.json` → `tools/art.py build|upload <cheie>` → `Config/ArtAssets` → așezare în cod (cu revenire procedurală doar dacă lipsește modelul).

## Sarcinile

1. **Galeria în playtest** (pasul 1g, după 1c): fiecare loc de aproape, copaci, drum, rutiera; fără HUD și fără lista de jucători, la amiază.
2. **Concepte noi:** copacii (Salcam, Plop, Mar, Prun, Stejar), tufele (Tufa, Liliac), Flori, Stuf, StalpBarza; Scoala, Porumb (zid de lan), Uluci (gardul nou), Pietre, Ponton, Banca, Caruta, Saci, Lemne. Rutiera reîncercată (20 GB liberi pe GPU, apoi pipeline 1024).
3. **TRELLIS + art.py** pentru toate; triunghiuri după rol (copaci mari 6k, pomi 4–5k, tufe 2,5k, flori 1,5k, clădiri ≥ 12k, segmente repetate 1,2–2k).
4. **Vegetația satului** (`VillageBuilder.scatter` rescris): pâlcuri și nu puncte uniforme; salcâmi de-a lungul drumului mare, plopi în șir, livezi lângă ogrăzi, codrul des din stejari și nuci, tufe și flori pe margini de garduri, stuf pe malul iazului și al pârâului, pietre. Determinist (seed), fără coliziuni, fără umbre la tufe și flori.
5. **Locurile:** Casa de cultură sculptată (ringul de dans afară, în fața ei, cu lumini), școala sculptată + terenul, iazul (stuf, ponton), via (butuc la fiecare par, fără bile), lanul de porumb (ziduri din segmente Porumb), moara/biserica/stâna mai mari și îmbrăcate (potecă, gard de uluci, pomi, saci, căruță, lăiță, lemne).
6. **Gardul ogrăzilor:** Uluci în loc de GardLow.
7. **Rutiera** sculptată (RutieraService sudează `char.Rutiera`).
8. **Bugetul de randare** refăcut: decorul unei ogrăzi ≤ 120k; densitatea locală (Σ triunghiuri pe o rază de 200 studs, maximul pe o grilă) ≤ 900k; plasele unice (memorie) raportate.
9. **Lumina:** amurgul și noaptea mai puțin roșii, mai luminoase (SkyCycle).
10. **Verificare:** galeria (capturi de aproape, comparate înainte/după), playtest complet, e2e, publicare; capturile trimise omului.

## Progres și decizii

- **Coroanele copacilor:** TRELLIS face trunchiul bine, dar frunzișul iese ca o coajă rară de frunze rupte (și în plasa brută de 40k). `tools/tree_crown.py` (pas în `art.py`, `"crown": true` în `art/models.json`) păstrează trunchiul și crengile, scoate frunzele, fructele și florile după culoarea texturii și pune smocuri pline (k-means pe pozițiile frunzelor, icosfere cu relief, atlas cu umbrire coaptă), fructele și florile ca bile. Verdele e stins (în Roblox iese lămâie aprins).
- **Decimarea trunchiului:** post3d decimează și coace textura (curat); decimarea făcută după coacere rupe UV-urile (așchii). Deci `tris` din models.json e ținta totală pentru post3d, iar coroana nu mai decimează.
- **TRELLIS și CuMesh:** obiectele cu multe detalii fine (rutiera cu geamuri transparente, mărul cu mere dese) cer o alocare uriașă în CuMesh. Rutiera are un concept nou, mai simplu (RutieraV2, geamuri opace, fără portbagaj); cele picate se reiau cu pipeline 512, apoi 1024 (`chain14.sh`).
- **Iarba animată (Terrain.Decoration):** setată în `default.project.json`; nu se poate citi din scripturi. În capturi nu se vede, deci nu contez pe ea.
- **Lumina:** apusul (18,6) mai auriu și mai luminos, noaptea mai luminoasă; galeria rulează la amiază (sfârșitul fazei „acum”).
- **Drumurile nu se vedeau deloc (nici înainte de refacere):** fața plăcii de iarbă e la −1, dar suprafața netezită a terenului iese la +1 (voxeli de 4 studs), deci fâșiile de la −0,84 stăteau sub iarbă. Acum fiecare segment se așază pe suprafața măsurată prin raycast (după 2 cadre), nimic peste apă; pământul de sub drum se pictează cu `ReplaceMaterial` (schimbă doar materialul, nu înălțimea). Drumul mare e din pământ bătătorit, nu din nisip.
- **Lanul de porumb:** TRELLIS a făcut un petec aproape pătrat; în joc segmentul se întinde neuniform (`stretch`): lung cât zidul, gros de 2,6 studs, deci coridoarele labirintului rămân libere.
- **Pietrele:** textura TRELLIS a ieșit oliv-neagră de două ori (seed 21 inclusiv); pietrele sunt procedurale (trei bolovani din Slate).
- **Mărul:** în pipeline 512 trunchiul ieșea rupt; refăcut cu alt seed. **Bucătăria de vară:** concept nou (Codex); CuMesh fără memorie în 1024_cascade și 1024, deci presimplificare 600k sau 512.
- **Liliacul** rămâne TRELLIS simplu (coroana procedurală îi pierdea florile); 2000 de triunghiuri.
- **Bugetul local** (1,048M la (−80, 0)): poarta și fântâna de la 19k la 12k (identice vizual), liliacul la 2000.
- **Galeria:** camera alege prima direcție care nu trece prin ogrăzi și nu lovește ceva mare; vegetația și pomii din ogrăzi dintre cameră și loc se ascund cât ține captura; rutiera e prinsă în stație (ceasul ei sare până la sosire).
- **Contextul locurilor:** biserica are plopi în spate, nuc și gard de uluci cu poarta liberă; moara și stâna au salcâmi, tufe și flori; stația e întoarsă spre drum (modelul are fața spre +Z).
