#!/usr/bin/env python3
"""Decupează fundalul alb al unui concept (umplere de la margini, nu pe culoare: albul din interior rămâne).

  cutout.py <intrare.png> <ieșire.png> [--tol 14]

Fundalul = pixelii aproape albi conectați la marginea imaginii. Marginea măștii e netezită ușor.
"""
import sys

import numpy as np
from PIL import Image, ImageFilter
from scipy import ndimage

src, out = sys.argv[1], sys.argv[2]
tol = int(sys.argv[sys.argv.index("--tol") + 1]) if "--tol" in sys.argv else 14
img = Image.open(src).convert("RGB")
a = np.asarray(img).astype(int)
near_white = (255 - a).max(axis=2) <= tol
labels, _ = ndimage.label(near_white)
border = set(np.unique(np.concatenate([labels[0], labels[-1], labels[:, 0], labels[:, -1]]))) - {0}
background = np.isin(labels, list(border))
# găurile (gogoașă, covrig, brațe în arc): zone închise de alb perfect uniform (fundalul), nu albul umbrit
# al hainelor sau al pomponului
strict = (255 - a).max(axis=2) <= 4
hole_labels, n = ndimage.label(strict & ~background)
for k in range(1, n + 1):
    region = hole_labels == k
    if region.sum() > 300 and a[region].std() < 1.5:
        background |= ndimage.binary_dilation(region, iterations=2) & near_white
alpha = Image.fromarray(np.where(background, 0, 255).astype(np.uint8)).filter(ImageFilter.GaussianBlur(0.8))
rgba = img.copy()
rgba.putalpha(alpha)
rgba.save(out)
print(out, "fundal:", round(background.mean() * 100, 1), "%")
