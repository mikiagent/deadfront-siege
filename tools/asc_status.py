#!/usr/bin/env python3
"""Print the app's recent TestFlight builds and their processing state.
Run with:  uv run --with pyjwt --with cryptography python3 tools/asc_status.py
Reads Key ID / Issuer from tools/release.env and the .p8 from ~/.appstoreconnect/private_keys."""
import json, time, pathlib, urllib.request, jwt
env = dict(l.strip().split("=", 1) for l in pathlib.Path(__file__).with_name("release.env").read_text().splitlines() if "=" in l and not l.startswith("#"))
kid, iss, bundle = env["ASC_KEY_ID"], env["ASC_ISSUER_ID"], env["BUNDLE_ID"]
key = (pathlib.Path.home()/".appstoreconnect/private_keys"/f"AuthKey_{kid}.p8").read_text()
tok = jwt.encode({"iss": iss, "iat": int(time.time()), "exp": int(time.time())+600, "aud": "appstoreconnect-v1"}, key, algorithm="ES256", headers={"kid": kid})
def get(path):
    r = urllib.request.Request("https://api.appstoreconnect.apple.com/v1"+path, headers={"Authorization": f"Bearer {tok}"})
    return json.load(urllib.request.urlopen(r))
for a in get(f"/apps?filter[bundleId]={bundle}")["data"]:
    print("APP", a["id"], a["attributes"]["name"], bundle)
    for x in get(f"/builds?filter[app]={a['id']}&sort=-uploadedDate&limit=5")["data"]:
        at = x["attributes"]; print("BUILD", at["version"], at["processingState"], at.get("uploadedDate"), "expired" if at.get("expired") else "")
