local _, ns = ...
local L = ns.L

-- Upgrade score: points per stat (weights), saved per character in StatDeltaCharDB.
-- Score of an item = sum of weight x stat.
--
-- Which value a weight is multiplied with:
-- * Attack Power, Ranged Attack Power, Health, Mana and Armor: your character's totals, with what
--   Strength, Agility, Stamina and Intellect turn into (ns.WithConversions, Classic Era rules).
-- * Every other stat, Strength, Agility, Stamina and Intellect included: the value printed on the item.
-- So a stat is never counted twice as long as a weight is on Strength OR on Attack Power, not on both
-- for the same thing. The presets weight what the primary stats turn into, and give Agility and
-- Intellect only a small weight for what isn't converted at every level (crit, dodge, spell crit).
-- Crit, Dodge and Spell Crit from Agility and Intellect are level 60 estimates, so the score uses the
-- printed values for those.

local SCORE_CONVERTED = { health = true, mana = true, attackPower = true, rangedAttackPower = true, armor = true }
ns.SCORE_CONVERTED = SCORE_CONVERTED

-- Stats with an edit box on the options page, in this order (labels from ns.STATS).
ns.WEIGHT_STATS = {
  "attackPower", "rangedAttackPower", "feralAttackPower", "dps", "crit", "hit",
  "spellDamage", "healing", "spellCrit", "spellHit", "mp5",
  "arcaneDamage", "fireDamage", "frostDamage", "holyDamage", "natureDamage", "shadowDamage",
  "health", "mana", "armor", "defense", "dodge", "parry", "block", "blockValue",
  "strength", "agility", "stamina", "intellect", "spirit",
}

-- Rough Classic Era starting values: per point of the stat, per 1% for Crit, Hit, Spell Crit,
-- Spell Hit, Dodge, Parry and Block, per 1 Weapon DPS. Physical damage: 1 Attack Power = 1.
-- Casters: 1 Spell Damage = 1. Healers: 1 Healing = 1. Tanks: 1 Stamina (10 Health) = 1.5.
local PRESETS = {
  WARRIOR = {
    { id = "WARRIOR_TANK", label = L["Tank"], weights = {
      health = 0.15, armor = 0.1, defense = 1.5, dodge = 12, parry = 12, block = 6, blockValue = 0.3,
      agility = 0.6, attackPower = 0.3, hit = 6, crit = 3, dps = 2,
    } },
    { id = "WARRIOR_DPS", label = L["DPS"], weights = {
      attackPower = 1, agility = 1, crit = 20, hit = 20, dps = 12,
    } },
  },
  ROGUE = {
    { id = "ROGUE", label = L["Rogue"], weights = {
      attackPower = 1, agility = 0.9, crit = 25, hit = 25, dps = 10,
    } },
  },
  HUNTER = {
    { id = "HUNTER", label = L["Hunter"], weights = {
      rangedAttackPower = 1, agility = 0.5, crit = 25, hit = 25, dps = 8, mana = 0.02,
    } },
  },
  MAGE = {
    { id = "MAGE", label = L["Mage"], weights = {
      spellDamage = 1, fireDamage = 0.8, frostDamage = 0.8, arcaneDamage = 0.3, intellect = 0.2,
      mana = 0.02, spirit = 0.1, spellCrit = 12, spellHit = 13, mp5 = 1, health = 0.005,
    } },
  },
  WARLOCK = {
    { id = "WARLOCK", label = L["Warlock"], weights = {
      spellDamage = 1, shadowDamage = 0.9, fireDamage = 0.3, intellect = 0.15, mana = 0.015,
      spirit = 0.05, spellCrit = 9, spellHit = 13, mp5 = 0.5, health = 0.02,
    } },
  },
  PRIEST = {
    { id = "PRIEST_HEALER", label = L["Healer"], weights = {
      healing = 1, intellect = 0.2, mana = 0.03, spirit = 0.4, mp5 = 2, spellCrit = 6, health = 0.005,
    } },
    { id = "PRIEST_SHADOW", label = L["Shadow"], weights = {
      spellDamage = 1, shadowDamage = 0.95, intellect = 0.15, mana = 0.015, spirit = 0.15,
      spellHit = 13, spellCrit = 4, mp5 = 0.6, health = 0.01,
    } },
  },
  DRUID = {
    { id = "DRUID_BEAR", label = L["Bear"], weights = {
      health = 0.15, armor = 0.12, agility = 0.6, defense = 1.2, dodge = 12,
      attackPower = 0.4, feralAttackPower = 0.4, hit = 8, crit = 5,
    } },
    { id = "DRUID_CAT", label = L["Cat"], weights = {
      attackPower = 1, feralAttackPower = 1, agility = 1, crit = 20, hit = 20,
    } },
    { id = "DRUID_HEALER", label = L["Healer"], weights = {
      healing = 1, intellect = 0.2, mana = 0.03, spirit = 0.3, mp5 = 2, spellCrit = 6,
    } },
    { id = "DRUID_BALANCE", label = L["Balance"], weights = {
      spellDamage = 1, natureDamage = 0.6, arcaneDamage = 0.4, intellect = 0.2, mana = 0.02,
      spirit = 0.15, spellCrit = 10, spellHit = 12, mp5 = 1,
    } },
  },
  PALADIN = {
    { id = "PALADIN_HOLY", label = L["Holy"], weights = {
      healing = 1, intellect = 0.35, mana = 0.03, spellCrit = 10, mp5 = 1.5, spirit = 0.05, health = 0.005,
    } },
    { id = "PALADIN_PROT", label = L["Protection"], weights = {
      health = 0.15, armor = 0.1, defense = 1.5, block = 6, blockValue = 0.5, dodge = 12, parry = 10,
      spellDamage = 0.6, holyDamage = 0.5, mana = 0.01, agility = 0.6, hit = 5, attackPower = 0.1,
    } },
    { id = "PALADIN_RET", label = L["Retribution"], weights = {
      attackPower = 1, agility = 0.8, crit = 20, hit = 20, dps = 12, spellDamage = 0.3, holyDamage = 0.2,
      intellect = 0.1, mana = 0.01,
    } },
  },
  SHAMAN = {
    { id = "SHAMAN_RESTO", label = L["Restoration"], weights = {
      healing = 1, intellect = 0.25, mana = 0.03, mp5 = 2.5, spellCrit = 8, spirit = 0.1,
    } },
    { id = "SHAMAN_ENHANCE", label = L["Enhancement"], weights = {
      attackPower = 1, agility = 0.9, crit = 20, hit = 20, dps = 12, intellect = 0.1, mana = 0.01,
      spellDamage = 0.2,
    } },
    { id = "SHAMAN_ELEMENTAL", label = L["Elemental"], weights = {
      spellDamage = 1, natureDamage = 0.85, fireDamage = 0.4, frostDamage = 0.2, intellect = 0.25,
      mana = 0.02, spellCrit = 12, spellHit = 12, mp5 = 1,
    } },
  },
}
ns.PRESETS = PRESETS

local function PlayerClass()
  local _, class = UnitClass("player")
  return class
end

-- The presets for this character's class (an empty list for classes without presets).
function ns.GetPresets()
  return PRESETS[PlayerClass()] or {}
end

function ns.FindPreset(id)
  for _, list in pairs(PRESETS) do
    for _, preset in ipairs(list) do
      if preset.id == id then
        return preset
      end
    end
  end
end

-- "Warrior DPS", "Custom", or nil while the score is off.
function ns.PresetName()
  local char = ns.charDB
  if not (char and char.preset) then
    return nil
  end
  local preset = ns.FindPreset(char.preset)
  local name = L["Custom"]
  if preset then
    local className = (LOCALIZED_CLASS_NAMES_MALE and LOCALIZED_CLASS_NAMES_MALE[PlayerClass()]) or ""
    name = (className ~= "" and className .. " - " or "") .. preset.label
  end
  if char.edited and preset then
    name = L["%s (edited)"]:format(name)
  end
  return name
end

-- The score is for Classic Era rules (WoW Forever, Classic Era): later game versions put ratings
-- on gear that the weights don't cover, so there the score, its line and the arrows are off.
function ns.ScoreAvailable()
  return ns.vanillaRules and true or false
end

-- The weights in use, or nil before a preset is chosen (the score is off then).
function ns.ActiveWeights()
  local char = ns.charDB
  if ns.ScoreAvailable() and char and char.preset and char.weights then
    return char.weights
  end
  return nil
end

function ns.ScoreShown()
  return ns.db and ns.db.showScore and ns.ActiveWeights() ~= nil
end

function ns.ArrowsShown()
  return ns.db and ns.db.showArrows and ns.ActiveWeights() ~= nil
end

-- Score of printed stats (one item, or the sum of the items it would replace).
function ns.Score(stats, weights)
  weights = weights or ns.ActiveWeights()
  if not (stats and weights) then
    return 0
  end
  local total = ns.WithConversions(stats)
  local score = 0
  for key, weight in pairs(weights) do
    local value
    if SCORE_CONVERTED[key] then
      value = total[key]
    else
      value = stats[key]
    end
    if type(weight) == "number" and value then
      score = score + weight * value
    end
  end
  return score
end

-- Text and color of the "Upgrade:" line: percent of the equipped score, or the difference in
-- points when the equipped score is 0 (or below, or an empty slot).
function ns.ScoreText(newScore, oldScore)
  local diff = newScore - oldScore
  local text
  if oldScore > 0 then
    local percent = diff / oldScore * 100
    if math.abs(percent) < 0.05 then
      return L["Upgrade: 0%"], 0.6, 0.6, 0.6
    end
    text = L["Upgrade: %+.1f%%"]:format(percent)
  else
    if math.abs(diff) < 0.05 then
      return L["Upgrade: 0 points"], 0.6, 0.6, 0.6
    end
    text = L["Upgrade: %+.1f points"]:format(diff)
  end
  if diff > 0 then
    return text, 0.1, 1, 0.1
  end
  return text, 1, 0.25, 0.25
end

local function CopyWeights(weights)
  local copy = {}
  for key, value in pairs(weights) do
    copy[key] = value
  end
  return copy
end

-- Settings changed: rebuild open tooltips, arrows and the options page.
local function Changed()
  if ns.Refresh then
    ns.Refresh()
  end
  if ns.RefreshArrows then
    ns.RefreshArrows()
  end
  if ns.RefreshOptions then
    ns.RefreshOptions()
  end
end
ns.ScoreChanged = Changed

-- One upgrade score per talent group (dual spec; 2026-11-22). The score in use (preset, weights, edited) belongs to
-- the active group (talentGroup); a swap puts it away in talentScores[group] and brings back the other
-- group's. The first time, the new group starts as a copy of the old one. Games without two talent groups stay on 1.
local function ActiveTalentGroup()
  if C_SpecializationInfo and type(C_SpecializationInfo.IsInitialized) == "function" then
    local ok, ready = pcall(C_SpecializationInfo.IsInitialized)
    if ok and ready == false then
      return nil -- not known yet (early in a login): no swap
    end
  end
  local group
  if C_SpecializationInfo and type(C_SpecializationInfo.GetActiveSpecGroup) == "function" then
    local ok, value = pcall(C_SpecializationInfo.GetActiveSpecGroup)
    group = ok and value or nil
  end
  if group == nil and type(GetActiveTalentGroup) == "function" then
    local ok, value = pcall(GetActiveTalentGroup)
    group = ok and value or nil
  end
  if group == nil or (issecretvalue and issecretvalue(group)) or type(group) ~= "number" then
    return 1
  end
  return group == 2 and 2 or 1
end
ns.ActiveTalentGroup = ActiveTalentGroup

-- Whether the character has two talent groups to switch between (the score line then says which one it is for).
function ns.HasTwoTalentGroups()
  local count_fn = GetNumSpecGroups or GetNumTalentGroups -- (the Classic versions' talent frame: GetNumTalentGroups)
  if type(count_fn) ~= "function" then
    return false
  end
  local ok, count = pcall(count_fn)
  if not ok or count == nil or (issecretvalue and issecretvalue(count)) or type(count) ~= "number" then
    return false
  end
  return count > 1
end

-- Follows a talent swap (and a swap made while the addon was off). Returns true when the score changed.
function ns.SyncTalentScore()
  local char = ns.charDB
  if not char then
    return false
  end
  local group, current = ActiveTalentGroup(), char.talentGroup or 1
  if group == nil then
    return false
  end
  if group == current then
    char.talentGroup = group
    return false
  end
  char.talentScores = char.talentScores or {}
  char.talentScores[current] = { preset = char.preset, weights = CopyWeights(char.weights or {}),
    edited = char.edited and true or false }
  local saved = char.talentScores[group]
  if saved then
    char.preset = saved.preset
    char.weights = CopyWeights(saved.weights or {})
    char.edited = saved.edited and true or false
  end
  char.talentGroup = group
  Changed()
  return true
end

-- Picks a preset (its weights replace the current ones), or turns the score off with nil.
function ns.SetPreset(id)
  local char = ns.charDB
  if id == nil then
    -- off: forget the weights too, so typing one later starts from nothing
    char.preset = nil
    char.weights = {}
    char.edited = false
  else
    local preset = ns.FindPreset(id)
    if not preset then
      return false
    end
    char.preset = id
    char.weights = CopyWeights(preset.weights)
    char.edited = false
  end
  Changed()
  return true
end

-- Sets one weight (0 or nil removes it). Before any preset, this starts a custom score.
function ns.SetWeight(key, value)
  local char = ns.charDB
  if type(value) ~= "number" or value ~= value or math.abs(value) == math.huge then
    return false -- not a number, NaN or infinite
  end
  if value == 0 then
    value = nil
  end
  if char.weights[key] == value then
    return
  end
  char.weights[key] = value
  char.edited = true
  if not char.preset then
    char.preset = "custom"
  end
  Changed()
  return true
end
