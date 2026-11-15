# Changelog

## 1.3.0

- Options page: Esc > Options > AddOns > Tylesser - Stat Delta, also opened with `/sdelta` and from the addon menu next to the minimap.
- Upgrade score: pick a preset for your class and role, and the Stat Delta section shows "Upgrade: +4.2%" (or the difference in points) for each comparison. The presets are rough starting values; you can change the points for every stat. Saved per character, off until you pick a preset; "Off" clears the points. For Classic Era and WoW Forever only: on other game versions the score and arrows are off.
- Upgrade arrows: once a preset is picked, a green arrow in the top right corner marks upgrades in Blizzard's bags, in Baganator and on quest rewards. Can be turned off.
- Strength, Agility, Stamina, Intellect, Spirit, Armor, Block, resistances and weapon damage, speed and DPS are now read on every client language. "Equip:" effects still need an English client.
- Fixed: Weapon DPS was never counted.
- Item tooltips of other addons and chat links (ItemRefTooltip) get the Stat Delta section more reliably, also before they are on screen.

## 1.2.1

- The feedback window (`/sdelta feedback`) also points to tylesser.com for the other Tylesser addons.

## 1.2.0

- Works with DialogueUI's quest reward tooltips, and with the item tooltips of other addons and chat links, not only Blizzard's main tooltip.
- A `/sdelta feedback` command: it shows the link to tylesser.com/feedback, where you can report a bug or suggest an idea.

## 1.1.0

- New Tylesser look: the Stat Delta section in tooltips starts with a gold "Stat Delta" heading, and chat messages match the other Tylesser addons.

## 1.0.0

- First release.
- Hold Shift over an item to add a Stat Delta section to its tooltip, with the stat changes compared to your equipped item: green for gains, red for losses.
- Two sections: "Item stats" (the stats printed on the items) and "Your character" (totals after your class's stat conversions).
- Attack Power, Ranged Attack Power, Health, Mana and Armor from Strength, Agility, Stamina and Intellect, based on your class (Classic Era and WoW Forever). Estimated Crit, Dodge and Spell Crit at level 60.
- Equip effects: Spell Damage, Healing, school damage, Attack Power, Hit, Crit, Mana per 5 sec, Defense, Block and more.
- Rings, trinkets, two-handed weapons, dual wielding and off-hand items are compared with the right equipped items.
- `/sdelta` to turn the stat changes, or just the base stats, on and off.
