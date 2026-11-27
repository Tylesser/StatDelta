local _, ns = ...
local L = ns.L

local GetItemInfoInstant = (C_Item and C_Item.GetItemInfoInstant) or GetItemInfoInstant

local MAIN_HAND, OFF_HAND, RANGED = 16, 17, 18

local SLOTS = {
  INVTYPE_HEAD = { 1 },
  INVTYPE_NECK = { 2 },
  INVTYPE_SHOULDER = { 3 },
  INVTYPE_BODY = { 4 },
  INVTYPE_CHEST = { 5 },
  INVTYPE_ROBE = { 5 },
  INVTYPE_WAIST = { 6 },
  INVTYPE_LEGS = { 7 },
  INVTYPE_FEET = { 8 },
  INVTYPE_WRIST = { 9 },
  INVTYPE_HAND = { 10 },
  INVTYPE_FINGER = { 11, 12 },
  INVTYPE_TRINKET = { 13, 14 },
  INVTYPE_CLOAK = { 15 },
  INVTYPE_TABARD = { 19 },
}

local ONE_HAND = { INVTYPE_WEAPON = true, INVTYPE_WEAPONMAINHAND = true }
local OFF_HAND_TYPES = { INVTYPE_WEAPONOFFHAND = true, INVTYPE_SHIELD = true, INVTYPE_HOLDABLE = true }
local RANGED_TYPES = { INVTYPE_RANGED = true, INVTYPE_RANGEDRIGHT = true, INVTYPE_THROWN = true, INVTYPE_RELIC = true }

local function EquipLoc(link)
  return link and select(4, GetItemInfoInstant(link))
end
ns.EquipLoc = EquipLoc

local function IsTwoHand(equipLoc)
  return equipLoc == "INVTYPE_2HWEAPON" or (not ns.hasRangedSlot and RANGED_TYPES[equipLoc] and equipLoc ~= "INVTYPE_RELIC")
end

local function Equipped(slot)
  return GetInventoryItemLink("player", slot)
end

-- Returns a list of comparisons; each one lists the equipped links the item would replace
-- (an empty list means an empty slot).
local function FindReplaced(link, equipLoc)
  local mainHand, offHand = Equipped(MAIN_HAND), Equipped(OFF_HAND)
  local mainIsTwoHand = IsTwoHand(EquipLoc(mainHand))

  if IsTwoHand(equipLoc) then
    return { { mainHand, offHand } }
  elseif OFF_HAND_TYPES[equipLoc] then
    -- An off-hand item takes the place of a two-handed weapon.
    return { { mainIsTwoHand and mainHand or offHand } }
  elseif ONE_HAND[equipLoc] then
    local list = { { mainHand } }
    if equipLoc == "INVTYPE_WEAPON" and offHand and EquipLoc(offHand) ~= "INVTYPE_SHIELD"
      and EquipLoc(offHand) ~= "INVTYPE_HOLDABLE" then
      table.insert(list, { offHand }) -- dual wield: it could replace either weapon
    end
    return list
  elseif RANGED_TYPES[equipLoc] then
    return { { Equipped(RANGED) } }
  end

  local slots = SLOTS[equipLoc]
  if not slots then
    return nil
  end
  if #slots == 1 then
    return { { Equipped(slots[1]) } }
  end
  -- Rings and trinkets: an empty slot is where it would go; otherwise compare with both.
  local first, second = Equipped(slots[1]), Equipped(slots[2])
  if first == link or second == link then
    return { { link } } -- already equipped; BuildComparisons skips it
  end
  if not first or not second then
    return { {} }
  end
  return { { first }, { second } }
end
ns.FindReplaced = FindReplaced

local function FormatValue(value, fmt)
  if fmt == "pct" then
    return string.format("%+.2f%%", value), math.abs(value) >= 0.005
  elseif fmt == "dec" then
    return string.format("%+.1f", value), math.abs(value) >= 0.05
  end
  local rounded = value >= 0 and math.floor(value + 0.5) or -math.floor(-value + 0.5)
  return string.format("%+d", rounded), rounded ~= 0
end

-- Builds { header = text, lines = { { label, valueText, value } } } for each comparison.
function ns.BuildComparisons(link)
  local equipLoc = EquipLoc(link)
  if not equipLoc or equipLoc == "" then
    return nil
  end
  local replacedList = FindReplaced(link, equipLoc)
  if not replacedList then
    return nil
  end
  -- Hovering an item that's already equipped (character window): nothing to compare.
  for _, replaced in ipairs(replacedList) do
    for i = 1, 2 do
      if replaced[i] == link then
        return nil
      end
    end
  end
  local newStats = ns.GetItemStats(link)
  if not newStats then
    return nil
  end
  local newTotal, newEstimated = ns.WithConversions(newStats)
  local weights = ns.ScoreShown and ns.ScoreShown() and ns.ActiveWeights()
  local newScore = weights and ns.Score(newStats, weights)

  local comparisons = {}
  for _, replaced in ipairs(replacedList) do
    local oldList, links = {}, {}
    local ready = true
    for i = 1, 2 do
      local oldLink = replaced[i]
      if oldLink then
        local stats = ns.GetItemStats(oldLink)
        if not stats then
          ready = false
        end
        table.insert(oldList, stats or {})
        table.insert(links, oldLink)
      end
    end
    if ready then
      local oldStats = ns.SumStats(oldList)
      local oldTotal, oldEstimated = ns.WithConversions(oldStats)
      local comparison = { itemLines = {}, characterLines = {} }
      if weights then
        comparison.score = { new = newScore, old = ns.Score(oldStats, weights) }
      end
      if #links == 0 then
        comparison.header = L["Compared to an empty slot:"]
      else
        comparison.header = L["Compared to %s:"]:format(table.concat(links, " + "))
      end
      for _, stat in ipairs(ns.STATS) do
        -- Item stats: only what's printed on the items.
        local raw = (newStats[stat.key] or 0) - (oldStats[stat.key] or 0)
        local rawText, rawNonZero = FormatValue(raw, stat.fmt)
        if rawNonZero and (not stat.primary or ns.db.showPrimary) then
          table.insert(comparison.itemLines, { stat.label, rawText, raw })
        end
        -- Your character: totals that include the conversions, when they differ from the above.
        if ns.CONVERTED[stat.key] and (not stat.primary or ns.db.showPrimary) then
          local total = (newTotal[stat.key] or 0) - (oldTotal[stat.key] or 0)
          local text, nonZero = FormatValue(total, stat.fmt)
          if nonZero and text ~= rawText then
            if newEstimated[stat.key] or oldEstimated[stat.key] then
              text = "~" .. text
            end
            table.insert(comparison.characterLines, { stat.label, text, total })
          end
        end
      end
      table.insert(comparisons, comparison)
    end
  end
  return comparisons
end

-- Lines in the item tooltip ---------------------------------------------------------
-- Any item tooltip gets the lines, not only GameTooltip:
-- * Tooltips built on Blizzard's GameTooltipTemplate (bag, quest and dialogue addons often use
--   their own): found through TooltipDataProcessor or OnTooltipSetItem.
-- * Custom tooltips that draw C_TooltipInfo data themselves, like DialogueUI's: frames with
--   ProcessTooltipData, GetHyperlink, AddDoubleLine and ReprocessInfo. They're found once all
--   addons have loaded, and ProcessTooltipData is hooked.
-- The shopping (compare) tooltips never get lines.

local added = {}  -- tooltip -> true while it shows the lines
local seen = {}   -- tooltip -> "template" or "custom": tooltips the Shift watcher looks after

local function CompareKeyDown()
  if IsModifiedClick("COMPAREITEMS") then
    return true
  end
  local ok, always = pcall(C_CVar and C_CVar.GetCVarBool or GetCVarBool, "alwaysCompareItems")
  return ok and always
end

local function IsShoppingTooltip(tooltip)
  if tooltip == ShoppingTooltip1 or tooltip == ShoppingTooltip2
    or tooltip == ItemRefShoppingTooltip1 or tooltip == ItemRefShoppingTooltip2 then
    return true
  end
  local ok, name = pcall(tooltip.GetName, tooltip)
  return ok and type(name) == "string" and name:find("Shopping") ~= nil
end

local function ItemLink(tooltip)
  if seen[tooltip] == "custom" then
    return tooltip:GetHyperlink()
  end
  if tooltip.GetItem then
    local _, link = tooltip:GetItem()
    return link
  end
end

local function AddStatLines(tooltip, lines)
  for _, line in ipairs(lines) do
    local label, text, value = line[1], line[2], line[3]
    if value > 0 then
      tooltip:AddDoubleLine("  " .. label, text, 0.85, 0.85, 0.85, 0.1, 1, 0.1)
    else
      tooltip:AddDoubleLine("  " .. label, text, 0.85, 0.85, 0.85, 1, 0.25, 0.25)
    end
  end
end

-- Adds the stat changes to the bottom of the tooltip, only while the compare key (Shift) is held.
-- show: call tooltip:Show() afterwards so the tooltip resizes (not needed inside a custom
-- tooltip's own build, which shows itself when done).
local function AddComparisons(tooltip, show)
  if added[tooltip] or not ns.db or not ns.db.enabled or not CompareKeyDown() then
    return
  end
  local ok, link = pcall(ItemLink, tooltip)
  if not (ok and link) then
    return
  end
  local comparisons = ns.BuildComparisons(link)
  if not comparisons or #comparisons == 0 then
    return
  end
  added[tooltip] = true
  local gold = ns.T.GOLD
  tooltip:AddLine(" ")
  tooltip:AddLine(ns.T.TextIcon(ns.T.STUD, 14) .. " STAT DELTA", gold[1], gold[2], gold[3])
  for index, comparison in ipairs(comparisons) do
    if index > 1 then
      tooltip:AddLine(" ")
    end
    tooltip:AddLine(comparison.header, 1, 1, 1)
    if comparison.score then
      local text, r, g, b = ns.ScoreText(comparison.score.new, comparison.score.old)
      tooltip:AddLine(text, r, g, b)
    end
    if #comparison.itemLines == 0 and #comparison.characterLines == 0 then
      tooltip:AddLine("  " .. L["No stat changes"], 0.6, 0.6, 0.6)
    end
    if #comparison.itemLines > 0 then
      tooltip:AddLine(L["Item stats"], gold[1], gold[2], gold[3])
      AddStatLines(tooltip, comparison.itemLines)
    end
    if #comparison.characterLines > 0 then
      tooltip:AddLine(L["Your character"], gold[1], gold[2], gold[3])
      AddStatLines(tooltip, comparison.characterLines)
    end
  end
  if show ~= false then
    tooltip:Show()
  end
end

-- Rebuilds the tooltip from scratch (adding the stat changes again only if Shift is held).
-- If the tooltip can't be rebuilt, its lines stay until the mouse moves away.
local function RefreshTooltip(tooltip)
  added[tooltip] = nil
  if seen[tooltip] == "custom" then
    tooltip:ReprocessInfo()
    return
  end
  if tooltip.RefreshData then
    tooltip:RefreshData()
    return
  end
  local owner = tooltip.GetOwner and tooltip:GetOwner()
  local onEnter = owner and owner.GetScript and owner:GetScript("OnEnter")
  if onEnter and owner:IsMouseOver() then
    onEnter(owner)
  else
    added[tooltip] = true
  end
end

-- First time a template tooltip shows an item: forget the lines whenever it's cleared.
local function WatchTemplateTooltip(tooltip)
  if seen[tooltip] then
    return
  end
  seen[tooltip] = "template"
  if tooltip.HookScript then
    tooltip:HookScript("OnTooltipCleared", function(self)
      added[self] = nil
    end)
  end
end

-- Hidden tooltips that addons use to read item text (scanners) must never get lines. GameTooltip and
-- ItemRefTooltip always count; other tooltips count when visible or anchored somewhere (a scanner
-- owned with ANCHOR_NONE has no points; a real tooltip may not be shown yet when it gets its item).
local function IsOnScreen(tooltip)
  if tooltip == GameTooltip or tooltip == ItemRefTooltip then
    return true
  end
  if tooltip:IsVisible() then
    return true
  end
  return tooltip.GetNumPoints ~= nil and tooltip:GetNumPoints() > 0
end

local function OnTemplateItem(tooltip)
  local ok, onScreen = pcall(IsOnScreen, tooltip)
  if IsShoppingTooltip(tooltip) or not (ok and onScreen) then
    return
  end
  WatchTemplateTooltip(tooltip)
  AddComparisons(tooltip)
end

-- Custom tooltips (DialogueUI and others built the same way).
local function IsCustomTooltip(frame)
  return type(frame) == "table" and not seen[frame]
    and type(frame.ProcessTooltipData) == "function" and type(frame.GetHyperlink) == "function"
    and type(frame.AddDoubleLine) == "function" and type(frame.ReprocessInfo) == "function"
    and type(frame.ClearLines) == "function"
end

local function WatchCustomTooltip(tooltip)
  seen[tooltip] = "custom"
  hooksecurefunc(tooltip, "ClearLines", function(self)
    added[self] = nil
  end)
  hooksecurefunc(tooltip, "ProcessTooltipData", function(self, tooltipData)
    if tooltipData and tooltipData.isItem then
      AddComparisons(self, false)
    end
  end)
end

local function FindCustomTooltips()
  if not EnumerateFrames then
    return
  end
  local frame = EnumerateFrames()
  while frame do
    local ok, match = pcall(IsCustomTooltip, frame)
    if ok and match then
      WatchCustomTooltip(frame)
    end
    frame = EnumerateFrames(frame)
  end
end

-- Equipment, level or settings changed: rebuild the open tooltips that show the lines.
function ns.Refresh()
  local open = {}
  for tooltip in pairs(added) do
    if tooltip:IsShown() then
      open[#open + 1] = tooltip
    end
  end
  for _, tooltip in ipairs(open) do
    RefreshTooltip(tooltip)
  end
end

-- Shift pressed or released while an item tooltip is open.
local function OnKeyChange(down)
  for tooltip in pairs(seen) do
    if tooltip:IsShown() then
      if down then
        if seen[tooltip] == "custom" then
          RefreshTooltip(tooltip) -- rebuilt with the lines, as Shift is down now
        else
          AddComparisons(tooltip)
        end
      elseif added[tooltip] then
        RefreshTooltip(tooltip)
      end
    end
  end
end

function ns.HookTooltips()
  seen[GameTooltip] = "template"
  GameTooltip:HookScript("OnTooltipCleared", function(self)
    added[self] = nil
  end)
  if TooltipDataProcessor and TooltipDataProcessor.AddTooltipPostCall and Enum and Enum.TooltipDataType then
    TooltipDataProcessor.AddTooltipPostCall(Enum.TooltipDataType.Item, OnTemplateItem)
  else
    GameTooltip:HookScript("OnTooltipSetItem", OnTemplateItem)
    -- clients without TooltipDataProcessor: other template tooltips are hooked when first shown
    if ItemRefTooltip and ItemRefTooltip.HookScript then
      ItemRefTooltip:HookScript("OnTooltipSetItem", OnTemplateItem)
    end
  end

  local watcher = CreateFrame("Frame")
  watcher:RegisterEvent("PLAYER_LOGIN")
  watcher:SetScript("OnEvent", function(self)
    -- every addon has loaded by now, so their custom tooltips exist
    FindCustomTooltips()
    self:UnregisterEvent("PLAYER_LOGIN")
  end)
  if IsLoggedIn and IsLoggedIn() then
    FindCustomTooltips()
  end

  local elapsed, keyDown = 0, false
  watcher:SetScript("OnUpdate", function(_, delta)
    elapsed = elapsed + delta
    if elapsed < 0.05 then
      return
    end
    elapsed = 0
    local down = CompareKeyDown() and true or false
    if down ~= keyDown then
      keyDown = down
      OnKeyChange(down)
    end
  end)
end
