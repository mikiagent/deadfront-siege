/* Local GLB viewer. The model listing and binaries remain on the wiki server.
   Exposes two entry points: renderModelViewer(pane) draws a full-pane viewer, and
   mountModelViewer(host, options) embeds the same viewer inside a page section
   (the art vision board mounts it with { compact: true }). Models appear in the
   owner's group order; selecting a rigged model fetches its species' clip files
   (libraries and per-clip exports alike) and lists every playable clip alongside
   the species' missing ("no file yet") and cancelled planned animations.
   Selected assets can be marked like the articles — status plus note — through
   /api/mark; marks show as suffixes in the asset dropdown and in a Mark row. */
(() => {
  'use strict';
  const el = (tag, className, text) => {
    const node = document.createElement(tag);
    if (className) node.className = className;
    if (text != null) node.textContent = text;
    return node;
  };

  window.mountModelViewer = async function mountModelViewer(host, options = {}) {
    const opts = Object.assign({
      eyebrow: 'Project assets',
      heading: '3D asset viewer',
      intro: 'Explore local model files. A preview shows the asset itself and does not confirm it is used in the current build.',
      compact: false,
    }, options);
    if (!host) return;
    host.replaceChildren();
    const section = el('section', opts.compact ? 'model-viewer is-embedded' : 'model-viewer');
    if (opts.eyebrow) section.append(el('div', 'eyebrow', opts.eyebrow));
    if (opts.heading) section.append(el(opts.compact ? 'h2' : 'h1', '', opts.heading));
    if (opts.intro) section.append(el('p', 'model-intro', opts.intro));
    const controls = el('div', 'model-controls');
    const filterLabel = el('label', '', 'Filter assets');
    const filter = el('input');
    filter.type = 'search'; filter.placeholder = 'Name or path'; filter.autocomplete = 'off';
    filterLabel.append(filter);
    const modelLabel = el('label', '', 'Model');
    const select = el('select'); select.setAttribute('aria-label', 'Choose a 3D asset');
    modelLabel.append(select);
    const reset = el('button', 'btn', 'Reset view'); reset.type = 'button'; reset.disabled = true;
    const zoomIn = el('button', 'btn', 'Zoom in'); zoomIn.type = 'button'; zoomIn.disabled = true;
    const zoomOut = el('button', 'btn', 'Zoom out'); zoomOut.type = 'button'; zoomOut.disabled = true;
    controls.append(filterLabel, modelLabel, zoomIn, zoomOut, reset);
    const status = el('p', 'model-status', 'Loading available models…'); status.setAttribute('role', 'status');
    const canvasWrap = el('div', 'model-canvas');
    const hint = el('p', 'model-hint', 'Drag to orbit. Scroll or pinch to zoom. Right-drag to pan.');
    const pathText = el('p', 'model-path');
    const animLabel = el('label', 'model-animation', 'Animation');
    const animRow = el('div', 'model-anim-row');
    const animations = el('select'); animations.disabled = true; animations.setAttribute('aria-label', 'Choose an animation clip');
    const play = el('button', 'btn', 'Play'); play.type = 'button'; play.disabled = true; play.setAttribute('aria-label', 'Play or pause the animation');
    animRow.append(animations, play);
    animLabel.append(animRow);
    const markLabel = el('label', 'model-mark', 'Mark');
    const markRow = el('div', 'model-mark-row');
    const markStatus = el('select'); markStatus.disabled = true; markStatus.setAttribute('aria-label', 'Choose a mark status');
    ['', 'review', 'rebuild', 'delete', 'redo-animations', 'ok']
      .map(value => value === '' ? ['Not marked', ''] : [{ review: 'Review', rebuild: 'Rebuild', delete: 'Delete', 'redo-animations': 'Redo animations', ok: 'OK (good as is)' }[value], value])
      .forEach(([label, value]) => { const option = el('option', '', label); option.value = value; markStatus.append(option); });
    const markNote = el('input'); markNote.type = 'text'; markNote.disabled = true; markNote.placeholder = 'Note (why)'; markNote.maxLength = 400;
    const markSave = el('button', 'btn', 'Save mark'); markSave.type = 'button'; markSave.disabled = true; markSave.setAttribute('aria-label', 'Save the model mark');
    const markState = el('span', 'model-mark-state', 'Choose an asset to mark.');
    markRow.append(markStatus, markNote, markSave, markState);
    markLabel.append(markRow);
    const mountLabel = el('label', 'model-mount', 'Mounted view');
    const mountRow = el('div', 'model-mount-row');
    const mountToggle = el('input'); mountToggle.type = 'checkbox'; mountToggle.disabled = true; mountToggle.setAttribute('aria-label', 'Compose the survivor on the saddle');
    const mountState = el('span', 'model-mount-state', 'The mounted view is off by default; an asset with saddle data can toggle it on.');
    mountRow.append(mountToggle, mountState);
    mountLabel.append(mountRow);
    section.append(controls, status, canvasWrap, hint, pathText, animLabel, markLabel, mountLabel);
    host.append(section);

    let models, THREE, GLTFLoader, OrbitControls;
    try {
      const [response, three, loader, orbit] = await Promise.all([
        fetch('/api/models'), import('/vendor/three/three.module.js'),
        import('/vendor/three/GLTFLoader.js'), import('/vendor/three/OrbitControls.js')
      ]);
      if (!response.ok) throw new Error(`Asset list returned HTTP ${response.status}`);
      const payload = await response.json();
      if (!Array.isArray(payload.models)) throw new Error('The asset list has an invalid format');
      models = payload.models.filter(m => typeof m.path === 'string' && typeof m.name === 'string');
      THREE = three; GLTFLoader = loader.GLTFLoader; OrbitControls = orbit.OrbitControls;
    } catch (error) {
      if (host.isConnected) status.textContent = `Could not start the 3D viewer: ${error.message}`;
      return;
    }
    if (!host.isConnected) return;
    if (!models.length) { status.textContent = 'No local GLB assets are available.'; select.disabled = true; return; }
    const rigged = models.filter(m => Array.isArray(m.anims) && m.anims.length);

    let renderer;
    try {
      renderer = new THREE.WebGLRenderer({ antialias: true, alpha: false });
    } catch (error) {
      status.textContent = 'WebGL is unavailable in this browser. Try a browser with WebGL enabled.';
      return;
    }
    renderer.setPixelRatio(Math.min(window.devicePixelRatio || 1, 2));
    renderer.setClearColor(0xf3f5f5);
    renderer.outputColorSpace = THREE.SRGBColorSpace;
    renderer.domElement.setAttribute('aria-label', '3D model preview');
    canvasWrap.append(renderer.domElement);
    const scene = new THREE.Scene();
    const camera = new THREE.PerspectiveCamera(40, 1, 0.001, 10000);
    camera.position.set(3, 2, 4);
    scene.add(new THREE.HemisphereLight(0xffffff, 0x757f78, 2.2));
    const sunlight = new THREE.DirectionalLight(0xffffff, 2.1); sunlight.position.set(4, 7, 6); scene.add(sunlight);
    const orbit = new OrbitControls(camera, renderer.domElement);
    orbit.enableDamping = true; orbit.dampingFactor = 0.1;
    const loader = new GLTFLoader();
    const clock = new THREE.Clock();
    let active = null, mountMixers = [], riderMixer = null, clips = [], loadId = 0, request = null, disposed = false;
    let extras = [];
    let initialPosition = null, initialTarget = null;
    const nodeNames = new Set();
    const disposeModel = (root) => {
      const geometry = new Set(), materials = new Set(), textures = new Set();
      root.traverse(obj => {
        if (obj.geometry) geometry.add(obj.geometry);
        const list = Array.isArray(obj.material) ? obj.material : obj.material ? [obj.material] : [];
        list.forEach(material => {
          materials.add(material);
          Object.values(material).forEach(value => { if (value && value.isTexture) textures.add(value); });
        });
      });
      geometry.forEach(g => g.dispose());
      materials.forEach(m => m.dispose());
      textures.forEach(t => { if (t.source?.data && typeof t.source.data.close === 'function') t.source.data.close(); t.dispose(); });
    };
    const dropExtras = () => {
      extras.forEach(root => { (root.parent || scene).remove(root); disposeModel(root); });
      extras = [];
    };
    const clearModel = () => {
      mountMixers.forEach(m => m.stopAllAction()); mountMixers = [];
      if (riderMixer) riderMixer.stopAllAction(); riderMixer = null;
      dropExtras();
      if (active) { scene.remove(active); disposeModel(active); active = null; }
      clips = []; nodeNames.clear();
      setAnimOptions(null);
      reset.disabled = zoomIn.disabled = zoomOut.disabled = true;
    };
    /* The clip dropdown: one row per playable clip plus a static-pose row, then
       the species' planned animations without files ("no file yet") and cancelled
       designs ("cancelled", hover carries the reason). Library clips that match
       no bone on the rig say so instead of promising a motion the mixer cannot
       bind. */
    let playing = false;
    const setPlaying = (value) => {
      playing = value;
      const scale = value ? 1 : 0;
      mountMixers.forEach(m => { m.timeScale = scale; });
      if (riderMixer) riderMixer.timeScale = scale;
      play.textContent = value ? 'Pause' : 'Play';
    };
    function setAnimOptions(playable, missing = [], cancelled = []) {
      animations.replaceChildren();
      if (playable === null) {
        animations.disabled = true; play.disabled = true; playing = false; play.textContent = 'Play';
        animations.append(el('option', '', 'No model loaded'));
        return;
      }
      const still = el('option', '', 'Static pose'); still.value = ''; animations.append(still);
      playable.forEach((row, index) => {
        const option = el('option', '', row.name + (row.ok ? '' : ' (no matching bones)'));
        option.value = String(index);
        if (row.note) option.title = row.note;
        animations.append(option);
      });
      (missing || []).forEach(name => {
        const option = el('option', '', `${name} (no file yet)`);
        option.disabled = true;
        option.title = 'Planned animation with no clip file on this line yet';
        animations.append(option);
      });
      (cancelled || []).forEach(item => {
        const option = el('option', '', `${item.name} (cancelled)`);
        option.disabled = true;
        option.title = item.note ? `Cancelled: ${item.note}` : 'Cancelled by design';
        animations.append(option);
      });
      animations.disabled = !playable.length;
      play.disabled = !playable.length;
      if (!playable.length) animations.selectedIndex = 0;
    }
    const trackMatches = (clip) => {
      const targets = new Set(clip.tracks.map(t => t.name.split('.')[0]));
      let matched = 0;
      targets.forEach(name => { if (nodeNames.has(name)) matched += 1; });
      return { matched, total: targets.size };
    };
    const collectClips = (inFile, sources, fallback) => {
      const rows = [];
      inFile.forEach((clip, index) => {
        const raw = (clip.name || '').replace(/^Armature\|/i, '').replace(/\|baselayer$/i, '');
        const name = raw && !/^clip\d+$/i.test(raw) ? raw : fallback;
        rows.push({ name: name || `Clip ${index + 1}`, clip, ok: trackMatches(clip).matched > 0 });
      });
      (sources || []).forEach(source => (source.clips || []).forEach((clip, index) => {
        const count = source.clips.length > 1 ? ` ${index + 1}/${source.clips.length}` : '';
        const match = trackMatches(clip);
        rows.push({ name: `${source.name}${count}`, clip, ok: match.matched > 0, matched: match.matched, total: match.total });
      }));
      return rows;
    };
    const resize = () => {
      const width = Math.max(1, canvasWrap.clientWidth), height = Math.max(1, canvasWrap.clientHeight);
      renderer.setSize(width, height, false); camera.aspect = width / height; camera.updateProjectionMatrix();
    };
    const observer = new ResizeObserver(resize); observer.observe(canvasWrap); resize();
    const cleanup = () => {
      if (disposed) return; disposed = true;
      if (request) request.abort(); observer.disconnect(); orbit.dispose(); clearModel(); renderer.dispose();
    };
    const tick = () => {
      if (!host.isConnected) { cleanup(); return; }
      requestAnimationFrame(tick);
      const delta = Math.min(clock.getDelta(), 0.1);
      mountMixers.forEach(m => m.update(delta));
      if (riderMixer) riderMixer.update(delta);
      orbit.update(); renderer.render(scene, camera);
    };
    tick();

    const GROUPS = [['player', 'Player'], ['creatures', 'Creatures'], ['nature', 'Nature'], ['props', 'Props'], ['generated', 'Generated'], ['other', 'Other']];
    const optionLabel = (m) => `${m.name}${m.variant ? ` (${m.variant} regional variant)` : ''} — ${m.path}${m.mark ? `  ·  mark: ${m.mark.status || 'noted'}` : ''}`;
    const refreshOption = (m) => {
      const option = Array.from(select.options).find(o => o.value === m.path);
      if (option) { option.textContent = optionLabel(m); option.title = m.mark?.notes || ''; }
    };
    const populate = () => {
      const term = filter.value.trim().toLowerCase();
      const matching = models.filter(m => `${m.name} ${m.path}`.toLowerCase().includes(term));
      const current = select.value;
      select.replaceChildren();
      const placeholder = el('option', '', matching.length ? `Choose an asset (${matching.length})` : 'No matching assets');
      placeholder.value = ''; select.append(placeholder);
      const buckets = new Map();
      matching.forEach(m => {
        const key = GROUPS.some(group => group[0] === m.group) ? m.group : 'other';
        if (!buckets.has(key)) buckets.set(key, []);
        buckets.get(key).push(m);
      });
      GROUPS.forEach(([key, label]) => {
        const items = buckets.get(key);
        if (!items) return;
        const group = document.createElement('optgroup'); group.label = label;
        items.forEach(m => {
          const option = el('option', '', optionLabel(m));
          option.value = m.path;
          if (m.mark?.notes) option.title = m.mark.notes;
          group.append(option);
        });
        select.append(group);
      });
      if (matching.some(m => m.path === current)) select.value = current;
      select.disabled = !matching.length;
    };
    filter.addEventListener('input', populate); populate();
    const families = rigged.length ? ` ${rigged.length} of them are rigged with playable animation files.` : '';
    status.textContent = `${models.length} local assets available.${families} Choose one to preview.`;

    const frameModel = (root) => {
      root.updateMatrixWorld(true);
      const box = new THREE.Box3().setFromObject(root);
      if (box.isEmpty()) throw new Error('The model has no visible geometry to frame');
      const size = box.getSize(new THREE.Vector3());
      const center = box.getCenter(new THREE.Vector3());
      const maxSize = Math.max(size.x, size.y, size.z);
      if (!Number.isFinite(maxSize) || maxSize <= 0) throw new Error('The model bounds could not be calculated');
      const distance = maxSize / (2 * Math.tan(THREE.MathUtils.degToRad(camera.fov / 2))) * 1.6;
      camera.near = Math.max(distance / 1000, 0.0001); camera.far = Math.max(distance * 100, 100);
      camera.position.copy(center).add(new THREE.Vector3(distance * 0.8, distance * 0.55, distance));
      camera.updateProjectionMatrix(); orbit.target.copy(center);
      orbit.minDistance = Math.max(distance / 50, 0.0001); orbit.maxDistance = distance * 50;
      orbit.update(); initialPosition = camera.position.clone(); initialTarget = center.clone();
    };
    const zoom = (factor) => {
      const offset = camera.position.clone().sub(orbit.target).multiplyScalar(factor);
      const length = THREE.MathUtils.clamp(offset.length(), orbit.minDistance, orbit.maxDistance);
      if (offset.lengthSq()) camera.position.copy(orbit.target).add(offset.setLength(length));
      orbit.update();
    };
    zoomIn.onclick = () => zoom(0.8); zoomOut.onclick = () => zoom(1.25);
    reset.onclick = () => { if (initialPosition && initialTarget) { camera.position.copy(initialPosition); orbit.target.copy(initialTarget); orbit.update(); } };
    const startRow = (row) => {
      if (!mountMixers.length || !row || !row.clip) return;
      mountMixers.forEach(m => { m.stopAllAction(); m.clipAction(row.clip).reset().play(); });
      setPlaying(true);
      status.textContent = `Playing ${row.name}. ${row.ok ? '' : 'No bones matched this clip, so the mesh stays still.'}`;
    };
    animations.onchange = () => {
      if (!mountMixers.length) return;
      if (animations.value === '') { mountMixers.forEach(m => m.stopAllAction()); setPlaying(false); return; }
      startRow(clips[Number(animations.value)]);
    };
    play.onclick = () => {
      if (!mountMixers.length || play.disabled) return;
      if (playing) { setPlaying(false); return; }
      if (!animations.value) {
        const first = Array.from(animations.options).find(option => !option.disabled && option.value !== '');
        if (first) animations.value = first.value;
      }
      startRow(clips[Number(animations.value)]);
    };
    /* The mark row: article-style annotation on any listed asset, saved by
       /api/mark into state.json beside the doc marks. A seeded suggestion
       clears as soon as a person saves (or clears) a mark of their own. */
    let current = null;
    const showMark = () => {
      if (!current) {
        markStatus.disabled = markNote.disabled = markSave.disabled = true;
        markStatus.value = 'review'; markNote.value = '';
        markState.textContent = 'Choose an asset to mark.';
        return;
      }
      markStatus.disabled = markNote.disabled = markSave.disabled = false;
      markStatus.value = current.mark?.status || 'review';
      markNote.value = current.mark?.notes || '';
      markState.textContent = current.mark
        ? `Marked ${current.mark.status || 'with a note'}${current.mark.by === 'seed' ? ' (' + current.mark.by + ' suggestion)' : ''}.`
        : 'Not marked yet.';
    };
    markSave.onclick = async () => {
      if (markSave.disabled || !current) return;
      const target = current;
      markSave.disabled = true;
      markState.textContent = 'Saving the mark…';
      try {
        const res = await fetch('/api/mark', {
          method: 'POST',
          headers: { 'Content-Type': 'application/json' },
          body: JSON.stringify({ kind: 'model', path: target.path, status: markStatus.value, note: markNote.value }),
        });
        if (!res.ok) throw new Error(`HTTP ${res.status}`);
        const data = await res.json();
        if (data.mark) { target.mark = data.mark; markState.textContent = `Marked ${data.mark.status || 'with a note'}.`; }
        else { delete target.mark; markState.textContent = 'Mark cleared.'; }
        refreshOption(target);
      } catch (error) {
        markState.textContent = `Could not save the mark: ${error.message}`;
      }
      markSave.disabled = false;
    };
    /* The mounted view: the survivor composed onto the species saddle in the
       space the engine intends — mount.json's rider_in_mount for the armature
       root, the species' game-scale factor (if the GLB ships at source scale)
       applied to the mount side, and the rider playing the family's seated
       mount idle instead of the standing idle. A default-off toggle switches
       it on; toggling off restores the bare asset. */
    let composing = false;
    const tearMount = () => {
      if (mountMixers.length > 1) { mountMixers.slice(1).forEach(m => m.stopAllAction()); mountMixers = [mountMixers[0]]; }
      if (riderMixer) { riderMixer.stopAllAction(); riderMixer = null; }
      dropExtras();
      if (active) {
        active.scale.setScalar(1);
        try { frameModel(active); } catch (_) { /* framing is cosmetic here */ }
      }
    };
    const composeMount = async () => {
      const target = current;
      if (composing || !target || !target.mount || !mountMixers.length) return;
      composing = true;
      const id = loadId;
      mountState.textContent = 'Composing the mounted view…';
      try {
        const factor = target.mount.scale?.game_m_per_source || 1;
        const signal = request?.signal;
        const loadPart = async (path) => {
          const res = await fetch('/api/model?path=' + encodeURIComponent(path), { signal });
          if (!res.ok) throw new Error(`HTTP ${res.status}`);
          return loader.parseAsync(await res.arrayBuffer(), '');
        };
        const [saddleId, riderId] = await Promise.all([loadPart(target.mount.saddle), loadPart(target.mount.rider)]);
        if (!host.isConnected || !mountToggle.checked || id !== loadId) { disposeModel(saddleId.scene); disposeModel(riderId.scene); return; }
        active.scale.setScalar(factor);
        active.add(saddleId.scene);
        mountMixers.push(new THREE.AnimationMixer(saddleId.scene));
        extras.push(saddleId.scene);
        const riderRoot = riderId.scene;
        riderRoot.matrixAutoUpdate = false;
        riderRoot.matrix.fromArray(target.mount.rider_in_mount);
        /* The mount GLB is scaled to game size here, but the rider keeps its own
           authored size — the engine's rider_transform() drops the mount's
           scale K (equip_mount_lab fails if it leaks), so bake the inverse into
           the rider root: position stays K × mount-space, basis returns to 1. */
        if (factor !== 1) riderRoot.matrix.scale(new THREE.Vector3(1 / factor, 1 / factor, 1 / factor));
        active.add(riderRoot);
        extras.push(riderRoot);
        riderMixer = new THREE.AnimationMixer(riderRoot);
        const riderEntry = models.find(m => m.path === target.mount.rider);
        const riderAnims = riderEntry?.anims || [];
        const norm = (s) => s.toLowerCase().replace(/[^a-z0-9]+/g, '');
        const riderClip = riderAnims.find(a => norm(a.name) === 'mountidle') || riderAnims.find(a => norm(a.name) === 'idle') || null;
        if (riderClip) {
          const riderLoaded = await loadPart(riderClip.path);
          if (!host.isConnected || !mountToggle.checked || id !== loadId) { disposeModel(riderLoaded.scene); return; }
          const riderIdle = (riderLoaded.animations || [])[0];
          if (riderIdle && riderMixer) riderMixer.clipAction(riderIdle).play();
        }
        frameModel(active);
        mountState.textContent = `Mounted: the survivor (${riderClip && norm(riderClip.name) === 'mountidle' ? 'seated mount idle' : riderClip ? 'standing idle' : 'no rider clip'}) on the saddle at game size${factor !== 1 ? ` (mount scaled ×${factor.toFixed(2)}, rider kept at its own scale)` : ''}.`;
      } catch (error) {
        if (!host.isConnected || error.name === 'AbortError') return;
        tearMount();
        mountState.textContent = `Mount composition failed: ${error.message}`;
      } finally {
        composing = false;
      }
    };
    const showMount = () => {
      if (current?.mount) {
        mountToggle.disabled = false;
        if (!mountToggle.checked) mountState.textContent = 'Saddle data available — toggle on for the mounted view.';
      } else {
        mountToggle.disabled = true;
        mountToggle.checked = false;
        tearMount();
        mountState.textContent = 'No mount data for this asset (not rideable, or no mount.json).';
      }
    };
    mountToggle.onchange = () => {
      if (!current?.mount) return;
      if (mountToggle.checked) composeMount();
      else tearMount();
    };
    select.onchange = async () => {
      const path = select.value;
      const entry = models.find(m => m.path === path) || {};
      current = path ? entry : null;
      showMark();
      mountToggle.checked = false;
      showMount();
      if (!path) return;
      const id = ++loadId;
      if (request) request.abort();
      request = new AbortController();
      const signal = request.signal;
      clearModel();
      pathText.textContent = path;
      status.textContent = 'Loading model…';
      let sources = [];
      try {
        const res = await fetch('/api/model?path=' + encodeURIComponent(path), { signal });
        if (!res.ok) throw new Error(`HTTP ${res.status}`);
        const data = await res.arrayBuffer();
        const gltf = await loader.parseAsync(data, '');
        if (!host.isConnected || id !== loadId) { disposeModel(gltf.scene); return; }
        active = gltf.scene;
        let meshes = 0; active.traverse(obj => { if (obj.isMesh) meshes++; });
        if (!meshes) throw new Error('The file contains no renderable mesh');
        scene.add(active); frameModel(active);
        active.traverse(obj => { if (obj.name) nodeNames.add(obj.name); });
        status.textContent = 'Fetching animation files…';
        const libraries = await Promise.allSettled((entry.anims || []).map(a =>
          fetch('/api/model?path=' + encodeURIComponent(a.path), { signal })
            .then(async r => {
              if (!r.ok) return { source: a, gltf: null };
              const parsed = await loader.parseAsync(await r.arrayBuffer(), '');
              return { source: a, gltf: parsed };
            })));
        if (!host.isConnected || id !== loadId) {
          libraries.forEach(r => { if (r.status === 'fulfilled' && r.value.gltf) disposeModel(r.value.gltf.scene); });
          return;
        }
        const lost = [];
        sources = libraries.flatMap(r => {
          if (r.status !== 'fulfilled') { if (r.reason?.name !== 'AbortError') lost.push('a clip file'); return []; }
          if (!r.value.gltf) { lost.push(r.value.source.name); return []; }
          return [{ ...r.value.source, clips: r.value.gltf.animations || [] }];
        });
        clips = collectClips(gltf.animations || [], sources, entry.name ? `${entry.name} (in file)` : '');
        mountMixers = [new THREE.AnimationMixer(active)];
        setAnimOptions(clips, entry.missing, entry.cancelled);
        reset.disabled = zoomIn.disabled = zoomOut.disabled = false;
        const clipNote = clips.length ? ` ${clips.length} animation${clips.length === 1 ? '' : 's'} ready under the Animation dropdown.` : ' No animation clips for this asset.';
        const planned = [
          entry.missing?.length ? `${entry.missing.length} planned animation${entry.missing.length === 1 ? '' : 's'} missing` : '',
          entry.cancelled?.length ? `${entry.cancelled.length} cancelled design${entry.cancelled.length === 1 ? '' : 's'} marked` : '',
        ].filter(Boolean).join(', ');
        const plannedNote = planned ? ` Animation design: ${planned} (see the Animation list).` : '';
        const mountText = '';
        const bad = lost.filter(Boolean).length ? ` ${lost.filter(Boolean).length} clip file${lost.filter(Boolean).length === 1 ? '' : 's'} unreadable.` : '';
        status.textContent = `Loaded ${entry.name || 'model'}.${clipNote}${plannedNote}${mountText}${bad}`;
      } catch (error) {
        if (!host.isConnected || id !== loadId || error.name === 'AbortError') return;
        clearModel(); status.textContent = `Could not load this model: ${error.message}`;
      }
    };
  };

  /* Full-pane default kept for compatibility. */
  window.renderModelViewer = function renderModelViewer(pane) {
    return window.mountModelViewer(pane);
  };
})();
