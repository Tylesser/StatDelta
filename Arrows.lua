local _, ns = ...
local L = ns.L

-- Upgrade arrows: a small green arrow on items that score higher than what they would replace.
-- Shown without Shift (they're the at-a-glance hint), only once a score preset is chosen and while
-- "Show upgrade arrows" is on. Places: Blizzard's bag buttons, Baganator (corner widget API) and
-- quest reward buttons. DialogueUI is not hooked: see CLAUDE.md.

local GetContainerItemLink = (C_Container and C_Container.GetContainerItemLink) or GetContainerItemLink

-- The game's down arrow (Interface\Buttons\Arrow-Down-Up, also used by WoW Forever addons), flipped
-- to point up, made grey and tinted green.
local ARROW_TEXTURE = "Interface\\Buttons\\Arrow-Down-Up"

-- Upgrade decision -----------------------------------------------------------------------------

-- The item's score against each comparison of FindReplaced: a list of { slot, altSlot, new, old, links } (slot: the
-- inventory slot it would go in; links: the equipped items it would replace). false: no score, not gear, not
-- usable or already worn; nil: the item's data isn't loaded yet. Cached per link until ns.RefreshArrows. Used by
-- the arrows, best in bags (Best.lua) and the auction house rows.
local choiceCache = {}

local function Choices(link)
  local weights = ns.ActiveWeights()
  if not weights then
    return false
  end
  local equipLoc = ns.EquipLoc(link)
  if not equipLoc or equipLoc == "" then
    return false
  end
  local replacedList = ns.FindReplaced(link, equipLoc)
  if not replacedList then
    return false
  end
  local newStats = ns.GetItemStats(link)
  if not newStats then
    return nil
  end
  local usable = ns.IsItemUsable(link)
  if usable == nil then
    return nil
  end
  if not usable then
    return false
  end
  local newScore = ns.Score(newStats, weights)
  local list = {}
  for _, replaced in ipairs(replacedList) do
    local oldList, links = {}, {}
    for i = 1, 2 do
      local oldLink = replaced[i]
      if oldLink == link then
        return false -- already equipped
      end
      if oldLink then
        local stats = ns.GetItemStats(oldLink)
        if not stats then
          return nil
        end
        table.insert(oldList, stats)
        table.insert(links, oldLink)
      end
    end
    table.insert(list, { slot = replaced.slot, altSlot = replaced.altSlot, new = newScore, old = ns.Score(ns.SumStats(oldList), weights), links = links })
  end
  return list
end

function ns.UpgradeChoices(link)
  if not link then
    return false
  end
  local cached = choiceCache[link]
  if cached ~= nil then
    return cached
  end
  local result = Choices(link)
  if result ~= nil then
    choiceCache[link] = result
  end
  return result
end

-- The comparison it beats by the most points (better than at least one of the items it could replace, or than
-- an empty slot), or false; nil while loading.
function ns.BestUpgrade(link)
  local list = ns.UpgradeChoices(link)
  if not list then
    return list
  end
  local best
  for _, choice in ipairs(list) do
    if choice.new > choice.old + 0.001 and (not best or choice.new - choice.old > best.new - best.old) then
      best = choice
    end
  end
  return best or false
end

-- true: an upgrade for this character; false: not (or arrows are off); nil: item data not loaded yet.
function ns.IsUpgrade(link)
  if not (link and ns.ArrowsShown()) then
    return false
  end
  local best = ns.BestUpgrade(link)
  if best == nil then
    return nil
  end
  return best and true or false
end

-- Arrows on item buttons ---------------------------------------------------------------------

local arrows = setmetatable({}, { __mode = "k" })  -- button -> arrow texture
local shownLinks = setmetatable({}, { __mode = "k" }) -- button -> link it was last set for
local anchors = setmetatable({}, { __mode = "k" })    -- button -> { region, point } for its arrow
local waiting = false -- an item wasn't loaded yet: try again when the game sends it

-- point: the corner of `anchor` (default: the button) for the arrow. TOPRIGHT by default: Blizzard's
-- own upgrade icon and Pawn's arrow use the top left corner of bag buttons.
local function CreateArrow(button, anchor, point)
  point = point or "TOPRIGHT"
  local arrow = button:CreateTexture(nil, "OVERLAY", nil, 7)
  arrow:SetTexture(ARROW_TEXTURE)
  arrow:SetTexCoord(0, 1, 1, 0)
  if arrow.SetDesaturated then
    arrow:SetDesaturated(true)
  end
  arrow:SetVertexColor(0.25, 1, 0.25)
  arrow:SetSize(16, 16)
  arrow:SetPoint(point, anchor or button, point, point:find("RIGHT") and 1 or -1, 3)
  return arrow
end
ns.CreateArrow = CreateArrow

-- Shows or hides the arrow on `button` for `link` (nil for an empty button).
-- anchor/point: where the arrow goes (default: the button's top right corner). Remembered per button,
-- so an arrow first created by a refresh goes to the same place.
local function SetArrow(button, link, anchor, point)
  shownLinks[button] = link or false
  if anchor or point then
    anchors[button] = { anchor, point }
  end
  local upgrade = link and ns.IsUpgrade(link)
  if link and upgrade == nil then
    waiting = true
  end
  local arrow = arrows[button]
  if upgrade then
    if not arrow then
      local place = anchors[button]
      arrow = CreateArrow(button, place and place[1], place and place[2])
      arrows[button] = arrow
    end
    arrow:Show()
  elseif arrow then
    arrow:Hide()
  end
end
ns.SetArrow = SetArrow

-- Blizzard bags ---------------------------------------------------------------------------------

local function UpdateBagButton(button, bag)
  local ok, slot = pcall(button.GetID, button)
  if bag == nil and button.GetBagID then
    bag = button:GetBagID()
  end
  local link = ok and bag and slot and GetContainerItemLink and GetContainerItemLink(bag, slot) or nil
  SetArrow(button, link)
end

-- Modern container frames (WoW Forever, Retail): frame:UpdateItems and EnumerateValidItems.
local function UpdateModernFrame(frame)
  if not frame.EnumerateValidItems then
    return
  end
  for _, button in frame:EnumerateValidItems() do
    UpdateBagButton(button)
  end
end

-- Older Classic container frames: ContainerFrame_Update(frame), buttons named <frame>Item<n>.
local function UpdateClassicFrame(frame)
  local name = frame and frame.GetName and frame:GetName()
  if not name then
    return
  end
  local bag = frame:GetID()
  for i = 1, frame.size or 36 do
    local button = _G[name .. "Item" .. i]
    if button then
      UpdateBagButton(button, bag)
    end
  end
end

local function HookBags()
  local hooked = false
  local names = { "ContainerFrameCombinedBags" }
  for i = 1, (NUM_CONTAINER_FRAMES or 13) do
    names[#names + 1] = "ContainerFrame" .. i
  end
  for _, name in ipairs(names) do
    local frame = _G[name]
    if type(frame) == "table" and type(frame.UpdateItems) == "function" and frame.EnumerateValidItems then
      hooksecurefunc(frame, "UpdateItems", UpdateModernFrame)
      hooked = true
    end
  end
  if not hooked and type(ContainerFrame_Update) == "function" then
    hooksecurefunc("ContainerFrame_Update", UpdateClassicFrame)
  end
end

-- Baganator -----------------------------------------------------------------------------------
-- Uses its corner widget API (Baganator/API/Main.lua): onUpdate returns true to show the widget,
-- false to hide it, nil when the item isn't loaded yet (Baganator asks again later).

local baganatorDone = false

-- Baganator also shows other characters' bags (and the bank) from its cache, and the widget isn't
-- told whose items they are. When Baganator gives the item's bag and slot, this character must have
-- the same item there; without a location the item counts as this character's.
local function IsOwnBaganatorItem(details)
  local location = details.itemLocation
  if type(location) ~= "table" or location.bagID == nil or location.slotIndex == nil or not GetContainerItemLink then
    return true
  end
  return GetContainerItemLink(location.bagID, location.slotIndex) == details.itemLink
end

local function HookBaganator()
  if baganatorDone then
    return
  end
  local api = Baganator and Baganator.API
  if not (api and api.RegisterCornerWidget) then
    return
  end
  baganatorDone = true
  pcall(api.RegisterCornerWidget, L["Tylesser - Stat Delta: upgrade"], "tylesser_statdelta_upgrade",
    function(_, details)
      if not details then
        return false
      end
      local ok, own = pcall(IsOwnBaganatorItem, details)
      if ok and not own then
        return false
      end
      local upgrade
      ok, upgrade = pcall(ns.IsUpgrade, details.itemLink)
      if not ok then
        return false
      end
      return upgrade
    end,
    function(itemButton)
      local arrow = CreateArrow(itemButton)
      arrow:SetSize(14, 14)
      arrow:ClearAllPoints() -- Baganator places it in the corner the player picked
      return arrow
    end,
    { corner = "top_right", priority = 1 })
end
ns.HookBaganator = HookBaganator

local function RefreshBaganator()
  local api = baganatorDone and Baganator and Baganator.API
  if api and api.RequestItemButtonsRefresh then
    local reason = Baganator.Constants and Baganator.Constants.RefreshReason
    pcall(api.RequestItemButtonsRefresh, reason and reason.ItemWidgets and { reason.ItemWidgets } or nil)
  end
end

-- Quest rewards ----------------------------------------------------------------------------------

local function QuestButtonIcon(button)
  local name = button.GetName and button:GetName()
  local candidates = { rawget(button, "Icon"), rawget(button, "icon"), name and _G[name .. "IconTexture"] }
  for i = 1, 3 do
    local icon = candidates[i]
    if type(icon) == "table" and icon.GetObjectType then
      return icon
    end
  end
  return nil
end

local function QuestButtonLink(button, inLog)
  if button.objectType and button.objectType ~= "item" then
    return nil
  end
  local ok, index = pcall(button.GetID, button)
  if not (ok and index and button.type) then
    return nil
  end
  if inLog then
    return GetQuestLogItemLink and GetQuestLogItemLink(button.type, index)
  end
  return GetQuestItemLink and GetQuestItemLink(button.type, index)
end

local function UpdateQuestButtons(buttons, inLog)
  for _, button in ipairs(buttons) do
    if button:IsShown() then
      SetArrow(button, QuestButtonLink(button, inLog), QuestButtonIcon(button) or button, "TOPRIGHT")
    elseif arrows[button] then
      arrows[button]:Hide()
    end
  end
end

-- QuestInfo (quest giver and, on most clients, the quest log): QuestInfoRewardsFrame.RewardButtons.
local function UpdateQuestInfo()
  local inLog = QuestInfoFrame and QuestInfoFrame.questLog and true or false
  for _, frame in ipairs({ QuestInfoRewardsFrame, MapQuestInfoRewardsFrame }) do
    if type(frame) == "table" and type(frame.RewardButtons) == "table" then
      UpdateQuestButtons(frame.RewardButtons, inLog)
    end
  end
end

-- Older quest log: QuestLogItem1..n.
local function UpdateQuestLog()
  local buttons = {}
  for i = 1, (MAX_NUM_ITEMS or 10) do
    local button = _G["QuestLogItem" .. i]
    if button then
      table.insert(buttons, button)
    end
  end
  UpdateQuestButtons(buttons, true)
end

local function HookQuests()
  if type(QuestInfo_Display) == "function" then
    hooksecurefunc("QuestInfo_Display", UpdateQuestInfo)
  end
  if type(QuestLog_UpdateQuestDetails) == "function" then
    hooksecurefunc("QuestLog_UpdateQuestDetails", UpdateQuestLog)
  end
end

-- Auction house ------------------------------------------------------------------------------------------
-- The rows of the game's auction house lists (forever Blizzard_AuctionHouseUI, Shared/Blizzard_AuctionHouseItemList.lua):
-- each list's table builder fills a row in AddRow (TableBuilderMixin: row.rowData, then the cells) and empties it in
-- RemoveRow. The browse list's rows are item keys: gear with a random suffix ("of the Bear") gets no arrow there,
-- as its stats come with the suffix; the item's own auction list (ItemBuyFrame) has each auction's link. The
-- arrow sits on a small frame above the row's cells, at the item icon's top right corner.

local auctionArrows = setmetatable({}, { __mode = "k" }) -- row -> arrow texture
local auctionLinks = setmetatable({}, { __mode = "k" })  -- row -> the link it shows (false: none)
local hookedBuilders = setmetatable({}, { __mode = "k" })
local hookedLists = setmetatable({}, { __mode = "k" })

local function AuctionRowLink(rowData)
  if type(rowData) ~= "table" then
    return nil
  end
  if type(rowData.itemLink) == "string" then
    return rowData.itemLink
  end
  local key = rowData.itemKey
  if type(key) ~= "table" or type(key.itemID) ~= "number" then
    return nil
  end
  if (key.battlePetSpeciesID or 0) ~= 0 or (key.itemSuffix or 0) ~= 0 then
    return nil
  end
  return "item:" .. key.itemID
end
ns.AuctionRowLink = AuctionRowLink

local function RowIcon(row)
  for _, cell in ipairs(type(row.cells) == "table" and row.cells or {}) do
    local icon = type(cell) == "table" and rawget(cell, "Icon")
    if type(icon) == "table" and icon.IsShown and icon:IsShown() then
      return icon
    end
  end
  return nil
end

local function UpdateAuctionRow(row)
  local link = AuctionRowLink(row.rowData)
  auctionLinks[row] = link or false
  local upgrade = link and ns.IsUpgrade(link)
  if link and upgrade == nil then
    waiting = true
  end
  local arrow = auctionArrows[row]
  if not upgrade then
    if arrow then
      arrow:Hide()
    end
    return
  end
  if not arrow then
    local holder = CreateFrame("Frame", nil, row)
    holder:SetAllPoints(row)
    holder:SetFrameLevel(row:GetFrameLevel() + 10)
    arrow = CreateArrow(holder)
    arrow:SetSize(14, 14)
    auctionArrows[row] = arrow
  end
  arrow:ClearAllPoints()
  local icon = RowIcon(row)
  if icon then
    arrow:SetPoint("TOPRIGHT", icon, "TOPRIGHT", 4, 4)
  else
    arrow:SetPoint("LEFT", row, "LEFT", 2, 0)
  end
  arrow:Show()
end

local function ClearAuctionRow(row)
  auctionLinks[row] = nil
  if auctionArrows[row] then
    auctionArrows[row]:Hide()
  end
end

local function HookAuctionList(list)
  if type(list) ~= "table" then
    return
  end
  local function HookBuilder()
    local builder = list.tableBuilder
    if type(builder) ~= "table" or hookedBuilders[builder] or type(builder.AddRow) ~= "function" then
      return
    end
    hookedBuilders[builder] = true
    hooksecurefunc(builder, "AddRow", function(_, row)
      if type(row) == "table" then
        local ok, err = pcall(UpdateAuctionRow, row)
        if not ok then
          geterrorhandler()(err)
        end
      end
    end)
    if type(builder.RemoveRow) == "function" then
      hooksecurefunc(builder, "RemoveRow", function(_, row)
        if type(row) == "table" then
          ClearAuctionRow(row)
        end
      end)
    end
  end
  HookBuilder()
  if not list.tableBuilder and type(list.Init) == "function" and not hookedLists[list] then
    hookedLists[list] = true
    hooksecurefunc(list, "Init", HookBuilder) -- the builder is made the first time the list is shown
  end
end

local function HookAuctionHouse()
  local frame = AuctionHouseFrame
  if type(frame) ~= "table" then
    return
  end
  for _, part in ipairs({ frame.BrowseResultsFrame, frame.ItemBuyFrame }) do
    if type(part) == "table" then
      HookAuctionList(part.ItemList)
    end
  end
end

local function RefreshAuctionRows()
  for row, link in pairs(auctionLinks) do
    if link and row:IsVisible() then
      UpdateAuctionRow(row)
    elseif auctionArrows[row] and not ns.ArrowsShown() then
      auctionArrows[row]:Hide()
    end
  end
end

-- Refresh ------------------------------------------------------------------------------------------

-- Gear, weights, level or settings changed: decide again for every arrow on screen.
function ns.RefreshArrows()
  choiceCache = {}
  waiting = false
  if ns.ForgetBest then
    ns.ForgetBest()
  end
  for button, link in pairs(shownLinks) do
    if button:IsVisible() then
      SetArrow(button, link or nil)
    elseif arrows[button] and not ns.ArrowsShown() then
      arrows[button]:Hide()
    end
  end
  RefreshAuctionRows()
  RefreshBaganator()
end

function ns.HookArrows()
  HookBags()
  HookQuests()
  HookBaganator()
  HookAuctionHouse() -- (when the game's auction house addon is already loaded)
  local events = CreateFrame("Frame")
  events:RegisterEvent("ADDON_LOADED")
  events:RegisterEvent("GET_ITEM_INFO_RECEIVED")
  events:SetScript("OnEvent", function(_, event, name)
    if event == "ADDON_LOADED" then
      if name == "Baganator" then
        HookBaganator()
      elseif name == "Blizzard_AuctionHouseUI" then
        HookAuctionHouse()
      end
    elseif waiting then
      waiting = false
      ns.QueueRefresh()
    end
  end)
end
