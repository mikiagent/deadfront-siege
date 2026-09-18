#!/usr/bin/env python3
"""Ensure an internal TestFlight group exists, contains the given tester email, and has the latest VALID build.
Run: uv run --with pyjwt --with cryptography python3 tools/asc_testflight.py <tester-email>"""
import json, sys, time, pathlib, urllib.request, urllib.error, jwt
env = dict(l.strip().split("=", 1) for l in pathlib.Path(__file__).with_name("release.env").read_text().splitlines() if "=" in l and not l.startswith("#"))
kid, iss, bundle = env["ASC_KEY_ID"], env["ASC_ISSUER_ID"], env["BUNDLE_ID"]
key = (pathlib.Path.home()/".appstoreconnect/private_keys"/f"AuthKey_{kid}.p8").read_text()
tok = jwt.encode({"iss": iss, "iat": int(time.time()), "exp": int(time.time())+900, "aud": "appstoreconnect-v1"}, key, algorithm="ES256", headers={"kid": kid})
API = "https://api.appstoreconnect.apple.com/v1"
def call(method, path, body=None):
    r = urllib.request.Request(API+path, method=method, data=json.dumps(body).encode() if body else None,
                               headers={"Authorization": f"Bearer {tok}", "Content-Type": "application/json"})
    try:
        with urllib.request.urlopen(r) as resp:
            raw = resp.read(); return json.loads(raw) if raw else {}
    except urllib.error.HTTPError as e:
        print("HTTP", e.code, path, e.read().decode()[:400]); return None
email = sys.argv[1]
app = call("GET", f"/apps?filter[bundleId]={bundle}")["data"][0]; aid = app["id"]
groups = call("GET", f"/betaGroups?filter[app]={aid}")["data"]
grp = next((g for g in groups if g["attributes"].get("isInternalGroup")), None)
if not grp:
    grp = call("POST", "/betaGroups", {"data": {"type": "betaGroups", "attributes": {"name": "Internal", "isInternalGroup": True, "hasAccessToAllBuilds": True},
                                                 "relationships": {"app": {"data": {"type": "apps", "id": aid}}}}})["data"]
    print("created internal group", grp["id"])
else:
    print("internal group", grp["id"], grp["attributes"]["name"], "allBuilds=", grp["attributes"].get("hasAccessToAllBuilds"))
testers = call("GET", f"/betaGroups/{grp['id']}/betaTesters")["data"]
if not any(t["attributes"].get("email", "").lower() == email.lower() for t in testers):
    existing = call("GET", f"/betaTesters?filter[email]={email}")["data"]
    if existing:
        call("POST", f"/betaGroups/{grp['id']}/relationships/betaTesters", {"data": [{"type": "betaTesters", "id": existing[0]["id"]}]}); print("added existing tester", email)
    else:
        r = call("POST", "/betaTesters", {"data": {"type": "betaTesters", "attributes": {"email": email}, "relationships": {"betaGroups": {"data": [{"type": "betaGroups", "id": grp["id"]}]}}}})
        print("created tester", email, "->", r["data"]["id"] if r else "failed")
else:
    print("tester already in group:", email)
builds = call("GET", f"/builds?filter[app]={aid}&sort=-uploadedDate&limit=1")["data"]
if builds and not grp["attributes"].get("hasAccessToAllBuilds"):
    call("POST", f"/betaGroups/{grp['id']}/relationships/builds", {"data": [{"type": "builds", "id": builds[0]["id"]}]}); print("build added to group")
print("latest build:", builds[0]["attributes"]["version"], builds[0]["attributes"]["processingState"] if builds else "none")
