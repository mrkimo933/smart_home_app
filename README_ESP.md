# ESP MQTT Smart Home Integration

This document outlines how to integrate the ESP-based hardware with the Smart Home Energy Monitor app.

## MQTT Setup

1. **Broker**: Install an MQTT Broker (e.g., Mosquitto) on your Raspberry Pi or local server.
2. **IP Address**: Note down the IP address of the broker. Enter this in the app settings.
3. **Port**: Default port is `1883` for mobile and `8080` for web (WebSockets).

## Topics and Payload Formats

### Sensors (ESP → App)
- `esp/sensor/voltage`: Double (e.g., `220.5`)
- `esp/sensor/current`: Double (e.g., `0.45`)
- `esp/sensor/power`: Double (e.g., `100.2`)
- `esp/sensor/kwh`: Double (e.g., `12.34`)

### Relays (App ↔ ESP)
- `esp/relay/X/state`: `ON` or `OFF` (ESP publishes status here)
- `esp/relay/X/set`: `ON` or `OFF` (App publishes commands here)

*Replace `X` with the relay ID (1-4).*

## Testing with Mosquitto CLI

### Simulate Sensor Data
```bash
mosquitto_pub -h <broker_ip> -t esp/sensor/power -m "150.5"
```

### Toggle Relay Status
```bash
mosquitto_pub -h <broker_ip> -t esp/relay/1/state -m "ON"
```

### Monitor Commands
```bash
mosquitto_sub -h <broker_ip> -t esp/relay/+/set
```
