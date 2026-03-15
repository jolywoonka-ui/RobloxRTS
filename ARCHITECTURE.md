# Architecture

## Overview

This project is a Roblox RTS split across three active layers:

1. `ServerScriptService` orchestration scripts start rounds, own authoritative game state, and process combat/building/unit actions.
2. `ServerStorage` and `ReplicatedStorage` module scripts hold shared gameplay logic, configuration, and UI helpers.
3. `StarterPlayerScripts` local scripts build the player UI, handle selection and input, and send commands back to the server through remotes.

The codebase is already modular, but many files still use a `.legacy` suffix. Those scripts are not dead code. They are part of the live runtime and should be treated as first-class systems until they are explicitly removed.

## Round And Match Flow

1. `GameManager.legacy.luau` is the bootstrap script. It ensures all remotes and bindables exist, requires the core managers, and wires the wall-building remote.
2. `ConnectionManager.luau` owns player lifecycle, team creation, respawn routing, disconnect bookkeeping, and the main intermission/game loop.
3. `RoundManager.luau` starts a match by loading `IslandMap`, assigning teams/spawns, resetting stats, scanning HQs, assigning starting HQ ownership, and spawning initial builders.
4. `GameState.luau` tracks whether the match is active, drives the lobby/intermission timer, updates replicated status values, and ends rounds.
5. `HQManager.luau` turns HQ slots into persistent faction slots. It remembers treasury and saved stats per HQ index, supports reconnect/reclaim behavior, and transfers ownership of buildings/units when a slot changes hands.
6. `SpawnManager.luau` places player characters at their assigned spawn or HQ-derived fallback location.
7. `VictoryChecker.luau` evaluates surviving HQ groups and ends the round when only one alliance/player group remains.

## Server Gameplay Systems

### Shared Configuration

`BuildingConfig.luau` is the central gameplay data source. It defines:

- all recruitable unit stats and metadata
- all buildable structure stats and upgrade paths
- base economy values
- helper functions for unit limit and energy calculations

Everything else reads from this config rather than hardcoding balance values.

### Building Pipeline

`EconomyServer.legacy.luau` is the building-system coordinator. At round start it creates and owns:

- `NodeManager.luau` for farm node discovery and occupancy
- `BuildingSpawner.luau` for authoritative structure placement
- `BuildingDeathHandler.luau` for cleanup on destruction
- `BuildingSellHandler.luau` for selling/refunds/stat rollback
- `EconomyManager.luau` for passive income ticks
- `UpgradeManager.luau` for timed building upgrades
- `BunkerManager.luau` for bunker garrisons

The normal building flow is:

1. `UIBuildMenu.luau` fires the local `StartBuild` bindable.
2. `PlacementClient.local.luau` shows the ghost model, validates terrain/range, and fires `BuildEvent`.
3. `EconomyServer.legacy.luau` forwards the request to `BuildingSpawner.luau`.
4. `BuildingSpawner.luau` validates credits, energy, node restrictions, allied proximity, and placement collision, then spawns an under-construction model.
5. `UnitAI.legacy.luau` lets builders automatically progress nearby construction by raising `Progress` and `Health`.
6. When construction finishes, the building's economy/energy/unit-limit contributions are applied to `PlayerStats`.

Related building subsystems:

- `BuildingAI.legacy.luau` runs offensive building targeting and damage.
- `HospitalAI.legacy.luau` runs hospital healing pulses against allied units.
- `WallManager.luau` creates/removes wall segments between eligible towers.
- `UpgradeManager.luau` replaces a building model with its upgraded variant while preserving ownership, health ratio, node occupancy, and bunker garrison data.
- `BuildingDeathHandler.luau` and `BuildingSellHandler.luau` both free occupied farm nodes and reverse stat effects for completed structures.

### Unit Pipeline

`UnitServer.legacy.luau` is the unit-system coordinator. It connects the transport, queue, spawn, deletion, and health-bar modules to remotes and bindables.

The normal unit flow is:

1. `UIInspector.luau` sends `UnitEvent` training requests from eligible buildings.
2. `UnitQueue.luau` validates cost/power/ownership, maintains a queue per production building, and tells the client about queue/progress changes.
3. `UnitSpawner.luau` clones the unit template, applies team color and attributes, sets collision groups, and inserts the unit into `CurrentMap.Army`.
4. `UnitServer.legacy.luau` attaches health-bar and death handling.
5. `UnitController_Main.local.luau` and `UnitInputHandler.luau` let the player select units and send `MoveCommand`.
6. `UnitAI.legacy.luau` is the server-authoritative simulation loop for movement, formation positions, attacking, builder construction, and air-unit altitude handling.
7. `UnitAI.Constants.luau`, `UnitAI.State.luau`, `UnitAI.Blockers.luau`, `UnitAI.Movement.luau`, `UnitAI.Combat.luau`, `UnitAI.Builder.luau`, and `UnitAI.Commands.luau` split that runtime into focused modules for tunables, per-unit state, collision/pathing, movement stepping, combat, builder construction, and command handling.
8. `UnitPathVisuals.luau` reflects the confirmed server path back to the client.

Related unit subsystems:


- `UnitAI.Constants.luau` centralizes movement/collision/pathing tunables.
- `UnitAI.State.luau` stores transient per-unit path/combat state and shared root/position helpers.
- `UnitAI.Blockers.luau` handles wall/map blocker caches and movement collision tests.
- `UnitAI.Movement.luau` executes ground and air movement with blocker-aware slide/steer fallback.
- `UnitAI.Combat.luau` runs alliance-aware target scans and damage/cooldown handling.
- `UnitAI.Builder.luau` handles builder construction progress and completion-side stat application.
- `UnitAI.Commands.luau` maps move requests into queued/formation destinations.
- `UnitTransport.luau` loads/unloads infantry into APCs and air transports.
- `UnitDeletion.luau` removes selected units and cleans up transport passengers.
- `UnitPhysics.luau` builds reusable unit health-bar UI.
- `UnitSelection.luau` owns the selected-unit set and hover/range visuals.
- `UnitSquadManager.luau` groups units into reusable client-side squads.
- `UIUnitInspector.luau` shows unit stats and issues delete commands.

### Economy, Ownership, And Persistence

`EconomyManager.luau` pays income per HQ slot, not just per connected player. That matters because `HQManager.luau` can keep a faction slot alive after a disconnect by storing treasury and stat state until someone reclaims it.

Ownership consistency depends on a small set of attributes:

- `Owner`
- `AllianceID`
- `Type`
- `Health`
- `MaxHealth`
- `IsUnderConstruction`
- `IsUpgrading`
- `Damage`
- `Range`
- `AttackCooldown`
- `Class`
- `Capacity`
- `Supply`

Most systems communicate by reading and mutating those attributes, so they are effectively part of the project's public architecture.

## Client And UI Architecture

`UIManager.local.luau` is the client UI composition root. It creates the main screen and initializes:

- `UIStatsPanel.luau` for credits, energy, income, and supply
- `UIBuildMenu.luau` for building categories and build start requests
- `UIInspector.luau` for building details, training queues, selling, and upgrading
- `UIInspector.Layout.luau` for inspector widget/layout creation and shared UI primitives
- `UIInspector.Rendering.luau` for unit viewports, hover tooltips, and info-row rendering
- `UIInspector.Selection.luau` for ownership checks, map-ground sampling, and selection/range visuals
- `UIInspector.Training.luau` for queue state, training progress visuals, and train/upgrade helper logic
- `UIUnitInspector.luau` for unit details and deletion
- `UIMouseHandler.luau` for building click handling, bunker/transport toggles, and wall hotkeys
- `UIMultiSelect.luau` for Ctrl-click building multiselect and range disks
- `UnitSelection.luau` for unit selection/hover visuals

Unit control is driven by:

- `UnitController_Main.local.luau` as the top-level controller
- `UnitInputHandler.luau` for drag-select and right-click move commands
- `UnitPathVisuals.luau` for movement path rendering
- `UnitSquadManager.luau` for squad HUD and callbacks

Placement and settings are separate client flows:

- `PlacementClient.local.luau` handles building ghosts, snap/rotate/range visuals, and sends `BuildEvent`.
- `SettingsClient.local.luau` and `SettingsServer.legacy.luau` manage keybind persistence plus local toggles for path/range overlays.
- `KeybindConfig.luau` and `KeybindHandler.local.luau` provide extra debug/convenience keybind behavior.

End-of-match and optional UI systems:

- `VictoryStatsScreen.local.luau` is the currently used victory presentation path because `VictoryChecker.luau` fires `ShowVictoryStats`.
- `VictoryScreen.local.luau` still exists and listens to `ShowVictory`.
- `DiplomacyClient.local.luau` and `DiplomacyManager.legacy.luau` provide alliance invites and alliance-list UI.
- `DebugClient.local.luau` and `DebugServer.legacy.luau` provide a debug-only HQ destruction shortcut.

## Event And Remote Contracts

The most important network contracts are:

- `MoveCommand`: client move request and server-confirmed path echo
- `AttackEffect`: server-to-client laser/heal beam visuals
- `BuildEvent`: client build placement request
- `SellEvent`: client sell request
- `UnitEvent`: training queue actions and queue/progress updates
- `UpgradeEvent`: client building upgrade request
- `BunkerEvent`: bunker load/unload toggle
- `LoadTransport`: transport load/unload toggle
- `DeleteUnit`: unit deletion request
- `BuildWall`: tower wall creation/removal request
- `WallMessage`: generic client-facing placement/build/wall error text
- `ShowVictoryStats`: end-of-match results payload

Local-only UI coordination also uses:

- `StartBuild` as a client bindable to begin placement mode
- `GameActive`, `GameStatus`, and `GameTimer` as replicated values for client UI state

## Script Roles By Subsystem

### Bootstrap And Match State

- `GameManager.legacy.luau`: startup composition root and remote/bindable creation
- `GameState.luau`: replicated match state and timers
- `ConnectionManager.luau`: player lifecycle and main loop
- `RoundManager.luau`: round startup sequence
- `MapInitializer.luau`: map clone and existing-building normalization
- `PlayerInitializer.luau`: team/spawn assignment
- `SpawnManager.luau`: character spawn placement
- `HQManager.luau`: faction slot ownership and persistence
- `VictoryChecker.luau`: alliance-aware win detection
- `PlayerStatsManager.luau`: per-player stat folder setup/reset
- `ServerEvents.luau`: helper that mirrors the bindables `GameManager` also ensures directly

### Buildings, Economy, And Defenses

- `BuildingConfig.luau`
- `EconomyServer.legacy.luau`
- `EconomyManager.luau`
- `BuildingSpawner.luau`
- `BuildingSellHandler.luau`
- `BuildingDeathHandler.luau`
- `NodeManager.luau`
- `UpgradeManager.luau`
- `WallManager.luau`
- `BuildingAI.legacy.luau`
- `HospitalAI.legacy.luau`
- `BunkerManager.luau`

### Units And Combat

- `UnitServer.legacy.luau`
- `UnitAI.legacy.luau`
- `UnitAI.Constants.luau`
- `UnitAI.State.luau`
- `UnitAI.Blockers.luau`
- `UnitAI.Movement.luau`
- `UnitAI.Combat.luau`
- `UnitAI.Builder.luau`
- `UnitAI.Commands.luau`
- `UnitSpawner.luau`
- `UnitQueue.luau`
- `UnitTransport.luau`
- `UnitDeletion.luau`
- `UnitPhysics.luau`
- `PhysicsManager.legacy.luau`

### Client UI And Input

- `UIManager.local.luau`
- `UIBuildMenu.luau`
- `UIInspector.luau`
- `UIInspector.Layout.luau`
- `UIInspector.Rendering.luau`
- `UIInspector.Selection.luau`
- `UIInspector.Training.luau`
- `UIUnitInspector.luau`
- `UIStatsPanel.luau`
- `UIMouseHandler.luau`
- `UIMultiSelect.luau`
- `PlacementClient.local.luau`
- `UnitController_Main.local.luau`
- `UnitInputHandler.luau`
- `UnitSelection.luau`
- `UnitPathVisuals.luau`
- `UnitSquadManager.luau`
- `SettingsClient.local.luau`
- `SettingsServer.legacy.luau`
- `KeybindConfig.luau`
- `KeybindHandler.local.luau`
- `VictoryScreen.local.luau`
- `VictoryStatsScreen.local.luau`

### Optional And Debug Systems

- `DiplomacyClient.local.luau`
- `DiplomacyManager.legacy.luau`
- `DebugClient.local.luau`
- `DebugServer.legacy.luau`

## Architectural Conventions

- Server authority lives in the `.legacy` server scripts plus the `ServerStorage` modules they compose.
- `BuildingConfig.luau` is the single source of truth for unit/building balance and unlock data.
- Gameplay state is shared mostly through Instance attributes rather than plain Lua tables.
- Client scripts are thin on authority: they preview, visualize, and request; the server validates and mutates real state.
- HQ slots are persistent strategic identities. Players can disconnect and later reclaim a slot's economy, buildings, and treasury.
- Alliances are modeled through `AllianceID` on both players and world objects, so diplomacy affects combat, economy, and victory checks.



