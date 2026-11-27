local addonName, ns = ...

local function CopyDefaults(target, defaults)
  for key, value in pairs(defaults) do
    if target[key] == nil then
      if type(value) == "table" then
        local copy = {}
        for k, v in pairs(value) do
          copy[k] = v
        end
        value = copy
      end
      target[key] = value
    end
  end
end

local eventFrame = CreateFrame("Frame")

-- Coalesced refresh: equipment changes fire once per slot (an outfit swap is ~19 events at once),
-- so open tooltips and arrows are rebuilt once, half a second after the last change. Arrow work waits
-- for the end of combat. forget: what the character can use changed (level, new weapon skill).
local pending, pendingForget = false, false

local function RunRefresh()
  pending = false
  if pendingForget then
    pendingForget = false
    ns.ForgetUsable()
  end
  ns.Refresh()
  if InCombatLockdown and InCombatLockdown() then
    eventFrame:RegisterEvent("PLAYER_REGEN_ENABLED")
    return
  end
  ns.RefreshArrows()
end

function ns.QueueRefresh(forget)
  if forget then
    pendingForget = true
  end
  if pending then
    return
  end
  pending = true
  if C_Timer and C_Timer.After then
    C_Timer.After(0.5, RunRefresh)
  else
    RunRefresh()
  end
end

-- The learned skills (names, not ranks): weapon and defense skills rise every few swings, but only a
-- new skill (e.g. Two-Handed Swords from a trainer) changes what the character can use.
local function SkillSignature()
  if not (GetNumSkillLines and GetSkillLineInfo) then
    return nil
  end
  local names = {}
  for i = 1, GetNumSkillLines() do
    local name, isHeader = GetSkillLineInfo(i)
    if name and not isHeader then
      table.insert(names, name)
    end
  end
  table.sort(names)
  return table.concat(names, "|")
end
local skills

eventFrame:RegisterEvent("ADDON_LOADED")
eventFrame:RegisterEvent("PLAYER_LOGIN")
eventFrame:RegisterEvent("PLAYER_EQUIPMENT_CHANGED")
eventFrame:RegisterEvent("PLAYER_LEVEL_UP")
eventFrame:RegisterEvent("UNIT_LEVEL")
eventFrame:RegisterEvent("SKILL_LINES_CHANGED")
pcall(eventFrame.RegisterEvent, eventFrame, "ACTIVE_TALENT_GROUP_CHANGED") -- dual spec; not in every game
eventFrame:RegisterEvent("PLAYER_TALENT_UPDATE") -- also when the talents are first known after a login
pcall(eventFrame.RegisterEvent, eventFrame, "TRAIT_CONFIG_UPDATED") -- WoW Forever: talents spent or reset
eventFrame:SetScript("OnEvent", function(_, event, loadedName)
  if event == "PLAYER_EQUIPMENT_CHANGED" then
    ns.QueueRefresh()
    return
  elseif event == "PLAYER_LEVEL_UP" then
    -- UnitLevel may still give the old level now: the delayed refresh reads it later
    ns.QueueRefresh(true)
    return
  elseif event == "UNIT_LEVEL" then
    if loadedName == "player" then
      ns.QueueRefresh(true)
    end
    return
  elseif event == "ACTIVE_TALENT_GROUP_CHANGED" or event == "PLAYER_TALENT_UPDATE" or event == "TRAIT_CONFIG_UPDATED" then
    ns.SyncTalentScore() -- one upgrade score per talent group (Score.lua)
    ns.ForgetTalents() -- talents that turn one stat into another (Stats.lua)
    ns.QueueRefresh()
    return
  elseif event == "SKILL_LINES_CHANGED" or event == "PLAYER_LOGIN" then
    if event == "PLAYER_LOGIN" then
      ns.SyncTalentScore()
    end
    local signature = SkillSignature()
    if event == "SKILL_LINES_CHANGED" and skills ~= nil and signature ~= skills then
      ns.QueueRefresh(true)
    end
    skills = signature
    return
  elseif event == "PLAYER_REGEN_ENABLED" then
    eventFrame:UnregisterEvent("PLAYER_REGEN_ENABLED")
    ns.RefreshArrows()
    return
  end
  if loadedName ~= addonName then
    return
  end
  StatDeltaDB = StatDeltaDB or {}
  CopyDefaults(StatDeltaDB, ns.defaults)
  ns.db = StatDeltaDB
  StatDeltaCharDB = StatDeltaCharDB or {}
  CopyDefaults(StatDeltaCharDB, ns.charDefaults)
  ns.charDB = StatDeltaCharDB
  ns.HookTooltips()
  ns.HookArrows()
  ns.CreateOptions()
  ns.T.AddCompartment({
    text = ns.TITLE,
    onClick = ns.OpenOptions,
    tooltip = { "Hold Shift over an item to compare it.", "Click to open the options." },
  })
  eventFrame:UnregisterEvent("ADDON_LOADED")
end)

local function OnOff(value)
  return value and "|cff20ff20on|r" or "|cffff4040off|r"
end

SLASH_STATDELTA1 = "/statdelta"
SLASH_STATDELTA2 = "/sdelta"
SlashCmdList.STATDELTA = function(msg)
  msg = strtrim(msg or ""):lower()
  if msg == "" or msg == "options" then
    ns.OpenOptions()
    return
  elseif msg == "on" or msg == "off" then
    ns.db.enabled = msg == "on"
    print(ns.PREFIX .. "stat changes " .. OnOff(ns.db.enabled) .. ".")
  elseif msg == "feedback" then
    ns.T.ShowFeedback()
    return
  elseif msg == "primary" then
    ns.db.showPrimary = not ns.db.showPrimary
    print(ns.PREFIX .. "Strength, Agility, Stamina, Intellect and Spirit " .. OnOff(ns.db.showPrimary) .. ".")
  else
    print(ns.PREFIX .. "hold Shift over an item to see the stat changes (" .. OnOff(ns.db.enabled) .. ").")
    print("  /sdelta: open the options (upgrade score, arrows)")
    print("  /sdelta on | off: turn the stat changes on or off")
    print("  /sdelta primary: show or hide Strength, Agility, Stamina, Intellect and Spirit ("
      .. OnOff(ns.db.showPrimary) .. ")")
    print("  /sdelta feedback: report a bug or suggest an idea")
  end
  ns.Refresh()
  if ns.RefreshOptions then
    ns.RefreshOptions()
  end
end
