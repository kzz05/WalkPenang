"""Publish walkpenang_sand.json to Mapbox as a Studio style.

The style is authored as JSON in this folder rather than clicked together in
the Studio canvas, so it can be diffed and reviewed in git like any other
source file. Studio can still open and edit it afterwards — but re-running
this script overwrites whatever Studio saved, so edit the JSON, not the canvas.

Usage (from the repo root):

    MAPBOX_USERNAME=your_username \
    MAPBOX_SECRET_TOKEN=sk.your_styles_write_token \
    python design/mapbox/upload_style.py

The secret token needs scope `styles:write` (plus `styles:list` is harmless).
It is read from the environment and never written to disk — deliberately
separate from the narrower `downloads:read` token in gradle.properties.

First run creates the style and records its id in style_id.txt. Later runs
update that same style, so you don't accumulate duplicates in your account.
"""
import json
import os
import sys
import urllib.error
import urllib.request

HERE = os.path.dirname(os.path.abspath(__file__))
STYLE_PATH = os.path.join(HERE, "walkpenang_sand.json")
ID_PATH = os.path.join(HERE, "style_id.txt")
API = "https://api.mapbox.com/styles/v1"


def fail(message):
    print("ERROR: " + message, file=sys.stderr)
    sys.exit(1)


def request(url, method, payload=None):
    data = json.dumps(payload).encode() if payload is not None else None
    req = urllib.request.Request(url, data=data, method=method)
    req.add_header("Content-Type", "application/json")
    try:
        with urllib.request.urlopen(req) as response:
            return json.loads(response.read().decode())
    except urllib.error.HTTPError as e:
        body = e.read().decode(errors="replace")
        if e.code in (401, 403):
            fail(
                "Mapbox rejected the token (HTTP %d).\n"
                "  - 401 usually means the token string is wrong or truncated.\n"
                "  - 403 usually means it lacks the `styles:write` scope.\n"
                "Create one at https://account.mapbox.com/access-tokens/\n"
                "Response: %s" % (e.code, body)
            )
        fail("HTTP %d from Mapbox: %s" % (e.code, body))


def main():
    username = os.environ.get("MAPBOX_USERNAME", "").strip()
    token = os.environ.get("MAPBOX_SECRET_TOKEN", "").strip()

    if not username:
        fail("MAPBOX_USERNAME is not set. This is your Mapbox account "
             "username, visible at https://account.mapbox.com/")
    if not token:
        fail("MAPBOX_SECRET_TOKEN is not set. It must be a secret token "
             "(starts with `sk.`) carrying the `styles:write` scope.")
    if not token.startswith("sk."):
        fail("MAPBOX_SECRET_TOKEN does not start with `sk.`. A public `pk.` "
             "token cannot write styles.")

    with open(STYLE_PATH, encoding="utf-8") as f:
        try:
            style = json.load(f)
        except json.JSONDecodeError as e:
            fail("walkpenang_sand.json is not valid JSON: %s" % e)

    existing_id = None
    if os.path.exists(ID_PATH):
        with open(ID_PATH, encoding="utf-8") as f:
            existing_id = f.read().strip() or None

    if existing_id:
        print("Updating existing style %s ..." % existing_id)
        url = "%s/%s/%s?access_token=%s" % (API, username, existing_id, token)
        result = request(url, "PATCH", style)
    else:
        print("Creating a new style ...")
        url = "%s/%s?access_token=%s" % (API, username, token)
        result = request(url, "POST", style)
        with open(ID_PATH, "w", encoding="utf-8") as f:
            f.write(result["id"])
        print("Recorded new style id in %s" % ID_PATH)

    style_uri = "mapbox://styles/%s/%s" % (result["owner"], result["id"])
    print("\nPublished: %s" % result.get("name", "(unnamed)"))
    print("Style URI: %s" % style_uri)
    print("\nRun the app against it with:")
    print("  flutter run --dart-define=MAPBOX_STYLE_URI=%s" % style_uri)
    print("\nOr edit it in Studio at:")
    print("  https://studio.mapbox.com/styles/%s/%s/edit"
          % (result["owner"], result["id"]))


if __name__ == "__main__":
    main()
