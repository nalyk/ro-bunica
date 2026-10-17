#!/usr/bin/env python3
"""Încarcă asset-uri (modele GLB/FBX, imagini PNG, audio OGG/MP3) prin Open Cloud și ține evidența lor.

  assets.py upload <cheie> <fișier> [--type Model|Image|Audio] [--name "..."]
  assets.py list

`assets.lock.json` (comis) leagă fiecare cheie de asset-ul încărcat și de hash-ul fișierului:
același fișier nu se reîncarcă (audio și imaginile nu se pot actualiza, fiecare încărcare e un asset nou,
iar audio are o limită lunară). Creatorul vine din ROBLOX_CREATOR_USER_ID (implicit: nalyque).

Audio încărcat aici e privat: jocul live nu-l poate reda („Failed to load sound: User is not authorized to access
Asset”) până nu primește permisiunea Use. În Studio se aude oricum, deci playtestul nu prinde lipsa ei. Pentru
fiecare audio nou: Creator Dashboard → asset → Permissions → Experiences → Add experiences → 1855994157 → Done
(cheia API nu are scope-ul asset-permissions:write). Verificare: POST
apis.roblox.com/asset-permissions-api/v1/assets/check-permissions (subject Universe 1855994157, action Use).
"""

import hashlib
import json
import os
import sys
import time
import uuid

import cloud

LOCK = os.path.join(cloud.ROOT, "assets.lock.json")
CREATOR = "1741390820"
TYPES = {".glb": ("Model", "model/gltf-binary"), ".fbx": ("Model", "model/fbx"), ".png": ("Image", "image/png"),
         ".ogg": ("Audio", "audio/ogg"), ".mp3": ("Audio", "audio/mpeg"), ".wav": ("Audio", "audio/wav")}


def load_lock() -> dict:
    if os.path.exists(LOCK):
        with open(LOCK, encoding="utf-8") as handle:
            return json.load(handle)
    return {}


def save_lock(lock: dict):
    with open(LOCK, "w", encoding="utf-8") as handle:
        json.dump(dict(sorted(lock.items())), handle, indent=2, ensure_ascii=False)
        handle.write("\n")


def sha(path: str) -> str:
    with open(path, "rb") as handle:
        return hashlib.sha256(handle.read()).hexdigest()[:16]


def upload(env: dict, key: str, path: str, asset_type: str | None = None, name: str | None = None) -> str:
    lock = load_lock()
    digest = sha(path)
    if key in lock and lock[key]["sha"] == digest:
        print(f"[assets] {key}: neschimbat, asset {lock[key]['id']}")
        return lock[key]["id"]
    ext = os.path.splitext(path)[1].lower()
    kind, mime = TYPES[ext]
    kind = asset_type or kind
    request = {"assetType": kind, "displayName": (name or f"BUNICA {key}")[:50], "description": "BUNICA",
               "creationContext": {"creator": {"userId": env.get("ROBLOX_CREATOR_USER_ID", CREATOR)}}}
    boundary = uuid.uuid4().hex
    with open(path, "rb") as handle:
        data = handle.read()
    body = (f"--{boundary}\r\nContent-Disposition: form-data; name=\"request\"\r\n\r\n{json.dumps(request)}\r\n"
            f"--{boundary}\r\nContent-Disposition: form-data; name=\"fileContent\"; filename=\"{os.path.basename(path)}\"\r\n"
            f"Content-Type: {mime}\r\n\r\n").encode() + data + f"\r\n--{boundary}--\r\n".encode()
    op = cloud.request(env, "POST", f"{cloud.API}/assets/v1/assets", body, f"multipart/form-data; boundary={boundary}")
    for _ in range(120):
        state = cloud.request(env, "GET", f"{cloud.API}/assets/v1/{op['path']}")
        if state.get("done"):
            break
        time.sleep(3)
    else:
        sys.exit(f"[assets] {key}: operația nu s-a terminat ({op['path']})")
    response = state.get("response") or {}
    asset_id = response.get("assetId")
    moderation = (response.get("moderationResult") or {}).get("moderationState")
    if not asset_id:
        sys.exit(f"[assets] {key}: eșec {json.dumps(state)[:400]}")
    lock[key] = {"id": asset_id, "type": kind, "sha": digest, "file": os.path.relpath(path, cloud.ROOT),
                 "moderation": moderation}
    save_lock(lock)
    print(f"[assets] {key}: asset {asset_id} ({kind}, moderare: {moderation})")
    return asset_id


def main() -> int:
    if len(sys.argv) >= 4 and sys.argv[1] == "upload":
        args = sys.argv[2:]
        kind = args[args.index("--type") + 1] if "--type" in args else None
        name = args[args.index("--name") + 1] if "--name" in args else None
        upload(cloud.load_env(), args[0], args[1], kind, name)
        return 0
    if len(sys.argv) == 2 and sys.argv[1] == "list":
        for key, entry in load_lock().items():
            print(f"{key:30} {entry['id']:>18} {entry['type']:6} {entry.get('moderation')}")
        return 0
    print(__doc__)
    return 2


if __name__ == "__main__":
    sys.exit(main())
