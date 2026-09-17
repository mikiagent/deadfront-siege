# Dinosaur Roster, Status Effects, and the Meshy 3D Pipeline

**Status:** v0.2, design spec (not research)
**Pipeline status:** Meshy key is live (3,895 credits at last check). §4.2 rewritten after three failed generations — **text-to-3D cannot produce correct theropod anatomy and the roster must be built through image-to-3D.** Measured evidence in §4.5.
**Depends on:** [`research/durango-wild-lands-bestiary-combat.md`](../../research/durango-wild-lands-bestiary-combat.md), [`docs/prd/durango-wild-lands-systems-prd.md`](./durango-wild-lands-systems-prd.md)
**Scope:** the creature layer only. Class/occupation system, the 12 skill trees, islands, crafting and fatigue are specified in the systems PRD and are **kept as-is**.

Three requirements drive this document:

1. **Real species, real silhouettes.** No Zebraceratops, no Pavomimus. Every creature is a real extinct animal, named correctly, and the model has to read as that animal to someone who knows dinosaurs.
2. **Fearsome and powerful.** Wild animals should be genuinely dangerous, and a tamed one must stay recognisably the same animal. This is a direct rejection of Durango's own worst mistake (systems PRD §22.9).
3. **Status effects — bleed, poison, and friends.** **Durango shipped none of these.** Its only damage-over-time effects were environmental or ingested, and the only status a wild animal could apply was a fatigue tax from being drooled on (bestiary §4.4). Everything in §3 below is a deliberate addition, not a reconstruction.

---

## 1. Design rules

**R1 — 18 rigs, not 90 species.** Durango shipped ~90 catalog entries off roughly 18 distinct rigs, multiplied by recolors, juvenile scales, and sex splits. Budget rigs. A juvenile is the adult rig at 0.55 scale with a faster animation timescale and its own drop table.

**R2 — the tame is the same animal.** A tamed creature keeps its wild stat block and gets balanced by **upkeep, cooldown, and bonded cap**, never by having its HP quartered. Durango cut Tarbosaurus from 60,000 HP wild to 2,500 tamed on a 16,000 hunger budget and the entire pet meta collapsed into "carry my stuff."

**R3 — every creature has one readable verb.** Players should be able to name what a species does to them in four words: *raptor opens you up*, *anky breaks your arm*, *dilo blinds you*. That verb is the status effect, and it is the species' whole identity in combat.

**R4 — no flying, no swimming, in v1.** Nexon spent five and a half years and shipped neither. Pterosaurs existed only as shadows on the ground; Sarcosuchus got animations and zero game files. Ground creatures only.

**R5 — biped-first build order.** Meshy's rigging and text-to-motion APIs support **bipeds only**. Quadrupeds can be rigged in the web UI but draw from a much thinner animation library. Theropods therefore cost a fraction of what ceratopsians cost. See §4.

---

## 2. The roster

18 rigs. Tier is the unstable-island level band from the systems PRD §4.4. Rig column drives the production route in §4.

### 2.1 Theropods — biped, cheap to animate, the backbone of the roster

| # | Species | Period / real size | Tier | Signature verb | Status applied | Tameable |
|---|---|---|---|---|---|---|
| 1 | **Compsognathus** | L. Jurassic, 1 m | 15 savannah | Swarm nips, 4–8 at once | none — trash mob, defense XP | no |
| 2 | **Coelophysis** | L. Triassic, 3 m | 15–20 savannah/temperate | Flock harass, darting bites | **Bleed 1** | capture I |
| 3 | **Velociraptor** | L. Cretaceous, 2 m (turkey-sized, feathered) | 25 temperate | Pounce knockdown from off-screen | **Bleed 2**, Knockdown | capture II |
| 4 | **Deinonychus** | E. Cretaceous, 3.4 m | 35 tropical | Pack flank, sickle-claw rake | **Bleed 3** | capture III |
| 5 | **Utahraptor** | E. Cretaceous, 5.5 m | 50 desert | Single devastating claw strike | **Deep Bleed** (stacks ×3) | capture V |
| 6 | **Dilophosaurus** | E. Jurassic, 6 m (**no frill, no spit in reality**) | 40 tropical | Ranged venom — see note | **Venom** | capture IV |
| 7 | **Gallimimus** | L. Cretaceous, 6 m | 30 desert | Charge, kick, outruns you | Knockdown | capture III |
| 8 | **Allosaurus** | L. Jurassic, 9 m | 50 desert | Hatchet-bite, arterial strike | **Deep Bleed**, Fracture | no — mini-boss |
| 9 | **Tarbosaurus** | L. Cretaceous, 10 m | 60 tundra/tropical | Grab-and-shake pin | **Pinned**, Deep Bleed | capture V, endgame |
| 10 | **Tyrannosaurus rex** | L. Cretaceous, 12 m | 60 volcanic | 3-phase raid: stomp, roar, tail | **Deafened**, Fracture, Pinned | no — raid boss |

**Dilophosaurus note.** The venom-spitting frilled Dilophosaurus is a *Jurassic Park* invention; the real animal was a 6 m predator with a notched snout and no evidence of either. Keep the venom because R3 needs a ranged status-applier at tier 40, but **model the real animal** — full size, paired head crests, no frill — and explain the venom as a cheek-gland adaptation in the codex entry. Correct silhouette, invented behavior, stated as such.

### 2.2 Quadrupeds — expensive to animate, high value as tames

| # | Species | Period / real size | Tier | Signature verb | Status applied | Tameable |
|---|---|---|---|---|---|---|
| 11 | **Protoceratops** | L. Cretaceous, 2 m | 20 temperate | Shoving beak, herd solidarity | none | capture I — first tame |
| 12 | **Styracosaurus** | L. Cretaceous, 5.5 m | 45 savannah | Horn sweep, knockback | Knockdown | capture III |
| 13 | **Triceratops** | L. Cretaceous, 9 m | 55 swamp | Full charge | **Fracture**, Knockdown | capture V |
| 14 | **Ankylosaurus** | L. Cretaceous, 8 m | 50 desert | Tail club | **Fracture** (the definitive one) | capture IV |
| 15 | **Stegosaurus** | L. Jurassic, 9 m | 45 temperate | Thagomizer tail sweep | **Deep Bleed** (spike punctures) | capture IV |
| 16 | **Smilodon** | Pleistocene, 1.2 m tall | 45 tundra/tropical | Two-hit pounce, throat bite | **Deep Bleed** | capture V |
| 17 | **Megaloceros** | Pleistocene, 2.1 m at shoulder | 30 tundra | Antler gore, flees | Knockdown | capture II |
| 18 | **Brachiosaurus** | L. Jurassic, 22 m | 60 any | Ambient titan — stomp only if provoked | Fracture | no — living terrain |

**Brachiosaurus is scenery with hit points.** It should not be a fight. Durango gave it 90,000 HP and an instant-cast dodge roll, which is a boss pretending to be an animal. Here it wanders, blocks sightlines, ignores you, and kills you instantly if you stand under a foot. It exists to make the island feel enormous.

### 2.3 Recolor and variant budget — free content off the same 18 rigs

| Rig | Variants |
|---|---|
| Velociraptor | Snow (white/grey, tundra), Crested (tropical, display feathers), juvenile at 0.55 |
| Deinonychus | Juvenile, swamp melanistic |
| Ankylosaurus | Juvenile, volcanic ash-grey |
| Triceratops | Juvenile, swamp |
| Smilodon | Snow, juvenile |
| Compsognathus | Three climate recolors |
| Stegosaurus | Juvenile, desert |

18 rigs → roughly 40 catalog entries. That is Durango's 5:1 ratio at a solo-project scale.

---

## 3. Status effects

Durango's own status system is the calibration reference: **열독 heat poison was −1 HP/s for 6m30s**, and **복통 stomachache was −0.2 HP/s for 5 min**. Those are the brackets a DoT should land in — the harsh one is 1 HP/s, the nagging one is a fifth of that.

Durango's stun/knockdown pair and 어지러움 (dizziness: evasion −40, accuracy −20%, 25 s) are **kept unchanged** — knockdown is the capture window and that mechanic worked.

### 3.1 New combat statuses

| Status | Applied by | Effect | Duration | Stacks | Cleared by |
|---|---|---|---|---|---|
| **Bleed** | Slashing, claws, teeth | −0.3 HP/s | 20 s | to 3 | Bandage (cloth + herb), natural expiry |
| **Deep Bleed** | Utahraptor, Allosaurus, Smilodon, Stegosaurus spikes | −1.0 HP/s, **blocks natural Health regen** | 30 s | to 3 | Cauterise (bonfire, costs 5 HP) or Pressure Dressing |
| **Venom** | Dilophosaurus | −0.4 HP/s, accuracy −30% | 45 s | no | Antivenom (crafted from the same gland) |
| **Fracture** | Ankylosaurus club, Triceratops charge, T. rex tail | Movement −35%, Defense −25%, **cannot sprint or roll** | 90 s | no | Splint (bone + binding) or rest in a residence |
| **Pinned** | Tarbosaurus grab, T. rex phase 2 | Cannot act. Taking damage each tick. Mash to break | 4 s or until broken | no | Struggle, or a pet pulling aggro |
| **Deafened** | T. rex roar, Tarbosaurus roar | Telegraph circles **do not render** | 12 s | no | expiry only |
| **Infected Wound** | Any Bleed left to expire untreated, 25% chance | Max Health −20%, fatigue +15%/min | until treated | to 2 | **Antibiotic / syringe** |

**Infected Wound reuses code that already exists.** The current `index.html` carries `S.infection` and `S.syringes` with a working consume-to-cure path. That is the one status in this table that is already half-built.

### 3.2 Statuses the player inflicts

Symmetry matters — a hunter should have the same verbs the animals do.

| Status | How | Effect |
|---|---|---|
| **Bleeding (target)** | Blade weapons, crit | −1% max HP/s. **Blood trail renders**, letting you track a fled animal |
| **Groggy** | Blunt weapon, Body Tackle | Stagger, sets up Knockdown |
| **Knockdown** | Hit a Groggy target | **The capture window.** Net here or not at all |
| **Snared** | Trap construction | Held 8 s, cannot flee |
| **Poisoned (target)** | Coated weapons, cooking line | −0.5 HP/s, 30 s. Poisoned meat is **inedible** — real tradeoff, not free damage |

Poisoning an animal ruining its meat is the interesting half of that mechanic. It turns poison into a choice between killing a dangerous thing safely and getting anything useful off the corpse.

### 3.3 Rules

- **Bleed is the common currency, Fracture is the rare one.** Roughly two-thirds of the roster applies some grade of Bleed. Fracture belongs to three species and should feel like a broken run.
- **Every status must be readable on the model, not only in the HUD.** Bleed is a particle drip plus a darkening texture. Fracture is a limp in the locomotion blend. Venom is a tint. Deafened mutes the audio bus and drops the telegraph rings. If a status only exists in a corner icon, it will not land.
- **No status stacks into an unrecoverable spiral.** Durango's 부활 후유증 stacked per death and dying twice was a death sentence. Cap total simultaneous debuffs at 3; the 4th replaces the weakest.
- **Every status has a crafted counter**, and each counter belongs to a different skill tree — Bandage from Tailoring, Cauterise from Construction (bonfire), Antivenom and Antibiotic from Cooking, Splint from Weapon/Tools. This is how the creature layer feeds the specialization pressure the systems PRD §7.3 requires.

---

## 4. The Meshy production pipeline

### 4.1 Hard constraints, verified against the API docs

| Capability | Status |
|---|---|
| Text-to-3D | `POST /openapi/v2/text-to-3d`, two-stage: `mode: "preview"` (geometry) → `mode: "refine"` (texture) |
| **Model / topology pairing** | **Undocumented and enforced server-side.** `smart-topology` requires `ai_model: "meshy-t2"` and is **triangle-only** — it rejects `topology: "quad"`. `meshy-7` accepts `model_type: "standard"` only. Getting this wrong returns HTTP 400 |
| **Measured preview cost** | meshy-t2 + smart-topology: **5 credits**. meshy-7 + standard: **20 credits**, and it produced the worst of the three test meshes |
| Auto-rigging | `POST /openapi/v1/rigging` — **"currently only works well with standard humanoid (bipedal) assets."** Quadrupeds are explicitly unsupported on the API |
| Quadruped rigging | Supported in the **web UI**, with a **smaller animation library** than bipeds |
| Rig output | FBX + GLB, plus walk and run clips, with and without skin |
| Animation library | `GET /openapi/v1/animations/library` — free, searchable, category-filtered. **678 actions across WalkAndRun (176), BodyMovements (158), DailyActions (157), Fighting (154), Dancing (33)** |
| **Library rig coverage** | **Every one of the 678 preview URLs is `/biped/`. There are zero quadruped presets.** The earlier read of "fewer options for quadrupeds" was too generous — via the API there are none |
| Preset actions | `action_ids`, **up to 10 per request, 3 credits each**. Added 2026-09-02 |
| Text-to-Motion | Natural-language motion clips. Prime mode 10 credits (FBX), swift mode 3 credits (BVH). Docs are explicit: motion task IDs **"require a biped rig; quadruped rigs are rejected"** |
| Model orientation | Must face **+Z**. Over 300,000 faces requires remeshing first |

**The consequence for this roster.** The ten theropods in §2.1 run the whole automated path: generate → auto-rig → text-to-motion for custom attacks. The eight quadrupeds in §2.2 need the web UI for rigging and hand-authored or heavily adapted clips for anything past walk and run.

**So build order is theropods first.** Ship a game full of raptors, then add the ceratopsians as the art budget allows. This also happens to be the right call for R3, since the theropods carry Bleed and Bleed is the core status.

**The quadruped route is entirely manual.** No API rigging, no library presets, no text-to-motion. Every quadruped needs web-UI rigging and hand-authored clips. Budget them at roughly 5× a theropod in human time and plan the roster around that, not around how much you like ceratopsians.

### 4.2 Generation route — image-to-3D, not text-to-3D

**Text-to-3D does not work for this roster.** Three generations, three different prompt and model strategies, same failure. Evidence and images in §4.5. The short version:

| Attempt | Config | Result |
|---|---|---|
| 1 | meshy-t2, full anatomical prompt (feathers, palms inward, horizontal spine, stiff tail) | Generic scaly movie theropod. No feathers. Drooping tail. Upright posture |
| 2 | meshy-7 + standard, same prompt, 20 credits | Worse. Mangled body, tail reduced to a stub |
| 3 | meshy-t2, bird-forward prompt leading with "giant flightless predatory bird… like an emu" | Feathers finally appeared on head and back. **Posture still upright tripod, tail still a stub** |

Two failure modes survived every attempt:

1. **The long stiff horizontal tail never generates.** It comes out as a stub or a droop every time. This is the single most defining feature of a dromaeosaur and the model will not produce it from text.
2. **Posture defaults to upright tripod** — the 1950s Godzilla stance — no matter how explicitly the prompt specifies a spine parallel to the ground.

Feathers respond to prompting; skeletal structure does not. Writing a better prompt is not the fix, because the failure is in the geometry prior, not the description.

**The route that works is image-to-3D.** Produce a clean orthographic side-view reference of the correct animal, then generate from that image. Meshy follows a silhouette far more faithfully than it follows anatomy words, and a side view pins down exactly the two things text cannot: **tail length and spine angle.** Reference images can be commissioned, sourced from palaeoart under an appropriate licence, or drawn as flat silhouettes — a clean black shape on white is enough to fix the posture.

The prompt template below is still needed. It becomes the **texture prompt** and the secondary conditioning on the image, where it does work well.

### 4.3 Prompt template

Meshy prompts cap at 800 characters. The pattern that matches the existing assets in this repo:

```
<species name>, <real length> long <clade>, <anatomically specific description:
head shape, limb proportion, tail carriage, integument>, <posture>,
<stylization>, game-ready low-poly creature, clean quad topology,
neutral <pose> facing forward, no base, no scenery
```

Worked example, Utahraptor:

```
Utahraptor, 5.5 meter dromaeosaur, heavy build, deep boxy skull with
serrated teeth, thick muscular neck, short powerful forelimbs with three
clawed fingers, enormous curved sickle claw on second toe of each foot,
stiff horizontal tail, body covered in coarse shaggy proto-feathers with
bare scaly hands and feet, rust brown with dark dorsal banding,
horizontal running posture with tail counterbalanced, stylized realism,
game-ready low-poly creature, clean quad topology, neutral stance facing
forward, no base, no scenery
```

Verified working parameters:

```json
{
  "mode": "preview",
  "ai_model": "meshy-t2",
  "model_type": "smart-topology",
  "topology": "triangle",
  "target_polycount": 12000,
  "should_remesh": false,
  "target_formats": ["glb"],
  "auto_size": true
}
```

Then refine with `enable_pbr: true` and `texture_resolution: "2k"`. 2k is correct here — these are isometric-camera creatures and 4k is wasted bandwidth.

`pose_mode` stays omitted. `"a-pose"` and `"t-pose"` are humanoid concepts and forcing one on a theropod produces a man-in-a-dinosaur-suit silhouette.

**Meshy trained on the internet, and the internet's dinosaurs are 1993 movie dinosaurs.** Stating the feathers does help. Stating the posture does not. See §4.2.

### 4.4 Test generations on record

Task IDs, reproducible against the same key:

| Attempt | Task ID | Credits |
|---|---|---|
| 1 — meshy-t2, anatomical prompt | `01a0b154-f2ac-746c-9437-931104d6a615` | 5 |
| 2 — meshy-7 + standard | `01a0b155-ea88-702f-aec3-0fc6e292fbb1` | 20 |
| 3 — meshy-t2, bird-forward prompt | `01a0b155-f574-7285-b123-7b2a28d4e911` | 5 |

Attempt 1's GLB is kept at `game/assets/creatures/utahraptor/utahraptor_preview.glb` as the reference for what "wrong" looks like. Do not ship it.

Total spent proving this out: **30 credits of 3,925.** Cheap lesson, learned before generating 18 creatures.

### 4.5 Animation clip contract

Every creature ships the same named clips, because the existing `loadMeshy()` in `index.html` already maps clip names into an action dictionary and that pattern should be preserved:

| Clip | Source | Required |
|---|---|---|
| `idle` | library preset | yes |
| `walk` | auto-rig output | yes |
| `run` | auto-rig output | yes |
| `attack_primary` | text-to-motion | yes |
| `attack_heavy` | text-to-motion | yes — this is the telegraphed one |
| `hit_react` | library preset | yes |
| `knockdown` | text-to-motion | **yes — this is the capture window** |
| `death` | library preset | yes |
| `alert` | text-to-motion | bipeds only |
| `feed` | text-to-motion | ambient, optional |

At 3 credits per preset action and 10 credits per prime text-to-motion clip, a fully animated biped is roughly **50 credits**. Ten theropods is about 500 credits plus generation. Budget accordingly before starting.

Text-to-motion prompt example for `attack_heavy` on Utahraptor:

```
Large predatory dinosaur rears back on one leg, raises the other leg high
with claw extended, holds for a beat, then drives the claw down and rakes
backward in a single powerful stroke, landing heavily on both feet
```

That held beat is the telegraph. The Defense tree's roll window keys off it, exactly as Durango's yellow telegraph circles did.

### 4.6 Naming and file layout

The current repo root has 90 loose HTML snapshots and 40 MB of GLBs mixed together. Do not extend that pattern.

```
game/assets/creatures/<species>/
  <species>.glb            rigged mesh
  <species>_anim.glb       clips only, armature no skin
  <species>.json           stat block, drops, status, tame data
```

Species keys are lowercase scientific: `utahraptor`, `ankylosaurus`, `tyrannosaurus`. Variants are suffixed: `velociraptor_snow`, `triceratops_juvenile`. Variants reference the parent GLB and override material and scale only — they never get their own mesh file.

---

## 5. Tooling

### 5.1 Meshy MCP — working

`meshy-mcp-server` is configured in `~/.claude.json` with a valid key and reports healthy. The earlier `CONNECTION_CLOSED` was a revoked key: the server validates against `/v1/balance` at startup and exits on 401, so auth failures surface as connection failures. To diagnose the next one, curl the balance endpoint directly rather than reading the MCP error.

**MCP tools register at session start only.** After changing MCP config, restart Claude Code or the tools stay unavailable for that session even though `claude mcp list` shows Connected.

### 5.2 `tools/meshy.py` — the actual driver

A resumable CLI that walks species through preview → refine → rig → animate → fetch, reading specs from `game/data/creatures/<species>.json` and recording task IDs in `tools/meshy_state.json` so nothing regenerates twice. It carries the verified model/topology pairings from §4.1 and refuses to rig quadrupeds with an explanation rather than a server error.

```bash
export MESHY_API_KEY=...
python3 tools/meshy.py balance
python3 tools/meshy.py library --category Fighting
python3 tools/meshy.py preview utahraptor
python3 tools/meshy.py status
```

This is the path that matters more than the MCP server. Roster generation is a batch job over 18 specs, which is a script, not a conversation.

---

## 6. Build order

1. ~~Fix the Meshy key.~~ Done. Key live, 3,895 credits, `tools/meshy.py` driving it.
2. **Solve the reference-image problem first.** Nothing else matters until §4.2 has an answer, because text-to-3D produces anatomically wrong theropods and no amount of downstream rigging fixes a stub tail. Get one correct Utahraptor side view, run image-to-3D, confirm the silhouette, and only then scale up.
3. **Three theropods end to end** — Velociraptor, Deinonychus, Utahraptor. Same clade, so the reference work and prompt language transfer and the rigs validate each other.
4. **Bleed, Deep Bleed, and their counters**, wired to those three. One status family, fully readable on the model, before any breadth.
5. **Capture on Knockdown**, reusing Durango's stun → knockdown → net sequence and the five-tier 포획기술 ladder from the systems PRD §12.1.
6. **Protoceratops as the first quadruped**, which is also the first tame. This is where the web-UI rigging route gets proven, on the smallest quadruped in the roster.
7. **Fracture and Ankylosaurus.** Second status family, second quadruped.
8. Everything else, in tier order.

Do not generate all 18 creatures up front. The first three will teach you what the prompts need to say, and every model made before that lesson will be regenerated.
