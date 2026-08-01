# Anime Farm Life (working title)

An indie Roblox farm-sim in the vein of Stardew Valley, anime-styled, with
deep fishing (depth zones, rarity tiers, reel-in tension) and a rhythm-game
cooking system. Story/lore is being built to be tight before release — see
`docs/LORE_BIBLE.md`.

This repo is the source of truth for game code and design docs. Roblox
Studio only opens a synced copy for playtesting/building — it is not where
code is authored or where history lives.

## Why Rojo

Roblox Studio's built-in script editor doesn't do git history, code review,
or working across sessions spread over a month. [Rojo](https://rojo.space/)
solves that: it syncs this filesystem project into a running Studio
instance live. You write/edit Luau here (or an AI session does), `rojo serve`
pushes it into Studio, you playtest, then commit.

## One-time local setup

1. **Install Roblox Studio** — https://www.roblox.com/create (Windows/Mac only).
2. **Install Rojo**:
   - Easiest: get the **Rojo plugin** for Studio from the Roblox toolbox
     (search "Rojo" in Studio's Toolbox), *and*
   - Install the Rojo **CLI** on your machine. Easiest via
     [Aftman](https://github.com/LPGhatguy/aftman) (a toolchain manager):
     ```
     # after installing Aftman:
     aftman install
     ```
     This reads `aftman.toml` in this repo and installs the exact Rojo,
     Selene (linter), and StyLua (formatter) versions the project uses.
   - Alternative without Aftman: `cargo install rojo` or download a binary
     from https://github.com/rojo-rbx/rojo/releases.
3. **Clone this repo** and check out this branch:
   ```
   git clone <this-repo-url>
   cd Liam-Hernandez
   git checkout claude/anime-stardew-roblox-game-6xd7os
   ```

## Everyday workflow

1. `git pull` to get the latest code/design changes.
2. In a terminal, from the repo root: `rojo serve`
3. Open Roblox Studio, open (or create) the game's `.rbxl` place file,
   click the **Rojo plugin** button, then **Connect**. Your file tree now
   mirrors `src/` live.
4. Playtest in Studio.
5. Make code changes in the repo (or ask Claude to), they sync instantly.
   Anything you build/place *in Studio* (terrain, map layout, models) stays
   in the `.rbxl` file — only scripts/modules under `src/` are synced by Rojo.
6. Commit + push code and doc changes from the repo as normal.

> The `.rbxl` place file itself isn't committed to git (binary, doesn't
> diff well) — see `.gitignore`. Treat it as a local build artifact you
> regenerate from `src/` plus whatever you've built by hand in Studio
> (terrain/map). If you want the map itself version-controlled long-term,
> we can revisit exporting it to a syncable format later.

## Project layout

```
default.project.json   Rojo mapping: filesystem -> Roblox instance tree
src/
  ReplicatedStorage/
    Modules/            Shared code + data configs (Farming, Fishing, Cooking, Shared)
    Assets/             Shared assets referenced by module code
  ServerScriptService/
    Main.server.lua      Server bootstrap
    Services/            Server-side game systems (one per system)
  ServerStorage/          Server-only assets (anti-exploit: never send to client)
  StarterPlayer/
    StarterPlayerScripts/ Client bootstrap
    StarterCharacterScripts/
  StarterGui/             UI
docs/
  GDD.md          Game design doc: core loop, systems breakdown
  LORE_BIBLE.md   World, factions, characters, timeline
  ROADMAP.md      Milestone plan across the month
```

## Linting / formatting

`selene.toml` and `stylua.toml` are configured. Run `selene src` and
`stylua src` locally (installed via `aftman install`) before committing.
