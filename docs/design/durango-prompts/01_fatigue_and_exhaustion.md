# Claude implementation prompt: Durango-inspired Fatigue and Exhaustion

Build the multi-layer survival-resource system of *Durango: Wild Lands* in my existing dinosaur survival game.

## Three resources, distinct purposes
- **Stamina:** rapidly regenerating short-term action resource used by sprinting, attacking, and defensive abilities.
- **Energy:** longer-term activity resource restored mainly by eating and related consumables.
- **Fatigue:** persistent exhaustion accumulating from working and exploration, removed by deliberate recovery instead of rapid passive regeneration.

## Fatigue gain
Award fatigue for traveling, gathering, crafting, processing, constructing, fighting or other strenuous work as appropriate. Make travel and workload costs configurable; higher-risk areas can add exposure. Environmental modifiers include heat, cold, wetness, poor clothing, dirtiness, and biome danger. Use one centralized modifier and fatigue application pipeline so work costs are not accidentally charged multiple times.

As **illustrative reconstruction-based initial coefficients**, consider `gathering_gain = 0.4 * sqrt(workload)`, `crafting_gain = 2 * sqrt(workload)`, and `construction_gain = 4 * sqrt(workload)`. These are starting values to verify and tune, not indisputable original values. Map workload consistently between action types.

## Thresholds and consequences
Use a configurable fatigue scale (initially 0–100). Suggested new-game thresholds: 0–24 rested, 25–49 slightly tired, 50–74 tired, 75–99 exhausted, 100 fully exhausted. Provide UI warnings and graduated stamina recovery/action penalties. At maximum, block demanding activities without trapping the player in an unrecoverable state. **These percentage thresholds are new balancing choices, not original Durango thresholds.**

## Recovery
Support tents, beds, comfortable furniture, campfires, safe camps, appropriate food and drinks, and special rest locations when they exist. Shelter quality, temperature protection, hygiene and conditions affect recovery. Allow deliberate rest interaction, status display and recovery rate prediction. Cleanliness and clothes should affect environmental penalties. Make all recovery methods data-driven.

## Integration and UX
Display separate stamina, energy and fatigue UI. Show fatigue meter with green/yellow/orange/red states, contextual fatigue-gain and recovery explanations, and alerts when crossing thresholds. Connect existing movement, harvesting, crafting, construction, food, resting, clothing and environmental systems. Save/load fatigue and currently active rest states. Handle offline recovery only if the project supports it, according to explicit rules.

## Test the vertical slice
Travel into a dangerous biome → gather and build → fatigue rises while stamina regenerates independently → fatigue penalties appear → reach a camp → rest/sleep and use appropriate recovery → resume work. Test clamping, save/reload, modifiers stacking, and no double-charging.

## Implementation standards
Inspect the existing project and its architecture first. Reuse existing gameplay, inventory, persistence, UI, and network components rather than introducing parallel systems. Implement working code in the project's language and engine, not just pseudocode. Separate definitions/configuration from saved runtime state. Make balancing parameters configurable. Preserve unique instance IDs and enforce atomic ownership/currency transitions. Where multiplayer exists, validate gameplay authoritatively and make retried operations idempotent. Include tests and summarize modified files, verified behavior, assumptions, and remaining limitations.

**Historical fidelity:** Durango: Wild Lands was updated during 2019; published guides can describe different revisions. Distinguish verified original mechanics from contemporary player reports, community reconstruction formulas, and new design choices. Do not claim illustrative values are exact original Nexon server values.
