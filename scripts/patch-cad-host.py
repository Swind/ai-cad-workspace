"""0.10.4-only patch: expose the daemon bind address on its foreground CLI."""
from importlib.metadata import version
from pathlib import Path
import cad_server

assert version("cad-server") == "0.10.4"
root = Path(cad_server.__file__).parent / "engine"
changes = {
    "cli.py": [
        ('def _server_arguments(server: argparse.ArgumentParser) -> None:\n',
         'def _server_arguments(server: argparse.ArgumentParser) -> None:\n'
         '    server.add_argument("--host", default="127.0.0.1", help="HTTP bind address (container compatibility patch)")\n'),
        ('rotate=args.rotate_token, foreground=True)',
         'rotate=args.rotate_token, foreground=True, host=args.host)'),
    ],
    "daemon.py": [
        ('foreground: bool = False) -> int:',
         'foreground: bool = False, host: str = "127.0.0.1") -> int:'),
        ('daemon.serve({})', 'daemon.serve({"host": host})'),
    ],
}
for name, replacements in changes.items():
    path = root / name
    text = path.read_text()
    for old, new in replacements:
        assert text.count(old) == 1, (name, old)
        text = text.replace(old, new)
    path.write_text(text)
