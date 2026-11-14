# StatDelta ("Tylesser - Stat Delta")

Shared conventions, release steps and the game client are in the workspace file `../../CLAUDE.md` (if present). This file covers this addon only.

## Files (load order from StatDelta.toc)

- `Tylesser.lua`: the shared Tylesser "Runestone" look (`ns.T`: stone panels, gold borders, studs, Cinzel, buttons,
  check boxes, options page header, chat prefix). Loaded first. The same file is in every Tylesser addon: edit them together
  (see the workspace CLAUDE.md).
- `Core.lua`: SavedVariables `StatDeltaDB` defaults (`enabled`, `showPrimary`), `ns.CONVERTED`, client checks (`ns.vanillaRules` for
  Interface < 20000, `ns.hasRangedSlot` for < 50000) and `ns.STATS`, the display order, labels and number formats.
- `Stats.lua`: reads an item's stats from its **tooltip text** (`C_TooltipInfo.GetHyperlink`, or a named scanning
  tooltip `TylesserStatDeltaScanner` on clients without it), cached per link. English patterns only. Skips set bonuses,
  "Use:" and "Chance on hit:". `ns.WithConversions` adds the Classic Era conversions per class (Attack Power, Ranged
  Attack Power, Health, Mana, Armor; Crit/Dodge/Spell Crit only at level 60, marked as estimates).
- `Tooltip.lua`: maps the item's equip location to the equipped items it would replace (two-handers replace main and
  off hand; one-handers compare with each dual-wielded weapon; rings/trinkets compare with both or with the empty slot),
  and adds one "Stat Delta: Compared to ..." block per comparison to the bottom of the item tooltip, each with an
  "Item stats" section (printed stats) and a "Your character" section (`ns.CONVERTED` totals, when they differ). Added
  only while `IsModifiedClick("COMPAREITEMS")` (Shift) or the `alwaysCompareItems` CVar is on. Any item tooltip counts
  (the user asked for DialogueUI and "any addon", 2026-11-15):
  - Template tooltips (GameTooltip, ItemRefTooltip, other addons' GameTooltipTemplate frames) via `TooltipDataProcessor`
    for any tooltip, or `OnTooltipSetItem` on GameTooltip and ItemRefTooltip on older clients. Never shopping tooltips
    (name contains "Shopping"), and tooltips other than GameTooltip only while visible and placed (`GetLeft()`), so
    other addons' hidden scanning tooltips are never changed.
  - Custom tooltips that draw `C_TooltipInfo` data themselves, like DialogueUI's `SharedTooltip`: found at
    `PLAYER_LOGIN` by scanning `EnumerateFrames` for `ProcessTooltipData` + `GetHyperlink` + `AddDoubleLine` +
    `ReprocessInfo` + `ClearLines`; `ProcessTooltipData` and `ClearLines` are hooked with `hooksecurefunc`.
  - One throttled watcher frame follows the key for every tooltip seen: pressing it appends the lines (custom tooltips
    are reprocessed), releasing it rebuilds the tooltip (`ReprocessInfo`, `RefreshData`, or the owner's OnEnter).
  Nothing is shown for an already equipped item.
- `Events.lua`: `ADDON_LOADED` setup and the slash commands `/sdelta` and `/statdelta` (`on`, `off`, `primary`).

## Rules

- Only while Shift is held, inside the hovered item's own tooltip (the user's choice; they rejected both "always shown"
  and a separate box). Never add lines to the shopping (compare) tooltips.
- The conversion numbers (AP per Strength, Agility per 1% crit, etc.) are the vanilla level 60 values. Change them only
  with a source, and keep the `~` mark on estimates.
- v1.0.0 released 2026-11-01 after the user tested it in game.
- tylesser.com and CurseForge show the illustration `branding/statdelta-card.png` (alt text in the site's `site.json`);
  the in-game screenshot `branding/Tylesser - Stat Delta 1.png` is no longer on the site. Keep images out of `Media/`:
  that folder ships in the zip.
