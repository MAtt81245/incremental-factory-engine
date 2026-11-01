# Pure Incremental Factory Engine

A reusable Roblox incremental engine in strict Luau, synced with Argon. Everything a game has is data in `IncrementalConfig.luau`. That covers currencies, upgrades, prestige tiers, loops, runes, trails, collectibles and products. The services stay the same from game to game.

## Setup

1. Run `argon serve` in this folder (it reads `default.project.json`) and connect from Studio.
2. Press Play. `WorkspaceBootstrapper` builds `Workspace.IncrementalTestZone` if it is missing. The Output should show `Self-test PASSED (109 checks)`.
3. DataStores: without "Enable Studio Access to API Services", profiles live in memory, so nothing is saved. A toast tells you which mode is active.

## Files

| File | Role |
|---|---|
| `ReplicatedStorage/Modules/BigNum.luau` | Mantissa/exponent numbers past 1.79e308, formatting K…Ce, then scientific notation |
| `ReplicatedStorage/Modules/IncrementalConfig.luau` | The game's data and shared lookups (`ById`, `DescribeRequirement`) |
| `ReplicatedStorage/Modules/Network.luau` | Remotes, rate limiting, shared snapshot types |
| `ServerScriptService/Services/DataService.luau` | Profiles, session lock, retries, autosave, BindToClose |
| `ServerScriptService/Services/EvaluatorService.luau` | Pure math: stats, caps, exponents, thresholds, visibility |
| `ServerScriptService/Services/ActiveLoopsService.luau` | Mining, refinery, combat, runes, collectibles, trails |
| `ServerScriptService/Services/IncrementalService.luau` | Tick loop, purchases, EL autobuy, prestige, binding, monetization |
| `ServerScriptService/Services/WorkspaceBootstrapper.luau` | Greybox test zone |
| `ServerScriptService/ServerMain.server.luau` | Boot order and self-test |
| `StarterPlayer/StarterPlayerScripts/UIController.client.luau` | HUD, billboards, local visibility |

## Hooking your own map

Tag any part or model and set its attributes. The engine binds it at runtime.

| Tag | Attribute | Notes |
|---|---|---|
| `IncrementalButton` | `UpgradeId` | Step on it to buy 1 level; the E prompt buys max |
| `MineNode` | `NodeType` | Click it or use the prompt |
| `RefineryMachine` | `RecipeId` | The prompt starts and pauses the recipe |
| `RuneAltar` | `RuneBannerId` | E rolls x1, R rolls x10 |
| `CombatArena` (model) | `ArenaId` | Needs a child part named `Enemy` |
| `UnlockableZone` (model) | `ZoneId` | Parts with `IsBarrier = true` are solid only while the zone is locked |
| `SecretCollectible` | `CollectibleId` | Touch or click it |

## Testing each loop in the greybox zone

You spawn at the center. The panel opens from the tab buttons on the left.

1. **Passive income and pads (green, west).** Cash rises at 1/s. Step on the Coin Press pad. Polished Coins unfolds at Coin Press Lv 3, and a toast appears. Gem Refraction appears at 50 Cash. Buy it to unfold Gems (cross-currency: 0.2 × CashRate^0.5).
2. **Math types.** Prismatic Lens raises the Gem exponent. Press Expansion (paid in Gems) raises Coin Press's max level. Vault Resonance unfolds at 1K Cash. It is free, but it only activates while you hold 2.5K Cash, and nothing is spent.
3. **Mining (grey, east).** Click the Stone nodes. Hitting the same node type again within 3 s builds a streak (+5% per hit). Mastery XP fills the bar in the Activity tab. Copper nodes unfold at 10 Stone.
4. **Refinery (orange, north).** At 5 Copper Ore the smelter unfolds. Every 3 s it turns 5 ore into 1 bar. The charge multiplier rises from x1 to x3 over 5 minutes after each reset.
5. **Combat (red, south).** The arena unfolds at 300 Cash. Stand on it and click the golem. Each kill pays Fight Coins and respawns the golem with x1.22 HP. If you lose, the golem heals and nothing else is lost.
6. **Runes (purple, northwest).** The altar unfolds with Gems. Use E for x1 and R for x10. You can set auto-delete in the Runes tab.
7. **Rebirth.** The Prestige tab unfolds at 500 Cash, and you can rebirth at 1K. Rebirth unfolds the Crystal Caves zone: the red barrier in the east disappears, and you get Crystal nodes plus the Crystal Polisher. In the simulation, the first rebirth came after about 3 minutes.
8. **Permanent lock.** With Rebirth Points, the upgrade card shows "Lock: 3 ♻". That upgrade then never resets.
9. **Transcend.** This needs 2 Rebirths and 25 RP. Buy Expend-Less Protocol: eligible tier-1 upgrades become free and are auto-bought (there is an Auto-Buy toggle). Memory Crystal protects nodes #1–#N.
10. **Milestone.** Hold 5 Shards. You get no currency, but Milestone 1 makes 1% of pending RP per second and gives permanent EL.
11. **Collectibles and trails.** There are 4 glowing orbs; the hints are in the Trails & Boosts tab. Trails, collectibles, runes and boost timers never reset.
12. **Boosts and gamepasses.** All IDs are 0, so in Studio the buttons grant the item for free. Set real `ProductId` and `GamePassId` values before you publish.

## Before publishing

- Put real product and gamepass IDs in `Monetization` (they are all 0 now). Set `StudioFreePurchases` to false if you don't want free test grants in Studio.
- Balance the numbers with real players. The dataset is tuned for a fast test, not for retention.
