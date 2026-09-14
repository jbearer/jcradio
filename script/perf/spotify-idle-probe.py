#!/usr/bin/env python3
"""Probe how long api.spotify.com keeps an idle HTTPS connection open, from this host.
For each idle interval, open one connection, make a request, sleep, then reuse the socket.
Usage: python3 script/perf/spotify-idle-probe.py 5 30 60 120
Unauthenticated GETs (401s) only; no token involved.
"""
import http.client
import select
import sys
import time

HOST = "api.spotify.com"

def request(conn):
    t0 = time.monotonic()
    conn.request("GET", "/v1/me/player", headers={"Connection": "keep-alive"})
    res = conn.getresponse()
    res.read()
    return res.status, res.getheader("Connection"), round((time.monotonic() - t0) * 1000)

for idle in [int(a) for a in sys.argv[1:]] or [5, 30, 60]:
    conn = http.client.HTTPSConnection(HOST, 443, timeout=20)
    status, conn_hdr, ms = request(conn)
    print("idle={:4d}s  first: {} in {} ms (Connection: {})".format(idle, status, ms, conn_hdr), flush=True)
    time.sleep(idle)
    sock = conn.sock
    fin = False
    if sock is not None:
        r, _, _ = select.select([sock], [], [], 0)
        if r:
            try:
                fin = sock.recv(1, 0x40) == b""  # MSG_PEEK: readable with no data => server FIN
            except OSError:
                fin = True
    try:
        status, conn_hdr, ms = request(conn)
        print("            reuse: {} in {} ms, server FIN seen before send: {}".format(status, ms, fin), flush=True)
    except Exception as e:  # noqa: BLE001 - report whatever the stale socket raises
        print("            reuse FAILED: {}: {}; server FIN seen: {}".format(type(e).__name__, e, fin), flush=True)
    conn.close()
