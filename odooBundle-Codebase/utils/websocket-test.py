#! /usr/bin/env python3
# -*- coding: utf-8 -*-
# vim:fenc=utf-8
#
# Copyleft (ɔ) 2024 wildfootw <wildfootw@wildfoo.tw>
#
# Distributed under the same license as odooBundle-Codebase.

import websocket
import ssl

def on_message(ws, message):
    print(f"Received: {message}")

def on_error(ws, error):
    print(f"Error: {error}")

def on_close(ws, close_status_code, close_msg):
    print("### Connection closed ###")

def on_open(ws):
    print("### Connection opened ###")
    ws.send("Hello WebSocket!")

if __name__ == "__main__":
#    websocket.enableTrace(True)
#    ws = websocket.WebSocketApp("wss://localhost:443/websocket/",
#                                on_open=on_open,
#                                on_message=on_message,
#                                on_error=on_error,
#                                on_close=on_close)
#    ws.run_forever(sslopt={"cert_reqs": ssl.CERT_NONE})

    ws = websocket.WebSocketApp("ws://localhost:8072/",
                                on_open=on_open,
                                on_message=on_message,
                                on_error=on_error,
                                on_close=on_close)

    ws.run_forever()
