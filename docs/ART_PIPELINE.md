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
