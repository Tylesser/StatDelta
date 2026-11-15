# StatDelta ("Tylesser - Stat Delta")

Shared conventions, release steps and the game client are in the workspace file `../../CLAUDE.md` (if present). This file covers this addon only.

## Files (load order from StatDelta.toc)

- `Tylesser.lua`: the shared Tylesser "Runestone" look (`ns.T`: stone panels, gold borders, studs, Cinzel, buttons,
  check boxes, options page header, chat prefix). Loaded first. The same file is in every Tylesser addon: edit them together
  (see the workspace CLAUDE.md).
- `Core.lua`: `ns.TITLE`, SavedVariables `StatDeltaDB` defaults (`enabled`, `showPrimary`, `showScore`, `showArrows`),
  per-character `StatDeltaCharDB` defaults (`preset`: nil = score off, a preset id or `"custom"`; `weights`: stat key ->
  points; `edited`), `ns.CONVERTED`, client checks (`ns.vanillaRules` for
  Interface < 20000, `ns.hasRangedSlot` for < 50000) and `ns.STATS`, the display order, labels and number formats.
- `Stats.lua`: reads an item's stats from its **tooltip text** (`C_TooltipInfo.GetHyperlink`, or a named scanning
  tooltip `TylesserStatDeltaScanner` on clients without it), cached per link, with left and right text. Primary stats,
  armor, shield block, resistances, weapon damage/speed/DPS use patterns built from Blizzard's global format strings
  (`ITEM_MOD_STRENGTH`... `ARMOR_TEMPLATE`, `SHIELD_BLOCK_TEMPLATE`, `ITEM_RESIST_SINGLE`/`_ALL` with school names from
  `SPELL_SCHOOLn_CAP`/`DAMAGE_SCHOOLn`, `DPS_TEMPLATE`, `DAMAGE_TEMPLATE`, `WEAPON_SPEED`/`SPEED`; each optional,
  `%c`/`%d`/`%s`/`%.1f`/`%1$s` handled; numbers may use "." "," space or no-break space as separators, decimal
  commas too; weapon speed tries `WEAPON_SPEED`, `SPEED` (word or format) and then English "Speed"), so they work on any client language. "Equip:" effects are
  English patterns only (other languages skip them; never invent translations). Skips set bonuses, "Use:" and "Chance on
  hit:" (also the localized `ITEM_SPELL_TRIGGER_ONUSE`/`ONPROC`). The weapon DPS line is read before the "(" set-bonus
  skip (it was skipped before). `ns.IsItemUsable`: false if any tooltip line is red (armor type, weapon skill, class,
  level), cached until the level changes (`PLAYER_LEVEL_UP`, `UNIT_LEVEL` player) or a new skill is learned. `ns.WithConversions` adds the Classic Era conversions per class (Attack Power, Ranged
  Attack Power, Health, Mana, Armor; Crit/Dodge/Spell Crit only at level 60, marked as estimates).
- `Tooltip.lua`: maps the item's equip location to the equipped items it would replace (two-handers replace main and
  off hand; one-handers compare with each dual-wielded weapon; rings/trinkets compare with both or with the empty slot),
  and adds one "Stat Delta: Compared to ..." block per comparison to the bottom of the item tooltip, each with an
  "Item stats" section (printed stats) and a "Your character" section (`ns.CONVERTED` totals, when they differ). Added
  only while `IsModifiedClick("COMPAREITEMS")` (Shift) or the `alwaysCompareItems` CVar is on. Any item tooltip counts
  (the user asked for DialogueUI and "any addon", 2026-11-15):
  - Template tooltips (GameTooltip, ItemRefTooltip, other addons' GameTooltipTemplate frames) via `TooltipDataProcessor`
    for any tooltip, or `OnTooltipSetItem` on GameTooltip and ItemRefTooltip on older clients. Never shopping tooltips
    (name contains "Shopping"). GameTooltip and ItemRefTooltip always count; other tooltips count when `IsVisible()` or
    `GetNumPoints() > 0` (they may get their item before they are shown), so other addons' hidden scanning tooltips
    (owned with ANCHOR_NONE, no points) are never changed.
  - Custom tooltips that draw `C_TooltipInfo` data themselves, like DialogueUI's `SharedTooltip`: found at
    `PLAYER_LOGIN` by scanning `EnumerateFrames` for `ProcessTooltipData` + `GetHyperlink` + `AddDoubleLine` +
    `ReprocessInfo` + `ClearLines`; `ProcessTooltipData` and `ClearLines` are hooked with `hooksecurefunc`.
  - One throttled watcher frame follows the key for every tooltip seen: pressing it appends the lines (custom tooltips
    are reprocessed), releasing it rebuilds the tooltip (`ReprocessInfo`, `RefreshData`, or the owner's OnEnter).
  Nothing is shown for an already equipped item.
- `Score.lua`: the upgrade score. `ns.PRESETS` per class (rough Classic Era weights), `ns.WEIGHT_STATS` (the stats with
  an edit box), `ns.Score(stats, weights)`, `ns.ScoreText`, `ns.SetPreset` (nil = off, which also clears the weights), `ns.SetWeight`
  (rejects NaN/inf). `ns.ScoreAvailable()`: only with `ns.vanillaRules`; on later clients gear has ratings that
  `WEIGHT_STATS` doesn't cover, so the score line, the arrows and the options' score controls are off (a note instead). Rule against double
  counting: Attack Power, Ranged Attack Power, Health, Mana and Armor (`ns.SCORE_CONVERTED`) use the `ns.WithConversions`
  totals; every other weight (Strength, Agility... included) uses the printed value. Presets weight a stat or what it
  turns into, never both; Agility/Intellect weights stand only for crit/dodge/spell crit (level 60 estimates, so the
  score never uses the converted crit values).
- `Tooltip.lua` also adds one "Upgrade: +4.2%" line under each "Compared to" header (points when the equipped score is
  0 or less), only with a preset and `showScore`, and exports `ns.EquipLoc` and `ns.FindReplaced`.
- `Arrows.lua`: `ns.IsUpgrade(link)` (true when it beats at least one item it could replace, or an empty slot; usable
  items only; cached per link until `ns.RefreshArrows`) and the arrows: Blizzard bags (top right corner, as Blizzard's UpgradeIcon and Pawn use the top left; `UpdateItems` on
  `ContainerFrameCombinedBags`/`ContainerFrameN` with `EnumerateValidItems`, else `ContainerFrame_Update`), Baganator
  (`Baganator.API.RegisterCornerWidget`, id `tylesser_statdelta_upgrade`, default corner top right; refresh with
  `RequestItemButtonsRefresh`; Baganator also shows other characters' bags and the widget isn't told whose: when
  `details.itemLocation` is given, the item must be at that bag/slot in this character's bags, otherwise no arrow; without a
  location the arrow is shown as for this character), quest rewards (on the icon's top right corner; each button's
  anchor is remembered for arrows created by a refresh; `QuestInfo_Display` -> `QuestInfoRewardsFrame.RewardButtons`, and
  `QuestLog_UpdateQuestDetails` -> `QuestLogItemN` on old quest logs). The arrow is the game's
  `Interface\Buttons\Arrow-Down-Up` flipped, desaturated and tinted green. Items not loaded yet are retried on
  `GET_ITEM_INFO_RECEIVED` (through `ns.QueueRefresh`). DialogueUI is not hooked: its `DialogueUIAPI.AddItemEvaluator` replaces DialogueUI's own
  item-level arrows for everyone, allows one evaluator (Pawn's), and only takes effect after its "Evaluate Item
  Rewards" option is toggled (the public call doesn't refresh it).
- `Options.lua`: Esc > Options > AddOns > Tylesser - Stat Delta (`ns.T.OptionsPage`, Settings API or
  `InterfaceOptions_AddCategory`): four check boxes, preset buttons for the player's class ("Off" + roles), and a
  scrolling grid of weight edit boxes (`T.EditBox`; typing a weight with no preset starts a "custom" score).
  `ns.OpenOptions`, `ns.RefreshOptions`.
- `Events.lua`: `ADDON_LOADED` setup (defaults, hooks, options page, addon compartment entry); `ns.QueueRefresh(forget)`:
  one refresh 0.5 s after the first event of a burst (equipment changes fire per slot), arrows deferred to
  `PLAYER_REGEN_ENABLED` in combat; usable items are forgotten only on level changes and when the set of learned skill
  names changes (`GetNumSkillLines`/`GetSkillLineInfo`; skill-ups don't count); and the slash commands
  `/sdelta` and `/statdelta` (no argument or `options`: open the options; `on`, `off`, `primary`, `feedback`; anything
  else prints the help).

## Rules

- Only while Shift is held, inside the hovered item's own tooltip (the user's choice; they rejected both "always shown"
  and a separate box). Never add lines to the shopping (compare) tooltips.
- The upgrade score and arrows exist only once the player picks a preset (or types a weight); before that the
  tooltip block looks as before. The "Upgrade:" line follows the Shift rule; the arrows don't (always shown, with a
  setting to turn them off). Preset weights are rough starting values and must be described that way in the UI and
  README. The score is for Classic Era rules only (`ns.vanillaRules`); keep it off on later clients unless rating
  stats get weights. Keep refresh work coalesced (`ns.QueueRefresh`) and out of combat: tooltip scans are not cheap.
- The conversion numbers (AP per Strength, Agility per 1% crit, etc.) are the vanilla level 60 values. Change them only
  with a source, and keep the `~` mark on estimates.
- v1.0.0 released 2026-11-01 after the user tested it in game.
- tylesser.com and CurseForge show the illustration `branding/statdelta-card.png` (alt text in the site's `site.json`);
  the in-game screenshot `branding/Tylesser - Stat Delta 1.png` is no longer on the site. Keep images out of `Media/`:
  that folder ships in the zip.
