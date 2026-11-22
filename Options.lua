local _, ns = ...

-- Options page: Esc > Options > AddOns > Tylesser - Stat Delta
-- Top: the tooltip settings. Below: the upgrade score (preset buttons and the points per stat).

local RIGHT_X = 330
local COLUMNS = 3
local COLUMN_WIDTH = 186
local ROW_HEIGHT = 24

local panel, checks, presetStatus, weightBoxes, weightHelp
local presetButtons = {}

local function CreateCheck(label, x, y, get, set)
  local check = ns.T.Check(panel, label)
  check:SetPoint("TOPLEFT", panel, "TOPLEFT", x, y)
  check:SetHitRectInsets(0, -(check.Text:GetStringWidth() + 4), 0, 0)
  check:SetScript("OnClick", function(self)
    set(self:GetChecked() and true or false)
  end)
  check.get = get
  table.insert(checks, check)
  return check
end

local function FormatWeight(value)
  if not value or value == 0 then
    return ""
  end
  if value == math.floor(value) then
    return string.format("%d", value)
  end
  return (string.format("%.3f", value):gsub("0+$", ""):gsub("%.$", ""))
end

local function StatLabel(key)
  for _, stat in ipairs(ns.STATS) do
    if stat.key == key then
      local label = stat.label
      if stat.fmt == "pct" then
        label = label:gsub(" Chance$", "") .. " (1%)"
      end
      return label
    end
  end
  return key
end

local function CommitWeight(box)
  local text = strtrim(box:GetText() or ""):gsub(",", ".")
  local value = text == "" and 0 or tonumber(text)
  -- not NaN ("nan") or infinite ("inf", "1e999")
  if value and value == value and math.abs(value) ~= math.huge then
    ns.SetWeight(box.statKey, value)
  end
  box:SetText(FormatWeight(ns.charDB.weights[box.statKey]))
end

local function CreateWeightBox(parent, key, index)
  local column = (index - 1) % COLUMNS
  local row = math.floor((index - 1) / COLUMNS)
  local label = parent:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
  label:SetPoint("TOPLEFT", column * COLUMN_WIDTH + 4, -row * ROW_HEIGHT - 5)
  label:SetWidth(COLUMN_WIDTH - 64)
  label:SetJustifyH("LEFT")
  label:SetWordWrap(false)
  label:SetText(StatLabel(key))

  local box = CreateFrame("EditBox", nil, parent, "InputBoxTemplate")
  box:SetSize(48, 18)
  box:SetPoint("TOPLEFT", column * COLUMN_WIDTH + COLUMN_WIDTH - 58, -row * ROW_HEIGHT - 2)
  box:SetAutoFocus(false)
  box:SetMaxLetters(8)
  ns.T.EditBox(box)
  box.statKey = key
  box:SetScript("OnEnterPressed", function(self)
    self:ClearFocus()
  end)
  box:SetScript("OnEscapePressed", function(self)
    self:SetText(FormatWeight(ns.charDB.weights[self.statKey]))
    self:ClearFocus()
  end)
  box:SetScript("OnEditFocusLost", CommitWeight)
  return box
end

local function PresetButtonColor(button, selected)
  local color = selected and { 0.3, 1, 0.3 } or ns.T.GOLD
  button.textColor = color
  button.label:SetTextColor(color[1], color[2], color[3])
end

function ns.RefreshOptions()
  if not (panel and panel:IsVisible()) then
    return
  end
  for _, check in ipairs(checks) do
    check:SetChecked(check.get() and true or false)
  end
  if not presetStatus then
    return -- no score on this game version
  end
  local preset = ns.charDB.preset
  for _, button in ipairs(presetButtons) do
    PresetButtonColor(button, button.presetId == preset or (button.presetId == false and not preset))
  end
  local name = ns.PresetName()
  if name then
    local which = ns.HasTwoTalentGroups()
      and (ns.ActiveTalentGroup() == 2 and " (your secondary talents)" or " (your primary talents)") or ""
    presetStatus:SetText("Score" .. which .. ": |cff40ff40" .. name .. "|r")
  else
    presetStatus:SetText("The score is off. Pick a preset (or type a weight) to turn it on.")
  end
  for _, box in ipairs(weightBoxes) do
    if not box:HasFocus() then
      box:SetText(FormatWeight(ns.charDB.weights[box.statKey]))
    end
  end
end

local function CreatePresetButtons(y)
  local list = ns.GetPresets()
  local entries = { { id = false, label = "Off" } }
  for _, preset in ipairs(list) do
    table.insert(entries, preset)
  end
  local previous
  for _, entry in ipairs(entries) do
    local button = ns.T.Button(panel, entry.id and 108 or 60, 22, entry.label)
    if previous then
      button:SetPoint("LEFT", previous, "RIGHT", 6, 0)
    else
      button:SetPoint("TOPLEFT", panel, "TOPLEFT", 18, y)
    end
    button.presetId = entry.id
    button:SetScript("OnClick", function(self)
      ns.SetPreset(self.presetId or nil)
    end)
    if entry.id then
      button:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:AddLine(entry.label)
        GameTooltip:AddLine("Fills in rough starting values for this role. Your edited values are replaced.",
          1, 1, 1, true)
        GameTooltip:Show()
      end)
      button:SetScript("OnLeave", function()
        GameTooltip:Hide()
      end)
    end
    table.insert(presetButtons, button)
    previous = button
  end
  if #list == 0 then
    local none = panel:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    none:SetPoint("LEFT", previous, "RIGHT", 10, 0)
    none:SetText("No presets for your class: type your own weights below.")
  end
  return previous
end

-- Esc > Options > AddOns, with the Settings API or the older InterfaceOptions.
local function RegisterPanel()
  if Settings and Settings.RegisterCanvasLayoutCategory and Settings.RegisterAddOnCategory then
    local category = Settings.RegisterCanvasLayoutCategory(panel, ns.TITLE)
    Settings.RegisterAddOnCategory(category)
    ns.optionsCategory = category
  elseif InterfaceOptions_AddCategory then
    InterfaceOptions_AddCategory(panel)
  end
  ns.optionsPanel = panel
end

function ns.CreateOptions()
  panel = CreateFrame("Frame")
  panel.name = ns.TITLE
  checks = {}

  local top = ns.T.OPTIONS_TOP
  ns.T.OptionsPage(panel, "Stat Delta",
    "Hold Shift over an item to see what you gain or lose compared to your gear.")

  CreateCheck("Show stat changes (hold Shift)", 14, top,
    function() return ns.db.enabled end,
    function(value) ns.db.enabled = value; ns.Refresh() end)
  CreateCheck("Show Strength, Agility, Stamina, Intellect, Spirit", 14, top - 26,
    function() return ns.db.showPrimary end,
    function(value) ns.db.showPrimary = value; ns.Refresh() end)
  local heading = ns.T.Heading(panel, "Upgrade score", 560)
  heading:SetPoint("TOPLEFT", panel, "TOPLEFT", 18, top - 62)

  if not ns.ScoreAvailable() then
    local note = panel:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    note:SetPoint("TOPLEFT", heading, "BOTTOMLEFT", 0, -6)
    note:SetWidth(560)
    note:SetJustifyH("LEFT")
    note:SetText("The upgrade score and the upgrade arrows are for Classic Era and WoW Forever. Gear on this game "
      .. "version has ratings the score doesn't count, so they're off here.")
    weightBoxes = {}
    panel:SetScript("OnShow", ns.RefreshOptions)
    RegisterPanel()
    return
  end

  CreateCheck("Show the upgrade score (hold Shift)", RIGHT_X, top,
    function() return ns.db.showScore end,
    function(value) ns.db.showScore = value; ns.ScoreChanged() end)
  CreateCheck("Show upgrade arrows on items", RIGHT_X, top - 26,
    function() return ns.db.showArrows end,
    function(value) ns.db.showArrows = value; ns.ScoreChanged() end)

  local help = panel:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
  help:SetPoint("TOPLEFT", heading, "BOTTOMLEFT", 0, -6)
  help:SetWidth(560)
  help:SetJustifyH("LEFT")
  help:SetTextColor(ns.T.PARCHMENT[1], ns.T.PARCHMENT[2], ns.T.PARCHMENT[3])
  help:SetText("Points per stat, saved for this character. The score of an item is the sum of its stats times "
    .. "these points; with Shift, the tooltip shows it against your gear, and upgrades get a green arrow. "
    .. "The presets are rough starting values for Classic Era, not exact numbers: change them as you like.")

  CreatePresetButtons(top - 128)
  presetStatus = panel:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
  presetStatus:SetPoint("TOPLEFT", panel, "TOPLEFT", 18, top - 156)
  presetStatus:SetWidth(560)
  presetStatus:SetJustifyH("LEFT")

  weightHelp = panel:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
  weightHelp:SetPoint("TOPLEFT", panel, "TOPLEFT", 18, top - 174)
  weightHelp:SetWidth(560)
  weightHelp:SetJustifyH("LEFT")
  weightHelp:SetText("Attack Power, Ranged Attack Power, Health, Mana and Armor include what Strength, Agility, "
    .. "Stamina and Intellect give you. Weight a stat or what it turns into, not both.")

  -- the weights, in a scroll frame in case the page is short
  local scroll = CreateFrame("ScrollFrame", nil, panel, "UIPanelScrollFrameTemplate")
  scroll:SetPoint("TOPLEFT", panel, "TOPLEFT", 14, top - 204)
  scroll:SetPoint("BOTTOMRIGHT", panel, "BOTTOMRIGHT", -34, 14)
  local content = CreateFrame("Frame", nil, scroll)
  local rows = math.ceil(#ns.WEIGHT_STATS / COLUMNS)
  content:SetSize(COLUMNS * COLUMN_WIDTH, rows * ROW_HEIGHT + 4)
  scroll:SetScrollChild(content)
  weightBoxes = {}
  for index, key in ipairs(ns.WEIGHT_STATS) do
    table.insert(weightBoxes, CreateWeightBox(content, key, index))
  end

  panel:SetScript("OnShow", ns.RefreshOptions)
  RegisterPanel()
end

function ns.OpenOptions()
  if ns.optionsCategory and Settings and Settings.OpenToCategory then
    local id = ns.optionsCategory.GetID and ns.optionsCategory:GetID() or ns.optionsCategory.ID
    Settings.OpenToCategory(id)
  elseif panel and InterfaceOptionsFrame_OpenToCategory then
    -- called twice: the first call only opens the frame on older clients
    InterfaceOptionsFrame_OpenToCategory(panel)
    InterfaceOptionsFrame_OpenToCategory(panel)
  end
end
