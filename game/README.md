# Infinity Fishing (Godot 4.7 project)

An original, offline, single-player 3D fishing and fish-business game for Android
(landscape, touch controls). Everything is generated in code: terrain, water,
buildings, characters, fish pictures and sound effects. There are no external art or
audio assets, and no accounts or networking.

## What is in the game

| Area | What you can do |
|---|---|
| Fishing | Hold CAST to charge, release to throw, tap HOOK on the bite, then hold REEL in a bar minigame. 8 rods, 4 baits, 50 species across 7 water types, 6 rarities, mutations (shiny, albino, giant, golden, void), weather and day/night change what bites. |
| Collection | Fishdex with caught counts, best weight and variants; backpack with favourites. |
| Breeding | Hatchery tanks: feed, move fish in, pick two compatible parents, fry grow into adults, genes (size, growth, fertility) are inherited, rare mutations and evolution chances, harvest into the backpack. |
| Business | Fish market with customers' orders and demand-based prices, stalls, a cannery with production lines, products (fillets, fishmeal, oil, smoked, canned), wholesale price drift, contracts, warehouse. |
| Cooking | Four station types, 8 recipes with ingredients bought at the General Store; dishes sell for more or give timed fishing buffs. |
| World | Village, cannery district, lake hamlet, river, ocean, 3 islands reached by ferry, permits that unlock waters, 12-minute day, 5 weather types with rain, fog and lightning. |
| Progression | XP and levels, 11 upgrades (backpack, tanks, kitchen, factory lines, assistants...), assistant anglers who fish for you, including while the app is closed. |
| Charms | 10 charms sold in the Tackle Shop (Charms tab): **Luck** charms make rarer fish bite, **Calm** charms slow the fish in the reel bar (and shorten its dashes). Wear up to 3 at once (shop or Backpack > Gear); luck adds to rod/bait/food luck, total calm is capped at 50 % so the fight never becomes trivial. Owned and worn charms are saved. |
| Movement | Faster walk/run (7 / 12 m/s) and higher jump, snappier acceleration, steeper banks can be climbed, and short jump forgiveness (coyote time + input buffer). You can **swim** in the lake, the river and the shallow sea around the main island, so nothing on the main island is blocked; swimming has its own animation, splash sounds and ripple. The open ocean and the other islands are still reachable only by ferry. |
| Visuals | All art is generated in code (no external assets): shaded terrain with grass/sand/rock detail and wet shorelines, depth-tinted animated water with foam, sun glints and sky reflection, a sky shader with sun/moon and drifting clouds, wind-swaying trees and grass, detailed houses with lit windows at night, a hull-lofted fishing boat that bobs, a smooth-shaded character with a face, 8 distinct rod models (reel, guides, glowing trims on the top rods), richly patterned fish, bobber ripples. The Low graphics preset switches to flat water, cheap ground and a plain sky. |
| Android | Floating joystick, camera drag pad, context action button, multi-touch, left-handed layout, pause menu, auto-save (every 45 s and when the app is paused or closed), Low/Medium/High presets and individual graphics options. |

## Controls

Touch: left side = joystick, right side drag = camera, big button = CAST / RELEASE / HOOK / REEL,
USE appears next to buildings, boats and beds. On a desktop: WASD or arrows to move, mouse drag to look, Space to jump, Shift to run, F to cast/hook/reel (hold), E to use, I or Tab for the backpack, Esc for the menu.

## Project layout

```
game/
  project.godot, export_presets.cfg      Godot project + Android export preset
  scenes/main.tscn                       boots scripts/main.gd (menu -> loading -> session)
  scripts/autoload/                      Data, Game (state), Clock, Settings, Sfx, Save
  scripts/data/                          fish, gear, food, world tables (plain data)
  scripts/systems/                       Hatchery, Kitchen, Factory, Economy, Assistants, FishLogic, ReelMinigame (no scene code)
  scripts/world/                         terrain, water, village builder, props, sky, weather, NPCs
  scripts/player/                        player + fishing controller
  scripts/ui/                            touch controls, HUD, panels, menu
  shaders/                               water + star shaders
  tests/                                 automated tests (see below)
```

Game rules live in `scripts/systems/` and operate on `Game` state, so they are tested without any scenes.

## Tests

```bash
godot --headless --path game --import                        # once, builds the class cache
godot --headless --path game -s res://tests/run_tests.gd      # unit/system tests (~555 checks)
godot --headless --path game res://tests/e2e_play.tscn        # scripted play-through (~68 checks)
```

* `test_compile` loads every script (a parse error otherwise breaks things silently).
* `test_logic`, `test_terrain`, `test_systems` cover data integrity, drop-rate and value maths, the reel minigame, terrain/water layout, breeding, cooking, processing, orders, assistants and the save round-trip.
* `e2e_play` starts the real main scene, creates a new game and drives the on-screen controls with simulated touch events: joystick, camera drag, swimming across the lake, cast, bite, hook, reel, catch, all panels, buying a charm in the shop, a purchase, resting, save/load, ferry travel and back to the menu.
* `tests/render_world.gd` is a developer tool that saves screenshots of the world (needs a renderer, e.g. xvfb).

## Building the APK

The repository's original Gradle/Kotlin workflow (`.github/workflows/android.yml`) is untouched; it cannot export Godot
projects. The Godot build is a separate workflow, `.github/workflows/godot-android.yml`:

1. Installs Godot 4.7 and its export templates and the Android SDK/NDK (`tools/ci/`).
2. Runs both test suites; the build fails if any test fails.
3. Exports a debug APK signed with the fixed debug key in `tools/ci/debug.keystore` (committed on purpose; it only signs test builds) and sets `version/code` from the run number, so each new build installs as an update over the previous one and keeps your save. (A build signed with an older, random key must be uninstalled once.) The APK is uploaded as the **`infinity-fishing-debug-apk`** artifact (Actions run page -> Artifacts).
4. On a `v*` tag, if the existing signing secrets are present, it also builds a signed release APK (`infinity-fishing-release-apk`) and attaches it to the release.

Dev screenshot tools (not part of the test suite): `tests/render_world.gd` (world views by day/night/weather) and `tests/render_gallery.gd` (close-ups of fish, rods, people, boat, houses, trees), both run with `xvfb-run godot --rendering-driver opengl3 ... -s res://tests/<tool>.gd -- <out dir>`.

## Honest status

* Verified here: all logic and flows above, via the tests, with the real game running on desktop (software OpenGL) and screenshots reviewed at 16:9 and 20:9.
* Not verified here: the actual APK export (the build sandbox cannot reach the Android SDK host; it is only proven when the GitHub Actions run succeeds), and anything on a physical phone: real touch feel, frame rate, thermal behaviour, GPU shader compilation, audio output, vibration and the Android back button. Expect to tune joystick size, button placement and graphics presets after trying it on a device.
* Settings that depend on the GPU (render scale, MSAA, shadows, view distance, density) take effect immediately but their effect on a real phone's frame rate has not been measured.
