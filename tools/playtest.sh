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
# Sub Wine rămân blocate peste viewport dialogul „Opening…” (646×130) și câteva ferestre goale
# de 100×100 (pătratul negru din centru). Le ascundem la nivel X11; Studio nu e afectat.
for w in $(xdotool search --name "Roblox" 2>/dev/null); do
	geometry=$(xdotool getwindowgeometry "$w" 2>/dev/null | awk '/Geometry/ {print $2}')
	case "$geometry" in
		646x130 | 100x100) xdotool windowunmap "$w" 2>/dev/null ;;
	esac
done
sleep 1
xdotool mousemove 900 500 click 1; sleep 1
xdotool key F5
START=$(date +%s)
echo "[playtest] pornit $NAME"

# Capturi periodice (la 4 s) și la comandă: regizorul scrie „[PLAYTEST] SNAP <nume>” în log
(
	i=0
	seen=0
	last=0
	while [ $(( $(date +%s) - START )) -lt $TIMEOUT ]; do
		LOGNOW=$(ls -t "$LOGS"/*Studio*.log 2>/dev/null | head -1)
		if [ -n "$LOGNOW" ]; then
			snaps=$(grep -o "\[PLAYTEST\] SNAP [A-Za-z0-9_-]*" "$LOGNOW" | awk '{print $3}')
			count=$(echo "$snaps" | grep -c .)
			if [ "$count" -gt "$seen" ]; then
				for name in $(echo "$snaps" | tail -n $((count - seen))); do
					import -window root "$FRAMES/snap-$name.png" 2>/dev/null
				done
				seen=$count
			fi
		fi
		now=$(date +%s)
		if [ $((now - last)) -ge 4 ]; then
			import -window root "$FRAMES/frame-$(printf %03d $i).png" 2>/dev/null
			i=$((i + 1))
			last=$now
		fi
		sleep 0.2
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

grep -o "\[\(PLAYTEST\|Raid\|Tutorial\|Slipper\|Plot\)\].*" "$LOG" | sed 's/\\n$//'
xdotool key shift+F5
if [ -z "$RESULT" ]; then
	echo "[playtest] TIMEOUT după ${TIMEOUT}s"
	exit 1
fi
echo "[playtest] capturi în $FRAMES"
SCORE=$(echo "$RESULT" | grep -o "REZULTAT [0-9]*/[0-9]*" | grep -o "[0-9]*/[0-9]*")
[ -n "$SCORE" ] && [ "${SCORE%/*}" = "${SCORE#*/}" ] && exit 0
exit 1
