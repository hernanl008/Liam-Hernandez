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
   - Install the Rojo **CLI** on your machine via
     [mise](https://mise.jdx.dev) (a toolchain manager — this repo used
     to use Aftman, but Aftman was pulled from Homebrew in July 2026, so
     mise is the current path):
     ```
     brew install mise
     echo 'eval "$(mise activate zsh)"' >> ~/.zshrc   # or ~/.bashrc, etc.
     source ~/.zshrc                                   # or open a new terminal
     ```
     Then, from this repo's root:
     ```
     mise install
     ```
     This reads `mise.toml` and installs Rojo, Selene (linter), StyLua
     (formatter), and Tarmac (asset pipeline).
   - Alternative: `cargo install rojo` or download a binary from
     https://github.com/rojo-rbx/rojo/releases.
3. **Clone this repo** and check out this branch:
   ```
   git clone https://github.com/hernanl008/Liam-Hernandez.git
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
   Anything you build/place *in Studio* (terrain, extra decorations,
   models) stays in the `.rbxl` file — only scripts/modules under `src/`
   are synced by Rojo.
6. Commit + push code and doc changes from the repo as normal.

> The `.rbxl` place file itself isn't committed to git (binary, doesn't
> diff well) — see `.gitignore`. Treat it as a local build artifact you
> regenerate from `src/` plus whatever you've built by hand in Studio.
> If you want the map itself version-controlled long-term, we can
> revisit exporting it to a syncable format later.

> **The starter map is code-generated, not hand-built.**
> `MapBuilder.lua` rebuilds a `Workspace.GeneratedMap` folder (tiles, farm
> plots, fishing spot, cooking stations, NPCs, spawn point) from
> `MapConfig.lua` every time the server starts — don't hand-edit anything
> inside that folder in Studio, it gets wiped and regenerated on the next
> Play session. Extend the actual map by editing `MapConfig.lua`, or build
> unrelated decoration elsewhere in `Workspace` (outside `GeneratedMap`).

## Assets pipeline

Rojo syncs *code*, not *images* — Roblox has no API for uploading assets
without an authenticated human account, so art has to go through
[Tarmac](https://github.com/rojo-rbx/tarmac) instead (`tarmac.toml`,
already configured). Short version: put PNGs in `assets/`, run
`tarmac sync --target roblox` (your own Roblox login), commit the
regenerated `AssetIds.generated.lua`. Full walkthrough, including the
placeholder pixel-art tiles/sprites already in this repo, is in
`docs/VERTICAL_SLICE_SETUP.md` §2.

## Project layout

```
default.project.json   Rojo mapping: filesystem -> Roblox instance tree
mise.toml               Toolchain manifest (Rojo/Selene/StyLua/Tarmac versions)
tarmac.toml             Asset upload pipeline config (see "Assets pipeline" above)
assets/                 Source PNGs for Tarmac to upload (tiles/, sprites/)
src/
  ReplicatedFirst/       Loading screen (runs before everything else)
  ReplicatedStorage/
    Modules/            Shared code + data configs (Farming, Fishing, Cooking,
                         Shared, UI, Client) — see Shared/ for Remotes,
                         RhythmScoring, DialogueData, SkillTreeConfig,
                         MapConfig, AssetIds
  ServerScriptService/
    Main.server.lua      Server bootstrap
    Services/            Server-side game systems (one per system, incl.
                         MapBuilder which generates the starter map)
  ServerStorage/          Server-only assets (anti-exploit: never send to client)
  StarterPlayer/
    StarterPlayerScripts/ Client bootstrap + Controllers/
    StarterCharacterScripts/
  StarterGui/             UI
docs/
  GDD.md                 Game design doc: core loop, systems breakdown
  LORE_BIBLE.md           World, factions, characters, timeline
  NPC_ROSTER.md           Full 50+ NPC list
  DIALOGUE_ACT1.md        Act 1 dialogue scripts
  OPENING_CUTSCENE.md     Death -> rebirth cutscene beat sheet (not yet wired into code)
  ROADMAP.md              Milestone plan across the month
  VERTICAL_SLICE_SETUP.md What to do in Studio to playtest what's built so far
```

## Linting / formatting

`selene.toml` and `stylua.toml` are configured. Run `selene src` and
`stylua src` locally (installed via `mise install`) before committing.
