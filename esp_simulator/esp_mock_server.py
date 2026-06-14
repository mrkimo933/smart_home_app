#!/usr/bin/env python3
# esp_simulator/esp_mock_server.py

import sys
import random
import socket
import json
from http.server import HTTPServer, BaseHTTPRequestHandler
from urllib.parse import urlparse, parse_qs

# Global state
relay_states = [False] * 8
shorted_relay_index = -1

devices = [
    {"name": "Lamp",    "current": 0.27,  "wattage": 120.0},
    {"name": "AC",      "current": 6.82,  "wattage": 1500.0},
    {"name": "TV",      "current": 0.68,  "wattage": 150.0},
    {"name": "Fan",     "current": 0.34,  "wattage": 75.0},
    {"name": "Fridge",  "current": 0.91,  "wattage": 200.0},
    {"name": "Washer",  "current": 2.27,  "wattage": 500.0},
    {"name": "PC",      "current": 1.36,  "wattage": 300.0},
    {"name": "Heater",  "current": 9.09,  "wattage": 2000.0},
]

def get_total_current():
    total = 0.0
    for i in range(8):
        if relay_states[i]:
            if i == shorted_relay_index:
                total += 75.0
            else:
                # Add random fluctuation between -5% and +5%
                fluctuation = random.randint(-5, 5) / 100.0
                total += devices[i]["current"] * (1.0 + fluctuation)
    return total

def get_total_power():
    total = 0.0
    for i in range(8):
        if relay_states[i]:
            if i == shorted_relay_index:
                total += (75.0 * 220.0)
            else:
                # Add random fluctuation between -5% and +5%
                fluctuation = random.randint(-5, 5) / 100.0
                total += devices[i]["wattage"] * (1.0 + fluctuation)
    return total

class EspMockHandler(BaseHTTPRequestHandler):
    def end_headers(self):
        self.send_header("Access-Control-Allow-Origin", "*")
        self.send_header("Access-Control-Allow-Methods", "GET, POST, OPTIONS")
        self.send_header("Access-Control-Allow-Headers", "Content-Type")
        super().end_headers()

    def do_OPTIONS(self):
        self.send_response(204)
        self.end_headers()

    def do_GET(self):
        global relay_states, shorted_relay_index
        parsed_url = urlparse(self.path)
        path = parsed_url.path
        query = parse_qs(parsed_url.query)

        if path == "/":
            self.send_response(200)
            self.send_header("Content-Type", "text/html; charset=utf-8")
            self.end_headers()
            
            # HTML Dashboard
            is_warning = shorted_relay_index != -1 and relay_states[shorted_relay_index]
            warning_html = "<h2 class='alert'>⚠️ WARNING: SHORT CIRCUIT DETECTED! ⚠️</h2>" if is_warning else ""
            
            grid_html = ""
            for i in range(8):
                btn_class = "on" if relay_states[i] else "off"
                btn_text = "ON" if relay_states[i] else "OFF"
                
                short_btn = ""
                if shorted_relay_index == i:
                    short_btn = "<button class='btn danger' disabled>🔥 Shorted!</button>"
                else:
                    short_btn = f"<button class='btn off danger' onclick='triggerShort({i})' style='background:transparent; border:1px solid #FF4B4B; color:#FF4B4B;'>⚡ Sim Short</button>"
                
                grid_html += f"""
                <div class='card'>
                    <span class='name'>{devices[i]['name']}</span>
                    <button class='btn {btn_class}' onclick='toggle({i})'>{btn_text}</button>
                    {short_btn}
                </div>
                """

            stats_power_style = "style='color:#FF4B4B;'" if is_warning else ""
            stats_current_style = "style='color:#FF4B4B;'" if is_warning else ""

            html = f"""<!DOCTYPE HTML><html><head>
<meta charset='UTF-8'>
<title>SHEMS Dashboard</title>
<meta name='viewport' content='width=device-width, initial-scale=1'>
<style>
body{{font-family:'Segoe UI',sans-serif;background:#0A0E21;color:#fff;text-align:center;margin:0;padding:20px;}}
h1{{color:#00B4D8;font-weight:300;letter-spacing:2px;}}
.grid{{display:grid;grid-template-columns:repeat(auto-fit,minmax(140px,1fr));gap:15px;max-width:800px;margin:auto;}}
.card{{background:#1D1E33;padding:20px;border-radius:12px;border:1px solid #333; position:relative;}}
.name{{display:block;font-size:16px;color:#aaa;margin-bottom:15px;font-weight:bold;}}
.btn{{width:100%;padding:12px;border-radius:8px;border:none;cursor:pointer;font-weight:bold;font-size:16px; margin-top:5px;}}
.on{{background:#00B4D8;color:#121212;}}
.off{{background:#333;color:#888;}}
.danger{{background:#FF4B4B;color:#fff;font-size:14px;}}
.safe{{background:#00F5A0;color:#121212;max-width:300px;margin:20px auto;display:block;}}
.stats{{margin-top:40px;background:#1D1E33;padding:25px;border-radius:12px;display:inline-block;min-width:300px;border:1px solid #333;}}
.val{{color:#00B4D8;font-weight:bold;font-size:22px;}}
.alert{{color:#FF4B4B;font-weight:bold; animation: blink 1s infinite;}}
@keyframes blink {{ 50% {{ opacity: 0; }} }}
</style></head><body>
<h1>SHEMS DASHBOARD (MOCK)</h1>
{warning_html}
<div class='grid'>
{grid_html}
</div>
<button class='btn safe' onclick='triggerShort(-1)'>✅ Fix All (Reset)</button>
<div class='stats'>
<p>Total Power: <span class='val' {stats_power_style}>{get_total_power():.1f} W</span></p>
<p>Total Current: <span class='val' {stats_current_style}>{get_total_current():.2f} A</span></p>
</div>
<script>
function toggle(id){{fetch('/toggle?id='+id).then(()=>location.reload());}}
function triggerShort(id){{fetch('/short?id='+id).then(()=>location.reload());}}
setInterval(()=>location.reload(),3000);
</script></body></html>"""
            self.wfile.write(html.encode("utf-8"))

        elif path == "/toggle":
            self.send_response(200)
            self.send_header("Content-Type", "text/plain")
            self.end_headers()
            
            relay_id = query.get("id")
            if relay_id:
                try:
                    idx = int(relay_id[0])
                    if 0 <= idx < 8:
                        relay_states[idx] = not relay_states[idx]
                        print(f"Relay toggle: {devices[idx]['name']} -> {'ON' if relay_states[idx] else 'OFF'}")
                except ValueError:
                    pass
            self.wfile.write(b"OK")

        elif path == "/short":
            self.send_response(200)
            self.send_header("Content-Type", "text/plain")
            self.end_headers()
            
            short_id = query.get("id")
            if short_id:
                try:
                    idx = int(short_id[0])
                    if -1 <= idx < 8:
                        shorted_relay_index = idx
                        if idx != -1:
                            print(f"🔥 SHORT CIRCUIT TRIGGERED ON: {devices[idx]['name']}")
                        else:
                            print("✅ SYSTEM NORMALIZED")
                except ValueError:
                    pass
            self.wfile.write(b"Short state updated")

        elif path == "/api/data":
            self.send_response(200)
            self.send_header("Content-Type", "application/json")
            self.end_headers()
            
            data = {
                "voltage": 220.0,
                "totalPower": round(get_total_power(), 1),
                "totalCurrent": round(get_total_current(), 2),
                "relays": relay_states
            }
            self.wfile.write(json.dumps(data).encode("utf-8"))
        else:
            self.send_response(404)
            self.end_headers()
            self.wfile.write(b"Not Found")

def get_local_ip():
    s = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
    try:
        s.connect(('10.255.255.255', 1))
        IP = s.getsockname()[0]
    except Exception:
        IP = '127.0.0.1'
    finally:
        s.close()
    return IP

def run():
    port = 8080
    if len(sys.argv) > 1:
        try:
            port = int(sys.argv[1])
        except ValueError:
            pass
            
    local_ip = get_local_ip()
    server_address = ('', port)
    httpd = HTTPServer(server_address, EspMockHandler)
    print(f"\n--- SHEMS ESP32 Mock Server Started ---")
    print(f"Dashboard: http://localhost:{port}/")
    print(f"Local IP for mobile devices: http://{local_ip}:{port}/")
    print(f"API Endpoint: http://localhost:{port}/api/data\n")
    try:
        httpd.serve_forever()
    except KeyboardInterrupt:
        print("\nStopping ESP32 Mock Server...")
        sys.exit(0)

if __name__ == '__main__':
    run()
