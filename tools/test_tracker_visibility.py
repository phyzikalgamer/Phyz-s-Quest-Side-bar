"""Regression checks for tracker visibility. Requires lupa Lua 5.1."""
from pathlib import Path
import sys

root = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(root.parent / 'Leveling Addon' / 'backups' / 'test-runtime'))
from lupa.lua51 import LuaRuntime

lua = LuaRuntime()
source = (root / 'PhyzQuestBar' / 'PhyzQuestBar_UI.lua').read_text()
block = source[source.index('local hooked = {}'):source.index('-- window\n')]
lua.execute('''
local UI = {}
local db = {settings={hideTracker=true}}
local combat = false
function InCombatLockdown() return combat end
local function Frame(shown)
    return {
        shown=shown, hooks={},
        HookScript=function(self,event,fn) self.hooks[event]=fn end,
        IsShown=function(self) return self.shown end,
        Hide=function(self) assert(not combat); self.shown=false end,
        Show=function(self)
            assert(not combat); self.shown=true
            if self.hooks.OnShow then self.hooks.OnShow(self) end
        end
    }
end
ObjectiveTrackerFrame = Frame(true)
WatchFrame = Frame(false)
''' + block + '''
UI.ApplyTracker()
assert(not ObjectiveTrackerFrame.shown)
ObjectiveTrackerFrame:Show()
assert(not ObjectiveTrackerFrame.shown) -- Prevent delayed re-show.
QuestWatchFrame = Frame(true)
UI.ApplyTracker()
assert(not QuestWatchFrame.shown) -- Frame created after login.
db.settings.hideTracker=false
UI.ApplyTracker(true)
assert(ObjectiveTrackerFrame.shown and QuestWatchFrame.shown)
assert(not WatchFrame.shown) -- Do not show an initially hidden frame.
db.settings.hideTracker=true
combat=true
UI.ApplyTracker()
assert(ObjectiveTrackerFrame.shown) -- No protected mutation in combat.
combat=false
UI.ApplyTracker()
assert(not ObjectiveTrackerFrame.shown)
''')
print('PASS: hide on load; delayed frames; re-show hooks; selective restore; combat deferral.')
