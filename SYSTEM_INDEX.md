# System Index

## Bootstrap And Match State

`BuildingConfig.luau`  
Central balance/config module for all units, buildings, upgrades, and base economy values. It is the shared data source for nearly every gameplay system.

`ConnectionManager.luau`  
Handles player join/leave behavior, team setup, respawn wiring, and the main intermission/match loop. It is the runtime bridge between `GameState`, `HQManager`, `SpawnManager`, and `VictoryChecker`.

`EconomyServer.legacy.luau`  
Server-side coordinator for building placement, selling, upgrading, bunker use, and round-start economy initialization. It instantiates the building/economy modules and connects their remotes.

`GameManager.legacy.luau`  
Top-level bootstrap script for the whole game. It creates remotes/bindables, requires the main managers, and wires wall-building into the round start flow.

`GameState.luau`  
Owns replicated match-state values like active status, lobby text, and timer text. It starts and ends rounds and drives the countdown/intermission state machine.

`HQManager.luau`  
Tracks the six HQ faction slots, their treasury, saved stats, last owner, and reclaim behavior. It also transfers ownership of existing buildings and units when a slot changes hands.

`MapInitializer.luau`  
Clones the active map template into `workspace.CurrentMap` and ensures the map contains normalized `PlayerBuildings` and `Army` folders. It also applies initial building attributes and health setup to pre-placed structures.

`PlayerInitializer.luau`  
Randomizes player faction/spawn assignment at round start and stores the result in `ActivePlayerData`. It is the source of each player's HQ spawn index.

`PlayerStatsManager.luau`  
Creates and resets the `Stats` and `PlayerStats` folders on each player. Those value objects are the project's canonical per-player economy/combat counters.

`RoundManager.luau`  
Runs the round-start sequence: destroy old map, load new map, assign teams, reset stats, scan/assign HQs, and spawn opening builders. It is the high-level match setup pipeline.

`ServerEvents.luau`  
Utility module that ensures the core `ServerStorage` bindables exist. It overlaps with `GameManager.legacy.luau`, so it currently reads as a helper or earlier abstraction layer.

`SpawnManager.luau`  
Places player characters at their assigned spawn part or fallback HQ position. It is focused on player avatar spawning, not unit production.

`VictoryChecker.luau`  
Counts surviving HQs by alliance/player group and decides when the match is over. It also builds the victory-stats payload sent to clients.

## Building, Economy, And Defense

`BuildingAI.legacy.luau`  
Runs autonomous targeting and firing for offensive buildings such as turrets and HQ defenses. It respects alliances and updates `DamageDealt` stats for the owner.

`BuildingDeathHandler.luau`  
Cleans up destroyed buildings by freeing nodes, reversing stat bonuses, removing walls, and destroying bunker garrisons. It is the authoritative destruction rollback path for structures.

`BuildingSellHandler.luau`  
Handles player-requested building sales, including refunds, node release, stat rollback, and wall removal. It prevents selling HQs and ignores invalid ownership requests.

`BuildingSpawner.luau`  
Validates build requests on the server and creates the actual structure model. It handles terrain checks, energy/credit checks, node occupancy, team coloring, and initial construction-state attributes.

`BunkerManager.luau`  
Loads infantry into bunkers and converts the garrison into bunker combat stats. It also removes garrison supply when a bunker is destroyed.

`EconomyManager.luau`  
Pays recurring income to each HQ slot, including alliance-shared building income and treasury accumulation for disconnected factions. It is the passive economy tick loop.

`HospitalAI.legacy.luau`  
Scans for completed hospital buildings and heals nearby allied units on a cooldown. It reuses `AttackEffect` to show the healing beam.

`NodeManager.luau`  
Discovers and tracks special farm nodes on the current map. It is used to reserve and free restricted building locations like `Node_Farm`.

`UpgradeManager.luau`  
Runs timed building upgrades and swaps the old model for the upgraded one when complete. It preserves ownership, health ratio, node data, and bunker garrison state during replacement.

`WallManager.luau`  
Creates and removes physical wall segments between eligible tower buildings. It also tracks which walls belong to which towers so tower death/sale can remove linked walls.

## Units And Combat

`PhysicsManager.legacy.luau`  
Registers collision groups and exposes `_G.setCollisionGroup` for shared use. It is the global collision bootstrap for players, buildings, units, walls, and air units.

`UnitAI.legacy.luau`  
Authoritative server simulation loop for unit movement, attack targeting, damage application, builder construction, formation destinations, and air-unit altitude behavior. This is the core RTS unit brain.
`UnitAI.Blockers.luau`  
Movement/pathing collision helper for `UnitAI.legacy.luau`. It caches map blockers and walls, performs movement collision checks, clamps ground targets, and computes slide/steer alternatives.

`UnitAI.Builder.luau`  
Builder-focused helper for `UnitAI.legacy.luau` that advances nearby allied construction progress. It also applies the final building economy/stat effects when construction completes.

`UnitAI.Combat.luau`  
Combat helper for `UnitAI.legacy.luau` handling ally checks, target-type validation, target scans, and damage application. It fires `AttackEffect` and updates `DamageDealt` stats.

`UnitAI.Commands.luau`  
Move-command handler for `UnitAI.legacy.luau`. It assigns formation destinations, supports queued moves, and applies ground target clamping for ground units.

`UnitAI.Constants.luau`  
Shared constants for the modular UnitAI stack (movement thresholds, steering angles, collision padding, and non-walkable material rules).

`UnitAI.Movement.luau`  
Movement executor for `UnitAI.legacy.luau` for both ground and air units. It applies kinematic stepping, ground snapping, blocker-aware sliding, and blocked-path abort logic.

`UnitAI.State.luau`  
Per-unit transient state store for the modular UnitAI stack. It tracks movement/combat state and provides shared position/root resolution helpers.

`UnitDeletion.luau`  
Deletes selected units and correctly removes their supply usage. It also kills or clears passengers when a transport is deleted.

`UnitPhysics.luau`  
Small helper module that builds reusable 3D health-bar UI for units. Other server scripts use it rather than duplicating billboard creation code.

`UnitQueue.luau`  
Owns per-building training queues, validates recruitment requests, refunds cancellations/failures, and emits queue/progress updates to the client. It is the production queue manager behind `UnitEvent`.

`UnitServer.legacy.luau`  
Connects training, spawning, transports, deletion, and health-bar attachment into the live game. It is the unit-side equivalent of `EconomyServer.legacy.luau`.

`UnitSpawner.luau`  
Clones neutral or player-owned units from templates, positions them safely near a building, sets all gameplay attributes, and parents them into `CurrentMap.Army`. It is the canonical unit creation path.

`UnitTransport.luau`  
Loads nearby infantry into transports and unloads them later, including special rules for air transports. It serializes passenger data into attributes and can restore full unit instances on unload.

## Client UI And Input

`KeybindConfig.luau`  
Simple replicated config module for client key names like teleport and highlight. Settings scripts mutate this table at runtime after loading saved preferences.

`KeybindHandler.local.luau`  
Implements local convenience/debug keybinds such as teleport-to-mouse and owned-unit highlighting. It reads its keys from `KeybindConfig.luau`.

`PlacementClient.local.luau`  
Owns building ghost placement, snap/rotate behavior, builder-range visuals, placement validation, and `BuildEvent` submission. It is the client half of the building pipeline.

`SettingsClient.local.luau`  
Builds the settings and FAQ UI, loads saved keybinds, and toggles client-only preferences like path/range overlays. It talks to `SettingsServer.legacy.luau` for persisted keybind data.

`SettingsServer.legacy.luau`  
Persists keybind settings in a DataStore and exposes them through `GetSettings` and `SaveSettings`. It only stores the keybinding subset, not every local UI preference.

`UIBuildMenu.luau`  
Creates the build dock UI with category tabs and buttons for buildable structures. Clicking a button fires the local `StartBuild` bindable used by `PlacementClient.local.luau`.

`UIInspector.luau`  
Shows selected-building info including HP, training queue, recruit buttons, sell, upgrade, garrison count, and range disk. It is the main building interaction panel.
`UIInspector.Layout.luau`  
UI construction helper for `UIInspector.luau`. It creates the inspector frame, queue/training containers, and shared styled controls.

`UIInspector.Rendering.luau`  
Rendering helper for `UIInspector.luau` that builds unit previews/tooltips and reusable info rows for the inspector panel.

`UIInspector.Selection.luau`  
Selection-visual helper for `UIInspector.luau`. It handles ownership/alliance checks plus selection highlights and live range-disk rendering.

`UIInspector.Training.luau`  
Training/queue helper for `UIInspector.luau`. It tracks queue state from `UnitEvent`, renders training progress bars, and provides recruit/upgrade/refund utility logic.

`UIManager.local.luau`  
Client composition root that creates the main screen and initializes the build menu, stats panel, inspectors, and mouse handler. It also toggles between lobby UI and in-game UI based on team assignment.

`UIMouseHandler.luau`  
Handles building clicks, Ctrl-click building multiselect, and the `F` hotkey for bunkers, transports, and wall creation. It is the input bridge between the 3D world and the building inspectors.

`UIMultiSelect.luau`  
Tracks Ctrl-selected buildings and renders their highlights/range indicators with one shared update loop. It is specialized for building multiselect rather than units.

`UIStatsPanel.luau`  
Displays credits, income, energy, and unit supply from the replicated `Stats` and `PlayerStats` values. It updates live as those values change.

`UIUnitInspector.luau`  
Shows unit stats for a single selected unit or a multi-unit summary, and exposes the delete action. It is the dedicated inspection panel for units.

`UnitController_Main.local.luau`  
Top-level client controller for unit interaction. It wires selection, movement input, formation previews, squads, unit inspector updates, and attack/heal beam visuals.

`UnitInputHandler.luau`  
Handles drag selection, single-click selection, right-click move commands, and deselect hotkeys. It sends `MoveCommand` to the server and leaves movement authority there.

`UnitPathVisuals.luau`  
Draws confirmed waypoint/path lines for the player's units and shows move-error text. It listens for server responses on `MoveCommand`.

`UnitSelection.luau`  
Owns the selected-unit list, hover info panel, selection outlines, and optional range overlays. Other client systems query it rather than maintaining their own selection state.

`UnitSquadManager.luau`  
Provides the squad HUD, squad paging, squad editing, and callbacks for adding/selecting units. It is a client-only grouping layer on top of `UnitSelection`.

`VictoryScreen.local.luau`  
Simple "game over" popup that listens for `ShowVictory`. It appears to be an older or alternate victory presentation path because the current server flow uses `ShowVictoryStats`.

`VictoryStatsScreen.local.luau`  
Displays the current victory/results payload with personal stats and global leaders. This is the actively used end-of-match UI.

## Diplomacy And Debug

`DebugClient.local.luau`  
Creates a debug button that asks the server to destroy enemy HQs. It is clearly a development/testing aid, not core gameplay UI.

`DebugServer.legacy.luau`  
Receives the debug HQ-destruction request and kills all HQs not owned by the caller. It is a server-only cheat/testing hook.

`DiplomacyClient.local.luau`  
Builds the alliance-management UI, including invite popups, ally lists, and player lists. It is the client face of the diplomacy system.

`DiplomacyManager.legacy.luau`  
Creates the diplomacy remotes and applies the alliance rules on the server. It updates `AllianceID` on players and owned units when alliances form.



