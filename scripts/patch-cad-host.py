"""0.11.9-only patch: expose the daemon bind address on its foreground CLI."""
from importlib.metadata import version
from pathlib import Path
import cad_server

assert version("cad-server") == "0.11.9"
root = Path(cad_server.__file__).parent / "engine"
changes = {
    "cli.py": [
        ('def _server_arguments(server: argparse.ArgumentParser) -> None:\n'
         '    from cad_server._internal.consent import add_yes\n',
         'def _server_arguments(server: argparse.ArgumentParser) -> None:\n'
         '    from cad_server._internal.consent import add_yes\n'
         '    server.add_argument("--host", default="127.0.0.1", help="HTTP bind address (container compatibility patch)")\n'),
        ('    return daemon([], port=args.port, rotate=args.rotate_token, foreground=True)\n',
         '    return daemon([], port=args.port, rotate=args.rotate_token, foreground=True, host=args.host)\n'),
    ],
    "daemon.py": [
        ('def main(argv: list[str] | None = None, *, port: int | None = None, rotate: bool = False,\n'
         '         foreground: bool = False) -> int:\n',
         'def main(argv: list[str] | None = None, *, port: int | None = None, rotate: bool = False,\n'
         '         foreground: bool = False, host: str = "127.0.0.1") -> int:\n'),
        ('            daemon.serve({})\n', '            daemon.serve({"host": host})\n'),
    ],
}
for name, replacements in changes.items():
    path = root / name
    text = path.read_text()
    for old, new in replacements:
        assert text.count(old) == 1, (name, old)
        text = text.replace(old, new)
    path.write_text(text)
