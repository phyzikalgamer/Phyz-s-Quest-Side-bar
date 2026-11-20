"""Check native atlas slicing without stretching header caps. Requires lupa Lua 5.1."""
from pathlib import Path
import sys
root = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(root.parent / 'Leveling Addon' / 'backups' / 'test-runtime'))
from lupa.lua51 import LuaRuntime
lua = LuaRuntime()
source = (root / 'PhyzQuestBar' / 'PhyzQuestBar_UI.lua').read_text()
block = source[source.index('local function TrackerBar'):source.index('local function TrackerTab')]
lua.execute('''
local textures = {}
local parent = {CreateTexture=function()
    local texture = {}
    for _, name in ipairs({'SetAtlas','SetTexture','SetTexCoord','SetSize','SetPoint','SetHeight','SetAlpha','SetColorTexture'}) do
        texture[name] = function(self, ...) self[name .. 'Args'] = {...} end
    end
    table.insert(textures, texture)
    return texture
end}
local function SetGradient() end
C_Texture = {GetAtlasInfo=function(name)
    return {file=name,width=256,height=32,leftTexCoord=0.25,rightTexCoord=0.75,topTexCoord=0.1,bottomTexCoord=0.2}
end}
''' + block + '''
local bar = TrackerBar(parent, 28, true)
assert(bar.SetTextureArgs[1] == 'ui-questtracker-primary-objective-header' and not bar.SetAtlasArgs)
assert(#bar.pieces == 2 and #textures == 3)
assert(bar.pieces[1].SetSizeArgs[1] == 14)
assert(bar.pieces[2].SetSizeArgs[1] == 14)
assert(bar.pieces[1].SetTexCoordArgs[2] == bar.SetTexCoordArgs[1])
assert(bar.pieces[2].SetTexCoordArgs[1] == bar.SetTexCoordArgs[2])
SetBarAlpha(bar, 0.5)
assert(bar.SetAlphaArgs[1] == 0.5 and bar.pieces[1].SetAlphaArgs[1] == 0.5 and bar.pieces[2].SetAlphaArgs[1] == 0.5)
local section = TrackerBar(parent, 22)
assert(section.SetTextureArgs[1] == 'UI-QuestTracker-Secondary-Objective-Header')
C_Texture.GetAtlasInfo=function() return nil end
local fallback = TrackerBar(parent, 28, true)
assert(not fallback.SetAtlasArgs and fallback.SetHeightArgs[1] == 28)
''')
print('PASS: native primary/secondary atlases; continuous UV slices; fixed-width caps; shared opacity; missing-atlas fallback.')
