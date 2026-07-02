#!/usr/bin/env python3
"""Minimal DNS forwarder for Termux: listens on [::1]:5353, forwards to 8.8.8.8."""
import socket, sys, select

UPSTREAM_V4 = ("8.8.8.8", 53)
LISTEN_ADDR = ("::1", 5353)

sock = socket.socket(socket.AF_INET6, socket.SOCK_DGRAM)
sock.setsockopt(socket.SOL_SOCKET, socket.SO_REUSEADDR, 1)
sock.bind(LISTEN_ADDR)
sock.setblocking(False)

print(f"DNS forwarder listening on [{LISTEN_ADDR[0]}]:{LISTEN_ADDR[1]}, forwarding to 8.8.8.8", flush=True)

while True:
    try:
        rlist, _, _ = select.select([sock], [], [], 1.0)
        for s in rlist:
            data, client_addr = s.recvfrom(4096)
            try:
                upstream = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
                upstream.settimeout(5)
                upstream.sendto(data, UPSTREAM_V4)
                response, _ = upstream.recvfrom(4096)
                upstream.close()
                s.sendto(response, client_addr)
            except Exception as e:
                print(f"Forward failed: {e}", file=sys.stderr, flush=True)
    except Exception as e:
        print(f"Error: {e}", file=sys.stderr, flush=True)
