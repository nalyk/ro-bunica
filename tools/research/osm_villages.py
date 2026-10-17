import json, math, sys, collections
import numpy as np
import matplotlib
matplotlib.use("Agg")
import matplotlib.pyplot as plt

def proj(lat0, lon0):
    k = 111320.0
    return lambda lat, lon: ((lon - lon0) * k * math.cos(math.radians(lat0)), (lat - lat0) * k)

def analyze(name, path, lat0, lon0, ax=None):
    d = json.load(open(path))
    P = proj(lat0, lon0)
    buildings, roads, water, amen = [], [], [], []
    for e in d["elements"]:
        t = e.get("tags", {})
        if e["type"] == "way" and "geometry" in e:
            pts = [P(g["lat"], g["lon"]) for g in e["geometry"]]
            if "building" in t:
                buildings.append(pts)
            elif "highway" in t and t["highway"] in ("residential", "unclassified", "tertiary", "secondary", "track", "service", "living_street", "primary", "path", "footway"):
                roads.append((t["highway"], pts))
            elif "waterway" in t or t.get("natural") == "water":
                water.append(pts)
        if "amenity" in t:
            if e["type"] == "node":
                amen.append((t["amenity"], P(e["lat"], e["lon"])))
            elif "geometry" in e:
                g = e["geometry"][0]; amen.append((t["amenity"], P(g["lat"], g["lon"])))
    # road sinuosity for named village roads (not tracks)
    sinu = []
    for kind, pts in roads:
        if kind in ("residential", "unclassified", "tertiary", "living_street") and len(pts) > 2:
            L = sum(math.dist(pts[i], pts[i+1]) for i in range(len(pts)-1))
            D = math.dist(pts[0], pts[-1])
            if L > 150 and D > 1:
                sinu.append(L / D)
    # building orientation relative to nearest road segment
    segs = []
    for kind, pts in roads:
        if kind not in ("path", "footway"):
            for i in range(len(pts)-1):
                segs.append((pts[i], pts[i+1]))
    S = np.array([[a[0], a[1], b[0], b[1]] for a, b in segs]) if segs else np.zeros((0,4))
    rel, setbacks, areas, absang = [], [], [], []
    cents = []
    for pts in buildings:
        if len(pts) < 4: continue
        xs = np.array(pts)
        c = xs[:-1].mean(axis=0); cents.append(c)
        # area
        a = 0.5*abs(np.dot(xs[:-1,0], xs[1:,1]) - np.dot(xs[1:,0], xs[:-1,1])); areas.append(a)
        # longest edge angle
        best, ang = 0, 0
        for i in range(len(pts)-1):
            dx, dy = pts[i+1][0]-pts[i][0], pts[i+1][1]-pts[i][1]
            l = math.hypot(dx, dy)
            if l > best: best, ang = l, math.atan2(dy, dx)
        absang.append(math.degrees(ang) % 90)
        if len(S):
            ax_, ay_, bx, by = S[:,0], S[:,1], S[:,2], S[:,3]
            vx, vy = bx-ax_, by-ay_
            t = np.clip(((c[0]-ax_)*vx + (c[1]-ay_)*vy) / np.maximum(vx*vx+vy*vy, 1e-9), 0, 1)
            px, py = ax_+t*vx, ay_+t*vy
            dist = np.hypot(c[0]-px, c[1]-py); j = int(np.argmin(dist))
            setbacks.append(float(dist[j]))
            road_ang = math.atan2(vy[j], vx[j])
            diff = abs((math.degrees(ang - road_ang) + 90) % 180 - 90)  # 0..90
            rel.append(min(diff, 90 - diff))  # 0 = parallel or perpendicular to road
    cents = np.array(cents)
    nn = []
    if len(cents) > 2:
        for i, c in enumerate(cents):
            dd = np.hypot(*(cents - c).T); dd[i] = 1e9; nn.append(dd.min())
    rel = np.array(rel)
    res = {
        "village": name,
        "buildings": len(buildings),
        "roads": len(roads),
        "road_sinuosity_median": round(float(np.median(sinu)), 3) if sinu else None,
        "road_sinuosity_p90": round(float(np.percentile(sinu, 90)), 3) if sinu else None,
        "aligned_to_road_pct(<10deg)": round(float((rel < 10).mean()*100), 1) if len(rel) else None,
        "misaligned_pct(>20deg)": round(float((rel > 20).mean()*100), 1) if len(rel) else None,
        "setback_median_m": round(float(np.median(setbacks)), 1) if setbacks else None,
        "setback_p10_p90_m": [round(float(np.percentile(setbacks, 10)),1), round(float(np.percentile(setbacks, 90)),1)] if setbacks else None,
        "building_area_median_m2": round(float(np.median(areas)), 1),
        "nearest_neighbour_median_m": round(float(np.median(nn)), 1) if nn else None,
        "nearest_neighbour_cv": round(float(np.std(nn)/np.mean(nn)), 2) if nn else None,
        "amenities": collections.Counter(a for a, _ in amen).most_common(12),
    }
    if ax is not None:
        for pts in water:
            x, y = zip(*pts); ax.plot(x, y, color="#4a90d9", lw=2)
        for kind, pts in roads:
            x, y = zip(*pts)
            ax.plot(x, y, color="#b08850" if kind not in ("track","path","footway") else "#d8c8a8", lw=2.2 if kind in ("tertiary","secondary","primary") else 1.2)
        for pts in buildings:
            x, y = zip(*pts); ax.fill(x, y, color="#c0392b", lw=0)
        for a, (x, y) in amen:
            ax.plot(x, y, "o", color="#2c3e50", ms=3)
        ax.set_title(name); ax.set_aspect("equal"); ax.set_xlim(-900, 900); ax.set_ylim(-900, 900); ax.axis("off")
    return res

if __name__ == "__main__":
    specs = [l.split() for l in sys.argv[1:]]
    n = len(specs)
    fig, axes = plt.subplots(1, n, figsize=(6*n, 6))
    axes = np.atleast_1d(axes)
    out = []
    for (name, path, lat, lon), ax in zip(specs, axes):
        out.append(analyze(name, path, float(lat), float(lon), ax))
    plt.tight_layout(); plt.savefig("villages.png", dpi=110)
    for r in out:
        print(json.dumps(r, ensure_ascii=False))
