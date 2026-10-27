# WildLands MMO | Vision workshop

> **Status:** Open product discussion  
> **Vision reference:** [WildLands MMO Game Vision](WildLandsMMO_Game_Vision.md)  
> **Purpose:** Record decisions about the player's experience, the multiplayer shape and the recurring gameplay loop without conflating those decisions with the current implementation.

## What is already established

WildLands MMO is an isometric prehistoric survival and civilization-building RPG with a protected, persistent private home, a personal human character, evolving tribe members, dinosaurs, differentiated materials, processing and physical logistics. Optional endgame PvPvE creates meaningful risk at exposed remote settlements, never at the private home. Player specialization in craftsmanship, trading and animal breeding should be as valid as combat progression.

## Vision decisions: Round 1 confirmed

| ID | Owner's choice | Player-visible meaning | Still open |
|---|---|---|---|
| **V-01** | **D: A combination** | The first 20 to 30 minutes introduce survival danger, immediately useful gathering/crafting and a meaningful dinosaur encounter/bonding possibility in a coherent opening | First tame method, exact sequence, pressure, onboarding freedom |
| **V-02** | **C: Open sandbox** | A normal 30 to 60 minute session is self-directed. Exploring, breeding, building, manufacturing, trade and social play all count as legitimate ways to spend time; no fixed expedition/home quota | Progress signals, profession rewards, offline cadence, viable short sessions |
| **V-03** | **C: Hybrid world** | Protected personal home islands, expedition instances, public shared zones and social/trading hubs, plus optional frontier settlements coexist in one connected player economy | How frequently strangers meet, co-op/party boundaries, public persistence, guild roles |

These choices determine the **structure of player freedom** without locking details the owner has not decided. They complement, rather than override, the existing confirmed private-home safety and PvPvE rules in [decisions.md](decisions.md).

## Sharpened gameplay loops

The first half hour introduces **three mutually reinforcing promises**: "I can survive this world," "what I make matters," and "these dinosaurs can become companions or threats." The exact tutorial chronology and whether the first animal is actually tamed in that window are not yet determined.

After onboarding, the game does **not** prescribe a session pattern. Players may spend their time in several interconnected loops:

| Player-chosen loop | Experience |
|---|---|
| **Expedition** | Prepare → travel → face risk → gather, hunt, tame or discover → extract → keep, craft or sell |
| **Maker** | Find or buy unusual inputs → process → assemble quality goods → equip, deploy or trade |
| **Breeder** | Discover individuals → care and train → select traits → develop a lineage or specialist role |
| **Settlement** | Plan → gather or buy inputs → build → assign and support real workers → gain new capabilities |
| **Social/economic** | Visit a shared place → meet, cooperate or trade → invest gains in a chosen pursuit |

An expedition is a signature cycle, **not** a required daily or hourly activity. Private-base progress and trade-only sessions are real gameplay. These paths depend on one another economically, even when individual players do not personally participate in all of them.

The hybrid world makes these loops visible across spaces: safe homes for permanent creation, instanced expeditions for focused adventure, shared hubs and public zones for meeting others, and optional PvPvE settlements for competitive stakes.

### Round 1 results and interpretation

- **V-01: D.** A balanced opening including survival, crafting and dinosaur encounters; no one subsystem owns the entire introduction.
- **V-02: C.** Self-directed sandbox sessions. Expeditions are one available loop, not a daily checklist.
- **V-03: C.** Hybrid MMO: private homes, instanced expeditions, shared public locations/hubs and optional frontier settlements.

### Round 2: highest-leverage questions

**V-04: What is the first dinosaur bonding experience?** Does a player capture a wild creature with meaningful effort, receive an early guided introduction that still requires taming, rescue a creature, or begin with one? The choice sets the emotional payoff and progression cadence of onboarding.

**V-07: What happens when a PvE expedition fails?** How much carried gear, cargo, companions and invested effort can be lost or recovered, and what does failure feel like for a new versus experienced player? This defines the risk that makes preparation and extraction matter.

**V-09: How important is cooperation?** Can a determined solo player enjoy the complete non-PvP game, with cooperation mainly improving efficiency/social experience, or should some content deliberately require multiple human players? The hybrid world needs a recognizable answer.

### Follow-up themes once these are decided

| ID | Topic | Why it changes the player experience | State |
|---|---|---|---|
| V-04 | First tame | Wild capture, rescue, guided-but-earned tame, starting companion? | **NEXT: Round 2** |
| V-05 | The protagonist | Does the player begin with one character and eventually control descendants, or choose a party-style avatar early? | OPEN |
| V-06 | Economic independence | How much can an explorer, builder, breeder or merchant progress without PvP? | Direction confirmed, specifics OPEN |
| V-07 | Risk and death | What happens to inventory, mounts and crew on failed PvE expedition? | **NEXT: Round 2** |
| V-08 | Expedition resets | Can a player predict resets, and what percentage of unextracted building materials reaches the recovery vault? | OPEN; conflicting source material |
| V-09 | Social play | Solo-friendly with optional cooperation, tightly coupled co-op, or guild-driven MMO? | **NEXT: Round 2** |
| V-10 | Tribe terminology | Is a "tribe" the personal NPC population or a multi-player guild? | OPEN |
| V-11 | World cadence | How does food spoilage, breeding and island reset work for someone who cannot log in daily? | OPEN |
| V-12 | Tech ceiling | Primarily primitive weapons, early metal, optional firearms, mechanical turret sophistication? | OPEN |
| V-13 | Progression cap | Is level 60 the permanent character cap or a major gateway to further progression? | OPEN |
| V-14 | Naming | WildLands MMO vs WildLandsMMO vs a more distinctive title. | Working title only |

## Decision entries

**2026-10-27, owner-confirmed vision answers:**

- **V-01: D, A combination.** Onboarding should expose survival, crafting and dinosaurs together. Neither a fixed scripted sequence nor the timing of a successful first tame was selected.
- **V-02: C, Open sandbox.** Typical play is goal-driven without a mandated 30 to 60 minute itinerary. Peaceful industry, breeding, exploration, trade and other chosen goals remain legitimate.
- **V-03: C, Hybrid world.** Private homes, instanced expeditions, shared public zones, social/trading hubs and optional frontier settlements are intended to coexist.

**Implementation status:** These are confirmed *desired game experience* decisions, not proof that multiplayer infrastructure, tutorials or every sandbox profession is currently implemented. The working-title rebrand affects vision documents only; it does not rename the current Godot project, game assets, repository or deployment.

**Next owner answers requested:** V-04 first tame; V-07 expedition failure; V-09 solo versus cooperative design. Each should be recorded without silently inventing drop rates, revive costs, instance sizes, or party requirements.

## How this document evolves

Each resolved question should gain a short statement of the intended player-visible rule and any remaining uncertainty. Experimental numbers and optional suggestions remain clearly marked as proposals. Later questions should be selected based on the prior answers, instead of asking the entire list at once.