#!/usr/bin/env bash
# Playtest automat în Roblox Studio (Vinegar pe Xvfb :99): jucător real + jucător-bot.
# Cerințe: Studio deschis și logat pe :99 (vezi docs/PROGRESS.md). Rezultatele: liniile [PLAYTEST] din log.
# Folosire: tools/playtest.sh [director-capturi]
set -uo pipefail
cd "$(dirname "$0")/.."
. "$HOME/.rokit/env"

FRAMES="${1:-/tmp/bunica-playtest-frames}"
PLACES="$HOME/.var/app/org.vinegarhq.Vinegar/data/places"
LOGS="$HOME/.var/app/org.vinegarhq.Vinegar/data/vinegar/appdata/Roblox/logs"
export DISPLAY=:99
TIMEOUT=480

rojo build playtest.project.json -o build/bunica-playtest.rbxl >/dev/null
mkdir -p "$PLACES" "$FRAMES"
rm -f "$FRAMES"/*.png
NAME="playtest-$(date +%s).rbxl"
cp build/bunica-playtest.rbxl "$PLACES/$NAME"

# Închide instanțele Studio anterioare (câte un proces per place) și pornește una nouă direct cu place-ul.
# PID-urile se aleg după argumentele lui Studio, nu cu `pkill -f` (care ar putea prinde chiar acest script).
tmux kill-session -t studio 2>/dev/null
for pid in $(ps -eo pid,args | awk '/-task EditFile -localPlaceFile/ && !/awk/ {print $1}'); do
	kill "$pid" 2>/dev/null
done
sleep 3
WINPATH="Z:/home/ubuntu/.var/app/org.vinegarhq.Vinegar/data/places/$NAME"
tmux new-session -d -s studio "env DISPLAY=:99 flatpak run org.vinegarhq.Vinegar run -task EditFile -localPlaceFile $WINPATH"
for _ in $(seq 1 60); do
	sleep 2
	WIN=$(xdotool search --name "$NAME" 2>/dev/null | head -1)
	[ -n "$WIN" ] && break
done
if [ -z "${WIN:-}" ]; then
	echo "[playtest] Studio nu a deschis $NAME"
	exit 1
fi
sleep 15
xdotool windowactivate --sync "$WIN" 2>/dev/null
xdotool mousemove 900 500 click 1; sleep 1
xdotool key F5
START=$(date +%s)
echo "[playtest] pornit $NAME"

# Capturi periodice în fundal
(
	i=0
	while [ $(( $(date +%s) - START )) -lt $TIMEOUT ]; do
		import -window root "$FRAMES/frame-$(printf %03d $i).png" 2>/dev/null
		i=$((i + 1))
		sleep 4
	done
) &
CAPTURE=$!

LOG=""
RESULT=""
while [ $(( $(date +%s) - START )) -lt $TIMEOUT ]; do
	sleep 5
	LOG=$(ls -t "$LOGS"/*Studio*.log 2>/dev/null | head -1)
	if [ -n "$LOG" ] && grep -q "\[PLAYTEST\] REZULTAT" "$LOG"; then
		RESULT=$(grep -o "\[PLAYTEST\] REZULTAT.*" "$LOG" | tail -1)
		break
	fi
done
kill $CAPTURE 2>/dev/null

grep -o "\[\(PLAYTEST\|Raid\|Tutorial\|Slipper\)\].*" "$LOG" | sed 's/\\n$//'
xdotool key shift+F5
if [ -z "$RESULT" ]; then
	echo "[playtest] TIMEOUT după ${TIMEOUT}s"
	exit 1
fi
echo "[playtest] capturi în $FRAMES"
SCORE=$(echo "$RESULT" | grep -o "REZULTAT [0-9]*/[0-9]*" | grep -o "[0-9]*/[0-9]*")
[ -n "$SCORE" ] && [ "${SCORE%/*}" = "${SCORE#*/}" ] && exit 0
exit 1
