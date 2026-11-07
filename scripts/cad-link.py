"""Print an authenticated viewer link with its authority changed for LAN use."""
import argparse
import json
import subprocess
from urllib.parse import urlsplit, urlunsplit

parser = argparse.ArgumentParser()
parser.add_argument("host", help="Host IP or DNS name, optionally with :3245")
parser.add_argument("file", nargs="?")
args = parser.parse_args()
authority = urlsplit("http://" + args.host)
if not authority.hostname or authority.username or authority.path or authority.query or authority.fragment:
    parser.error("host must be an IP/DNS authority, not a URL or path")
netloc = authority.netloc if authority.port else authority.netloc + ":3245"
command = ["cad", "viewer", "--json"]
if args.file:
    command.append(args.file)
data = json.loads(subprocess.check_output(command, text=True))
urls = [item["url"] for item in data.get("documents", [])] or [data["url"]]
for url in urls:
    parsed = urlsplit(url)
    print(urlunsplit((parsed.scheme, netloc, parsed.path, parsed.query, parsed.fragment)))
