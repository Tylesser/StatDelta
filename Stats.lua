local _, ns = ...

local GetItemInfo = (C_Item and C_Item.GetItemInfo) or GetItemInfo

local SCHOOLS = { "arcane", "fire", "frost", "holy", "nature", "shadow" }
local PRIMARY = { "strength", "agility", "stamina", "intellect", "spirit" }

-- Stat names as they appear in "+10 Strength" / "Strength +10" lines (lower case).
local NAMED = {
  strength = "strength",
  agility = "agility",
  stamina = "stamina",
  intellect = "intellect",
  spirit = "spirit",
  ["all stats"] = PRIMARY,
  armor = "armor",
  block = "blockValue", -- shields: "15 Block"
  ["block value"] = "blockValue",
  health = "health",
  mana = "mana",
  defense = "defense",
  ["attack power"] = "attackPower",
  ["ranged attack power"] = "rangedAttackPower",
  ["spell power"] = "spellPower",
  ["spell damage"] = "spellDamage",
  ["damage spells"] = "spellDamage",
  ["healing"] = "healing",
  ["healing spells"] = "healing",
  ["spell damage and healing"] = { "spellDamage", "healing" },
  ["healing and spell damage"] = { "spellDamage", "healing" },
  ["hit rating"] = "hitRating",
  ["critical strike rating"] = "critRating",
  ["critical strike"] = "critRating",
  ["crit rating"] = "critRating",
  ["spell hit rating"] = "spellHitRating",
  ["spell critical strike rating"] = "spellCritRating",
  ["spell critical rating"] = "spellCritRating",
  ["haste rating"] = "hasteRating",
  ["haste"] = "hasteRating",
  ["expertise rating"] = "expertiseRating",
  ["armor penetration rating"] = "armorPenetrationRating",
  ["mastery rating"] = "masteryRating",
  ["mastery"] = "masteryRating",
  ["versatility"] = "versatility",
  ["defense rating"] = "defenseRating",
  ["dodge rating"] = "dodgeRating",
  ["parry rating"] = "parryRating",
  ["block rating"] = "blockRating",
  ["shield block rating"] = "blockRating",
  ["resilience rating"] = "resilienceRating",
  ["resilience"] = "resilienceRating",
  ["all resistances"] = {
    "arcaneResistance", "fireResistance", "frostResistance", "natureResistance", "shadowResistance",
  },
}
for _, school in ipairs(SCHOOLS) do
  NAMED[school .. " resistance"] = school .. "Resistance"
  NAMED[school .. " spell damage"] = school .. "Damage"
  NAMED[school .. " damage"] = school .. "Damage"
end

local function Add(stats, keys, amount)
  if type(keys) == "table" then
    for _, key in ipairs(keys) do
      stats[key] = (stats[key] or 0) + amount
    end
  else
    stats[keys] = (stats[keys] or 0) + amount
  end
end

local function AddNamed(stats, name, amount)
  name = name:gsub("%.$", "")
  local keys = NAMED[name]
  if keys then
    Add(stats, keys, amount)
    return true
  end
  return false
end

-- "Equip:" effects, matched against the lower-cased text after "Equip: ".
-- First match wins, so the more specific patterns come first.
local EQUIP = {
  { "^increases damage and healing done by magical spells and effects by up to (%d+)", { "spellDamage", "healing" } },
  { "^increases healing done by spells and effects by up to (%d+)", "healing" },
  { "^increases spell power by (%d+)", "spellPower" },
  { "^increases attack power by (%d+) in cat", "feralAttackPower" },
  { "^%+(%d+) attack power in cat", "feralAttackPower" },
  { "^increases ranged attack power by (%d+)", "rangedAttackPower" },
  { "^%+(%d+) ranged attack power", "rangedAttackPower" },
  { "^increases attack power by (%d+)%.?$", "attackPower" },
  { "^%+(%d+) attack power%.?$", "attackPower" },
  { "^improves your chance to get a critical strike with spells by ([%d%.]+)%%", "spellCrit" },
  { "^improves your chance to hit with spells by ([%d%.]+)%%", "spellHit" },
  { "^improves your chance to get a critical strike by ([%d%.]+)%%", "crit" },
  { "^improves your chance to hit by ([%d%.]+)%%", "hit" },
  { "^restores (%d+) mana per 5 sec", "mp5" },
  { "^restores (%d+) health", "hp5" },
  { "^increased defense %+(%d+)", "defense" },
  { "^increases your chance to dodge an attack by ([%d%.]+)%%", "dodge" },
  { "^increases your chance to parry an attack by ([%d%.]+)%%", "parry" },
  { "^increases your chance to block attacks with a shield by ([%d%.]+)%%", "block" },
  { "^increases the block value of your shield by (%d+)", "blockValue" },
  { "^increases your shield block value by (%d+)", "blockValue" },
}

local function ParseEquip(text, stats)
  text = text:lower()
  -- "Increases healing done by up to 44 and damage done by up to 15 for all magical spells and effects."
  local heal, dmg = text:match("^increases healing done by up to (%d+) and damage done by up to (%d+)")
  if heal then
    Add(stats, "healing", tonumber(heal))
    Add(stats, "spellDamage", tonumber(dmg))
    return
  end
  -- "Increases damage done by Fire spells and effects by up to 20."
  local school, amount = text:match("^increases damage done by (%a+) spells and effects by up to (%d+)")
  if school and NAMED[school .. " damage"] then
    Add(stats, NAMED[school .. " damage"], tonumber(amount))
    return
  end
  for _, rule in ipairs(EQUIP) do
    local value = text:match(rule[1])
    if value then
      Add(stats, rule[2], tonumber(value))
      return
    end
  end
  -- "Improves your hit rating by 10." / "Increases defense rating by 12."
  local name, rating = text:match("^improves y?o?u?r? ?(.-) rating by (%d+)")
  if not name then
    name, rating = text:match("^increases y?o?u?r? ?(.-) rating by (%d+)")
  end
  if name and AddNamed(stats, name .. " rating", tonumber(rating)) then
    return
  end
  -- "Equip: +10 Spell Damage."
  local sign, value, statName = text:match("^([%+%-])(%d+) (.+)$")
  if value then
    AddNamed(stats, statName, tonumber(value) * (sign == "-" and -1 or 1))
  end
end

-- Localized lines ---------------------------------------------------------------------
-- Primary stats, armor, block, resistances and weapon damage, DPS and speed are read with patterns
-- built from Blizzard's own format strings (GlobalStrings), so they work on every client language.
-- Equip effects ("Equip: Increases damage and healing...") have no such strings: English only.

-- "2.60", "2,60" and "1.234,5" for decimals (the last separator is the decimal point);
-- "1,234", "1.234" and "1 234" (space or no-break space) for whole numbers.
local function ToNumber(text, decimal)
  if not text then
    return nil
  end
  text = text:gsub("[%s\194\160]", "")
  if decimal then
    local whole, fraction = text:match("^([%d%.,]-)[%.,](%d+)$")
    if whole then
      return tonumber((whole:gsub("[%.,]", "")) .. "." .. fraction)
    end
  end
  return tonumber((text:gsub("[%.,]", "")))
end

-- Numbers start with a digit and may contain "." "," and spaces (thousands separators).
local NUMBER = "(%d[%d%.,%s\194\160]*)"
local CAPTURE = { sign = "([%+%-]?)", int = NUMBER, dec = NUMBER, word = "(.-)" }

-- Turns a printf-style format ("%c%d Strength", "%2$s ...") into an anchored Lua pattern.
-- kinds: the kind of each argument, by position. Returns the pattern and the argument
-- position of each capture, or nil if the format has something unexpected.
local function FormatToPattern(fmt, kinds)
  if type(fmt) ~= "string" or fmt == "" then
    return nil
  end
  local parts, order = { "^" }, {}
  local position, nextArg = 1, 1
  while position <= #fmt do
    local char = fmt:sub(position, position)
    if char == "%" then
      local rest = position + 1
      local arg
      local index, afterIndex = fmt:match("^(%d+)%$()", rest)
      if index then
        arg, rest = tonumber(index), afterIndex
      end
      local conversion, after = fmt:match("^[%-%+ #0]*%d*%.?%d*([%a%%])()", rest)
      if not conversion then
        return nil
      end
      if conversion == "%" then
        table.insert(parts, "%%")
      else
        if not arg then
          arg, nextArg = nextArg, nextArg + 1
        end
        local kind = kinds[arg]
        if not kind then
          return nil
        end
        table.insert(parts, CAPTURE[kind])
        table.insert(order, arg)
      end
      position = after
    else
      if char:find("[%^%$%(%)%.%[%]%*%+%-%?]") then
        char = "%" .. char
      end
      table.insert(parts, char)
      position = position + 1
    end
  end
  table.insert(parts, "$")
  return table.concat(parts), order
end

-- Matches `text` against a pattern from FormatToPattern; returns the values by argument position.
local function MatchFormat(text, rule)
  local captures = { text:match(rule.pattern) }
  if #captures == 0 then
    return nil
  end
  local values = {}
  for i, arg in ipairs(rule.order) do
    values[arg] = captures[i]
  end
  return values
end

local SCHOOL_GLOBALS = {
  -- key, SPELL_SCHOOLn_CAP, DAMAGE_SCHOOLn
  { "holy", 1, 2 }, { "fire", 2, 3 }, { "nature", 3, 4 }, { "frost", 4, 5 }, { "shadow", 5, 6 }, { "arcane", 6, 7 },
}

-- name of a school (lower case, any language) -> resistance key
local function SchoolNames()
  local names = {}
  for _, school in ipairs(SCHOOL_GLOBALS) do
    local key = school[1] .. "Resistance"
    names[school[1]] = key
    for _, global in ipairs({ "SPELL_SCHOOL" .. school[2] .. "_CAP", "DAMAGE_SCHOOL" .. school[3] }) do
      local name = _G[global]
      if type(name) == "string" and name ~= "" then
        names[name:lower()] = key
      end
    end
  end
  return names
end

-- Each rule: global string, argument kinds, what a match adds.
local LOCALIZED_RULES = {
  { "ITEM_MOD_STRENGTH", { "sign", "int" }, "strength" },
  { "ITEM_MOD_AGILITY", { "sign", "int" }, "agility" },
  { "ITEM_MOD_STAMINA", { "sign", "int" }, "stamina" },
  { "ITEM_MOD_INTELLECT", { "sign", "int" }, "intellect" },
  { "ITEM_MOD_SPIRIT", { "sign", "int" }, "spirit" },
  { "ARMOR_TEMPLATE", { "int" }, "armor" },
  { "SHIELD_BLOCK_TEMPLATE", { "int" }, "blockValue" },
  { "ITEM_RESIST_ALL", { "sign", "int" }, NAMED["all resistances"] },
  { "ITEM_RESIST_SINGLE", { "sign", "int", "word" }, "resistance" },
  { "DPS_TEMPLATE", { "dec" }, "dps" },
  { "DAMAGE_TEMPLATE", { "int", "int" }, "damage" },
  { "DAMAGE_TEMPLATE_WITH_SCHOOL", { "int", "int", "word" }, "damage" },
}

local localized, schoolNames, speedPatterns, skipPrefixes

local function Escape(text)
  return (text:gsub("[%^%$%(%)%%%.%[%]%*%+%-%?]", "%%%0"))
end

-- Built on first use, from whatever global strings this client has (every one is optional).
local function BuildLocalized()
  localized = {}
  for _, rule in ipairs(LOCALIZED_RULES) do
    local pattern, order = FormatToPattern(_G[rule[1]], rule[2])
    if pattern then
      table.insert(localized, { pattern = pattern, order = order, kinds = rule[2], target = rule[3] })
    end
  end
  schoolNames = SchoolNames()
  -- Weapon speed (right text): "Speed 2.60". The global is the word, or on some clients a format.
  speedPatterns = {}
  for _, global in ipairs({ "WEAPON_SPEED", "SPEED" }) do
    local speed = _G[global]
    if type(speed) == "string" and speed ~= "" then
      local pattern = speed:find("%%") and FormatToPattern(speed, { "dec" })
      if not pattern and not speed:find("%%") then
        pattern = "^" .. Escape(speed) .. "%s*" .. NUMBER .. "$"
      end
      if pattern then
        table.insert(speedPatterns, pattern)
      end
    end
  end
  table.insert(speedPatterns, "^Speed%s*" .. NUMBER .. "$") -- English fallback
  -- "Use:" and "Chance on hit:" in this client's language
  skipPrefixes = {}
  for _, global in ipairs({ "ITEM_SPELL_TRIGGER_ONUSE", "ITEM_SPELL_TRIGGER_ONPROC" }) do
    local prefix = _G[global]
    if type(prefix) == "string" and prefix ~= "" then
      table.insert(skipPrefixes, "^" .. Escape(prefix))
    end
  end
end

-- Adds a localized line's stat; weapon damage goes to `weapon` (min, max) for the DPS fallback.
local function ParseLocalized(text, stats, weapon)
  for _, rule in ipairs(localized) do
    local values = MatchFormat(text, rule)
    if values then
      if rule.target == "damage" then
        weapon.min, weapon.max = ToNumber(values[1]), ToNumber(values[2])
        return true
      elseif rule.target == "dps" then
        local dps = ToNumber(values[1], true)
        if dps then
          weapon.dps = dps
          return true
        end
      elseif rule.target == "resistance" then
        local key = schoolNames[strtrim(values[3] or ""):lower()]
        local amount = ToNumber(values[2])
        if key and amount then
          Add(stats, key, amount * (values[1] == "-" and -1 or 1))
          return true
        end
      else
        local signIndex, amountIndex = 0, 1
        if rule.kinds[1] == "sign" then
          signIndex, amountIndex = 1, 2
        end
        local amount = ToNumber(values[amountIndex])
        if amount then
          Add(stats, rule.target, amount * (values[signIndex] == "-" and -1 or 1))
          return true
        end
      end
    end
  end
  return false
end

local function ParseLine(text, stats, weapon, rightText)
  if not localized then
    BuildLocalized()
  end
  weapon = weapon or {}
  if rightText then
    local right = strtrim((rightText:gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", "")))
    for _, pattern in ipairs(speedPatterns) do
      local speed = right:match(pattern)
      if speed then
        weapon.speed = ToNumber(speed, true)
        break
      end
    end
  end
  text = text:gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", "")
  text = strtrim(text)
  if text == "" then
    return
  end
  -- Weapon DPS first: the line starts with "(" like set bonuses do. The localized patterns are
  -- anchored at both ends, so set bonus and "Use:" lines never match them.
  local dps = text:match("^%(([%d%.,]+) damage per second%)$")
  if dps then
    weapon.dps = ToNumber(dps, true)
    return
  end
  if ParseLocalized(text, stats, weapon) then
    return
  end
  -- Set bonuses, on-use and on-hit effects are not permanent stats.
  if text:find("^%(") or text:find("^Use:") or text:find("^Chance on hit:") or text:find("^Set:") then
    return
  end
  for _, prefix in ipairs(skipPrefixes) do
    if text:find(prefix) then
      return
    end
  end
  local equip = text:match("^Equip: (.+)$")
  if equip then
    ParseEquip(equip, stats)
    return
  end
  -- "+10 Strength", "-5 Spirit", "120 Armor", "15 Block", "+10 Fire Resistance"
  local sign, value, name = text:match("^([%+%-]?)(%d+) (.+)$")
  if value then
    AddNamed(stats, name:lower(), tonumber(value) * (sign == "-" and -1 or 1))
    return
  end
  -- Enchants written the other way round: "Agility +7"
  name, sign, value = text:match("^(.-) ([%+%-])(%d+)$")
  if value then
    AddNamed(stats, name:lower(), tonumber(value) * (sign == "-" and -1 or 1))
  end
end

local SCANNER_NAME = "TylesserStatDeltaScanner"
local scanner

-- Blizzard writes what this character can't use (armor type, weapon skill, class, level) in red.
local function IsRed(r, g, b)
  return type(r) == "number" and r > 0.95 and (g or 1) < 0.2 and (b or 1) < 0.2
end

local function ColorIsRed(color)
  return type(color) == "table" and IsRed(color.r, color.g, color.b)
end

-- Returns the tooltip lines ({ left, right }) and whether any line is red.
local function GetTooltipLines(link)
  local lines, red = {}, false
  if C_TooltipInfo and C_TooltipInfo.GetHyperlink then
    local data = C_TooltipInfo.GetHyperlink(link)
    if data and data.lines then
      for _, line in ipairs(data.lines) do
        if line.leftText == nil and TooltipUtil and TooltipUtil.SurfaceArgs then
          TooltipUtil.SurfaceArgs(line)
        end
        if line.leftText then
          table.insert(lines, { line.leftText, line.rightText })
        end
        if ColorIsRed(line.leftColor) or (line.rightText and ColorIsRed(line.rightColor)) then
          red = true
        end
      end
      return lines, red
    end
  end
  if not scanner then
    scanner = CreateFrame("GameTooltip", SCANNER_NAME, nil, "GameTooltipTemplate")
  end
  scanner:SetOwner(WorldFrame, "ANCHOR_NONE")
  scanner:ClearLines()
  scanner:SetHyperlink(link)
  for i = 1, scanner:NumLines() do
    local left = _G[SCANNER_NAME .. "TextLeft" .. i]
    local right = _G[SCANNER_NAME .. "TextRight" .. i]
    local text = left and left:GetText()
    local rightText = right and right:IsShown() and right:GetText() or nil
    if text then
      table.insert(lines, { text, rightText })
      if IsRed(left:GetTextColor()) then
        red = true
      end
    end
    if rightText and IsRed(right:GetTextColor()) then
      red = true
    end
  end
  scanner:Hide()
  return lines, red
end

-- Parses tooltip lines: plain strings, or { leftText, rightText }.
local function ParseAll(lines)
  local stats, weapon = {}, {}
  for _, line in ipairs(lines) do
    if type(line) == "table" then
      ParseLine(line[1], stats, weapon, line[2])
    else
      ParseLine(line, stats, weapon)
    end
  end
  -- Weapon DPS from its own line, or from the damage and speed lines.
  if weapon.dps then
    Add(stats, "dps", weapon.dps)
  elseif weapon.min and weapon.max and weapon.speed and weapon.speed > 0 then
    Add(stats, "dps", math.floor((weapon.min + weapon.max) / 2 / weapon.speed * 10 + 0.5) / 10)
  end
  return stats
end

local cache = {}
local usableCache = {}

local function Scan(link)
  local lines, red = GetTooltipLines(link)
  cache[link] = ParseAll(lines)
  usableCache[link] = not red
end

-- Stats printed on the item (no conversions). Returns nil while the item isn't loaded yet.
function ns.GetItemStats(link)
  if cache[link] then
    return cache[link]
  end
  if not GetItemInfo(link) then
    return nil
  end
  Scan(link)
  return cache[link]
end

-- False when the tooltip has red text (wrong armor type or weapon skill, class, level too low).
-- Returns nil while the item isn't loaded yet.
function ns.IsItemUsable(link)
  if usableCache[link] == nil then
    if not GetItemInfo(link) then
      return nil
    end
    Scan(link)
  end
  return usableCache[link]
end

-- Level up or new weapon skill: what's red changes, the stats don't.
function ns.ForgetUsable()
  usableCache = {}
end

function ns.ParseLines(lines)
  if not localized then
    BuildLocalized()
  end
  return ParseAll(lines)
end

-- For tests: rebuild the localized patterns after changing the global strings.
function ns.RebuildLocalized()
  BuildLocalized()
  cache, usableCache = {}, {}
end

function ns.SumStats(list)
  local total = {}
  for _, stats in ipairs(list) do
    for key, value in pairs(stats) do
      total[key] = (total[key] or 0) + value
    end
  end
  return total
end

-- Classic Era conversions --------------------------------------------------------

-- Melee Attack Power per point of Strength / Agility, and Ranged Attack Power per Agility.
local ATTACK_POWER = {
  WARRIOR = { str = 2, agi = 0, rangedAgi = 1 },
  PALADIN = { str = 2, agi = 0 },
  SHAMAN = { str = 2, agi = 0 },
  DRUID = { str = 2, agi = 0 },
  ROGUE = { str = 1, agi = 1, rangedAgi = 1 },
  HUNTER = { str = 1, agi = 1, rangedAgi = 2 },
  MAGE = { str = 1, agi = 0 },
  PRIEST = { str = 1, agi = 0 },
  WARLOCK = { str = 1, agi = 0 },
}
-- Points needed for 1% at level 60.
local AGILITY_PER_CRIT = { ROGUE = 29, HUNTER = 53 }
local AGILITY_PER_DODGE = { ROGUE = 14.5, HUNTER = 26.5 }
local INTELLECT_PER_SPELL_CRIT = {
  MAGE = 59.5, PRIEST = 59.2, WARLOCK = 60.6, DRUID = 60, SHAMAN = 59.2, PALADIN = 54,
}
local NO_MANA = { WARRIOR = true, ROGUE = true }

-- WoW Forever's talents ------------------------------------------------------------------------------------
-- Talents that raise a stat by a percentage, or give a share of one stat as another (2026-11-27, GitHub issue
-- StatDelta#2: the shaman's Mental Dexterity, Attack Power equal to 100% of Intellect). Keyed by the talent's
-- spell; the percent per rank comes from Forever's TraitDefinitionEffectPoints curves (wago.tools, product
-- wowf, build 1.60.1.71139). raise: that stat goes up by the percent; from/to: the percent of "from" is added
-- to each "to". Raised stats count first ("% of your Intellect" is the raised Intellect), as in the game.
local TALENTS = {
  [415140] = { { from = "intellect", to = { "attackPower" }, ranks = { 33, 66, 100 } } }, -- Mental Dexterity
  [30812] = { { from = "intellect", to = { "spellDamage", "healing" }, ranks = { 15, 30 } } }, -- Mental Quickness
  [1223984] = { -- Careful Aim
    { from = "intellect", to = { "attackPower", "rangedAttackPower" }, ranks = { 20, 40, 60, 80, 100 } },
  },
  [28574] = { { from = "intellect", to = { "armor" }, ranks = { 25, 50, 75 } } }, -- Arcane Resilience
  [1311084] = { { from = "intellect", to = { "spellDamage" }, ranks = { 12, 24, 36, 48, 60 } } }, -- Champion of the Light
  [14901] = { -- Spiritual Guidance
    { from = "spirit", to = { "spellDamage" }, ranks = { 1, 3, 5, 6, 8 } },
    { from = "spirit", to = { "healing" }, ranks = { 5, 10, 15, 20, 25 } },
  },
  [16252] = { { raise = "stamina", ranks = { 2, 4, 6, 8, 10 } } }, -- Toughness (shaman)
  [17485] = { { raise = "intellect", ranks = { 2, 4, 6, 8, 10 } } }, -- Ancestral Knowledge
  [19168] = { { raise = "agility", ranks = { 3, 6, 9, 12, 15 } } }, -- Lightning Reflexes
  [20257] = { { raise = "intellect", ranks = { 2, 4, 6, 8, 10 } } }, -- Divine Intellect
  [20262] = { { raise = "strength", ranks = { 2, 4, 6, 8, 10 } } }, -- Divine Strength
  [11232] = { { raise = "intellect", ranks = { 2, 4, 6, 8, 10 } } }, -- Arcane Mind
  [18551] = { { raise = "intellect", ranks = { 2, 4, 6, 8, 10 } } }, -- Mental Strength
  [18697] = { { raise = "stamina", ranks = { 3, 6, 9, 12, 15 } } }, -- Demonic Embrace
  [1309631] = { { raise = "spirit", ranks = { 5, 10, 15 } } }, -- Living Spirit
}
-- The talent trees those talents are in (TraitNode), read besides the trees of the talent config.
local TALENT_TREES = { 1082, 1089, 1091, 1100, 1112, 1114, 1116 }

local function Plain(value) -- not nil and not a secret value
  return value ~= nil and (not canaccessvalue or canaccessvalue(value))
end

local function Call(func, ...)
  if type(func) ~= "function" then
    return nil
  end
  local ok, result = pcall(func, ...)
  if ok and Plain(result) then
    return result
  end
  return nil
end

local function ActiveTalentConfig()
  local config = C_ClassTalents and Call(C_ClassTalents.GetActiveConfigID)
  local spec = C_SpecializationInfo
  if type(config) ~= "number" and spec and spec.GetCombatConfigIDForSpecGroup then
    local group = Call(spec.GetActiveSpecGroup)
    config = Call(spec.GetCombatConfigIDForSpecGroup, type(group) == "number" and group or 1)
  end
  return type(config) == "number" and config or nil
end

-- [talent spell] = rank, for the talents above that this character has (C_Traits: the active config's nodes).
-- Nil when the game has no talent config (Classic Era, or before the talents are known after a login).
local function ReadTalentRanks()
  local traits = C_Traits
  if not (traits and traits.GetTreeNodes and traits.GetNodeInfo and traits.GetEntryInfo and traits.GetDefinitionInfo) then
    return nil
  end
  local config = ActiveTalentConfig()
  if not config then
    return nil
  end
  local trees, seenTree, seenNode, ranks = {}, {}, {}, {}
  local function AddTree(tree)
    if type(tree) == "number" and not seenTree[tree] then
      seenTree[tree] = true
      trees[#trees + 1] = tree
    end
  end
  local info = Call(traits.GetConfigInfo, config)
  if type(info) == "table" and type(info.treeIDs) == "table" then
    for _, tree in ipairs(info.treeIDs) do
      AddTree(Plain(tree) and tree)
    end
  end
  for _, tree in ipairs(TALENT_TREES) do
    AddTree(tree)
  end
  for _, tree in ipairs(trees) do
    local nodes = Call(traits.GetTreeNodes, tree)
    for _, node in ipairs(type(nodes) == "table" and nodes or {}) do
      if Plain(node) and not seenNode[node] then
        seenNode[node] = true
        local nodeInfo = Call(traits.GetNodeInfo, config, node)
        local entry = type(nodeInfo) == "table" and nodeInfo.activeEntry
        local rank = type(nodeInfo) == "table" and Plain(nodeInfo.activeRank) and nodeInfo.activeRank
        if type(rank) ~= "number" and type(nodeInfo) == "table" and Plain(nodeInfo.ranksPurchased) then
          rank = nodeInfo.ranksPurchased
        end
        if type(entry) == "table" and Plain(entry.entryID) and type(rank) == "number" and rank > 0 then
          local entryInfo = Call(traits.GetEntryInfo, config, entry.entryID)
          local definitionID = type(entryInfo) == "table" and Plain(entryInfo.definitionID) and entryInfo.definitionID
          local definition = definitionID and Call(traits.GetDefinitionInfo, definitionID)
          local spell = type(definition) == "table" and Plain(definition.spellID) and definition.spellID
          if spell and TALENTS[spell] then
            ranks[spell] = rank
          end
        end
      end
    end
  end
  return ranks
end

local talentRanks -- cached until the talents change (ForgetTalents)

local function TalentRanks()
  if talentRanks == nil then
    talentRanks = ReadTalentRanks()
  end
  return talentRanks or {}
end

local function TalentPercent(effect, rank)
  return (effect.ranks[rank] or effect.ranks[#effect.ranks]) / 100
end

-- Raises the stats in total (in place) by the character's percentage talents.
local function RaiseStats(total)
  for spell, rank in pairs(TalentRanks()) do
    for _, effect in ipairs(TALENTS[spell]) do
      if effect.raise and total[effect.raise] then
        total[effect.raise] = total[effect.raise] * (1 + TalentPercent(effect, rank))
      end
    end
  end
end

-- Adds what the character's talents give for other stats (in place).
local function TalentGains(total)
  for spell, rank in pairs(TalentRanks()) do
    for _, effect in ipairs(TALENTS[spell]) do
      local from = effect.from and total[effect.from]
      if from and from ~= 0 then
        for _, key in ipairs(effect.to) do
          total[key] = (total[key] or 0) + from * TalentPercent(effect, rank)
        end
      end
    end
  end
end

-- After a talent change (Events): read the ranks again.
function ns.ForgetTalents()
  talentRanks = nil
end

-- Adds what the item's Strength, Agility, Stamina and Intellect give this character, with its talents.
-- Returns the new table and a set of keys whose value is an estimate.
function ns.WithConversions(stats)
  local total, estimated = {}, {}
  for key, value in pairs(stats) do
    total[key] = value
  end
  if not ns.vanillaRules then
    return total, estimated
  end
  local _, class = UnitClass("player")
  local _, race = UnitRace("player")
  RaiseStats(total)
  local str, agi = total.strength or 0, total.agility or 0
  local sta, int = total.stamina or 0, total.intellect or 0

  local health = (total.health or 0) + sta * 10
  if race == "Tauren" then
    health = health * 1.05
  end
  total.health = health
  if not NO_MANA[class] then
    total.mana = (total.mana or 0) + int * 15
  end
  total.armor = (total.armor or 0) + agi * 2

  local ap = ATTACK_POWER[class]
  if ap then
    local itemAttackPower = total.attackPower or 0
    total.attackPower = itemAttackPower + str * ap.str + agi * ap.agi
    if ap.rangedAgi then
      -- "+Attack Power" gear counts for ranged attacks too.
      total.rangedAttackPower = (total.rangedAttackPower or 0) + itemAttackPower + agi * ap.rangedAgi
    end
  end
  TalentGains(total) -- after the gear's "+Attack Power" (which counts for ranged too); a talent names its own

  if UnitLevel("player") == 60 then
    if agi ~= 0 then
      total.crit = (total.crit or 0) + agi / (AGILITY_PER_CRIT[class] or 20)
      total.dodge = (total.dodge or 0) + agi / (AGILITY_PER_DODGE[class] or 20)
      estimated.crit, estimated.dodge = true, true
    end
    if int ~= 0 and INTELLECT_PER_SPELL_CRIT[class] then
      total.spellCrit = (total.spellCrit or 0) + int / INTELLECT_PER_SPELL_CRIT[class]
      estimated.spellCrit = true
    end
  end
  return total, estimated
end
