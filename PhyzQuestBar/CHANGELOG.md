# Phyz's Quest bar changelog

## 0.4.1 - 2026-11-17

- Move Share all quests to a small title-bar button beside Settings.
- Remove the full-width sharing row and retain current-zone sharing, tooltips and disabled/busy behaviour.

## 0.4.0 - 2026-11-17

- Use Blizzard's standard inset window artwork, native scrollbar thumb and standard gold zone headings.
- Improve title clearance, row control alignment, selected-tab text and list spacing.
- Widen the minimum window and settings panel to keep controls readable; preserve saved position and other settings.

## 0.3.1 - 2026-11-17

- Keep ready-to-turn-in quests visible in Current Zone, including their completion highlight and zone count. The Turn in tab remains available.

## 0.3.0 - 2026-11-17

- Added Follow Phyz Leveling step in settings, enabled by default when the leveling bridge is loaded. Explicitly disabling it is remembered.
- Automatically selects the first unfinished quest in the current guide step that is in the quest log; steps without one clear the guide highlight.
- Added a small PhyzLeveling bridge, stored under integration in the source workspace and loaded from PhyzLeveling's manifest when installed.

## 0.1.0 - 2026-11-17

- Forked Quest Sidebar 1.12.0 with original MIT credit preserved.
- Renamed the addon, global identifiers, UI frames and saved settings to PhyzQuestBar.
- Added /pqb and /phyzquestbar commands.
- Declared PhyzLeveling as an optional dependency for future integration.

## Original Quest Sidebar history

# Changelog

## 1.12.0 - 2026-11-15

- **Finished quests have moved to the Turn in tab.** Current Zone now lists only the quests you still need to do. A gold line at the top, such as "2 ready to turn in  4,650 XP - open Turn in", tells you how many are waiting and what they're worth. Click it to jump to the Turn in tab. When everything in a zone is finished, it says "Nothing left to do in <zone>."

## 1.11.0 - 2026-11-15

- **Quest item buttons.** A quest that needs you to use an item now has a button for it just outside the sidebar, level with the quest. Click it to use the item; it shows charges and its cooldown. It works in combat too; if the list moves mid-fight, the buttons line up again when combat ends. It uses the game's own quest item, or, for older quests that don't flag one, the item the quest gave you (from Questie's data) if it's in your bags. Turn it off with **Quest item buttons** in settings.
- **Fixed:** some quests were listed under the place you did the objective instead of where you hand them in. For example, Earthen Echo showed under "Excavation Site: Wetlands" instead of Mulgore. Turn-in places now come straight from Questie's data, even before Questie has finished starting up, and the misleading map from the game is no longer used.

## 1.10.0 - 2026-11-15

- **The Turn in tab is grouped by where you hand quests in**, not the zone you got them in. A quest you did in the Barrens but hand in at Orgrimmar is listed under **Orgrimmar**. The place you're in comes first, then A to Z. Inside each place, quests are listed nearest first.
- **Each quest names who to hand it to**, for example "Hand in to Thrall in Orgrimmar.", when the game doesn't provide its own turn-in text.
- **Route to every turn-in at a place.** Each place header in the Turn in tab has a map button. Click it to be taken to every hand-in there, one after another, nearest first. Each time you hand one in, the rest are re-planned from where you're standing. Click it again to stop.
  - With Shortest Path Forever, it's one journey with a stop at each NPC.
  - Without it, the quest arrow moves from one hand-in to the next.
- Turn-in places come from Questie's quest database when Questie is installed. Without Questie, the game's own turn-in marker is used.

## 1.9.0 - 2026-11-14

- **XP for each turn-in.** Every finished quest shows the XP you'll get for handing it in, for example **+1,250 XP**, next to "Ready to turn in".
- The **Ready to turn in** section in Current Zone shows the total XP for that zone.
- The **Turn in** tab starts with the total for every finished quest and how much of a level that is, for example **Total 4,650 XP (25% of a level)**.
- The numbers update when you level up. At max level they're hidden, because quests pay gold instead.

## 1.8.2 - 2026-11-14

- The settings panel has an **X** in its corner to close it, so you no longer need to click the cog again.

## 1.8.1 - 2026-11-14

- **Fixed:** finished quests weren't recognised in the game, so the **Turn in** tab was empty and the **Ready to turn in** section never appeared. The game no longer reports "finished" in the quest log entry, so the addon now asks each quest directly, the same way Questie and Shortest Path Forever do. Failed quests are detected the same way.
- **The fastest-route button is now an on/off switch.** Click it again (or Ctrl-click the quest again, or choose **Stop the route** in the right-click menu) to stop the journey and clear the arrow. If routing was what started tracking the quest, it is untracked again. While a route is running, its button glows gold.

## 1.8.0 - 2026-11-14

- New **Turn in** tab. It lists every finished quest from every zone, grouped by zone, with the zone you're in at the top.
  - Each quest says who to hand it to when the game provides it, and has the fastest-route button, so you can plan a hand-in run.
  - The tab shows how many quests are ready, for example **Turn in 3**.
  - `/qsb turnin` opens it.
- The tabs are a little narrower so all three fit. The narrowest the window can go is now 250 wide (it was 230); a smaller saved size widens to fit.

## 1.7.0 - 2026-11-14

- **Fastest route to a quest.** Each quest has a small map button, and the right-click menu now starts with **Fastest route there**. Ctrl-clicking a quest does the same, and `/qsb route` routes to your tracked quest in the zone you're in.
  - With [Shortest Path Forever](https://www.curseforge.com/wow/addons/shortest-path-forever) installed, it plans the quickest journey: walking, flight paths, boats, zeppelins, lifts, the tram, portals and teleports. It takes you to the quest's objective area, or to the turn-in NPC once the quest is done.
  - Without it, the quest becomes your tracked quest and the game's own arrow points the way, in a straight line only.

## 1.6.0 - 2026-11-14

- Finished quests stand out much more in the **Current Zone** tab:
  - They have their own **Ready to turn in** section at the top, with a count. The rest follow under **In progress**.
  - Each one has a gold edge down the left, a stronger gold highlight, and a green tick next to "Ready to turn in".
  - When the game provides it, the quest says who to hand it in to (for example "Return to Regthar Deathgate..."). If it doesn't, you see the usual quest summary.
- The finished count on zone headers is green.

## 1.5.0 - 2026-11-14

- **Party markers.** In a party, each quest shows how many party members have it, for example `1/2`. Hover over the quest to see who has it and who doesn't.
- **Share all quests** now skips quests your whole party already has.
- **Right-click menu** on a quest: Track, Share with party, Link in chat, Show in quest log, and Abandon quest (it asks first). Right-click used to only track the quest.
- **Auto-share new quests with party.** A new setting, **off by default**. When it's on, any quest you pick up while in a party is shared straight away. Quests the whole party already has are not sent back. `/qsb autoshare` turns it on and off too.
- **Ready to turn in** quests move to the top of their zone with a soft gold highlight.
- **Search box** on the All tab. It searches quest names, objectives and zone names.
- **Quest log full warning.** The count in the title turns orange when you have 3 or fewer slots left, and red when the log is full.
- **Hide grey quests.** A new setting (`/qsb grey`) that hides quests far below your level. Quests that are ready to turn in always stay visible.

## 1.4.0 - 2026-11-14

- New **Share all quests** button in the Current Zone tab. In a party, it shares every quest you have for the zone you are in, one after another, with a short gap between each.
- If a party member is busy (they still have the last shared quest open), that quest is tried again at the end, up to 3 times.
- Quests that the game won't let you share are skipped, and the chat message tells you how many.
- When you're not in a group the button is greyed out. `/qsb share` does the same as the button.

## 1.3.1 - 2026-11-14

- The settings button is now a proper cog symbol. It is gold when you hover over it.

## 1.3.0 - 2026-11-14

- The close X is replaced by a **minimize** button. It shrinks the window to its title bar, and clicking again restores it to the size you chose. `/qsb min` does the same.
- **Minimap button:** click to show or hide the sidebar, right-click for settings, drag to move it around the minimap. You can turn it off in settings or with `/qsb minimap`.
- Reset size & position also restores a minimized window.

## 1.2.0 - 2026-11-14

- Settings panel: click the small cog in the title bar (or `/qsb settings`). It has an **Opacity** slider, a **Size** slider, and checkboxes for opening the zone you're in, showing objectives, hiding Blizzard's tracker, and locking the position.
- Opacity fades the window background and zone bars only. Quest text and buttons stay solid. `/qsb opacity 70` works too.
- Zone bars restyled after the world-map quest log: a dark brown bar with a thin bronze frame, the zone name in large off-white text, and a flat yellow - (open) or + (closed). In the All tab, the zone you're in reads gold.

## 1.1.0 - 2026-11-14

- New look, based on the quest log in the world map: grey zone bars with gold names and -/+ buttons, quest icons, "[level] Title" coloured by difficulty, "- objective" lines, (Dungeon)/(Elite) tags, an open button and a track checkbox on every quest.
- Two tabs: **Current Zone** (the default) shows only the quests for where you are, with each quest's objective text, and updates as you travel. **All** shows every zone like before.
- Zones are sorted A-Z. A leading "The" is ignored, so The Barrens sorts under B.
- The window can be resized with the grip in the bottom-right corner, and keeps its size and position. Opening and closing zones scrolls inside the window instead of making it grow or move. There's a scroll bar when the list is longer than the window.
- Click a quest to show or hide its objectives.
- Closing the window (X) brings Blizzard's tracker back. Reopening it starts on Current Zone.

## 1.0.0 - 2026-11-14

- First release.
