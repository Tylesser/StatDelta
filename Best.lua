local _, ns = ...
local L = ns.L

-- Best in bags: for each equipment slot, the bag item that beats what you wear there by the most points of the
-- upgrade score (usable items only, by the same comparisons as the tooltip: rings and trinkets against either
-- one, a two-hander against both weapons). Each bag item is offered for one slot only, the biggest gain first.
-- `/sdelta best` lists them in chat; the tooltip of an item you wear (the character window's slots) says "Better in
-- your bags: [item]" without Shift, while the score line is on. Worked out once and kept until the bags, your
-- gear or the score change (ns.ForgetBest, also from ns.RefreshArrows).

local GetContainerNumSlots = (C_Container and C_Container.GetContainerNumSlots) or GetContainerNumSlots
local GetContainerItemLink = (C_Container and C_Container.GetContainerItemLink) or GetContainerItemLink

local function Readable()
  return true
end

local function Say(text)
  print(ns.PREFIX .. text)
end
local BAGS = NUM_BAG_SLOTS or 4

local best -- the last result; nil: work it out again

function ns.ForgetBest()
  best = nil
end

local function Compute()
  local candidates, loading = {}, false
  for bag = 0, BAGS do
    for bagSlot = 1, GetContainerNumSlots(bag) or 0 do
      local link = GetContainerItemLink(bag, bagSlot)
      if type(link) == "string" and Readable(link) then
        local list = ns.UpgradeChoices(link)
        if list == nil then
          loading = true
        elseif list then
          for _, choice in ipairs(list) do
            if choice.slot and choice.new > choice.old + 0.001 then
              table.insert(candidates, { id = bag * 1000 + bagSlot, link = link, choice = choice,
                gain = choice.new - choice.old })
            end
          end
        end
      end
    end
  end
  table.sort(candidates, function(a, b)
    if a.gain ~= b.gain then
      return a.gain > b.gain
    end
    return a.id < b.id
  end)
  local bySlot, used, list = {}, {}, {}
  for _, candidate in ipairs(candidates) do
    local slot = candidate.choice.slot
    if bySlot[slot] and candidate.choice.altSlot then
      slot = candidate.choice.altSlot -- (both ring or trinket slots empty: the second one)
    end
    if not bySlot[slot] and not used[candidate.id] then
      used[candidate.id] = true
      local entry = { slot = slot, link = candidate.link, new = candidate.choice.new, old = candidate.choice.old,
        links = candidate.choice.links }
      bySlot[slot] = entry
      table.insert(list, entry)
    end
  end
  table.sort(list, function(a, b)
    return a.slot < b.slot
  end)
  return { list = list, bySlot = bySlot, loading = loading }
end

-- { list = { { slot, link, new, old, links } } (by slot), bySlot = { [slot] = entry }, loading = true when some
-- bag item wasn't loaded yet }; nil without a score.
function ns.BestInBags()
  if not ns.ActiveWeights() then
    return nil
  end
  if best then
    return best
  end
  local result = Compute()
  if not result.loading then
    best = result
  end
  return result
end

local function Colored(text, r, g, b)
  return ("|cff%02x%02x%02x%s|r"):format(math.floor(r * 255 + 0.5), math.floor(g * 255 + 0.5),
    math.floor(b * 255 + 0.5), text)
end

-- The chat list.
function ns.PrintBest()
  if ns.ScoreAvailable and not ns.ScoreAvailable() then
    Say(L["The upgrade score and the upgrade arrows are for Classic Era and WoW Forever."])
    return
  end
  local result = ns.BestInBags()
  if not result then
    Say(L["Pick an upgrade score in the options first."])
    return
  end
  if #result.list == 0 then
    Say(result.loading and L["Some items are still loading; try again in a moment."]
      or L["Nothing in your bags beats what you wear."])
    return
  end
  Say(L["Better in your bags:"])
  for _, entry in ipairs(result.list) do
    local score = Colored(ns.ScoreText(entry.new, entry.old))
    if #entry.links == 0 then
      print("  " .. L["%s in an empty slot (%s)"]:format(entry.link, score))
    else
      print("  " .. L["%s instead of %s (%s)"]:format(entry.link, table.concat(entry.links, " + "), score))
    end
  end
  if result.loading then
    print("  " .. L["Some items are still loading; try again in a moment."])
  end
end

-- The inventory slot whose item the tooltip shows, when its owner is an equipment slot button (the character
-- window's are named Character<Slot>Slot, with the slot as their ID) and that slot holds this item.
local function WornSlot(tooltip, link)
  local owner = tooltip.GetOwner and tooltip:GetOwner()
  if type(owner) ~= "table" or type(owner.GetID) ~= "function" or type(owner.GetName) ~= "function" then
    return nil
  end
  local okName, name = pcall(owner.GetName, owner)
  if not (okName and type(name) == "string" and name:find("Slot$")) then
    return nil
  end
  local okID, slot = pcall(owner.GetID, owner)
  if not (okID and type(slot) == "number" and slot >= 1 and slot <= 19) then
    return nil
  end
  if GetInventoryItemLink("player", slot) ~= link then
    return nil
  end
  return slot
end

-- From the item tooltip post call (Tooltip.lua). Returns true when it added the line.
function ns.AddBestLine(tooltip, link)
  if not (type(link) == "string" and ns.ScoreShown()) then
    return false
  end
  local slot = WornSlot(tooltip, link)
  local result = slot and ns.BestInBags()
  local entry = result and result.bySlot[slot]
  if not entry then
    return false
  end
  local text = ns.ScoreText(entry.new, entry.old)
  tooltip:AddLine(L["Better in your bags: %s (%s)"]:format(entry.link, text), 0.1, 1, 0.1)
  tooltip:Show()
  return true
end

-- Bags changed: work it out again next time.
function ns.HookBest()
  if ns.bestHooked then
    return
  end
  ns.bestHooked = true
  local events = CreateFrame("Frame")
  events:RegisterEvent("BAG_UPDATE_DELAYED")
  events:SetScript("OnEvent", ns.ForgetBest)
end
