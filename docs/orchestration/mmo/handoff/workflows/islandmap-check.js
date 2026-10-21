export const meta = {
  name: 'deadfront-islandmap-check',
  description: 'Compare our islands (scale, shape), map screen and harbour travel menu with the owner\'s Durango island-map and Sail references; side-by-side shots, measured gaps, a package plan (no build)',
  phases: [
    { title: 'Measure', detail: 'our map, travel menu and islands in pixels and metres; code and docs' },
    { title: 'Plan', detail: 'gap table, package design, owner questions' },
  ],
}
const OSP = '/private/tmp/claude-501/-Users-milankinzy-Documents-deadfront-siege/1899b1df-f06b-4b94-91be-9e3f3c22081d/scratchpad'
const SP = '/private/tmp/claude-501/-Users-milankinzy-Documents-deadfront-siege/72cebc8b-d241-430b-9ea6-94d65339bfef/scratchpad'
const REPO = '/Users/milankinzy/Documents/deadfront-siege'
const OWNER = '/Users/milankinzy/Documents/deadfront'
const G = '/Applications/Godot_mono.app/Contents/MacOS/Godot'
const REF = `${OWNER}/docs/reference/durango-island-map.webp`
const OUT = `${SP}/islandmap`
const BASE = `Project: DEADFRONT, a Godot 4.7.1 typed-GDScript dinosaur survival MMO (game/ is the project), Durango: Wild Lands-style systems and UI; judged in desktop Chrome at 1600x900 (web renderer gl_compatibility) and on landscape phones (844x390).
The owner sent two Durango references. (1) The island map screen, "to give you an idea of the scale and shape of an island, as well as the UI": ${REF} (open it). (2) The Sail menu, "Menu scrolls rightward and has many islands" (the image was not saved; its description is in the second section of ${OWNER}/docs/design/durango-prompts/15_island_map_scale.md - read the whole file). Our facts so far: rules.json island_size_m home 160 / unstable 240; docs/design/world-design.md section 2 sets 240 x 240 m unstable islands read from the harbour in rings; island_runtime.gd builds unstable islands at 2 x far_shore radius (about 480 m); the map screen is game/scripts/ui/map_screen.gd; harbour travel is game/scripts/world/harbour.gd (+ harbour_site.gd, harbour_lab, camp_travel_probe) with 15 islands (t_harbour).
Rules: do not edit the repo or any package worktree; nothing is committed. Godot only through ${OSP}/gslot.sh with its own timeout (e.g. ${OSP}/gslot.sh perl -e 'alarm 600; exec @ARGV' ${G} ...), silent; never --editor; for your own tree run: bash ${SP}/mkscratch.sh islandmap claude/mmo-overhaul (prints its path; cloned cache, isolated user dir). Probe scripts go under ${OUT}/probe/ (copy into the tree's game/ folder if they need res:// paths; never commit). Look at every PNG you make before describing it. Quote numbers you measured, never guess.`
const NOTES = { type: 'object', properties: { notes: { type: 'string' }, shots: { type: 'array', items: { type: 'string' } } }, required: ['notes', 'shots'] }

phase('Measure')
const [pix, code] = await parallel([
  () => agent(`${BASE}

TASK (pixels and metres): in your scratch tree, (1) take windowed shots of OUR map screen on the home island and on one unstable island, and of OUR harbour travel / destination menu (the screen where the player picks an island to sail to), at 1600x900 gl_compatibility and 844x390 (find how the game or a lab opens them; a small probe is fine); (2) take a top-down overview of the home island and of one unstable island at the same metres-per-pixel (an orthographic camera probe), plus one at the Durango map's apparent scale (50 m bar ~ 70 px in a 1306 px wide shot); (3) measure each island: land bounding box in metres, land area, coastline roundness (perimeter / sqrt(area)), harbour distance from the centre, walking time edge to edge at the survivor's run speed. Save everything under ${OUT}/shots/ and return the paths and numbers.`, { label: 'measure:pixels', phase: 'Measure', schema: NOTES }),
  () => agent(`${BASE}

TASK (code and docs): on claude/mmo-overhaul (git -C ${REPO} show claude/mmo-overhaul:<path>): (a) map_screen.gd element by element against the map reference: fog of war / exploration memory (exists? saved?), painted rendering, island info panel (level, climate, life span, fatigue and its rate - check the fatigue system here and on main commit 7ff08dc4), difficulty emblem and text, scale bar, player marker with coordinates, domain label with portrait (claims), harbour/shelter/bonfire/other-player markers, legend, "To Harbor" / "To Waypoint" (what the PRD or docs say they do - say if no doc covers it), close; (b) the harbour travel menu against the Sail reference: how destinations are listed, the island list data (names, levels, climates, discovery), what sailing costs and takes, sea zones vs named islands, discovery state, and whether it scrolls; (c) the island generator (island_runtime.gd, terrain, coast, rings, island defs): how shape and size are made and what a change would touch (spawns, rings, node counts island_lab and the integrator gate on, harbour placement, travel); (d) what docs/design/world-design.md, the PRD (docs/prd/durango-wild-lands-systems-prd.md: islands, sailing, cargo warp, unstable islands, city islands) and STATUS owner decisions bind about island size, shape, the sea layout, the map and sailing. Return notes with file:line refs.`, { label: 'measure:code', phase: 'Measure', schema: NOTES }),
])

phase('Plan')
const PLAN = { type: 'object', properties: {
  verdict: { type: 'string', description: 'two or three blunt sentences: how our islands, map and travel menu compare with the references' },
  side_by_side: { type: 'array', items: { type: 'object', properties: { what: { type: 'string' }, ours: { type: 'string' }, reference: { type: 'string' } }, required: ['what', 'ours', 'reference'] } },
  gaps: { type: 'array', items: { type: 'object', properties: { area: { type: 'string', enum: ['scale', 'shape', 'map_ui', 'sail_ui', 'gameplay'] }, gap: { type: 'string' }, fix: { type: 'string' }, risk: { type: 'string' } }, required: ['area', 'gap', 'fix', 'risk'] } },
  packages: { type: 'array', items: { type: 'object', properties: { key: { type: 'string' }, scope: { type: 'string' }, gates: { type: 'string' }, depends_on: { type: 'string' }, when: { type: 'string' } }, required: ['key', 'scope', 'gates', 'depends_on', 'when'] } },
  owner_questions: { type: 'array', items: { type: 'string' } },
  report_md: { type: 'string' } }, required: ['verdict', 'side_by_side', 'gaps', 'packages', 'owner_questions', 'report_md'] }
const plan = await agent(`${BASE}

ROLE: planner. Open the map reference and every shot listed below, read spec 15, then compare. Produce: a side-by-side table (ours vs the references: island size, shape, map look and each map UI element, the travel menu vs the Sail menu); the gaps with the smallest fix for each and its risk; one to three packages (e.g. MAPUI for the island map screen, SAILUI for the rightward-scrolling sea of islands by level, ISLANDSHAPE for generator scale/shape) with measurable gates (sizes in metres, coastline roundness, walking times, pixel checks at 1600x900 and 844x390, island_lab counts changing only as intended), dependencies (the seven-package merge run is landing now and gates on island_lab counts; UI screens should share the Durango theme being built in claude/mmo-invui) and when to start. Owner questions only for what the docs and the references do not settle and that changes a major visual direction or gameplay (e.g. shrinking unstable islands, how many islands the sea holds). report_md is the note for docs/orchestration/mmo/islandmap-check.md.

Measurements (pixels/metres):
${pix ? pix.notes + '\nShots: ' + pix.shots.join(', ') : '(failed)'}

Code and docs:
${code ? code.notes : '(failed)'}`, { label: 'plan', phase: 'Plan', schema: PLAN, effort: 'high' })
return { plan, shots: pix ? pix.shots : [] }
