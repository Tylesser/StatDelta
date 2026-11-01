# StatDelta ("Tylesser - Stat Delta")

Shared conventions, release steps and the game client are in the workspace file `../../CLAUDE.md` (if present). This file covers this addon only.

## Files (load order from StatDelta.toc)

- `Core.lua`: SavedVariables `StatDeltaDB` defaults (`enabled`, `showPrimary`), `ns.CONVERTED`, client checks (`ns.vanillaRules` for
  Interface < 20000, `ns.hasRangedSlot` for < 50000) and `ns.STATS`, the display order, labels and number formats.
- `Stats.lua`: reads an item's stats from its **tooltip text** (`C_TooltipInfo.GetHyperlink`, or a named scanning
  tooltip `TylesserStatDeltaScanner` on clients without it), cached per link. English patterns only. Skips set bonuses,
  "Use:" and "Chance on hit:". `ns.WithConversions` adds the Classic Era conversions per class (Attack Power, Ranged
  Attack Power, Health, Mana, Armor; Crit/Dodge/Spell Crit only at level 60, marked as estimates).
- `Tooltip.lua`: maps the item's equip location to the equipped items it would replace (two-handers replace main and
  off hand; one-handers compare with each dual-wielded weapon; rings/trinkets compare with both or with the empty slot),
  and adds one "Stat Delta: Compared to ..." block per comparison to the bottom of `GameTooltip`, each with an
  "Item stats" section (printed stats) and a "Your character" section (`ns.CONVERTED` totals, when they differ). Added
  only while `IsModifiedClick("COMPAREITEMS")` (Shift) or the `alwaysCompareItems` CVar is on, via `TooltipDataProcessor`
  or `OnTooltipSetItem`. A throttled `GameTooltip` OnUpdate hook watches the key: pressing it appends the lines,
  releasing it rebuilds the tooltip (`RefreshData`, or the owner's OnEnter). Nothing is shown for an already equipped
  item. Chat links (`ItemRefTooltip`) are not handled.
- `Events.lua`: `ADDON_LOADED` setup and the slash commands `/sdelta` and `/statdelta` (`on`, `off`, `primary`).

## Rules

- Only while Shift is held, inside the hovered item's own tooltip (the user's choice; they rejected both "always shown"
  and a separate box). Never add lines to the shopping (compare) tooltips.
- The conversion numbers (AP per Strength, Agility per 1% crit, etc.) are the vanilla level 60 values. Change them only
  with a source, and keep the `~` mark on estimates.
- v1.0.0 released 2026-11-01 after the user tested it in game.
