"""LAN Host, token admission, session cookie and cross-origin rejection."""
import json
import subprocess
import urllib.error
import urllib.request
from urllib.parse import urlsplit

launch = json.loads(subprocess.check_output(['cad', 'viewer', '--json'], text=True))
url = urlsplit(launch['url'])
base = 'http://127.0.0.1:3245'
headers = {'Host': '192.0.2.42:3245', 'Origin': 'http://192.0.2.42:3245', 'Sec-Fetch-Site': 'same-origin'}


def request(path, supplied, status):
    try:
        response = urllib.request.urlopen(urllib.request.Request(base + path, headers=supplied), timeout=10)
    except urllib.error.HTTPError as error:
        response = error
    with response:
        assert response.status == status, response.status
        return response.headers


request('/', headers, 403)
answer = request(url.path + '?' + url.query, headers, 200)
cookie = answer.get('Set-Cookie')
assert cookie and 'HttpOnly' in cookie and 'SameSite=Strict' in cookie
authenticated = {**headers, 'Cookie': cookie.split(';')[0]}
request('/', authenticated, 200)
request('/', {**authenticated, 'Origin': 'http://other.example', 'Sec-Fetch-Site': 'cross-site'}, 403)
print('PASS: LAN Host/Origin, token, cookie, cross-origin rejection')
