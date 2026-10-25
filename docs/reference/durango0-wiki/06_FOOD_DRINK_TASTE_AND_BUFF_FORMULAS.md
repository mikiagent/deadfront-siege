# Food, drink, digestion, taste and buff rules

## Dataset
The food catalog documents 352 consumable entries, including plants, meats, cooked foods, drinks, medicine and event consumables. Entries show level-sensitive effects, latent Energy, instant-release rate, Fullness, taste and stat buffs.

## Consumption computation
`Instant Energy = modified latent Energy × clamp(modified instant ratio,0,1)`
`Delayed Energy = modified latent Energy − Instant Energy`

The restoration distributes delayed Energy over **300 seconds**, an estimated implementation detail. Item properties can add/multiply/overwrite individual fields; raw food and preparation tags can apply conditions or replace effects.

## Health, Life, Fatigue, Fullness, thirst
Health and Life are separately adjusted and clamped. Fullness can reach 120 (1.2× nominal 100) in the restoration and decays by 0.1/s; drinks with Water restore thirst. Food can modify fatigue directly, adjust maximum fatigue, or create timed statuses. These precise behavior details are marked estimated in the wiki where server rules are missing.

## Two food buff slots
- `food_ability`: most food stat buffs.
- `food_survival`: a small set such as Dutch Coffee, Cooked Rice and Prawn Skewer.

Same-slot buffs replace one another. A food with no applicable buff need not erase the prior buff. Original values of some stats were intentionally amplified in the 2026 fork; check for `Changed from original` labels.

## Examples
- Persimmon at Lv60: 29.7 immediate Energy, 19.8 delayed, Fullness 10 (current calculated wiki data).
- Raw meat can carry a stomach-pain status.
- Certain coffee preparations improve fatigue-related capacity rather than simply removing fatigue.
- Potent Fatigue Restorative is an event drink with Fatigue −1000 in the documented catalog.

## Taste
Seven taste channels are modeled: sweet, salty, sour, bitter, greasy, umami, astringent. Reconstructed thresholds can apply Delicious/Phenomenal Flavor or Horrible/Disgusting; repeated dominant flavors influence appetite. Original constants survive, but the score aggregation was reconstructed.

## Cooking and unique items
Fruit and berries must keep their individual item level, attributes, and processing state. Recipes must consume exact instances and inherit only permitted properties. Cooking can transform energy timing and remove raw-status tags. Expose a preview showing which buffs will survive.

References: [Food formulas](https://kghj76138.github.io/durango-homecoming-guide/en/food.html), [352-entry food catalog](https://kghj76138.github.io/durango-homecoming-guide/en/food-list.html).
