-- Loaded by PhyzLeveling: expose only the current step's unfinished quest IDs.
local _, addon = ...
PhyzLevelingQuestBarAPI = {}
function PhyzLevelingQuestBarAPI.GetCurrentStepQuestIDs()
    local guide = addon.currentGuide
    local index = addon.GetGuideProgress and addon.GetGuideProgress()
    local step = guide and guide.steps and guide.steps[index or 1]
    local ids, seen = {}, {}
    for _, element in ipairs(step and step.elements or {}) do
        local id = tonumber(element.questId)
        if id and id > 0 and not element.completed and not element.skip and not seen[id] then
            ids[#ids + 1] = id
            seen[id] = true
        end
    end
    return ids
end
