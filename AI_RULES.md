# AI Rules
Always read ARCHITECTURE.md and SYSTEM_INDEX.md before making changes.
## Core Principles

1. Treat `.legacy.luau` scripts as active production code, not as archival leftovers.
2. Keep the server authoritative. Client scripts may preview, visualize, or request actions, but the server must validate and mutate real gameplay state.
3. Use `BuildingConfig.luau` as the single source of truth for unit stats, building stats, recruit lists, supply, energy, and upgrade paths.
4. Preserve the current split between orchestration scripts and focused modules instead of collapsing behavior into one large script.
5. **No Automated Testing:** The project developer prefers to perform testing entirely manually in Play mode. Do NOT suggest, write, or add automated testing frameworks, scripts, or unit tests under any circumstances.

## Match Flow Rules

1. Do not bypass `GameManager.legacy.luau` for creating new shared remotes or bindables unless you are deliberately replacing that bootstrap role everywhere.
2. Keep `ConnectionManager.luau`, `RoundManager.luau`, `GameState.luau`, `HQManager.luau`, and `SpawnManager.luau` in sync when changing round-start or reconnect behavior.
3. Preserve the six-slot HQ model. Many systems assume HQ indices, faction slots, treasury storage, and reclaim logic are keyed by HQ index.
4. When changing victory behavior, verify `VictoryChecker.luau`, HQ destruction handling, and the client victory UI all still agree on the end-of-round contract.

## Data Contract Rules

1. Treat frequently used attributes as public API: `Owner`, `AllianceID`, `Type`, `Health`, `MaxHealth`, `Damage`, `Range`, `AttackCooldown`, `IsUnderConstruction`, `IsUpgrading`, `Class`, `Capacity`, `Supply`, `Passengers`, and `GarrisonCount`.
2. If you add a new gameplay attribute, update every place that creates, copies, restores, upgrades, inspects, or serializes that object.
3. Keep ownership propagation consistent. If a player/building/unit can change owner, update both `Owner` and `AllianceID` where applicable.
4. Keep `Stats` and `PlayerStats` as the canonical per-player economy/combat stores. Do not invent parallel stat containers.

## Building-System Rules

1. Keep building placement validation mirrored between `PlacementClient.local.luau` and `BuildingSpawner.luau`. Client validation is for feedback; server validation is authoritative.
2. When adding a building, update all relevant paths:
   `BuildingConfig.luau`, `UIBuildMenu.luau`, `PlacementClient.local.luau`, `BuildingSpawner.luau`, `UIInspector.luau`, and any AI/manager module that depends on its special behavior.
3. If a building affects income, energy, supply cap, walls, garrison, or restricted nodes, make sure sell, death, upgrade, and construction-complete code all reverse/apply the same effects.
4. Keep node-restricted buildings routed through `NodeManager.luau`. Do not replace node occupancy with ad hoc checks.
5. Preserve the current under-construction flow: spawn ghosted structure, let builders raise progress, then apply full stat contribution on completion.
6. If you change tower or wall behavior, update both `WallManager.luau` and the client scripts that trigger or visualize wall selection.

## Unit-System Rules

1. Keep unit spawning centralized in `UnitSpawner.luau`.
2. Keep training queues centralized in `UnitQueue.luau`; do not let UI scripts or unrelated server scripts deduct cost and spawn units directly.
3. If you add a new unit stat or behavior flag, update:
   `BuildingConfig.luau`, `UnitSpawner.luau`, `UnitAI.legacy.luau`, `UIUnitInspector.luau`, `UnitSelection.luau`, and any transport/garrison logic that serializes units.
4. Preserve supply accounting. Any change to spawning, deletion, transport loading/unloading, bunker destruction, or HQ transfer must keep `PlayerStats.CurrentUnits` correct.
5. Preserve air/ground distinctions based on `Class`, `FlightHeight`, and `TargetType`. Combat and movement code depend on those fields.
6. Keep movement server-authoritative through `MoveCommand` and `UnitAI.legacy.luau`. Client scripts should not directly reposition units.

## UI And Client Rules

1. Keep `UIManager.local.luau` as the composition root for the main gameplay UI.
2. When adding a new world interaction hotkey, update the owning input layer instead of scattering it across multiple scripts.
3. Keep selection state centralized in `UnitSelection.luau`. Other client modules should query it rather than cloning its state.
4. If you add a new server action initiated from the UI, define the remote contract clearly and update both the client caller and the server validator in the same change.
5. Preserve the distinction between building interaction and unit interaction:
   `UIInspector`/`UIMultiSelect`/`UIMouseHandler` for buildings, `UnitSelection`/`UIUnitInspector`/`UnitInputHandler` for units.

## Dependency And Module Rules

1. Require dependencies explicitly inside each file that uses them. Do not rely on globals or implicit module availability.
2. Keep small helper modules focused. Prefer extending an existing subsystem module over creating a new cross-cutting global table.
3. If a module is reused by both server and client, place it where both sides can actually access it in Roblox and keep its responsibilities data-oriented.
4. Before removing an apparently unused script, verify whether a `.legacy` script, remote hookup, or external placement target still depends on it.

## Remote And Event Rules

1. Preserve existing remote names unless you update every producer and consumer together.
2. Keep remote payload shapes stable. Many UI scripts assume exact argument ordering for `UnitEvent`, `MoveCommand`, `AttackEffect`, `WallMessage`, and victory events.
3. Use remotes for cross-boundary communication and bindables for server-only/local-only coordination. Do not silently swap one pattern for the other.

## Safety Checks For Future AI Edits

1. After changing any unit or building attribute set, audit spawner, upgrade, delete, death, transport, bunker, and inspector code for drift.
2. After changing round flow, audit bootstrap, reconnect, HQ reclaim, neutral spawns, and victory checks.
3. After changing UI input, audit keybinds, settings persistence, and all client modules that share the same hotkeys.
4. After changing remotes, search both server and client scripts for the old name before finalizing the edit.
5. If a change touches alliances, audit combat target checks, economy sharing, HQ reclaim state, and victory grouping.
