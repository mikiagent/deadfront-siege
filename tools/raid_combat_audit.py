#!/usr/bin/env python3
"""Deterministic expected-value audit of the current solo melee formulas.
Not a movement, dodge, pet, or rendered playtest. No gameplay data is changed.
"""
import json
from pathlib import Path
root = Path(__file__).resolve().parents[1] / 'game'
items = json.loads((root / 'data/items.json').read_text())['items']
boss = json.loads((root / 'data/creatures/tyrannosaurus.json').read_text())['stats']
# hunt.gd: armor subtraction, 5% floor, Melee60, behind, crit, tyrant resistance.
for item in items:
    if item.get('damage', 0) <= 0:
        continue
    damage = item['damage'] * (1 + item.get('stats_per_level', {}).get('damage', 0) * 60)
    if item.get('is_work_tool'):
        damage *= .45
    base = max(damage * .05, damage - boss['defense'] * .5)
    match = .6 if item.get('damage_type') == 'slashing' else 1
    for behind in (False, True):
        crit = .08 + .002 * 60 + (.20 if behind else 0)
        dps = base * 1.6 * match * (1.25 if behind else 1) * (1 + crit * .75) * .93 * item['attack_rate']
        print(f"{item['id']} L60 behind={behind}: damage={damage:.2f} expected_DPS={dps:.3f} uninterrupted_TTK={boss['hp']/dps/60:.1f} min")
print(f"Boss contact: {boss['attack'] - 20*.5:.0f} HP noncrit against 100 HP survivor; one landed hit kills.")
print('Baseline without gear: survivor defense20 and maxHP100. Equipped armor is now read by CreatureAttack.')
# Desired 5-minute best-case behind kill, neutral blunt, Melee60, rate1.
raw_needed = boss['hp'] / 300 / (1.6 * 1.25 * 1.30 * .93)
print(f"Minimum neutral blunt weapon damage at L60 for 5 min behind TTK (before dodge downtime): {boss['defense']*.5 + raw_needed:.2f}")
print('Weapon alone does not fix one-hit death; full equipped kit is audited below.')

armor_items = [i for i in items if i['id'] in ('raid_helm', 'raid_cuirass', 'raid_greaves')]
for level in (55, 60):
    armor = 20 + sum(i.get('armor_value', 0) * (1 + i.get('stats_per_level', {}).get('armor_value', 0) * level) for i in armor_items)
    hp = 100 + sum(i.get('health_bonus', 0) * (1 + i.get('stats_per_level', {}).get('health_bonus', 0) * level) for i in armor_items)
    hit = max(boss['attack']*.05, boss['attack']-armor*.5)
    print(f'Full kit L{level}: defense={armor:.0f}, maxHP={hp:.0f}; boss hit={hit:.1f}, crit={hit*1.5:.1f}; four critical hits kill, no tanking.')
