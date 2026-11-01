local _, ns = ...

ns.defaults = {
  enabled = true,
  showPrimary = true, -- Strength, Agility, Stamina, Intellect, Spirit
}

ns.PREFIX = "|cffffd700Tylesser - Stat Delta|r: "

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
}

-- Display order. fmt: "int" (default), "pct" or "dec".
ns.STATS = {
  { key = "health", label = "Health" },
  { key = "mana", label = "Mana" },
  { key = "attackPower", label = "Attack Power" },
  { key = "rangedAttackPower", label = "Ranged Attack Power" },
  { key = "feralAttackPower", label = "Attack Power in forms" },
  { key = "dps", label = "Weapon DPS", fmt = "dec" },
  { key = "spellPower", label = "Spell Power" },
  { key = "spellDamage", label = "Spell Damage" },
  { key = "arcaneDamage", label = "Arcane Damage" },
  { key = "fireDamage", label = "Fire Damage" },
  { key = "frostDamage", label = "Frost Damage" },
  { key = "holyDamage", label = "Holy Damage" },
  { key = "natureDamage", label = "Nature Damage" },
  { key = "shadowDamage", label = "Shadow Damage" },
  { key = "healing", label = "Healing" },
  { key = "crit", label = "Crit Chance", fmt = "pct" },
  { key = "hit", label = "Hit Chance", fmt = "pct" },
  { key = "spellCrit", label = "Spell Crit Chance", fmt = "pct" },
  { key = "spellHit", label = "Spell Hit Chance", fmt = "pct" },
  { key = "critRating", label = "Crit Rating" },
  { key = "hitRating", label = "Hit Rating" },
  { key = "spellCritRating", label = "Spell Crit Rating" },
  { key = "spellHitRating", label = "Spell Hit Rating" },
  { key = "hasteRating", label = "Haste" },
  { key = "expertiseRating", label = "Expertise" },
  { key = "armorPenetrationRating", label = "Armor Penetration" },
  { key = "masteryRating", label = "Mastery" },
  { key = "versatility", label = "Versatility" },
  { key = "mp5", label = "Mana per 5 sec" },
  { key = "hp5", label = "Health per 5 sec" },
  { key = "armor", label = "Armor" },
  { key = "defense", label = "Defense" },
  { key = "defenseRating", label = "Defense Rating" },
  { key = "dodge", label = "Dodge Chance", fmt = "pct" },
  { key = "dodgeRating", label = "Dodge Rating" },
  { key = "parry", label = "Parry Chance", fmt = "pct" },
  { key = "parryRating", label = "Parry Rating" },
  { key = "block", label = "Block Chance", fmt = "pct" },
  { key = "blockRating", label = "Block Rating" },
  { key = "blockValue", label = "Block Value" },
  { key = "resilienceRating", label = "Resilience" },
  { key = "strength", label = "Strength", primary = true },
  { key = "agility", label = "Agility", primary = true },
  { key = "stamina", label = "Stamina", primary = true },
  { key = "intellect", label = "Intellect", primary = true },
  { key = "spirit", label = "Spirit", primary = true },
  { key = "arcaneResistance", label = "Arcane Resistance" },
  { key = "fireResistance", label = "Fire Resistance" },
  { key = "frostResistance", label = "Frost Resistance" },
  { key = "natureResistance", label = "Nature Resistance" },
  { key = "shadowResistance", label = "Shadow Resistance" },
}
