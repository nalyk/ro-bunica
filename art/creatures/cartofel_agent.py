"""Cartofel Agent: cartof spion cu ochelari negri, cravată roșie și zâmbet încrezut."""

import math
import sys

sys.path.insert(0, __file__.rsplit("/", 2)[0] + "/lib")
import kit  # noqa: E402

kit.reset()
POTATO = "#D4A464"
DARK = "#8E6534"
INK = "#1A1420"
kit.blob([((0, 0, 1.15), 1.0, (1.0, 0.85, 1.2)), ((0.15, 0.05, 1.85), 0.75), ((-0.15, 0, 0.6), 0.8)], POTATO)
for pos in [(0.62, -0.55, 1.95), (-0.55, -0.62, 0.75), (0.48, -0.7, 0.5), (-0.7, -0.45, 1.9)]:
    kit.sphere(pos, 0.08, DARK, scale=(1, 0.35, 0.8))
# ochelari de agent, cu ramă
for side in (-1, 1):
    kit.sphere((side * 0.36, -0.8, 1.62), 0.3, INK, scale=(1.2, 0.3, 0.8))
    kit.sphere((side * 0.36 + 0.12, -0.9, 1.72), 0.07, "#FFFFFF", scale=(1.6, 0.3, 0.6))
kit.tube([(-0.12, -0.9, 1.66), (0, -0.93, 1.69), (0.12, -0.9, 1.66)], 0.05, INK)
# sprânceană ridicată, a spionului
kit.tube([(0.1, -0.86, 2.0), (0.35, -0.85, 2.1), (0.62, -0.78, 2.03)], 0.06, DARK)
# zâmbet strâmb
kit.tube([(-0.3, -0.9, 1.32), (-0.1, -0.95, 1.08), (0.15, -0.95, 1.08), (0.4, -0.88, 1.4)], 0.06, "#5A2E14")
# cămașă albă, cravată
kit.sphere((0, -0.62, 0.78), 0.42, "#F4F0E6", scale=(1, 0.5, 0.9))
kit.tube([(0, -0.83, 0.98), (0, -0.88, 0.75), (0, -0.85, 0.5)], 0.09, "#D7263D", taper=(0.7, 1.0, 1.5))
# brațe atașate: unul salută (mână deschisă, fără degete ridicate: nimic ce poate fi citit ca gest urât)
kit.tube([(0.85, -0.1, 1.1), (1.2, -0.3, 1.3), (1.35, -0.55, 1.7)], 0.13, POTATO)
kit.sphere((1.37, -0.6, 1.8), 0.21, POTATO, scale=(1.0, 0.6, 1.15))
kit.tube([(-0.85, -0.1, 1.05), (-1.15, -0.2, 0.8), (-1.2, -0.25, 0.55)], 0.13, POTATO)
kit.sphere((-1.2, -0.27, 0.48), 0.17, POTATO)
# picioare cu pantofi lustruiți
for side in (-1, 1):
    kit.tube([(side * 0.35, 0, 0.35), (side * 0.38, -0.05, 0.12)], 0.12, "#2B2B33")
    kit.sphere((side * 0.4, -0.18, 0.1), 0.24, INK, scale=(1.0, 1.5, 0.55))
obj = kit.finish("CartofelAgent", max_tris=3000, height=4)
print("TRIS", kit.tri_count(obj))
out = sys.argv[sys.argv.index("--") + 1]
kit.export_glb(obj, out + "/CartofelAgent.glb")
kit.preview(obj, out + "/CartofelAgent.png")
