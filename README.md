# Grow and Survive

*(Proposal title: "Grow and Survive" / "Colony Engine")*

Grow and Survive is a 2D colony-management game built with **Godot 4 (GDScript)**.
You do not control ants directly. Instead you **program them**: each ant role
(worker, explorer, defender, guard) follows a small rule script that you write
in an in-game editor. Ants gather food and building materials, build structures,
flee from or fight roaming bugs, and must satisfy the queen's periodic food quota.
Miss a quota and the colony collapses.

## Important features

- **Programmable ant behavior** - a rule language (`condition: action`, first
  matching rule wins) with `define` aliases, `and` / `or` / `not`, and numeric
  comparisons such as `health < 30`.
- **Four ant roles**, each with its own script: worker, explorer, defender, guard post.
- **Rules editor** with validation errors, example scripts, and a scenario preview
  that traces which rule fires.
- **Procedural island world** generated from noise, with hills, food patches and
  material patches that replenish, streamed tile by tile.
- **Colony economy** - food and materials, buildable structures, producers, and a
  recurring queen quota with on-screen warnings.
- **Threats** - roaming bugs that attack ants away from the nest and drop food when defeated.
- **Three save slots** plus persistent custom rules.
- **HUD and menus** - spawn/selection tools, behavior overlay, pause, reset, game-over screen.

## OOP implementation

The project is organised as small, single-purpose classes. Each script is a
class (GDScript treats every `.gd` file as one) that extends a Godot base class.

| Concept | Where it appears |
|---|---|
| **Inheritance** | `ant_worker`, `roaming_bug`, `game_controller` extend `Node2D`; `camera_controller` extends `Camera2D`; `hud` extends `CanvasLayer`; menu screens extend `Control` / `PanelContainer`; pure-logic classes extend `RefCounted`. |
| **Encapsulation** | State is private (underscore-prefixed members) and changed only through methods. `save_system`, `colony_rules`, `food_patch_manager` and `world_data` own their data and expose small APIs. |
| **Composition** | `game_controller` composes `world_map`, `colony_rules`, `colony_rule_interpreter`, `food_patch_manager` and `save_system` instead of inheriting from them. `world_map` composes the island, hill, tile-picker and tile-streamer classes. |
| **Polymorphism** | One `ant_worker` class behaves differently per `Role` enum value, driven by the rule script assigned to that role. Rule actions resolve to behavior through the interpreter. |
| **Abstraction** | The rule interpreter hides parsing and evaluation behind a validate/evaluate API; `save_system` hides slot files and schema versions. |
| **Loose coupling (signals)** | UI and entities communicate through signals (`food_delivered`, `died`, `defeated`, `spawn_requested`, `apply_requested`, ...), so the HUD never touches ant internals. |

Source layout:

```
Scripts/
  game_controller.gd         # coordinates simulation, world, ants and HUD
  ant_worker.gd              # ant entity with roles and behavior state
  roaming_bug.gd             # enemy entity
  colony_rules.gd            # per-role rule scripts and persistence
  colony_rule_interpreter.gd # parser / evaluator for the rule language
  food_patch_manager.gd      # food and material patches
  save_system.gd             # 3 save slots
  camera_controller.gd
  map/                       # island, hills, land mask, tile picker/streamer, world data
  UI/                        # main menu, HUD, rules editor, save slots, game over
Scenes/                      # .tscn scenes (main, NPCs, UI)
examples/                    # example rule script
tools/make_proposal_pdf.py   # Python helper that generates the proposal PDF
```

## Setup instructions

### Run the game

1. Install [Godot 4.7](https://godotengine.org/download) (or later).
2. Clone the repository:
   ```
   git clone <repository-url>
   cd grow-ans-survive
   ```
3. Open Godot, choose **Import**, and select `project.godot`.
4. Press **F5** (Run Project). The main menu is the startup scene.

### Optional: Python tool

The game needs no Python packages. The only Python file is
`tools/make_proposal_pdf.py`, which builds the proposal PDF.

```
python -m venv .venv
.venv\Scripts\activate          # Windows (Linux/macOS: source .venv/bin/activate)
pip install -r requirements.txt
python tools/make_proposal_pdf.py
```

### Export for Windows

Install the matching Godot export templates, then select **Project > Export** and
export the **Windows Desktop** preset. It writes `GrowAndSurvive.exe` to the project
directory. Exported executables and data packages are excluded from Git.

## Configuration

- **Custom rules** - see [examples/colony_rules.example.txt](examples/colony_rules.example.txt).
  Paste it into the in-game Rules Editor. Rules are saved to
  `user://colony_rules.txt` and game saves to `user://saves`, both in Godot's
  per-user data directory (not in the repository).
- **Environment variables** - none are required. [.env.example](.env.example) shows
  where any future secret would go; real `.env` files are git-ignored.

## Security

No passwords, API keys, or credentials are stored in this repository. Local
editor files, `.env` files, key files, export credentials, the `.godot/` cache and
the virtual environment are excluded by `.gitignore`.

## Third-party assets

The Complete UI Essential Pack Free is by Crusenho Agus Hennihuno and is
licensed under [CC BY 4.0](https://creativecommons.org/licenses/by/4.0/).
Creator: [Crusenho](https://crusenho.itch.io).

The project also includes the Sprout Lands - Sprites - Basic pack. The project
owner has confirmed the right to redistribute these assets with this project.
