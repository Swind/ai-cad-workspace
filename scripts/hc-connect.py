"""Plain byte transport for Ovis: existing hc socket only, never autostart.

hc schema/README.md specifies the same JSON-RPC/framed transport on its socket
and `hc connect` stdio. No messages are interpreted or rewritten here.
"""
import os
import selectors
import socket
import sys

with socket.socket(socket.AF_UNIX) as connection, selectors.DefaultSelector() as ready:
    connection.connect(os.environ['HC_SOCKET'])
    ready.register(connection, selectors.EVENT_READ)
    ready.register(sys.stdin.buffer, selectors.EVENT_READ)
    while True:
        for key, _ in ready.select():
            if key.fileobj is connection:
                data = connection.recv(65536)
                if not data:
                    sys.exit(0)
                sys.stdout.buffer.write(data)
                sys.stdout.buffer.flush()
            else:
                data = os.read(sys.stdin.fileno(), 65536)
                if not data:
                    sys.exit(0)
                connection.sendall(data)
