# Phyz's Quest bar

A quest sidebar for **World of Warcraft: Forever**, styled as a transparent Blizzard objective tracker, with quests grouped by zone and optional integration with [Phyz Leveling](https://github.com/phyzikalgamer/Phyz-s-Leveling-Addon).

Keep your current zone's quests in view, see what is ready to hand in, and choose an active quest without opening your quest log every time.

## Features

- **Current Zone, All, and Turn in views.** Completed quests remain visible in Current Zone; Turn in brings together finished quests from every zone.
- **Quest objectives and completion states**, with quest levels coloured by difficulty.
- **Active quest selection.** Click a quest's circular icon to select it and highlight its row.
- **Click a quest title to open its quest-log entry.**
- **Spoken quest playback** when Spoken's quest module and a matching voice pack are available.
- **Quest item buttons**, including cooldowns, for supported quest items in your bags.
- **Optional routing**, party sharing, search in the All view, and a minimap button.
- **Resizable, movable window** with opacity, scale, and position-lock settings.

## Installation

1. Download this repository using **Code → Download ZIP** and extract it.
2. Copy the **`PhyzQuestBar`** folder into your Forever client's `Interface/AddOns/` folder.
3. Check that the resulting path is `Interface/AddOns/PhyzQuestBar/PhyzQuestBar.toc`.
4. Fully restart WoW and enable **Phyz's Quest bar** in the AddOns list.

For a client installed under `_forever_`, the destination is `World of Warcraft/_forever_/Interface/AddOns/`.

Install the `PhyzQuestBar` folder itself, rather than the downloaded repository folder. If you also use the original Quest Sidebar, disable it to avoid displaying two similar bars. This addon uses separate settings and does not replace it.

## Controls

| Control | Action |
| --- | --- |
| `/pqb` or `/phyzquestbar` | Show or hide the quest bar |
| `/pqb settings` | Open settings |
| `/pqb help` | List commands |
| Quest title | Open the quest in the quest log |
| Circular quest icon | Select or clear the active quest |
| Play button | Play or stop the quest's spoken audio, when available |
| Right-click → Track / Stop tracking | Track or untrack the quest |
| Ctrl-click a quest or use its right-click route action | Start or stop routing to that quest |
| Right-click a quest | Open quest actions |
| Shift-click a quest | Link it in chat |
| Zone heading | Expand or collapse that zone |
| Shift-click a zone heading | Pin or unpin the zone |
| Minimap button | Show or hide; right-click for settings |

Use the title-bar sharing button to share eligible quests from your current zone with your party. Automatic sharing is available in settings and is off by default.

## Optional integrations

The quest bar can be used on its own. Additional addons provide these features:

| Addon | Integration |
| --- | --- |
| Phyz Leveling | Follow the current guide step's quest using the bridge described below |
| Spoken (`Spoken_Quests`) | Quest voice playback with matching voice packs |
| Questie / QuestieDB | Additional quest and turn-in location data; Questie-style circular quest icons |
| Shortest Path Forever | Travel routes, including supported flights, boats and portals |

### Follow Phyz Leveling

With Phyz Leveling installed and enabled, **Follow Phyz Leveling step** is on by default unless you previously disabled it. The quest bar reads the leveling addon's live active steps, including sticky objectives, and highlights matching quests already in your quest log. The current step takes priority for the quest arrow.

Selected quests have a glowing icon, gold left edge and subtle background tint. Turn this setting off to select quests manually. Your choice is remembered.

No changes to Phyz Leveling's files are required. The legacy bridge under `integration/` is retained for compatibility with older setups.

## Compatibility and support

Targets the Forever client with interface version **16001**. Other WoW editions are not currently supported. Forever client updates may change addon APIs; in-game testing is still needed after updates.

Report problems through [GitHub Issues](https://github.com/phyzikalgamer/Phyz-s-Quest-Side-bar/issues). Include your addon version, client build, steps to reproduce, and any Lua error text. Screenshots help with layout issues.

See [the changelog](PhyzQuestBar/CHANGELOG.md) for version history.

## Credits and licence

Developed by **Phyz**, based on **Quest Sidebar by Kaeldrom**. Original copyright and licence notices are preserved.

Released under the [MIT licence](LICENSE). Optional third-party addons are separate projects with their own licences.
