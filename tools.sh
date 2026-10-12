#!/usr/bin/env bash
# Verificarea completă: teste, lint, format, tipuri, build.
set -euo pipefail
cd "$(dirname "$0")"
. "$HOME/.rokit/env"
[ -f roblox.yml ] || selene generate-roblox-std >/dev/null
if [ ! -f roblox.d.luau ]; then
	curl -sSL -o roblox.d.luau https://raw.githubusercontent.com/JohnnyMorganz/luau-lsp/main/scripts/globalTypes.None.d.luau
fi
echo "== teste"; lune run tests
echo "== lint"; selene src tests
echo "== format"; stylua --check src tests
echo "== tipuri"
rojo sourcemap default.project.json -o sourcemap.json >/dev/null
luau-lsp analyze --definitions=roblox.d.luau --sourcemap=sourcemap.json --ignore="src/server/Packages/**" src
echo "== build"; mkdir -p build && rojo build default.project.json -o build/bunica.rbxl
echo "TOTUL OK"
