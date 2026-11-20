local QSB = PhyzQuestBar

function QSB.LevelingAvailable()
    local loaded = C_AddOns and C_AddOns.IsAddOnLoaded or IsAddOnLoaded
    return (loaded and loaded("PhyzLeveling")) or PhyzLevelingQuestBarAPI ~= nil
end

function QSB.LevelingQuestIDs()
    local ids, seen = {}, {}
    local function AddStep(step)
        if not step or step.completed then return end
        for _, element in ipairs(step.elements or {}) do
            local id = tonumber(element.questId)
            if id and id > 0 and not element.completed and not element.skip and not seen[id] then
                ids[#ids + 1] = id
                seen[id] = true
            end
        end
    end
    -- Phyz Leveling exposes its live steps on this frame, including sticky objectives.
    -- This survives leveling-addon updates without adding files to its manifest.
    if QSB.LevelingAvailable() and RXPFrame and RXPFrame.activeSteps then
        local steps = RXPFrame.activeSteps
        -- The current step is appended after sticky steps; prefer it for the quest arrow.
        for index = #steps, 1, -1 do AddStep(steps[index]) end
        return ids
    end
    local api = PhyzLevelingQuestBarAPI
    if api and api.GetCurrentStepQuestIDs then return api.GetCurrentStepQuestIDs() end
    return ids
end
