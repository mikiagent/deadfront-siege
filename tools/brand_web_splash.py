#!/usr/bin/env python3
"""Replace Godot's generic web splash with DEADFRONT mobile-first branding."""
from pathlib import Path
import sys

out = Path(sys.argv[1] if len(sys.argv) > 1 else "export/web")
path = out / "index.html"
html = path.read_text()
marker = "deadfront-loading-shell"
if marker in html:
    print("web splash already branded")
    raise SystemExit(0)
css = r'''
/* deadfront-loading-shell */
#status {
  overflow: hidden; isolation: isolate; background:
    radial-gradient(ellipse at 50% 42%, rgba(91,112,64,.32) 0, rgba(12,18,17,.94) 46%, #050807 78%),
    linear-gradient(145deg, #111713, #050706);
  color: #f1ead5; font-family: -apple-system, BlinkMacSystemFont, "Segoe UI", sans-serif;
}
#status::before { content:""; position:absolute; inset:-25%; z-index:-1; opacity:.28;
  background-image: linear-gradient(rgba(154,179,110,.09) 1px,transparent 1px),linear-gradient(90deg,rgba(154,179,110,.09) 1px,transparent 1px);
  background-size:42px 42px; transform:perspective(520px) rotateX(64deg) translateY(34%); }
#status-splash { display:none !important; }
#deadfront-brand { width:min(82vw,540px); display:flex; flex-direction:column; align-items:center; gap:12px; transform:translateY(-3vh); }
#deadfront-mark { width:70px; height:78px; display:grid; place-items:center; color:#d7b96b; font:900 31px/1 Georgia,serif;
  clip-path:polygon(25% 4%,75% 4%,100% 50%,75% 96%,25% 96%,0 50%); background:linear-gradient(145deg,#263326,#101612); box-shadow:0 0 40px rgba(183,151,72,.22); }
#deadfront-kicker { color:#9dab89; font-size:10px; font-weight:800; letter-spacing:.42em; text-indent:.42em; }
#deadfront-title { margin:0; color:#f3eddb; font:900 clamp(38px,11vw,72px)/.88 Impact,"Arial Black",sans-serif; letter-spacing:.045em; text-shadow:0 3px 0 #392f21,0 0 34px rgba(235,207,132,.12); }
#deadfront-subtitle { color:#c7a95f; font-size:11px; font-weight:800; letter-spacing:.31em; text-indent:.31em; }
#deadfront-rule { width:100%; height:1px; margin:9px 0 1px; background:linear-gradient(90deg,transparent,#8ea070 22%,#d0ae59 50%,#8ea070 78%,transparent); }
#deadfront-loading { width:100%; display:flex; justify-content:space-between; color:#aab49d; font-size:10px; font-weight:750; letter-spacing:.18em; text-transform:uppercase; }
#status-progress { position:relative; inset:auto; display:none; width:100%; height:8px; margin:0; border:1px solid rgba(181,190,151,.32); border-radius:0; background:#151b17; color:#c7a95f; overflow:hidden; appearance:none; -webkit-appearance:none; }
#status-progress::-webkit-progress-bar { background:#151b17; }
#status-progress::-webkit-progress-value { background:linear-gradient(90deg,#718058,#d7b96b); box-shadow:0 0 14px rgba(215,185,107,.55); }
#status-progress::-moz-progress-bar { background:linear-gradient(90deg,#718058,#d7b96b); }
#status-notice { max-width:min(82vw,540px); background:#261713; border-color:#744635; font-size:14px; }
@media (max-height:520px) { #deadfront-mark{width:50px;height:56px;font-size:23px} #deadfront-brand{gap:7px} #deadfront-rule{margin-top:3px} }
'''
brand = r'''
<div id="deadfront-brand">
  <div id="deadfront-mark">D</div>
  <div id="deadfront-kicker">SURVIVE THE RIFT</div>
  <h1 id="deadfront-title">DEADFRONT</h1>
  <div id="deadfront-subtitle">DURANGO PROTOCOL</div>
  <div id="deadfront-rule"></div>
  <div id="deadfront-loading"><span>Preparing the island</span><span>Stay alive</span></div>
</div>
'''
html = html.replace("\t\t</style>", css + "\n\t\t</style>", 1)
needle = '<img id="status-splash" class="show-image--true fullsize--true use-filter--true" src="index.png" alt="">'
if needle not in html:
    raise SystemExit("Godot splash image hook not found")
html = html.replace(needle, needle + brand, 1)
html = html.replace("<title>Durango-like (working title)</title>", "<title>DEADFRONT · Durango Protocol</title>", 1)
path.write_text(html)
print("branded DEADFRONT web splash")
