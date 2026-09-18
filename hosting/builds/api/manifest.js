// Build manifest endpoint for the downloader shell.
// GET /api/manifest with header X-Access-Code (or ?code=). ACCESS_CODES env: comma-separated list;
// when unset, the manifest is public (dev). manifest.json is written by tools/publish_pck.sh.
const fs = require("fs");
const path = require("path");

module.exports = (req, res) => {
  const codes = (process.env.ACCESS_CODES || "").split(",").map((s) => s.trim()).filter(Boolean);
  const code = String(req.headers["x-access-code"] || (req.query && req.query.code) || "").trim();
  res.setHeader("Cache-Control", "no-store");
  if (codes.length && !codes.includes(code)) {
    res.status(401).json({ error: "bad access code" });
    return;
  }
  let manifest;
  try {
    manifest = JSON.parse(fs.readFileSync(path.join(process.cwd(), "manifest.json"), "utf8"));
  } catch (e) {
    res.status(503).json({ error: "no build published yet" });
    return;
  }
  res.status(200).json(manifest);
};
