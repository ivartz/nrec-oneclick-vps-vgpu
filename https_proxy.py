#!/usr/bin/env python3
"""Minimal HTTPS proxy for terraform on Android/Termux.
Forwards HTTPS connections, resolving DNS via Python socket (which works on Termux).
"""
import socket, ssl, sys, select, threading, http.server, socketserver

PORT = 9080
BUFFER_SIZE = 65536

class ProxyHandler(http.server.BaseHTTPRequestHandler):
    def do_CONNECT(self):
        host, _, port_str = self.path.partition(":")
        port = int(port_str) if port_str else 443
        
        try:
            client = self.connection
            client.settimeout(None)
            
            # Resolve and connect
            addrinfo = socket.getaddrinfo(host, port, socket.AF_UNSPEC, socket.SOCK_STREAM)
            family, socktype, proto, canonname, sockaddr = addrinfo[0]
            
            backend = socket.socket(family, socktype, proto)
            backend.settimeout(10)
            backend.connect(sockaddr)
            backend.settimeout(None)
            
            # Send OK
            self.wfile.write(b"HTTP/1.1 200 Connection Established\r\n\r\n")
            self.wfile.flush()
            
            # Relay data both ways
            def forward(src, dst):
                try:
                    while True:
                        data = src.recv(BUFFER_SIZE)
                        if not data:
                            break
                        dst.sendall(data)
                except Exception:
                    pass
                finally:
                    try:
                        src.close()
                        dst.close()
                    except:
                        pass
            
            t1 = threading.Thread(target=forward, args=(client, backend), daemon=True)
            t2 = threading.Thread(target=forward, args=(backend, client), daemon=True)
            t1.start()
            t2.start()
            t1.join()
            t2.join()
            
        except Exception as e:
            try:
                self.wfile.write(f"HTTP/1.1 502 {e}\r\n\r\n".encode())
            except:
                pass
    
    def log_message(self, format, *args):
        pass  # Suppress logs

if __name__ == "__main__":
    server = socketserver.ThreadingTCPServer(("127.0.0.1", PORT), ProxyHandler)
    print(f"Proxy listening on 127.0.0.1:{PORT}", flush=True)
    server.serve_forever()
