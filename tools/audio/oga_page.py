"""Summarise saved OpenGameArt pages: title, author, licences, file links. Reads saved HTML only.
Usage: python3 -I oga_page.py page.html [...]
"""
import re, sys, html as H

for path in sys.argv[1:]:
    t = open(path, encoding="utf-8", errors="replace").read()
    title = re.search(r"<title>([^<]*)</title>", t)
    author = re.search(r'field-name-author-submitter.*?<a href="/users/([^"]+)"', t, re.S)
    lics = re.findall(r"class=[\"']license-name[\"'][^>]*>([^<]+)<", t)
    if not lics:
        lics = re.findall(r'href="(https?://creativecommons\.org/[^"]+)"', t)
    files = re.findall(r'href="(https://opengameart\.org/sites/default/files/[^"]+)"', t)
    print("==", path, "|", H.unescape(title.group(1)) if title else "?", "| author:", author.group(1) if author else "?")
    print("   licences:", sorted(set(lics)))
    for f in sorted(set(files)):
        if not re.search(r"\.(png|jpg|gif|jpeg)$", f, re.I):
            print("   file:", f)
