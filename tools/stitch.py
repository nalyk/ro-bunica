#!/usr/bin/env python3
"""Bandă de cusătură populară (cruciuliță), generată procedural: se repetă perfect pe orizontală.

  stitch.py <ieșire.png> [--cell 8]

Motivul e desenat pe grilă (ca pe pânza de ie): fiecare celulă e o cruciuliță cu fir umbrit pe pânză crem.
Perioada e lățimea motivului, deci imaginea (un număr întreg de motive) se poate pune cap la cap.
"""
import sys

from PIL import Image, ImageDraw

MOTIF = [  # R = roșu, K = negru (brun închis), . = pânză; 16 coloane = o perioadă
    "................",
    "RR....R.R....RR.",
    ".R...RRKRR...R..",
    "....RRK.KRR.....",
    "...RRK.R.KRR....",
    "..RRK.RRR.KRR...",
    "...RRK.R.KRR....",
    "....RRK.KRR.....",
    ".R...RRKRR...R..",
    "RR....R.R....RR.",
    "................",
]
RED, BLACK, LINEN = (200, 30, 44), (52, 30, 24), (246, 238, 220)
out = sys.argv[1]
cell = int(sys.argv[sys.argv.index("--cell") + 1]) if "--cell" in sys.argv else 8
repeats = 4
rows, cols = len(MOTIF), len(MOTIF[0])
pad = 2  # rânduri de pânză sus și jos, cu tiv roșu
w, h = cols * repeats * cell, (rows + 2 * pad) * cell
img = Image.new("RGB", (w, h), LINEN)
d = ImageDraw.Draw(img)
# țesătura pânzei: grilă foarte fină
for x in range(0, w, cell // 2):
    d.line([(x, 0), (x, h)], fill=(236, 226, 205))
for y in range(0, h, cell // 2):
    d.line([(0, y), (w, y)], fill=(236, 226, 205))


def cross(cx, cy, color):
    shade = tuple(max(0, c - 55) for c in color)
    light = tuple(min(255, c + 45) for c in color)
    m = max(1, cell // 8)
    x0, y0, x1, y1 = cx + m, cy + m, cx + cell - m, cy + cell - m
    width = max(2, cell // 3)
    d.line([(x0, y1), (x1, y0)], fill=shade, width=width)  # firul de dedesubt
    d.line([(x0, y0), (x1, y1)], fill=color, width=width)  # firul de deasupra
    d.line([(x0 + 1, y0), (x1 - 1, y1 - 2)], fill=light, width=max(1, width // 3))  # lucirea firului


for r in range(repeats):
    for j, line in enumerate(MOTIF):
        for i, ch in enumerate(line):
            if ch in "RK":
                cross((r * cols + i) * cell, (j + pad) * cell, RED if ch == "R" else BLACK)
# tivul: un rând de cruciulițe roșii sus și jos
for i in range(cols * repeats):
    cross(i * cell, 0, RED)
    cross(i * cell, h - cell, RED)
img.save(out)
print(out, img.size)
