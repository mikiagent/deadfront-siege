# Character stats, action costs and progression

## Eight base attributes
Strength, Dexterity, Agility, Endurance, Will, Intelligence, Perception, Charisma. Derived values include Attack, Defense, Accuracy, crafting abilities, gathering abilities, climate resistance, Energy and Fatigue.

## Character abilities
The wiki distinguishes category level and effective ability. Construction uses Endurance and Intelligence; Sewing and Tailoring use Charisma and Dexterity; Metal Processing uses Dexterity, Will and Intelligence. Food, equipment, titles and purchased skills modify abilities independently.

The restoration estimates a crafting-ability scale that resembles `35 + floor((average related attributes + 2×character level)/6)` for many crafts, with a different base for gathering categories. **This is not a verified original server formula**.

## Workload and costs
The wiki classifies the action-cost formulas below as preserved original calculations (some early-island discounts are fork changes):

| Action | Workload `e` | Fatigue cost |
|---|---|---|
| Gathering | `2.5 + (L−1)×0.25` | `0.4×sqrt(e)` |
| Crafting | `5 + (L−1)×0.5` or recipe effort | `2×sqrt(e)` |
| Construction | `10 + (L−1)` | `4×sqrt(e)` |
| Repair item | required performance ×0.8 | `2×sqrt(e)` |
| Repair building | required performance ×0.8 | `4×sqrt(e)` |

Energy cost is typically `0.7×e` before additional modifiers. The low-level-island Energy discounts documented by the restoration are developer changes.

## Representative abilities in character UI
Combat Power is a weighted sum of Attack, Defense, Accuracy, Evasion, Lethality and Penetration. Crafting Power and Gathering Power aggregate related ability scores; they are indicators, not substitutes for individual required-ability checks.

## Implementation guidance
Create one stat-modifier pipeline for equipment, food, temporary effects and skill tree nodes. Recalculate derived stats on source changes; never cumulatively reapply gear bonuses upon reload.

References: [Character stats](https://kghj76138.github.io/durango-homecoming-guide/en/stats.html), [Skills](https://kghj76138.github.io/durango-homecoming-guide/en/skills.html).
