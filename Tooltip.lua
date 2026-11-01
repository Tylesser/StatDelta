local _, ns = ...

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
      if #links == 0 then
        comparison.header = "Compared to an empty slot:"
      else
        comparison.header = "Compared to " .. table.concat(links, " + ") .. ":"
      end
      for _, stat in ipairs(ns.STATS) do
        -- Item stats: only what's printed on the items.
        local raw = (newStats[stat.key] or 0) - (oldStats[stat.key] or 0)
        local rawText, rawNonZero = FormatValue(raw, stat.fmt)
        if rawNonZero and (not stat.primary or ns.db.showPrimary) then
          table.insert(comparison.itemLines, { stat.label, rawText, raw })
        end
        -- Your character: totals that include the conversions, when they differ from the above.
        if ns.CONVERTED[stat.key] then
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

local added = {}

local function CompareKeyDown()
  if IsModifiedClick("COMPAREITEMS") then
    return true
  end
  local ok, always = pcall(C_CVar and C_CVar.GetCVarBool or GetCVarBool, "alwaysCompareItems")
  return ok and always
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
local function AddComparisons(tooltip)
  if added[tooltip] or not ns.db or not ns.db.enabled or not CompareKeyDown() then
    return
  end
  local _, link = tooltip:GetItem()
  if not link then
    return
  end
  local comparisons = ns.BuildComparisons(link)
  if not comparisons or #comparisons == 0 then
    return
  end
  added[tooltip] = true
  for _, comparison in ipairs(comparisons) do
    tooltip:AddLine(" ")
    tooltip:AddLine("Stat Delta: " .. comparison.header, 1, 1, 1)
    if #comparison.itemLines == 0 and #comparison.characterLines == 0 then
      tooltip:AddLine("  No stat changes", 0.6, 0.6, 0.6)
    end
    if #comparison.itemLines > 0 then
      tooltip:AddLine("Item stats", 1, 0.82, 0)
      AddStatLines(tooltip, comparison.itemLines)
    end
    if #comparison.characterLines > 0 then
      tooltip:AddLine("Your character", 1, 0.82, 0)
      AddStatLines(tooltip, comparison.characterLines)
    end
  end
  tooltip:Show()
end

-- Rebuilds the tooltip from scratch (adding the stat changes again only if Shift is held).
-- If the tooltip can't be rebuilt, its lines stay until the mouse moves away.
local function RefreshTooltip(tooltip)
  added[tooltip] = nil
  if tooltip.RefreshData then
    tooltip:RefreshData()
    return
  end
  local owner = tooltip:GetOwner()
  local onEnter = owner and owner.GetScript and owner:GetScript("OnEnter")
  if onEnter and owner:IsMouseOver() then
    onEnter(owner)
  else
    added[tooltip] = true
  end
end

-- Equipment, level or settings changed: rebuild the open tooltip.
function ns.Refresh()
  if added[GameTooltip] and GameTooltip:IsShown() then
    RefreshTooltip(GameTooltip)
  end
end

function ns.HookTooltips()
  GameTooltip:HookScript("OnTooltipCleared", function(self)
    added[self] = nil
  end)
  if TooltipDataProcessor and TooltipDataProcessor.AddTooltipPostCall and Enum and Enum.TooltipDataType then
    TooltipDataProcessor.AddTooltipPostCall(Enum.TooltipDataType.Item, function(tooltip)
      if tooltip == GameTooltip then
        AddComparisons(tooltip)
      end
    end)
  else
    GameTooltip:HookScript("OnTooltipSetItem", AddComparisons)
  end

  -- Shift pressed or released while the tooltip is open.
  local elapsed, keyDown = 0, false
  GameTooltip:HookScript("OnUpdate", function(self, delta)
    elapsed = elapsed + delta
    if elapsed < 0.05 then
      return
    end
    elapsed = 0
    local down = CompareKeyDown() and true or false
    if down == keyDown then
      return
    end
    keyDown = down
    if down then
      AddComparisons(self)
    elseif added[self] then
      RefreshTooltip(self)
    end
  end)
end
