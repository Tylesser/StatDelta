local _, ns = ...
local L = ns.L

ns.TITLE = "Tylesser - Stat Delta"

-- StatDeltaDB (account wide)
ns.defaults = {
  enabled = true,
  showPrimary = true, -- Strength, Agility, Stamina, Intellect, Spirit
  showScore = true,   -- "Upgrade: +4.2%" lines, once a score preset is chosen
  showArrows = true,  -- green arrows on bag and quest reward items, once a score preset is chosen
}

-- StatDeltaCharDB (per character): the upgrade score.
-- preset: nil (score off), a preset id from Score.lua, or "custom"; weights: stat key -> points.
ns.charDefaults = {
  weights = {},
  edited = false,
}

ns.PREFIX = ns.T.Prefix("Stat Delta")

local tocVersion = select(4, GetBuildInfo())
-- Classic Era and WoW Forever (Interface 1xxxx) use the original stat formulas, so
-- Strength, Agility, Stamina and Intellect are turned into Attack Power, Health, etc.
-- Other clients only show the stats printed on the items.
ns.vanillaRules = tocVersion < 20000
-- Mists of Pandaria removed the ranged slot: bows, guns and wands go in the main hand.
ns.hasRangedSlot = tocVersion < 50000

-- Stats that ns.WithConversions can change; shown under "Your character".
ns.CONVERTED = {
  health = true, mana = true, attackPower = true, rangedAttackPower = true, armor = true,
  crit = true, dodge = true, spellCrit = true,
  -- WoW Forever's talents (Stats.lua TALENTS): stats raised by a percentage, spell damage and healing from a stat
  strength = true, agility = true, stamina = true, intellect = true, spirit = true, spellDamage = true, healing = true,
}

-- Display order. fmt: "int" (default), "pct" or "dec". weightLabel: the options page's name for a percent stat
-- (its weight is per 1%).
ns.STATS = {
  { key = "health", label = L["Health"] },
  { key = "mana", label = L["Mana"] },
  { key = "attackPower", label = L["Attack Power"] },
  { key = "rangedAttackPower", label = L["Ranged Attack Power"] },
  { key = "feralAttackPower", label = L["Attack Power in forms"] },
  { key = "dps", label = L["Weapon DPS"], fmt = "dec" },
  { key = "spellPower", label = L["Spell Power"] },
  { key = "spellDamage", label = L["Spell Damage"] },
  { key = "arcaneDamage", label = L["Arcane Damage"] },
  { key = "fireDamage", label = L["Fire Damage"] },
  { key = "frostDamage", label = L["Frost Damage"] },
  { key = "holyDamage", label = L["Holy Damage"] },
  { key = "natureDamage", label = L["Nature Damage"] },
  { key = "shadowDamage", label = L["Shadow Damage"] },
  { key = "healing", label = L["Healing"] },
  { key = "crit", label = L["Crit Chance"], weightLabel = L["Crit (1%)"], fmt = "pct" },
  { key = "hit", label = L["Hit Chance"], weightLabel = L["Hit (1%)"], fmt = "pct" },
  { key = "spellCrit", label = L["Spell Crit Chance"], weightLabel = L["Spell Crit (1%)"], fmt = "pct" },
  { key = "spellHit", label = L["Spell Hit Chance"], weightLabel = L["Spell Hit (1%)"], fmt = "pct" },
  { key = "critRating", label = L["Crit Rating"] },
  { key = "hitRating", label = L["Hit Rating"] },
  { key = "spellCritRating", label = L["Spell Crit Rating"] },
  { key = "spellHitRating", label = L["Spell Hit Rating"] },
  { key = "hasteRating", label = L["Haste"] },
  { key = "expertiseRating", label = L["Expertise"] },
  { key = "armorPenetrationRating", label = L["Armor Penetration"] },
  { key = "masteryRating", label = L["Mastery"] },
  { key = "versatility", label = L["Versatility"] },
  { key = "mp5", label = L["Mana per 5 sec"] },
  { key = "hp5", label = L["Health per 5 sec"] },
  { key = "armor", label = L["Armor"] },
  { key = "defense", label = L["Defense"] },
  { key = "defenseRating", label = L["Defense Rating"] },
  { key = "dodge", label = L["Dodge Chance"], weightLabel = L["Dodge (1%)"], fmt = "pct" },
  { key = "dodgeRating", label = L["Dodge Rating"] },
  { key = "parry", label = L["Parry Chance"], weightLabel = L["Parry (1%)"], fmt = "pct" },
  { key = "parryRating", label = L["Parry Rating"] },
  { key = "block", label = L["Block Chance"], weightLabel = L["Block (1%)"], fmt = "pct" },
  { key = "blockRating", label = L["Block Rating"] },
  { key = "blockValue", label = L["Block Value"] },
  { key = "resilienceRating", label = L["Resilience"] },
  { key = "strength", label = L["Strength"], primary = true },
  { key = "agility", label = L["Agility"], primary = true },
  { key = "stamina", label = L["Stamina"], primary = true },
  { key = "intellect", label = L["Intellect"], primary = true },
  { key = "spirit", label = L["Spirit"], primary = true },
  { key = "arcaneResistance", label = L["Arcane Resistance"] },
  { key = "fireResistance", label = L["Fire Resistance"] },
  { key = "frostResistance", label = L["Frost Resistance"] },
  { key = "natureResistance", label = L["Nature Resistance"] },
  { key = "shadowResistance", label = L["Shadow Resistance"] },
}
