# Contribuții

Proiectul e lucrat pe `main`. Înainte de orice commit:

1. `./tools.sh` trebuie să treacă (teste Lune, Selene, StyLua, luau-lsp, build).
2. Pentru schimbări de server: `python3 tools/cloud.py e2e`.
3. Pentru schimbări de gameplay sau client: `tools/playtest.sh`.
4. `docs/PROGRESS.md` se actualizează după fiecare pas terminat.

Convențiile de cod (date în `Config`, logică pură în `Domain`, require-uri pe instanțe, comentarii în română) sunt în [`docs/ARCHITECTURE.md`](docs/ARCHITECTURE.md). Textele afișate jucătorului trec doar prin cheile din `src/shared/Strings`.
