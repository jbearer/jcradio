#!/usr/bin/env python3
"""Time page loads against the live site, including every local /assets/ file the page
references (dev-mode Sprockets serves each file separately, so this shows the fan-out).

Usage: python3 script/perf/page-timings.py https://host:3000 [/path ...] [--runs=N] [--no-assets]
Anonymous GETs only; never logs in or mutates anything.
"""
import http.client
import re
import ssl
import sys
import time
from urllib.parse import urlsplit

args = sys.argv[1:]
base = next((a for a in args if a.startswith("http")), None)
if not base:
    sys.exit("base URL required")
runs = int(next((a for a in args if a.startswith("--runs=")), "--runs=3").split("=")[1])
with_assets = "--no-assets" not in args
paths = [a for a in args if not a.startswith(("http", "--"))] or ["/sessions", "/stations/1", "/songs"]

u = urlsplit(base)
ctx = ssl._create_unverified_context()  # LAN IP does not match the cert name
def connect():
    if u.scheme == "https":
        return http.client.HTTPSConnection(u.hostname, u.port or 443, context=ctx, timeout=60)
    return http.client.HTTPConnection(u.hostname, u.port or 80, timeout=60)

conn = connect()

def fetch(path):
    global conn
    t0 = time.monotonic()
    try:
        conn.request("GET", path)
        res = conn.getresponse()
        body = res.read()
    except (http.client.HTTPException, OSError):
        conn.close()
        conn = connect()
        conn.request("GET", path)
        res = conn.getresponse()
        body = res.read()
    return res, body, round((time.monotonic() - t0) * 1000)

for path in paths:
    totals, asset_totals, slow = [], [], {}
    asset_count = asset_bytes = html_bytes = 0
    for i in range(runs):
        res, body, ms = fetch(path)
        totals.append(ms)
        html_bytes = len(body)
        if res.status != 200:
            print(f"{path}: HTTP {res.status}")
        if not with_assets:
            continue
        assets = sorted(set(re.findall(rb'(?:src|href)="(/assets/[^"]+)"', body)))
        asset_count = len(assets)
        t_assets = 0
        for a in assets:
            a = a.decode()
            ares, abody, ams = fetch(a)
            t_assets += ams
            if i == 0:
                asset_bytes += len(abody)
            slow[a] = max(slow.get(a, 0), ams)
        asset_totals.append(t_assets)
    print(f"{path}: html {html_bytes} B; page ms {totals}")
    if with_assets:
        print(f"  assets: {asset_count} requests, {asset_bytes // 1024} KiB, serial ms {asset_totals}")
        for a, v in sorted(slow.items(), key=lambda kv: -kv[1])[:6]:
            print(f"    {v:5d} ms  {a}")
