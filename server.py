#!/usr/bin/env python3
import http.server
import socketserver
import os

PORT = 5060
DIRECTORY = "/home/user/flutter_app/build/web"

os.chdir(DIRECTORY)

class ReuseAddrTCPServer(socketserver.TCPServer):
    allow_reuse_address = True

class CORSRequestHandler(http.server.SimpleHTTPRequestHandler):
    def end_headers(self):
        self.send_header('Access-Control-Allow-Origin', '*')
        self.send_header('X-Frame-Options', 'ALLOWALL')
        self.send_header('Content-Security-Policy', 'frame-ancestors *')
        super().end_headers()

with ReuseAddrTCPServer(("0.0.0.0", PORT), CORSRequestHandler) as httpd:
    print(f"Serving on port {PORT}")
    httpd.serve_forever()
