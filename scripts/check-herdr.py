"""Read-only official JSON-RPC probe; hc server status would auto-start core."""
import json
import os
import socket

with socket.socket(socket.AF_UNIX) as connection:
    connection.settimeout(4)
    connection.connect(os.environ['HC_SOCKET'])
    connection.sendall(b'{"jsonrpc":"2.0","id":1,"method":"server.status","params":{}}\n')
    answer = json.loads(connection.makefile('rb').readline(1024 * 1024))
    assert answer.get('result', {}).get('pid', 0) > 0
