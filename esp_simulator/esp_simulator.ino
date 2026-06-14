#include <WiFi.h>
#include <WebServer.h>

// ===== WiFi Settings =====
const char* ssid = "Kareem";
const char* password = "KIMO1#mrkimo2###3444330";

WebServer server(80);

// ===== Relay Pins =====
int relayPins[8] = {26, 27, 14, 12, 13, 25, 33, 32};

// ===== Relay States =====
bool relayStates[8] = {
  false, false, false, false,
  false, false, false, false
};

// ===== متغير الماس الكهربي =====
// -1 معناها إن مفيش ماس كهربي والدنيا تمام
int shortedRelayIndex = -1; 

// ===== قراءات افتراضية =====
struct DeviceReadings {
  String name;
  float current;
  float wattage;
};

DeviceReadings devices[8] = {
  {"Lamp",    0.27,  120.0},
  {"AC",      6.82,  1500.0},
  {"TV",      0.68,  150.0},
  {"Fan",     0.34,  75.0},
  {"Fridge",  0.91,  200.0},
  {"Washer",  2.27,  500.0},
  {"PC",      1.36,  300.0},
  {"Heater",  9.09,  2000.0},
};

// ===== حساب القراءات مع محاكاة الواقعية والماس الكهربي =====
float getTotalCurrent() {
  float total = 0;
  for (int i = 0; i < 8; i++) {
    if (relayStates[i]) {
      if (i == shortedRelayIndex) {
        total += 75.0; // رقم ضخم جداً يمثل الشورت سيركت
      } else {
        // إضافة نسبة تذبذب عشوائية بين -5% و +5% لمحاكاة الواقع
        float fluctuation = random(-5, 6) / 100.0; 
        total += devices[i].current * (1.0 + fluctuation);
      }
    }
  }
  return total;
}

float getTotalPower() {
  float total = 0;
  for (int i = 0; i < 8; i++) {
    if (relayStates[i]) {
      if (i == shortedRelayIndex) {
        total += (75.0 * 220.0); // سحب طاقة وهمي وقت القفلة
      } else {
        // إضافة نسبة تذبذب عشوائية بين -5% و +5% لمحاكاة الواقع
        float fluctuation = random(-5, 6) / 100.0;
        total += devices[i].wattage * (1.0 + fluctuation);
      }
    }
  }
  return total;
}

// ===== CORS Headers =====
void addCorsHeaders() {
  server.sendHeader("Access-Control-Allow-Origin", "*");
  server.sendHeader("Access-Control-Allow-Methods", "GET, POST, OPTIONS");
  server.sendHeader("Access-Control-Allow-Headers", "Content-Type");
}

// ===== صفحة الويب =====
void handleRoot() {
  addCorsHeaders();
  String html = "<!DOCTYPE HTML><html><head>";
  html += "<meta charset='UTF-8'>"; // لتصليح الـ Emojis
  html += "<title>SHEMS Dashboard</title>";
  html += "<meta name='viewport' content='width=device-width, initial-scale=1'>";
  html += "<style>";
  html += "body{font-family:'Segoe UI',sans-serif;background:#0A0E21;color:#fff;text-align:center;margin:0;padding:20px;}";
  html += "h1{color:#00B4D8;font-weight:300;letter-spacing:2px;}";
  html += ".grid{display:grid;grid-template-columns:repeat(auto-fit,minmax(140px,1fr));gap:15px;max-width:800px;margin:auto;}";
  html += ".card{background:#1D1E33;padding:20px;border-radius:12px;border:1px solid #333; position:relative;}";
  html += ".name{display:block;font-size:16px;color:#aaa;margin-bottom:15px;font-weight:bold;}";
  html += ".btn{width:100%;padding:12px;border-radius:8px;border:none;cursor:pointer;font-weight:bold;font-size:16px; margin-top:5px;}";
  html += ".on{background:#00B4D8;color:#121212;}";
  html += ".off{background:#333;color:#888;}";
  html += ".danger{background:#FF4B4B;color:#fff;font-size:14px;}";
  html += ".safe{background:#00F5A0;color:#121212;max-width:300px;margin:20px auto;display:block;}";
  html += ".stats{margin-top:40px;background:#1D1E33;padding:25px;border-radius:12px;display:inline-block;min-width:300px;border:1px solid #333;}";
  html += ".val{color:#00B4D8;font-weight:bold;font-size:22px;}";
  html += ".alert{color:#FF4B4B;font-weight:bold; animation: blink 1s infinite;}";
  html += "@keyframes blink { 50% { opacity: 0; } }";
  html += "</style></head><body>";
  html += "<h1>SHEMS DASHBOARD</h1>";
  
  if (shortedRelayIndex != -1 && relayStates[shortedRelayIndex]) {
    html += "<h2 class='alert'>⚠️ WARNING: SHORT CIRCUIT DETECTED! ⚠️</h2>";
  }

  html += "<div class='grid'>";
  for(int i=0; i<8; i++) {
    html += "<div class='card'><span class='name'>" + devices[i].name + "</span>";
    
    // زرار التشغيل والإيقاف العادي
    html += "<button class='btn " + String(relayStates[i] ? "on" : "off") + "' onclick='toggle(" + String(i) + ")'>";
    html += relayStates[i] ? "ON" : "OFF";
    html += "</button>";

    // زرار محاكاة الماس الكهربي
    if (shortedRelayIndex == i) {
       html += "<button class='btn danger' disabled>🔥 Shorted!</button>";
    } else {
       html += "<button class='btn off danger' onclick='triggerShort(" + String(i) + ")' style='background:transparent; border:1px solid #FF4B4B; color:#FF4B4B;'>⚡ Sim Short</button>";
    }
    html += "</div>";
  }
  html += "</div>";

  // زرار تصليح النظام
  html += "<button class='btn safe' onclick='triggerShort(-1)'>✅ Fix All (Reset)</button>";

  html += "<div class='stats'>";
  html += "<p>Total Power: <span class='val' " + String((shortedRelayIndex != -1 && relayStates[shortedRelayIndex]) ? "style='color:#FF4B4B;'" : "") + ">" + String(getTotalPower(), 1) + " W</span></p>";
  html += "<p>Total Current: <span class='val' " + String((shortedRelayIndex != -1 && relayStates[shortedRelayIndex]) ? "style='color:#FF4B4B;'" : "") + ">" + String(getTotalCurrent(), 2) + " A</span></p>";
  html += "</div>";
  
  html += "<script>";
  html += "function toggle(id){fetch('/toggle?id='+id).then(()=>location.reload());}";
  html += "function triggerShort(id){fetch('/short?id='+id).then(()=>location.reload());}";
  html += "setInterval(()=>location.reload(),3000);"; // تحديث الشاشة كل 3 ثواني هيبين التذبذب
  html += "</script></body></html>";
  
  server.send(200, "text/html", html);
}

// ===== Toggle Relay =====
void handleToggle() {
  addCorsHeaders();
  if (server.hasArg("id")) {
    int id = server.arg("id").toInt();
    if(id >= 0 && id < 8) {
      relayStates[id] = !relayStates[id];
      digitalWrite(relayPins[id], relayStates[id] ? LOW : HIGH);
      Serial.println(devices[id].name + " → " + (relayStates[id] ? "ON" : "OFF"));
    }
  }
  server.send(200, "text/plain", "OK");
}

// ===== محاكاة الماس الكهربي (Endpoint) =====
void handleShortCircuit() {
  addCorsHeaders();
  if (server.hasArg("id")) {
    int id = server.arg("id").toInt();
    if (id >= -1 && id < 8) {
      shortedRelayIndex = id;
      if (id != -1) {
        Serial.println("🔥 SHORT CIRCUIT TRIGGERED ON: " + devices[id].name);
      } else {
        Serial.println("✅ SYSTEM NORMALIZED");
      }
    }
  }
  server.send(200, "text/plain", "Short state updated");
}

// ===== API Data =====
void handleApiData() {
  addCorsHeaders();
  String json = "{";
  json += "\"voltage\": 220.0,";
  json += "\"totalPower\": " + String(getTotalPower(), 1) + ",";
  json += "\"totalCurrent\": " + String(getTotalCurrent(), 2) + ",";
  json += "\"relays\": [";
  for(int i=0; i<8; i++) {
    json += (relayStates[i] ? "true" : "false");
    if(i < 7) json += ",";
  }
  json += "]}";
  server.send(200, "application/json", json);
}

// ===== OPTIONS Handler =====
void handleOptions() {
  addCorsHeaders();
  server.send(204);
}

void setup() {
  Serial.begin(115200);
  delay(3000);
  Serial.println("\n--- SHEMS ESP32 Started ---");

  // تهيئة دالة العشوائية عشان التذبذب يتغير كل مرة
  randomSeed(analogRead(0));

  for (int i = 0; i < 8; i++) {
    pinMode(relayPins[i], OUTPUT);
    digitalWrite(relayPins[i], HIGH);
  }

  Serial.print("Connecting to WiFi");
  WiFi.begin(ssid, password);
  while (WiFi.status() != WL_CONNECTED) {
    delay(500);
    Serial.print(".");
  }

  Serial.println("\nWiFi Connected!");
  Serial.print("IP: ");
  Serial.println(WiFi.localIP());

  server.on("/", handleRoot);
  server.on("/toggle", handleToggle);
  server.on("/short", handleShortCircuit); 
  server.on("/api/data", handleApiData);
  
  server.on("/toggle", HTTP_OPTIONS, handleOptions);
  server.on("/short", HTTP_OPTIONS, handleOptions);
  server.on("/api/data", HTTP_OPTIONS, handleOptions);

  server.begin();
  Serial.println("SHEMS Server is ON!");
}

void loop() {
  server.handleClient();
  delay(10);
}
