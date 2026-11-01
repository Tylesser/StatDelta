local addonName, ns = ...

local eventFrame = CreateFrame("Frame")
eventFrame:RegisterEvent("ADDON_LOADED")
eventFrame:RegisterEvent("PLAYER_EQUIPMENT_CHANGED")
eventFrame:RegisterEvent("PLAYER_LEVEL_UP")
eventFrame:SetScript("OnEvent", function(_, event, loadedName)
  if event ~= "ADDON_LOADED" then
    ns.Refresh()
    return
  end
  if loadedName ~= addonName then
    return
  end
  StatDeltaDB = StatDeltaDB or {}
  for key, value in pairs(ns.defaults) do
    if StatDeltaDB[key] == nil then
      StatDeltaDB[key] = value
    end
  end
  ns.db = StatDeltaDB
  ns.HookTooltips()
  eventFrame:UnregisterEvent("ADDON_LOADED")
end)

local function OnOff(value)
  return value and "|cff20ff20on|r" or "|cffff4040off|r"
end

SLASH_STATDELTA1 = "/statdelta"
SLASH_STATDELTA2 = "/sdelta"
SlashCmdList.STATDELTA = function(msg)
  msg = strtrim(msg or ""):lower()
  if msg == "on" or msg == "off" then
    ns.db.enabled = msg == "on"
    print(ns.PREFIX .. "stat changes " .. OnOff(ns.db.enabled) .. ".")
  elseif msg == "primary" then
    ns.db.showPrimary = not ns.db.showPrimary
    print(ns.PREFIX .. "Strength, Agility, Stamina, Intellect and Spirit " .. OnOff(ns.db.showPrimary) .. ".")
  else
    print(ns.PREFIX .. "hold Shift over an item to see the stat changes (" .. OnOff(ns.db.enabled) .. ").")
    print("  /sdelta on | off: turn the stat changes on or off")
    print("  /sdelta primary: show or hide Strength, Agility, Stamina, Intellect and Spirit ("
      .. OnOff(ns.db.showPrimary) .. ")")
  end
  ns.Refresh()
end
