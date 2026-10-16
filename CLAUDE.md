# BUNICA (Roblox)

Joc Roblox construit de un singur om cu agenți AI. Răspunde în română.

Înainte de orice muncă, citește:

1. `docs/PROGRESS.md` — unde am rămas și ce urmează.
2. `docs/GDD.md` — designul (sursa de adevăr).
3. `docs/ARCHITECTURE.md` — structura și convențiile de cod.
4. `docs/VISION.md` — direcția strategică (cercetarea din 2026-10-12): cei trei piloni și pașii 1–7. Aprobați pentru lucru: pașii 1–6; pasul 7 (Configs/Experiments/Analytics/Server Authority) doar la cerere.
5. `docs/PRESENTATION.md` — modele, UI/UX și sunet (cercetarea din 2026-10-16): direcția artistică, fluxul Blender → Open Cloud și pașii P1–P5. Vocea Bunicii: `docs/VOICE.md`.

Reguli:

- Actualizează `docs/PROGRESS.md` după fiecare pas terminat, ca munca să poată fi reluată după un restart.
- Uneltele sunt prin Rokit (`. ~/.rokit/env`), rulate din rădăcina repo-ului.
- Verificare înainte de a declara ceva gata: `./tools.sh` (teste, lint, format, tipuri cu luau-lsp, build `.rbxl`). Pentru server: `python3 tools/cloud.py e2e` (motorul Roblox, Open Cloud). Pentru gameplay și client: `tools/playtest.sh` (Studio prin Vinegar pe Xvfb `:99`; niciodată pe `:1`, desktopul omului).
- Nu critica bugetul, echipa sau „începe mic”: proiectul e construit ambițios de la început.
- După fiecare pas verificat: commit cu tot (`git add -A`) și `git push origin main` (remote: `git@github.com:nalyk/ro-bunica.git`). `.env.cloud` conține cheile API (Roblox, Gemini) și nu se comite niciodată.
- Buget: vocea are un plafon de 2 $, plătit o singură dată, deci se folosește Gemini pe plan gratuit. Nicio cheltuială fără acordul omului.
