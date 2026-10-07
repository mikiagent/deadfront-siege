# Saved material attributes and stacking, October 7

Actual saved training bag accumulated many same-quality branch stacks. JSON parses attribute level1 as float1.0. ItemStack._attrs_equal compared values by str(), so a saved float stamp differed from a fresh integer stamp and prevented merging. Fix compares two numeric values numerically; nonnumeric values retain exact string comparison and numeric-vs-string is rejected. No material quality promotion, merging across distinct levels, count/capacity or XP change.

Godot4.7 full suite PASS, including JSON-roundtrip branch merging with fresh integer-stamped branch, different-quality rejection and numeric-string rejection. This is a serialization/stack equality unit test, not earned bag cleanup: existing duplicate stacks are not silently consolidated.

Earned saved endpoint before fix: Survival60/Gathering37/Processing34/WeaponTools20/Tailoring20. Paid volcanic gate journey earlier verified Survival55/5Tdebit/free return through button callbacks, but home camp retention failed on travel and remains a separate blocker. Do not describe the journey as complete or camp/material continuity as retained.
