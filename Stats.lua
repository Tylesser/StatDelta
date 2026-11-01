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

local function ParseLine(text, stats)
  text = text:gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", "")
  text = strtrim(text)
  if text == "" then
    return
  end
  -- Set bonuses, on-use and on-hit effects are not permanent stats.
  if text:find("^%(") or text:find("^Use:") or text:find("^Chance on hit:") or text:find("^Set:") then
    return
  end
  local dps = text:match("^%(([%d%.,]+) damage per second%)$")
  if dps then
    Add(stats, "dps", tonumber((dps:gsub(",", ""))))
    return
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

local function GetTooltipLines(link)
  local lines = {}
  if C_TooltipInfo and C_TooltipInfo.GetHyperlink then
    local data = C_TooltipInfo.GetHyperlink(link)
    if data and data.lines then
      for _, line in ipairs(data.lines) do
        if line.leftText == nil and TooltipUtil and TooltipUtil.SurfaceArgs then
          TooltipUtil.SurfaceArgs(line)
        end
        if line.leftText then
          table.insert(lines, line.leftText)
        end
      end
      return lines
    end
  end
  if not scanner then
    scanner = CreateFrame("GameTooltip", SCANNER_NAME, nil, "GameTooltipTemplate")
  end
  scanner:SetOwner(WorldFrame, "ANCHOR_NONE")
  scanner:ClearLines()
  scanner:SetHyperlink(link)
  for i = 1, scanner:NumLines() do
    local fontString = _G[SCANNER_NAME .. "TextLeft" .. i]
    local text = fontString and fontString:GetText()
    if text then
      table.insert(lines, text)
    end
  end
  scanner:Hide()
  return lines
end

local cache = {}

-- Stats printed on the item (no conversions). Returns nil while the item isn't loaded yet.
function ns.GetItemStats(link)
  if cache[link] then
    return cache[link]
  end
  if not GetItemInfo(link) then
    return nil
  end
  local stats = {}
  for _, text in ipairs(GetTooltipLines(link)) do
    ParseLine(text, stats)
  end
  cache[link] = stats
  return stats
end

function ns.ParseLines(lines)
  local stats = {}
  for _, text in ipairs(lines) do
    ParseLine(text, stats)
  end
  return stats
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

-- Adds what the item's Strength, Agility, Stamina and Intellect give this character.
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
  local str, agi = stats.strength or 0, stats.agility or 0
  local sta, int = stats.stamina or 0, stats.intellect or 0

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
