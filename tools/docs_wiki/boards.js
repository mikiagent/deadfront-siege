/* Curated visual references. Paths point to source files, not copies. */
(function () {
  "use strict";

  const images = {
    art: [
      { title: "Canyon oasis and savanna", type: "Concept reference", path: "docs/reference/biome-concept-canyon-oasis-savanna.webp", doc: "docs/design/durango-prompts/26_biome_concept_art.md" },
      { title: "Volcanic wetland", type: "Concept reference", path: "docs/reference/biome-concept-volcanic-wetland.webp", doc: "docs/design/durango-prompts/26_biome_concept_art.md" },
      { title: "Savanna river delta", type: "Concept reference", path: "docs/reference/biome-concept-savanna-river-delta.webp", doc: "docs/design/durango-prompts/26_biome_concept_art.md" },
      { title: "Stegosaurus concept sheet", type: "Project concept", path: "assets/concept-art/creatures/stegosaurus/concept-sheet-v01.png", doc: "assets/concept-art/README.md" },
      { title: "Utahraptor concept sheet", type: "Project concept", path: "assets/concept-art/creatures/utahraptor/concept-sheet-v01.png", doc: "assets/concept-art/README.md" },
      { title: "Deinonychus concept sheet", type: "Project concept", path: "assets/concept-art/creatures/deinonychus/concept-sheet-v01.png", doc: "assets/concept-art/README.md" },
      { title: "Velociraptor concept sheet", type: "Project concept", path: "assets/concept-art/creatures/velociraptor/concept-sheet-v01.png", doc: "assets/concept-art/README.md" },
      { title: "Stegosaurus field-journal contact sheet", type: "Journal page", path: "assets/concept-art/journal/creatures/stegosaurus/contact-sheet-v01.jpg", doc: "assets/concept-art/README.md" },
      { title: "Stegosaurus journal hero", type: "Journal page", path: "assets/concept-art/journal/creatures/stegosaurus/stegosaurus-journal-hero-v01.png", doc: "assets/concept-art/README.md" },
      { title: "Survivor — current build model", type: "Model render", path: "artifacts/wiki/survivor-render.png", note: "Neutral Blender render of the player GLB the build uses (player_view.gd SURVIVOR_BASE_GLB at rest pose)." },
      { title: "Survivor v1 — image-to-mesh candidate", type: "Model render", path: "artifacts/wiki/survivor-v1-render.png", note: "Neutral Blender render of the newer survivor model (game/assets/characters/survivor_v1), shown in rest pose; the build still plays the current model above." },
      { title: "Coelophysis model input sheet", type: "Model input sheet", path: "game/assets/creatures/coelophysis/sheet.png" },
      { title: "Compsognathus model input sheet", type: "Model input sheet", path: "game/assets/creatures/compsognathus/sheet.png" },
      { title: "Deinonychus model input sheet", type: "Model input sheet", path: "game/assets/creatures/deinonychus/sheet.png" },
      { title: "Gallimimus model input sheet", type: "Model input sheet", path: "game/assets/creatures/gallimimus/sheet.png" },
      { title: "Megaloceros model input sheet", type: "Model input sheet", path: "game/assets/creatures/megaloceros/sheet.png" },
      { title: "Stegosaurus model input sheet", type: "Model input sheet", path: "game/assets/creatures/stegosaurus/sheet.png" },
      { title: "Stegosaurus (v1) model input sheet", type: "Model input sheet", path: "game/assets/creatures/stegosaurus/v1/sheet.png" },
      { title: "Tyrannosaurus model input sheet", type: "Model input sheet", path: "game/assets/creatures/tyrannosaurus/sheet.png" },
      { title: "Utahraptor model input sheet", type: "Model input sheet", path: "game/assets/creatures/utahraptor/sheet.png" },
      { title: "Velociraptor model input sheet", type: "Model input sheet", path: "game/assets/creatures/velociraptor/sheet.png" },
      { title: "Zebraceratops model input sheet", type: "Model input sheet", path: "game/assets/creatures/zebraceratops/sheet.png" },
    ],
    ui: [
      { title: "Inventory and bag instances", type: "Durango reference", path: "docs/reference/durango-bag-instances.webp", doc: "docs/design/durango-prompts/13_inventory_equipment_ui.md" },
      { title: "Character equipment", type: "Durango reference", path: "docs/reference/durango-character-gear.webp", doc: "docs/design/durango-prompts/13_inventory_equipment_ui.md" },
      { title: "Island map", type: "Durango reference", path: "docs/reference/durango-island-map.webp", doc: "docs/design/durango-prompts/15_island_map_scale.md" },
      { title: "HUD and day/night dial", type: "Durango reference", path: "docs/reference/durango-hud-daynight.webp", doc: "docs/design/durango-prompts/16_hud_day_night_dial.md" },
      { title: "Pet radial", type: "Durango reference", path: "docs/reference/durango-pet-radial.webp", doc: "docs/design/durango-prompts/23_target_select_pet_radial.md" },
      { title: "Market search", type: "Durango reference", path: "docs/reference/durango-market-buy-search.webp", doc: "docs/design/durango-prompts/14_island_market_ui.md" },
      { title: "Taming pen placement", type: "Durango reference · owner screenshot", path: "docs/reference/durango-placement-taming-pen-owner-2026-10-27.png", doc: "docs/design/durango-prompts/10_construction_building_quality.md", note: "Owner-provided reference, 2026-10-27. Shows the pen placement preview and domain-protection message." },
      { title: "Taming success and companion stats", type: "Durango reference · owner screenshot", path: "docs/reference/durango-taming-success-owner-2026-10-27.png", doc: "docs/design/durango-prompts/02_dinosaur_taming_and_companions.md", note: "Owner-provided reference, 2026-10-27. Shows the taming-success dialog and companion stats." },
      { title: "Skill selection and spent SP", type: "Durango reference · owner screenshot", path: "docs/reference/durango-skill-melee-owner-2026-10-27.png", doc: "docs/design/durango-prompts/03_leveling_progression_skill_trees.md", note: "Owner-provided reference, 2026-10-27. Shows the melee skill selection and spent SP." },
    ],
    screenshots: [
      { title: "Home camp and HUD", type: "Build screenshot · 2026-10-22", path: "artifacts/web-shader-soak/checkpoint-01.png", note: "A local web shader-soak capture. It is a dated test artifact, not a claim about the current build." },
      { title: "Web shader soak, second checkpoint", type: "Build screenshot · 2026-10-22", path: "artifacts/web-shader-soak/checkpoint-02.png", note: "A local test artifact that may disappear when generated artifacts are cleaned." },
    ],
  };
  const escape = (text) => String(text).replace(/[&<>"']/g, (c) => ({ "&": "&amp;", "<": "&lt;", ">": "&gt;", '"': "&quot;", "'": "&#39;" }[c]));
  const urlFor = (path) => "/api/image?path=" + encodeURIComponent(path);

  function card(item) {
    const url = urlFor(item.path);
    return `<figure class="board-card">
      <a class="board-image" href="${url}" target="_blank" rel="noopener noreferrer"><img src="${url}" alt="${escape(item.title)}" loading="lazy"><span class="board-missing" hidden>Image unavailable in this checkout</span></a>
      <figcaption><span class="board-kind">${escape(item.type)}</span><h3>${escape(item.title)}</h3>${item.note ? `<p>${escape(item.note)}</p>` : ""}
        <div class="board-source">${escape(item.path)}</div>${item.doc ? `<button class="board-doc" type="button" data-doc="${escape(item.doc)}">Read source context</button>` : ""}</figcaption>
    </figure>`;
  }

  function renderVisionBoard(kind, pane) {
    if (!pane || !Object.prototype.hasOwnProperty.call(images, kind)) return false;
    const headers = {
      art: ["Art vision board", "These project concepts and environment references are visual direction for discussion. Their presence here does not establish approval or imply the game already looks like them. The 3D previews below render model files from this checkout; a playable model is not the build using it."],
      ui: ["UI vision board", "These screenshots come from Durango: Wild Lands. They are design references, not screenshots of WildLands MMO or approved final designs."],
      screenshots: ["Build screenshots", "Dated captures show a particular test run, not a guarantee of today's implementation. Re-capture and cite the build revision when comparing changes."],
    };
    const [title, summary] = headers[kind];
    const embed = kind === "art";
    pane.innerHTML = `<div class="eyebrow">WildLands MMO · visual library</div><h1>${escape(title)}</h1><div class="article-tabs"><span>Visual references</span></div><p class="article-lead">${escape(summary)}</p><div class="board-grid">${images[kind].map(card).join("")}</div>${embed ? `<section class="model-embed"><h2>3D model previews</h2><p class="article-lead">Assets from the art pipeline under <code>game/assets</code>: static props, plus rigged models whose family animation files the previewer loads — pick a rigged model, then choose a clip under Animation. Species with a saddle offer a Mounted-view toggle, off by default: switching it on composes the survivor in the saddle on the mount — mount.json seat data, the species' game-scale factor where its GLB ships at source scale, and the rider playing the seated mount idle. Any asset can be marked like the articles: choose a status plus a note under Mark and save — seeded suggestions say so until a person saves over them.</p><p class="model-note">A preview renders a file on this checkout. It does not confirm that the current build loads the asset, and a rig's clip list follows its species folder rather than the game's animation map; planned animations with no file yet and cancelled designs are marked in the Animation list.</p><div class="model-host" data-model-viewer></div></section>` : ""}`;
    if (embed && typeof window.mountModelViewer === "function") {
      window.mountModelViewer(pane.querySelector("[data-model-viewer]"), {
        compact: true, eyebrow: "", heading: "",
        intro: "Drag to orbit. A preview shows the asset file itself and does not confirm it is used in the current build.",
      });
    }
    pane.querySelectorAll(".board-card img").forEach((img) => img.addEventListener("error", () => {
      img.hidden = true;
      img.nextElementSibling.hidden = false;
      img.closest("a").removeAttribute("href");
    }, { once: true }));
    pane.querySelectorAll(".board-doc").forEach((button) => button.addEventListener("click", () => {
      if (typeof window.openDoc === "function") window.openDoc("canon:" + button.dataset.doc);
    }));
    return true;
  }

  window.renderVisionBoard = renderVisionBoard;
})();
