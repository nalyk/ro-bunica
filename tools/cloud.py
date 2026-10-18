#!/usr/bin/env python3
"""Teste e2e în motorul Roblox real, prin Open Cloud.

Comenzi:
  cloud.py publish <fișier.rbxl>      publică o versiune „Saved” (versiunea live nu se schimbă)
  cloud.py publish-live <fișier.rbxl> publică versiunea live, cea care se joacă din link (locul e privat)
  cloud.py run <versiune> <script.luau> rulează un script Luau pe acea versiune, afișează log-urile
  cloud.py e2e                         build test.project.json + publish + rulează tests/e2e

Configurare în `.env.cloud` (ignorat de git):
  ROBLOX_API_KEY=...        drepturi: universe-places (write), luau-execution-sessions (read, write)
  ROBLOX_UNIVERSE_ID=...
  ROBLOX_PLACE_ID=...
"""

import json
import os
import subprocess
import sys
import time
import urllib.error
import urllib.request

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
API = "https://apis.roblox.com"
POLL_SECONDS = 3
TASK_TIMEOUT = "280s"


def load_env() -> dict:
    path = os.path.join(ROOT, ".env.cloud")
    if not os.path.exists(path):
        sys.exit(f"Lipsește {path} (vezi docstring-ul din tools/cloud.py)")
    env = {}
    with open(path, encoding="utf-8") as handle:
        for line in handle:
            line = line.strip()
            if line and not line.startswith("#") and "=" in line:
                key, value = line.split("=", 1)
                env[key.strip()] = value.strip()
    for key in ("ROBLOX_API_KEY", "ROBLOX_UNIVERSE_ID", "ROBLOX_PLACE_ID"):
        if not env.get(key):
            sys.exit(f"Lipsește {key} în .env.cloud")
    return env


def request(env: dict, method: str, url: str, body: bytes | None = None, content_type: str | None = None):
    req = urllib.request.Request(url, data=body, method=method)
    req.add_header("x-api-key", env["ROBLOX_API_KEY"])
    if content_type:
        req.add_header("Content-Type", content_type)
    for attempt in range(8):
        try:
            with urllib.request.urlopen(req, timeout=120) as response:
                return json.loads(response.read() or b"{}")
        except urllib.error.HTTPError as error:
            detail = error.read().decode("utf-8", "replace")
            if error.code in (429, 502, 503) and attempt < 7:
                time.sleep(5 * (attempt + 1))  # limita de cereri: așteaptă și reîncearcă
                req = urllib.request.Request(url, data=body, method=method)
                req.add_header("x-api-key", env["ROBLOX_API_KEY"])
                if content_type:
                    req.add_header("Content-Type", content_type)
                continue
            sys.exit(f"HTTP {error.code} la {method} {url}\n{detail}")


def publish(env: dict, place_file: str, version_type: str = "Saved") -> int:
    with open(place_file, "rb") as handle:
        data = handle.read()
    url = (
        f"{API}/universes/v1/{env['ROBLOX_UNIVERSE_ID']}/places/{env['ROBLOX_PLACE_ID']}"
        f"/versions?versionType={version_type}"
    )
    result = request(env, "POST", url, data, "application/octet-stream")
    version = int(result["versionNumber"])
    print(f"[cloud] publicat {os.path.basename(place_file)} ca versiunea {version} ({version_type})")
    return version


def run(env: dict, version: int, script: str) -> dict:
    url = (
        f"{API}/cloud/v2/universes/{env['ROBLOX_UNIVERSE_ID']}/places/{env['ROBLOX_PLACE_ID']}"
        f"/versions/{version}/luau-execution-session-tasks"
    )
    task = request(env, "POST", url, json.dumps({"script": script, "timeout": TASK_TIMEOUT}).encode(), "application/json")
    path = task["path"]
    print(f"[cloud] sarcină creată: {path}")
    while task.get("state") in (None, "STATE_UNSPECIFIED", "QUEUED", "PROCESSING"):
        time.sleep(POLL_SECONDS)
        task = request(env, "GET", f"{API}/cloud/v2/{path}")
    logs = request(env, "GET", f"{API}/cloud/v2/{path}/logs")
    for chunk in logs.get("luauExecutionSessionTaskLogs", []):
        for message in chunk.get("messages", []):
            print(message)
    print(f"[cloud] stare: {task.get('state')}")
    if task.get("error"):
        print(f"[cloud] eroare: {json.dumps(task['error'], ensure_ascii=False)}")
    return task


def build_test_place() -> str:
    out = os.path.join(ROOT, "build", "bunica-test.rbxl")
    os.makedirs(os.path.dirname(out), exist_ok=True)
    rojo = os.path.expanduser("~/.rokit/bin/rojo")
    subprocess.run([rojo, "build", "test.project.json", "-o", out], cwd=ROOT, check=True)
    return out


E2E_SHARD = 3  # spec-uri pe sarcină: o sarcină Open Cloud are cel mult 5 minute
E2E_PARALLEL = 3


def e2e_specs() -> list:
    folder = os.path.join(ROOT, "tests", "e2e")
    names = [f[: -len(".luau")] for f in os.listdir(folder) if f.endswith(".spec.luau")]
    return sorted(names)


def e2e(env: dict) -> int:
    from concurrent.futures import ThreadPoolExecutor

    version = publish(env, build_test_place())
    specs = e2e_specs()
    shards = [specs[i : i + E2E_SHARD] for i in range(0, len(specs), E2E_SHARD)]

    def one(shard: list) -> tuple:
        names = ", ".join(json.dumps(name) for name in shard)
        script = f"return require(game:GetService('ServerStorage').E2E.Runner)({{ {names} }})"
        return shard, run(env, version, script)

    passed, failed, failures = 0, 0, []
    with ThreadPoolExecutor(max_workers=E2E_PARALLEL) as pool:
        for shard, task in pool.map(one, shards):
            if task.get("state") != "COMPLETE":
                failed += 1
                failures.append(f"lotul {shard}: {task.get('state')} {json.dumps(task.get('error'), ensure_ascii=False)}")
                continue
            results = (task.get("output") or {}).get("results") or [{}]
            summary = results[0] if results else {}
            passed += int(summary.get("passed", 0))
            failed += int(summary.get("failed", 1))
            failures += summary.get("failures", [])
    print(f"[cloud] e2e: {passed} trecute, {failed} picate ({len(shards)} loturi)")
    for failure in failures:
        print(f"  ✗ {failure}")
    return 0 if failed == 0 else 1


def main() -> int:
    if len(sys.argv) < 2:
        print(__doc__)
        return 2
    env = load_env()
    command = sys.argv[1]
    if command == "publish" and len(sys.argv) == 3:
        publish(env, sys.argv[2])
        return
    if command == "publish-live" and len(sys.argv) == 3:
        publish(env, sys.argv[2], "Published")
        # serverele deja pornite rulează versiunea veche: le repornim (cheia are `universe:write`)
        url = f"{API}/cloud/v2/universes/{env['ROBLOX_UNIVERSE_ID']}:restartServers"
        request(env, "POST", url, b"{}", "application/json")
        print("[cloud] serverele live au fost repornite pe versiunea nouă")
        print(f"[cloud] link: https://www.roblox.com/games/{env['ROBLOX_PLACE_ID']}")
        return 0
    if command == "run" and len(sys.argv) == 4:
        with open(sys.argv[3], encoding="utf-8") as handle:
            task = run(env, int(sys.argv[2]), handle.read())
        print(json.dumps(task.get("output"), ensure_ascii=False, indent=2))
        return 0 if task.get("state") == "COMPLETE" else 1
    if command == "e2e":
        return e2e(env)
    print(__doc__)
    return 2


if __name__ == "__main__":
    sys.exit(main())
