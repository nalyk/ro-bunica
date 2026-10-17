import math, heapq, json
import numpy as np
import matplotlib
matplotlib.use("Agg")
import matplotlib.pyplot as plt
from matplotlib.patches import Rectangle, Circle, Polygon
from matplotlib.transforms import Affine2D

# Un sat = drumuri (polilinii), ogrăzi (centru, unghi = direcția porții spre drum, punctul porții), centrul (hub),
# repere. Distanțele se măsoară pe graful drumurilor (poarta → drum → ...).

def graph_from(roads, snap=4.0):
    nodes, edges = [], {}
    owner = []
    def node(p):
        for i, q in enumerate(nodes):
            if math.dist(p, q) < snap:
                return i
        nodes.append(p); return len(nodes)-1
    for pts in roads:
        # densificare la 10 studs, ca porțile să se lege aproape de unde sunt
        dense = []
        for a, b in zip(pts, pts[1:]):
            n = max(1, int(math.dist(a, b) // 10))
            for k in range(n):
                dense.append((a[0]+(b[0]-a[0])*k/n, a[1]+(b[1]-a[1])*k/n))
        dense.append(pts[-1])
        ids = [node(p) for p in dense]
        owner.append(set(ids))
        for i, j in zip(ids, ids[1:]):
            if i != j:
                d = math.dist(nodes[i], nodes[j])
                edges.setdefault(i, []).append((j, d)); edges.setdefault(j, []).append((i, d))
    # capetele de drum se leagă de cel mai apropiat punct al altui drum (intersecțiile)
    for k, pts in enumerate(roads):
        for end in (pts[0], pts[-1]):
            e = min(range(len(nodes)), key=lambda i: math.dist(nodes[i], end))
            others = [i for r, ids in enumerate(owner) if r != k for i in ids]
            if not others:
                continue
            o = min(others, key=lambda i: math.dist(nodes[i], end))
            d = math.dist(nodes[o], nodes[e])
            if 0 < d < 25:
                edges.setdefault(e, []).append((o, d)); edges.setdefault(o, []).append((e, d))
    return nodes, edges

def attach(nodes, edges, p):
    j = min(range(len(nodes)), key=lambda i: math.dist(nodes[i], p))
    nodes.append(p); k = len(nodes)-1
    d = math.dist(p, nodes[j])
    edges.setdefault(k, []).append((j, d)); edges.setdefault(j, []).append((k, d))
    return k

def dijkstra(edges, s):
    dist = {s: 0}; pq = [(0, s)]
    while pq:
        d, u = heapq.heappop(pq)
        if d > dist.get(u, 1e18): continue
        for v, w in edges.get(u, []):
            nd = d + w
            if nd < dist.get(v, 1e18):
                dist[v] = nd; heapq.heappush(pq, (nd, v))
    return dist

def metrics(name, layout):
    nodes, edges = graph_from(layout["roads"])
    gates = [attach(nodes, edges, p["gate"]) for p in layout["plots"]]
    hub = attach(nodes, edges, layout["hub"])
    dh = dijkstra(edges, hub)
    to_hub = np.array([dh[g] for g in gates])
    mean_other, nearest = [], []
    for g in gates:
        d = dijkstra(edges, g)
        others = [d[h] for h in gates if h != g]
        mean_other.append(np.mean(others)); nearest.append(min(others))
    mean_other, nearest = np.array(mean_other), np.array(nearest)
    sinu = []
    for pts in layout["roads"]:
        L = sum(math.dist(a, b) for a, b in zip(pts, pts[1:])); D = math.dist(pts[0], pts[-1])
        if L > 60 and D > 1: sinu.append(L / D)
    angles = np.array([p["angle"] for p in layout["plots"]]) % 360
    # dispersia orientărilor (statistică circulară: 0 = toate la fel, 1 = uniform)
    R = abs(np.mean(np.exp(1j*np.radians(angles))))
    cv = lambda a: float(np.std(a) / np.mean(a))
    return {
        "layout": name,
        "hub_cv": round(cv(to_hub), 3), "hub_maxmin": round(float(to_hub.max()/to_hub.min()), 2),
        "others_cv": round(cv(mean_other), 3), "others_maxmin": round(float(mean_other.max()/mean_other.min()), 2),
        "nearest_cv": round(cv(nearest), 3),
        "hub_mean": round(float(to_hub.mean())), "others_mean": round(float(mean_other.mean())),
        "road_sinuosity": round(float(np.mean(sinu)), 3) if sinu else 1.0,
        "orientation_spread": round(1 - float(R), 3),
    }

PLOT_W, PLOT_D = 80, 70

def plot_at(gate, angle):
    # ograda e în spatele porții, pe direcția opusă unghiului (unghiul = spre drum)
    a = math.radians(angle)
    c = (gate[0] - math.cos(a)*PLOT_D/2, gate[1] - math.sin(a)*PLOT_D/2)
    return {"gate": gate, "angle": angle, "center": c}

def arc(f, t0, t1, n=40):
    return [f(t0 + (t1-t0)*i/n) for i in range(n+1)]

# --- L0: satul de azi ---------------------------------------------------------------------
L0 = {"roads": [[(-230, 0), (230, 0)]], "hub": (0, 0), "plots": [], "water": [], "marks": {"Fântâna": (0, 0)}}
for x in (-135, -45, 45, 135):
    L0["plots"].append(plot_at((x, 12), -90 + 180))  # gate on road side
for x in (-135, -45, 45, 135):
    L0["plots"].append(plot_at((x, -12), -90))
# corectăm: ograda de sus (y>0) are poarta jos (unghi -90 → spre drum)
L0["plots"] = [plot_at((x, 12), -90) for x in (-135, -45, 45, 135)] + [plot_at((x, -12), 90) for x in (-135, -45, 45, 135)]

# --- L1: Valea cu pârâu (pieptene, ca Trebujeni): drumul mare urmează pârâul, ulițe care urcă dealul ---
def valley(x):
    return (x, 35*math.sin(x/140) - 0.0008*x*x)
main = arc(valley, -300, 300, 60)
river = [(x, y - 70) for x, y in arc(valley, -340, 340, 60)]
lanes = []
L1_plots = []
for x0, tilt in ((-170, 12), (0, -8), (165, 15)):
    base = valley(x0)
    # ulița urcă dealul, ușor curbată și înclinată
    lane = [(base[0] + math.sin(math.radians(tilt))*t + 8*math.sin(t/40), base[1] + t) for t in range(0, 241, 20)]
    lanes.append(lane)
    # două ogrăzi pe uliță, una de fiecare parte, la distanțe diferite (stânga mai jos, dreapta mai sus)
    for side, t in ((-1, 95), (1, 165)):
        p = lane[int(t // 20)]
        L1_plots.append(plot_at((p[0] + side*12, p[1]), 0 if side > 0 else 180))
# două ogrăzi pe drumul mare, cu fața spre drum, între ulițe
for x in (-85, 85):
    p = valley(x)
    L1_plots.append(plot_at((p[0], p[1] + 12), -90))
footbridge = [(-60, valley(-60)[1]), (-60, valley(-60)[1] - 70)]
L1 = {"roads": [main] + lanes, "hub": valley(0), "plots": L1_plots, "water": [river],
      "marks": {"Fântâna + Magazin": valley(0), "Biserica (deal)": (20, 300), "Moara": (-260, 260), "Iazul": (220, -120), "Podul": (-60, valley(-60)[1] - 70)}}

# --- L2: Răscrucea (centrul la intersecție, 4 ulițe la unghiuri neregulate, ca Sculeni) ---
L2_plots, L2_roads = [], []
for ang, length in ((8, 260), (101, 230), (187, 270), (281, 240)):
    a = math.radians(ang)
    road = []
    for t in range(0, length + 1, 20):
        bend = 18*math.sin(t/70)
        road.append((math.cos(a)*t - math.sin(a)*bend, math.sin(a)*t + math.cos(a)*bend))
    L2_roads.append(road)
    for side, t in ((1, 110), (-1, 190)):
        p = road[t // 20]
        nx, ny = -math.sin(a)*side, math.cos(a)*side
        L2_plots.append(plot_at((p[0] + nx*12, p[1] + ny*12), math.degrees(math.atan2(-ny, -nx))))
L2 = {"roads": L2_roads, "hub": (0, 0), "plots": L2_plots, "water": [[(-300, -260), (-120, -200), (60, -235), (300, -190)]],
      "marks": {"Centrul: fântâna, magazinul, stația": (0, 0), "Biserica": (60, 40)}}

# --- L3: Bucla în jurul iazului (8 ogrăzi pe exteriorul unei bucle ovale, pod peste iaz) ---
L3_plots = []
def loop(t):
    return (210*math.cos(t) + 25*math.cos(3*t), 150*math.sin(t) + 15*math.sin(2*t))
ring = arc(loop, 0, 2*math.pi, 80)
for k in range(8):
    t = 2*math.pi*k/8 + 0.2
    p = loop(t)
    nx, ny = p[0], p[1]; n = math.hypot(nx, ny)
    gate = (p[0] + nx/n*12, p[1] + ny/n*12)
    L3_plots.append(plot_at(gate, math.degrees(math.atan2(-ny, -nx)) + 180))
bridge = [loop(math.pi/2), (0, 0), loop(-math.pi/2)]
L3 = {"roads": [ring, bridge], "hub": (0, 0), "plots": L3_plots,
      "water": [arc(lambda t: (120*math.cos(t), 70*math.sin(t)), 0, 2*math.pi, 40)],
      "marks": {"Podul + fântâna (centru)": (0, 0)}}
# ograda e în afara buclei: unghiul porții spre interior
L3["plots"] = []
for k in range(8):
    t = 2*math.pi*k/8 + 0.2
    p = loop(t); n = math.hypot(*p)
    gate = (p[0] + p[0]/n*12, p[1] + p[1]/n*12)
    L3["plots"].append(plot_at(gate, math.degrees(math.atan2(-p[1], -p[0]))))

LAYOUTS = [("L0 — satul de azi", L0), ("L1 — Valea cu pârâu (pieptene)", L1), ("L2 — Răscrucea", L2), ("L3 — Bucla iazului", L3)]

def draw(ax, name, lay, m):
    for w in lay["water"]:
        x, y = zip(*w); ax.plot(x, y, color="#4a90d9", lw=6, alpha=0.6, solid_capstyle="round")
    for pts in lay["roads"]:
        x, y = zip(*pts); ax.plot(x, y, color="#b08850", lw=7, alpha=0.85, solid_capstyle="round")
    for i, p in enumerate(lay["plots"]):
        cx, cy = p["center"]
        r = Rectangle((cx - PLOT_W/2, cy - PLOT_D/2), PLOT_W, PLOT_D, facecolor="#7cb342", edgecolor="#33691e", alpha=0.75, lw=1.2)
        r.set_transform(Affine2D().rotate_deg_around(cx, cy, p["angle"] + 90) + ax.transData)
        ax.add_patch(r)
        ax.plot(*p["gate"], "s", color="#1e3a8a", ms=5)
        ax.text(cx, cy, str(i+1), ha="center", va="center", fontsize=9, color="white", weight="bold")
    ax.plot(*lay["hub"], "*", color="#d32f2f", ms=16)
    for label, (x, y) in lay["marks"].items():
        ax.text(x, y + 14, label, fontsize=7, ha="center", color="#5d4037")
    ax.set_title(f"{name}\nechitate: centru CV {m['hub_cv']:.2f}, ceilalți CV {m['others_cv']:.2f} · sinuozitate {m['road_sinuosity']:.2f} · orientări {m['orientation_spread']:.2f}", fontsize=8.5)
    ax.set_aspect("equal"); ax.set_xlim(-360, 360); ax.set_ylim(-330, 360); ax.axis("off")

results = []
fig, axes = plt.subplots(2, 2, figsize=(14, 13))
for (name, lay), ax in zip(LAYOUTS, axes.ravel()):
    m = metrics(name, lay); results.append(m); draw(ax, name, lay, m)
plt.tight_layout(); plt.savefig("layouts.png", dpi=100)
for r in results:
    print(json.dumps(r, ensure_ascii=False))

# --- metrica de orientare corectată: axa ogrăzii (mod 180) → unghi dublat ----------------------------------
def axis_spread(plots):
    ang = np.radians(np.array([p["angle"] for p in plots]) * 2)
    return round(1 - float(abs(np.mean(np.exp(1j*ang)))), 3)

# --- L4: Valea cu două ulițe legate (hibrid): drumul mare pe lângă pârâu + ulița de deal, legate de 3 ulițe
# scurte (capete + mijloc prin centru). Pozițiile ogrăzilor sunt căutate automat pentru echitate.
import random
def lower(x):  # drumul mare, pe lângă pârâu
    return (x, 30*math.sin(x/120) - 0.0006*x*x)
def upper(x):  # ulița de deal
    return (x*0.92 + 10, 150 + 28*math.sin(x/90 + 1.1) - 0.0004*x*x)
low_road = arc(lower, -280, 280, 56)
up_road = arc(upper, -280, 280, 56)
cross = [[lower(-280), upper(-280)], [lower(280), upper(280)], [lower(0), (lower(0)[0] + 15, 75), upper(0)]]
river4 = [(x, y - 75) for x, y in arc(lower, -330, 330, 60)]
hub4 = (lower(0)[0] + 15, 75)  # centrul: la mijlocul ulicioarei care leagă cele două drumuri

def facing(f, x, side):
    # poarta e pe normala drumului (ogrăzile urmează curba drumului, ca în satele reale) + o abatere mică
    a, b = f(x - 2), f(x + 2)
    tx, ty = b[0] - a[0], b[1] - a[1]; n = math.hypot(tx, ty)
    nx, ny = -ty / n * side, tx / n * side
    jitter = 7 * math.sin(x * 0.37)
    return nx, ny, math.degrees(math.atan2(-ny, -nx)) + jitter

def build4(params):
    plots = []
    for x in params["low"]:  # pe drumul mare, ogrăzile urcă dealul
        p = lower(x); nx, ny, ang = facing(lower, x, 1)
        plots.append(plot_at((p[0] + nx*12, p[1] + ny*12), ang))
    for x, side in params["up"]:  # deasupra uliței de deal
        p = upper(x); nx, ny, ang = facing(upper, x, side)
        plots.append(plot_at((p[0] + nx*12, p[1] + ny*12), ang))
    return {"roads": [low_road, up_road] + cross, "hub": hub4, "plots": plots, "water": [river4],
            "marks": {"Centrul: fântâna, magazinul, stația": hub4, "Podul": (lower(-120)[0], lower(-120)[1] - 75),
                      "Biserica (deal)": (40, 320), "Iazul": (230, -150), "Moara": (-250, 300), "Via (deal)": (180, 300)}}

def valid(params):
    xs = sorted(params["low"])
    if any(b - a < 95 for a, b in zip(xs, xs[1:])): return False
    ups = {1: [], -1: []}
    for x, s in params["up"]: ups[s].append(x)
    for s in ups:
        u = sorted(ups[s])
        if any(b - a < 95 for a, b in zip(u, u[1:])): return False
    # ogrăzile de sub ulița de sus nu se suprapun cu cele de deasupra drumului mare (deal de ~150 între ele)
    return all(abs(x) < 245 for x in xs) and all(abs(x) < 245 for x, _ in params["up"])

best, best_score = None, 1e9
rng = random.Random(4)
for it in range(4000):
    params = {"low": [rng.uniform(-240, 240) for _ in range(4)],
              "up": [(rng.uniform(-240, 240), rng.choice((1, -1))) for _ in range(4)]}
    if not valid(params): continue
    # ogrăzile de sub ulița de sus ar intra peste cele de pe drumul mare: le vrem doar deasupra uliței
    params["up"] = [(x, 1) for x, _ in params["up"]]
    if not valid(params): continue
    m = metrics("L4", build4(params))
    score = max(m["hub_cv"] / 0.15, m["others_cv"] / 0.10, m["hub_maxmin"] / 1.5)
    if score < best_score:
        best, best_score = params, score
L4 = build4(best)
print("L4 params", json.dumps(best))

LAYOUTS.append(("L4 — Valea cu două ulițe (hibrid, căutat automat)", L4))
results = []
fig, axes = plt.subplots(2, 3, figsize=(20, 13))
for (name, lay), ax in zip(LAYOUTS, axes.ravel()):
    m = metrics(name, lay); m["orientation_spread"] = axis_spread(lay["plots"]); results.append(m); draw(ax, name, lay, m)
axes.ravel()[-1].axis("off")
plt.tight_layout(); plt.savefig("layouts.png", dpi=90)
print("FINAL")
for r in results:
    print(json.dumps(r, ensure_ascii=False))
