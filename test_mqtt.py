import urllib.request, json, asyncio
import websockets

async def test_ws():
    try:
        async with websockets.connect("ws://broker.emqx.io:8083/mqtt", subprotocols=['mqtt']) as websocket:
            print("Successfully connected to ws://broker.emqx.io:8083/mqtt")
    except Exception as e:
        print(f"Failed: {e}")

asyncio.run(test_ws())
