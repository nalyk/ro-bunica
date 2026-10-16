# Fluxul de artă: concept AI → model 3D texturat → Roblox

Decis pe 2026-10-16, după ce omul a respins modelele din primitive Blender („vizualul e oribil”).
**De ce:** primitivele scrise în Python (sfere, tuburi, metaball-uri) au plafon de „jucărie asamblată”.
Arta de top înseamnă forme sculptate și texturi pictate, deci: concept generat de un model de imagine,
apoi imagine → 3D texturat.

```
1. Concept      Codex CLI `image_gen` (gpt-image-2, din abonamentul ChatGPT; 0 $ în plus)
2. QA concept   art/CONCEPT_QA.md (mâini, contact, stânga/dreapta, perechi, A-pose, obiecte separate)
3. 3D           TRELLIS.2 (Microsoft, MIT) pe Hugging Face ZeroGPU, cu contul `nalyk` (HF_TOKEN în .env.cloud)
4. Curățare     Blender: decimare la ≤ 19.000 de triunghiuri per MeshPart, scară, pivot, textură 1024
5. Roblox       tools/assets.py (Model), ArtService/ArtLibrary (deja construite), verificare în Studio
```

## Codex CLI și imaginile (verificat local, codex-cli 0.163)

- **Unealta:** `image_gen` (funcția `image_generation`, stabilă, activă). Sistemul are skill-ul
  `~/.codex/skills/.system/imagegen/` (SKILL.md, references/prompting.md, sample-prompts.md).
- **Rulare neinteractivă** (verificat):
  `codex exec --skip-git-repo-check -s read-only "<prompt; cere o singură imagine; fără cod>"`.
  Fișierul ajunge în `~/.codex/generated_images/<sesiune>/*.png`, apoi îl copiem în repo. Opțiunea
  `-i <fișier>` atașează imagini de referință sau de editat.
- **Cost:** contul e logat cu ChatGPT, deci imaginile consumă din limitele planului, de aproximativ 3–5 ori
  mai repede decât o tură normală, nu din API. Mărimea și raportul se cer în prompt; formatele observate
  sunt 1024×1536 (portret) și 1536×1024. Parametri precum quality, n, mască sau fundal transparent există
  doar în modul CLI cu API key (facturat), pe care nu-l folosim.
- **Transparență:** cel mai sigur e un fond plat (alb sau #00FF00), decupat cu
  `python ~/.codex/skills/.system/imagegen/scripts/remove_chroma_key.py --input in.png --out out.png --auto-key border --soft-matte --despill`.
- **Licență:** ieșirile aparțin utilizatorului (termenii OpenAI), dar nu sunt garantat unice.

## Prompting (oficial + ce a mers)

- **Ordinea:** cadru/fond → subiect → detalii → constrângeri → scop. Pe rânduri scurte, cu etichete:
  `Intended use / Style / Framing / Pose / Subject / Constraints`.
- **Stilul se repetă integral la fiecare imagine**: „premium 3D animated feature-film character, stylized,
  appealing chunky proportions…”. Pentru un set consecvent, prima imagine bună devine ancoră (`-i`), iar
  promptul spune „same character, do not redesign”.
- **Editări:** „change only X; keep Y unchanged”, cu invariantele repetate la fiecare iterație, câte o
  schimbare pe rând.
- **Text în imagine:** între ghilimele, „EXACT, verbatim”, cu fontul, mărimea și poziția.
- **Pentru 3D:** din față, aproape ortografic, întreg, A-pose cu brațele la 30° de corp, mâini goale
  deschise, tălpile pe sol, fond alb, lumină egală, fără umbră. Obiectele ținute în mână sunt modele separate.
- **Icoane UI:** un icon „master”, apoi toate celelalte cu `-i master.png`: „same outline weight, palette,
  light from top-left, padding”. Panouri 9-slice: chenar de grosime constantă, centru uniform, fără
  perspectivă; marginile le verificăm noi. Texturi: „seamless tileable”, iar îmbinarea se verifică
  decalând imaginea cu jumătate.

## TRELLIS.2 pe Hugging Face (verificat)

- Spațiul `microsoft/TRELLIS.2`. Apeluri, în aceeași sesiune: `/start_session` → `/preprocess_image` →
  `/image_to_3d` (seed, rezoluție 1024) → `/extract_glb` (decimare de minimum 100.000, textură 1024).
  Scriptul: `tools/trellis.py` (de mutat din scratchpad).
- **Cota gratuită ZeroGPU e mică** (câteva minute de GPU pe zi; o generare ≈ 40 s + export ≈ 120 s),
  deci 1–2 modele pe zi pe contul gratuit. HF PRO dă 25 de minute pe zi, dar costă bani și cere
  acordul omului.

## Ce rulează acum (2026-10-16, seara)

- **TRELLIS.2 local pe `ai-esempla` (RTX 5090)**, în Docker `bunica/trellis2:sm120` (detalii și capcane:
  memoria `ai-esempla-gpu`). Lot: `~/trellis2/restart_batch.sh <listă> --seed 7 --faces 40000,20000
  --texture 2048`. Textura e coaptă **după** decimare, pe fiecare nivel. La 10k, detaliile fine (găurile
  brânzei) ieșeau în cioburi; la 20k (limita practică Roblox per MeshPart) rezultatul e curat.
- **Decupajul conceptelor:** `tools/cutout.py` (umplere de la margini, plus găurile de alb perfect uniform:
  gogoașa, covrigul, brațele în arc). Decupajul pe culoare ar fi șters albul iei.
- **Creaturi:** `tools/art.py` (`art/models.json`) → `tools/post3d.py` (scară, pivot, textură 1024) →
  urcare → `ArtAssets.luau`. Mutațiile nuanțează `SurfaceAppearance.Color` și `Emissive*`
  (`Shared/Visual/MutationVisuals.luau`).
- **Bunica:** `tools/split_character.py` taie plasa în Body, Head, LeftArm, RightArm (capul și mânecile
  după poziție, mâinile după conectivitate și insule) și exportă pivoturile ca markeri. Serverul
  (`BunicaService.buildSculpted`) face rig-ul cu motoarele Root/Neck/LeftShoulder/RightShoulder, deci
  pozele procedurale vechi merg. Modelul e întors cu 180° față de `home` (rig-ul R15 vechi era rotit).
- **Iconițe UI:** `tools/icons.py` (master + referință, fond #00FF00 decupat, 256 px) → `UiIcons.luau`.
- **Fonturi:** Nunito (ș, ț și chirilice). Doar Regular vine cu clientul; **Black (900) a înghețat Studio
  sub Wine**, Bold merge.
- **Pete negre la 20k:** re-coacerea texturii de către TRELLIS după decimare poate lăsa texeli negri
  (Mămăligator). Atunci se ia nivelul de 40k și îl decimează `post3d.py` la 19k (colaps cu UV-urile
  păstrate, fără re-coacere): rezultatul e curat. În `art/models.json`: `"remote": "…_40k.glb"`.
- **Găuri adânci în concept:** TRELLIS modelează găurile brânzei ca cavități reale, care ies negre chiar
  și la 40k. Se repară din concept (Brânzoi v2: pori mici, puțin adânci), nu din semințe.
- **Socluri din concept:** `"trimBase": true` → `post3d.py --trim-base` taie soclul (cel mai înalt plan
  orizontal mare din sfertul de jos; plasele au pereți dubli, deci și fundul soclului are fețe în sus).
  Piedestalul îl dă jocul.
- **Satul:** `WorldBuilder.placeArt` pune modelele (doar vizuale) peste piesele vechi, care rămân coliziuni
  invizibile. Gardul, piedestalele și rafturile folosesc nivelul de ~3k (`low_*`), fără pierderi vizibile.
- **Hoțomanul:** concept `art/concepts/characters/hotoman_v2.png` (sacul pe spate, ca brațele să fie libere),
  nivelul de 40k decimat la ~22k în `split_character.py --profile hotoman` (picioare separate, tăieturi
  drepte pe planele vintrelui și gâtului prin `bisect_plane`). Rig-ul comun e `Server/Ai/SculptedRig`
  (Root, Neck, umeri, șolduri, Humanoid cu HipHeight); `Actors.createBot(name, at, "Hotoman")`. Mersul e
  procedural pe client (`StrideController`, atributul `Walks`); creatura cărată stă deasupra creștetului
  (`CarryHeight`). Mersul se verifică în playtest (sesiunile Luau din Open Cloud nu rulează fizica).
- **Culoarea deviată spre cald** (Brânzoi v2: G 153 în loc de 212 pe corp): `"colorGain": [r, g, b]` →
  `post3d.py --color-gain`, factori măsurați pe zonele deschise ale corpului (concept vs textură), apoi
  ajustați la ochi (Brânzoi: 1, 1,32, 1,22).
- **CuMesh pică la orice sămânță** (straturile): detaliile granulare din concept (firimituri de pământ) fac
  plasa imposibil de simplificat. Conceptul v2 cu brazde netede a trecut din prima.
