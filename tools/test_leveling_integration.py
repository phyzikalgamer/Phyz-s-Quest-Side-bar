"""Regression checks for live guide selection. Requires lupa with Lua 5.1."""
from pathlib import Path
import sys

root = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(root.parent / 'Leveling Addon' / 'backups' / 'test-runtime'))
from lupa.lua51 import LuaRuntime

lua = LuaRuntime(unpack_returned_tuples=True)
for path in (root / 'PhyzQuestBar').glob('*.lua'):
    lua.execute('assert(loadstring(...))', path.read_text(encoding='utf-8-sig'))
lua.execute('''
PhyzQuestBar = {}
C_AddOns = {IsAddOnLoaded = function(name) return name == 'PhyzLeveling' end}
RXPFrame = {activeSteps = {
    {elements = {{questId=101}, {questId=102, completed=true}, {questId=103, skip=true}}},
    {elements = {{questId=201}, {questId=101}, {questId=999}}}
}}
''')
lua.execute((root / 'PhyzQuestBar' / 'PhyzLevelingIntegration.lua').read_text())
lua.execute('''
assert(PhyzQuestBar.LevelingAvailable()) -- No bridge global or modified leveling manifest.
local ids = PhyzQuestBar.LevelingQuestIDs()
assert(#ids == 3 and ids[1] == 201 and ids[2] == 101 and ids[3] == 999)
''')
core = (root / 'PhyzQuestBar' / 'PhyzQuestBar.lua').read_text()
selection = core[core.index('function QSB.IsActive(q)'):core.index('function QSB.ToggleActive(q)')]
lua.execute('''
local QSB = PhyzQuestBar
local db = {settings={followPhyzLeveling=true}}
local entries = {{questID=101}, {questID=201}, {isHeader=true}}
local function NumEntries() return #entries end
local function Entry(i) return entries[i] end
local refreshes = 0
QSB.QueueRefresh = function() refreshes = refreshes + 1 end
C_SuperTrack = {SetSuperTrackedQuestID=function(id) selectedArrow=id end}
''' + selection + '''
QSB.SyncLevelingQuest()
assert(selectedArrow == 201)
assert(QSB.IsActive({questID=101}) and QSB.IsActive({questID=201}))
assert(not QSB.IsActive({questID=999})) -- Guide quest missing from quest log.
QSB.SyncLevelingQuest()
assert(refreshes == 1) -- Stable polling does not redraw.
RXPFrame.activeSteps[2].elements = {{questId=201}}
RXPFrame.activeSteps[1].elements[1].completed = true
QSB.SyncLevelingQuest()
assert(not QSB.IsActive({questID=101}) and QSB.IsActive({questID=201}))
assert(refreshes == 2) -- Sticky membership changed with the same primary quest.
RXPFrame.activeSteps = {}
QSB.SyncLevelingQuest()
assert(selectedArrow == 0 and not QSB.IsActive({questID=201}))
''')
print('PASS: Lua 5.1 syntax; bridge-free selection; current and sticky steps; completed/skipped filtering; quest-log membership; stable polling; clearing selection.')
