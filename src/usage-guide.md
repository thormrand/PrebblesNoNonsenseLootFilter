# Prebbles No-Nonsense Loot Filter — Usage Guide

Slash command: `/nps <command>` or type directly in the console.

---

## Table of Contents

1. [Opening the Console](#1-opening-the-console)
2. [Navigating the Console — Keyboard & Mouse](#2-navigating-the-console--keyboard--mouse)
3. [Understanding Rule Types and Filters](#3-understanding-rule-types-and-filters)
4. [Profile Management](#4-profile-management)
5. [Managing Keep Rules](#5-managing-keep-rules)
6. [Managing Sell Rules](#6-managing-sell-rules)
7. [Editing Rules with .mod](#7-editing-rules-with-mod)
8. [Searching Rules](#8-searching-rules)
9. [How Selling Works](#9-how-selling-works)
10. [Console Settings](#10-console-settings)
11. [Tracker](#11-tracker)
12. [Zone Monitor](#12-zone-monitor)
13. [Tools Reference](#13-tools-reference)
14. [Simple Mailer](#14-simple-mailer)
15. [Vendor Management](#15-vendor-management)
16. [Farm Invite](#16-farm-invite)
17. [Temp Sell Mode](#17-temp-sell-mode)
18. [Path Discovery — Exploring Commands](#18-path-discovery--exploring-commands)
19. [Tips and Tricks](#19-tips-and-tricks)

---

## 1. Opening the Console

Type `/nps console.show` in any chat window to toggle the console open or closed.

The console window can be:
- **Moved** — drag the **■** button in the title bar, or drag the title bar itself.
- **Resized** — drag the grip in the bottom-right corner.
- **Locked** — click the **U** button to prevent accidental movement.
- **Minimized to the tracker HUD** — use `tracker.dashboard 1` to show the HUD, then close the console; the HUD remains on screen.
- **Closed** — click the **X** button or type `exit`.

The console remembers whether it was open when you logged out and will restore that state on your next login after a `/reload`.

---

## 2. Navigating the Console — Keyboard & Mouse

### Input shortcuts

| Key | Action |
|-----|--------|
| **Enter** | Submit the current command |
| **Arrow Up** | Scroll backwards through your command history |
| **Arrow Down** | Scroll forwards through your command history |
| **Tab** | Auto-complete the current command or filter field (see below) |
| **Escape** | Clear input focus (unfocus the text box) |

### Tab auto-complete

Tab completes commands progressively. Type a partial command and press **Tab** to jump to the first match. Press **Tab** again to cycle to the next match.

```
v<Tab>          → vendorprofile
ve<Tab>         → vendorprofile
vendorprofile.c<Tab>  → vendorprofile.create
tool.<Tab>      → tool.bagspace  (then Tab again for next tool)
```

Tab also completes **filter field names and operators** when typing a `.keep.add` or `.sell.add` argument:

```
…sell.add <Tab>           → …sell.add EQUIPLOC
…sell.add n<Tab>          → …sell.add NAME
…sell.add NAME=<Tab>      → …sell.add NAME!=
…sell.add ILVL><Tab>      → …sell.add ILVL>=
…sell.add ILVL>=10 AND <Tab>   → …sell.add ILVL>=10 AND EQUIPLOC
```

Tab cycles through all valid operators for the field. Operators not valid for the field type (e.g. `>=` on a string field) are automatically skipped.

### Mouse

| Action | Result |
|--------|--------|
| **Scroll wheel** | Scroll the output up or down |
| **Shift-click an item link** (in chat or tooltip) | Inserts the item link into the console input |
| **Click an item link in the output** | Opens the item tooltip |
| **S button** (Free Select) | Switches output to a selectable text box for copy/paste |

### Command history

Every command you submit is saved (up to the limit set by `console.memory.previouscommands`, default 50). Use **Arrow Up / Down** to recall previous commands — this is very useful when you want to repeat a sell or keep rule addition with a small change.

---

## 3. Understanding Rule Types and Filters

Every keep or sell rule is one of four types, determined automatically by what you type.

### Rule type resolution

| What you type | Resolved as | Example |
|---------------|-------------|---------|
| An item link (shift-click from bags/tooltip) | `id` | `[Linen Cloth]` link |
| A bare number | `id` | `2589` |
| `[Exact Name]` — name in square brackets | `exact` (case-insensitive) | `[Linen Cloth]` |
| `*partial*` — asterisks around text | `match` (substring) | `*Cloth*` |
| Any expression containing `=`, `>`, `<`, or `(` | `filter` | `QUALITY>=4` |

### Filter fields

| Field | Type | Available operators |
|-------|------|---------------------|
| `ID` | numeric | `=` `!=` `>=` `<=` `>` `<` |
| `NAME` | string | `=` `!=` |
| `QUALITY` | numeric | `=` `!=` `>=` `<=` `>` `<` |
| `ILVL` | numeric | `=` `!=` `>=` `<=` `>` `<` |
| `REQLEVEL` | numeric | `=` `!=` `>=` `<=` `>` `<` |
| `TYPE` | string | `=` `!=` |
| `SUBTYPE` | string | `=` `!=` |
| `STACK` | numeric | `=` `!=` `>=` `<=` `>` `<` |
| `EQUIPLOC` | string | `=` `!=` |
| `PRICE` | numeric (copper) | `=` `!=` `>=` `<=` `>` `<` |
| `INTOOLTIP` | string | `=` `!=` |

**Quality values:** 0 = Poor (gray), 1 = Common (white), 2 = Uncommon (green), 3 = Rare (blue), 4 = Epic (purple), 5 = Legendary.

**Substring matching on string fields:** use `NAME=*partial*`.

```
NAME=*Cloth*          matches any item whose name contains "Cloth"
INTOOLTIP=*Stamina*   matches any item whose tooltip contains "Stamina"
TYPE=Armor            matches exact type string "Armor"
```

### Operators and grouping

Combine conditions with `AND`, `OR`, `NOT` (or lowercase). Group with parentheses:

```
QUALITY>=2 AND ILVL>=100
QUALITY=0 OR PRICE=0
NOT (QUALITY=0)
(ILVL>=10 AND ILVL<50) OR QUALITY>=4
!(ILVL<10 AND QUALITY=0)
```

Grouping and negation can be nested freely.

### Filter validation

Logically impossible filters are rejected before saving:

```
ILVL>=10 AND ILVL<10        → rejected: impossible range
NAME=Foo AND NAME=Bar       → rejected: two different exact values
QUALITY=4 AND QUALITY!=4    → rejected: value contradicts its own exclusion
```

---

## 4. Profile Management

Profiles are the central concept. Each character has one or more vendor profiles, each containing a **keep list** and a **sell list**. Only one profile is active at a time.

### Creating a profile

```
vendorprofile.create MyProfile
vendorprofile.create trash-vendor
vendorprofile.create dungeon_farm
```

Profile names can contain letters, numbers, underscores, and dashes. Creating a profile automatically activates it for the current character.

### Listing profiles

```
vendorprofile.list              → all profiles across all characters
vendorprofile.sell.list         → profiles for the current character
vendorprofile.keep.list         → only profiles that have keep rules
```

### Activating and deactivating

```
vendorprofile.MyProfile.activate
vendorprofile.MyProfile.deactivate
```

You can also set a profile to load automatically on login:

```
console.defaultprofile MyProfile
```

### Deleting a profile

Deletion requires you to type the profile name as confirmation:

```
vendorprofile.MyProfile.delete MyProfile
```

### Autosell per profile

Each profile has its own autosell flag, independent of `console.autosell`:

```
vendorprofile.MyProfile.autosell.on
vendorprofile.MyProfile.autosell.off
```

### Removing duplicates

If you accidentally add the same rule twice:

```
vendorprofile.MyProfile.cleanup
```

---

## 5. Managing Keep Rules

Keep rules protect items from being sold. When an item matches a keep rule it will never be sold — unless you also use `--fs` (force-sell).

### Adding keep rules — by item ID

Shift-click an item in your bags while the console input is focused to insert its link, then submit:

```
vendorprofile.MyProfile.keep.add [Linen Cloth]
vendorprofile.MyProfile.keep.add 2589
```

You can shift-click multiple items and add them all at once in a single command.

### Adding keep rules — by name

```
vendorprofile.MyProfile.keep.add [Linen Cloth]       exact match (case-insensitive)
vendorprofile.MyProfile.keep.add *Cloth*             keeps anything with "Cloth" in the name
vendorprofile.MyProfile.keep.add *Potion*            keeps any potion by name
```

### Adding keep rules — by filter

```
vendorprofile.MyProfile.keep.add QUALITY>=3
vendorprofile.MyProfile.keep.add ILVL>=200
vendorprofile.MyProfile.keep.add QUALITY>=2 AND TYPE=Armor
vendorprofile.MyProfile.keep.add QUALITY>=4 OR PRICE>=10000
vendorprofile.MyProfile.keep.add QUALITY>=2 AND ILVL>=100 AND TYPE=Weapon
vendorprofile.MyProfile.keep.add TYPE=Armor AND EQUIPLOC!=INVTYPE_TABARD
```

### Keep rule flags

| Flag | Effect |
|------|--------|
| `--fs` | Force-sell this item even if the keep rule matches (if a sell rule applies to it) | This is a KEEP flag only. ....keep.add [filters] --fs
| `--pts` | Protect from Temp Sell mode (see section 16) |

Example: keep all uncommon+ items, but force-sell gray-quality gear regardless:

```
vendorprofile.MyProfile.keep.add QUALITY>=2
vendorprofile.MyProfile.keep.add QUALITY=0 --fs
```

Example: protect your Hearthstone from Temp Sell mode:

```
vendorprofile.MyProfile.keep.add [Hearthstone] --pts
```

Both flags can be combined:

```
vendorprofile.MyProfile.keep.add [Some Item] --fs --pts
```

### Listing keep rules

```
vendorprofile.MyProfile.keep.list
```

Output example:

```
Profile 'MyProfile' KEEP list:
  [ID: 1] Filter: QUALITY>=2
  [ID: 2] Filter: TYPE=Armor
  [ID: 3] Exact: *Hearthstone* [--pts]
```

### Removing keep rules

```
vendorprofile.MyProfile.keep.rem [Linen Cloth]        remove by value
vendorprofile.MyProfile.keep.rem *Cloth*              remove by value
vendorprofile.MyProfile.keep.rem QUALITY>=2           remove by value
vendorprofile.MyProfile.keep.rem ID:3                 remove by list ID
vendorprofile.MyProfile.keep.rem --listid 3 7 12      remove multiple by list ID
```

---

## 6. Managing Sell Rules

Sell rules mark items to be sold at vendors. An item must match a sell rule AND not match any keep rule (unless the keep rule has `--fs`) to actually be sold.

### Adding sell rules — examples

```
vendorprofile.MyProfile.sell.add QUALITY=0
vendorprofile.MyProfile.sell.add QUALITY=0 OR PRICE=0
vendorprofile.MyProfile.sell.add ILVL<50 AND QUALITY<=2
vendorprofile.MyProfile.sell.add TYPE=Junk
vendorprofile.MyProfile.sell.add *Broken*
vendorprofile.MyProfile.sell.add [Fractured Item]
vendorprofile.MyProfile.sell.add QUALITY>=1 AND PRICE<100
```

### Typical setup: sell all grays

```
vendorprofile.trash.create trash
vendorprofile.trash.sell.add QUALITY=0
vendorprofile.trash.autosell.on
```

### Typical setup: keep blue+ and sell everything else

```
vendorprofile.create farm
vendorprofile.farm.keep.add QUALITY>=3
vendorprofile.farm.sell.add QUALITY<=2
vendorprofile.farm.autosell.on
```

### Listing and removing sell rules

Same syntax as keep rules, replacing `keep` with `sell`:

```
vendorprofile.MyProfile.sell.list
vendorprofile.MyProfile.sell.rem QUALITY=0
vendorprofile.MyProfile.sell.rem ID:5
vendorprofile.MyProfile.sell.rem --listid 2 5 8
```

---

## 7. Editing Rules with .mod

The `.mod` command lets you edit an existing rule in-place without losing its list ID. This is useful when you want to refine a filter without removing and re-adding it.

### How it works

1. Find the list ID from `.keep.list` or `.sell.list`.
2. Run `.mod ID:#` — this prefills the console input with the current rule value.
3. Edit the prefilled text and press **Enter** to commit.

```
vendorprofile.MyProfile.keep.mod ID:3
```

The console input will be automatically filled with something like:

```
vendorprofile.MyProfile.keep.mod.commit ID:3 QUALITY>=2
```

Edit `QUALITY>=2` to your new value and press **Enter**:

```
vendorprofile.MyProfile.keep.mod.commit ID:3 QUALITY>=3
```

You can also change flags during mod:

```
vendorprofile.MyProfile.keep.mod.commit ID:3 [Hearthstone] --pts
```

---

## 8. Searching Rules

Search through all keep and sell rules of a profile at once:

```
vendorprofile.MyProfile.search cloth          search by name fragment
vendorprofile.MyProfile.search QUALITY        search by filter keyword
vendorprofile.MyProfile.search [Linen Cloth]  search by exact name
vendorprofile.MyProfile.search 2589           search by item ID
```

You can also shift-click an item and search for it directly:

```
vendorprofile.MyProfile.search [item link here]
```

---

## 9. How Selling Works

### Manual sell

```
/nps vendorprofile.MyProfile.activate
```

Then open a vendor and the addon will evaluate your bags against the active profile's sell list (filtered by the keep list) and sell matching items.

### Autosell

If `console.autosell 1` or the profile has autosell enabled, selling triggers automatically when you open a vendor.

The sell queue is processed in batches of `console.autosell.batchsize` items per frame (default: 50). With 102 items to sell at the default, that becomes 3 batches (50 + 50 + 2). Spreading the sell across multiple frames keeps the merchant frame open long enough for the addon to abort cleanly if you close the vendor mid-sell — preventing leftover items from being equipped or used.

### Gray deletion

If `console.graydelete 1`, gray items are deleted automatically when your bags update (without needing to be at a vendor). Useful to immediately free slots from trash.

### Delete zero-value items

If `console.delnovalue 1`, any item with a vendor price of 0 that matches a sell rule is deleted instead of sold.

### Verbose mode

If `console.verbose 1`, the addon prints a message for every item it sells or deletes, so you can see exactly what happened.

---

## 10. Console Settings

All settings can be:
- **Read** — type the key alone: `console.autosell`
- **Written** — type the key and value: `console.autosell 1`
- **Reset** — type the key and `default`: `console.autosell default`
- **Targeted at another character** — prefix with the character name: `Prebble.console.autosell 1`

### Behaviour settings

| Key | Default | Description |
|-----|---------|-------------|
| `console.autosell` | `0` | Auto-sell matching items when a vendor opens |
| `console.autosell.batchsize` | `50` | Items processed per sell batch (posint ≥1). Total batches = `ceil(queue_size / batchsize)`. Lower values spread the sell across more frames; higher values finish faster but make a mid-sell merchant close less recoverable. |
| `console.graydelete` | `0` | Delete gray items automatically on bag update |
| `console.verbose` | `0` | Print a message for every sold/deleted item |
| `console.delnovalue` | `0` | Delete zero-value items instead of selling them |
| `console.activeprofile` | `void` | Currently active vendor profile |
| `console.defaultprofile` | `void` | Profile loaded automatically on login |

### Memory settings

| Key | Default | Range | Description |
|-----|---------|-------|-------------|
| `console.memory.linecount` | `200` | 10–10000 | Maximum output lines stored |
| `console.memory.previouscommands` | `50` | 5–500 | Maximum command history entries |

### Theme settings

| Key | Default | Description |
|-----|---------|-------------|
| `console.theme.textsize` | `14` | Console font size (6–30) |
| `console.theme.textsize.title` | `14` | Title bar font size (6–30) |
| `console.theme.consolecolor.bg` | `000000` | Background colour (hex) |
| `console.theme.consolecolor.border` | `008000` | Border colour (hex) |
| `console.theme.consolecolor.input.bg` | `000000` | Input box background (hex) |
| `console.theme.consolecolor.user` | `00cc00` | Prompt colour (hex) |
| `console.theme.consolecolor.textcolor.command` | `00ff00` | Command highlight colour (hex) |
| `console.theme.consolecolor.textcolor.output` | `00cc00` | Output text colour (hex) |
| `console.theme.consolecolor.textcolor.error` | `c70c15` | Error text colour (hex) |

Hex colours can be written with or without the `#` prefix: `console.theme.consolecolor.border ff8800` or `#ff8800`.

Example — change the border to orange:

```
console.theme.consolecolor.border ff8800
```

---

## 11. Tracker

The tracker records gold earned and items sold/deleted, both for the current session and across all sessions (genesis).

### Viewing stats

```
console.tracker.show
```

Shows session totals (with gold-per-hour rate) and cumulative genesis totals.

### Tracker HUD

The tracker HUD is a small on-screen frame that shows live totals without opening the console:

```
tracker.dashboard 1         show the HUD
tracker.dashboard 0         hide the HUD
tracker.dashboard           read current visibility setting
```

### Resetting trackers

```
console.tracker.session.gold.reset      reset session gold totals
console.tracker.session.item.reset      reset session item counts
console.tracker.genesis.gold.reset      reset genesis gold totals
console.tracker.genesis.item.reset      reset genesis item counts
```

### Manually correcting genesis values

Genesis values are stored per-character and can be read or written directly:

```
tracker.genesis.sold                    read current genesis sold total (in copper)
tracker.genesis.sold 500000             set to 5 gold
tracker.genesis.deleted 0
tracker.genesis.item.sold
tracker.genesis.item.deleted
tracker.genesis.time                    total tracked session time in seconds
```

---

## 12. Zone Monitor

Each profile can be set to activate automatically when you enter a specific zone.

### Registering the current zone

Travel to the zone, then:

```
vendorprofile.MyProfile.zone.register
```

### Adding zones by name

```
vendorprofile.MyProfile.zone.add Hellfire Peninsula
vendorprofile.MyProfile.zone.add Zangarmarsh,Nagrand,Blade's Edge Mountains
```

Multiple zones can be added in a single command, separated by commas.

### Listing and removing zones

```
vendorprofile.MyProfile.zone.list
vendorprofile.MyProfile.zone.delete Zangarmarsh
vendorprofile.MyProfile.zone.delete *          removes all zones
```

### Enabling and disabling

Zone monitoring only activates when the profile is already the active profile. Enable it after registering at least one zone:

```
vendorprofile.MyProfile.zone.enable
vendorprofile.MyProfile.zone.disable
```

When enabled, entering a registered zone will automatically switch to that profile.

---

## 13. Tools Reference

### `tool.getproperties` — inspect item filter values

Prints every filter-visible property of an item. Useful to know exactly what values to write in a filter rule.

```
tool.getproperties [item link]
tool.getproperties 2589
```

Example output:

```
--- Item Properties: [Linen Cloth] ---
  ID        = 2589
  NAME      = Linen Cloth
  QUALITY   = 1
  ILVL      = 5
  REQLEVEL  = 0
  TYPE      = Trade Goods
  SUBTYPE   = Cloth
  STACK     = 200
  EQUIPLOC  =
  PRICE     = 150
  INTOOLTIP = Linen Cloth
```

If the item is not cached (you have not seen it in a tooltip recently), shift-click it first to load it, then run the command.

### `tool.sortbags` — sort bags

Sorts your bag contents. Items of the same type are grouped together.

```
tool.sortbags
```

### `tool.minimaprefresh` — minimap refresh rate

WoW's minimap updates on a timer. This tool can increase the refresh rate for smoother blip movement.

```
tool.minimaprefresh 1           enable minimap refresh
tool.minimaprefresh 0           disable minimap refresh
tool.minimaprefresh 100         set refresh interval to 100 ms (default)
tool.minimaprefresh 50          set to minimum (50 ms = fastest)
tool.minimaprefresh.frequency   read current interval setting
```

### `tool.bagspace` — bag space indicator

Shows a colour-coded indicator of how full your bags are.

```
tool.bagspace 1             show the indicator
tool.bagspace 0             hide the indicator
```

Colour thresholds (slots free as a percentage of total bag capacity):

| Setting | Default | Description |
|---------|---------|-------------|
| `tool.bagspace.threshold.empty` | `0` | Slots free % below which the "empty" colour shows |
| `tool.bagspace.threshold.low` | `10` | Slots free % below which "low" colour shows |
| `tool.bagspace.threshold.mid` | `50` | Slots free % below which "mid" colour shows |
| `tool.bagspace.color.empty` | `ff0000` | Colour when bags are nearly full (red) |
| `tool.bagspace.color.mid` | `ffff00` | Colour for mid range (yellow) |
| `tool.bagspace.color.high` | `00ff00` | Colour when bags have plenty of space (green) |

Example — raise the warning threshold:

```
tool.bagspace.threshold.low 20
tool.bagspace.color.empty ff4400
```

---

## 14. Simple Mailer

Simple Mailer lets you mail a large number of items to a character (typically a bank alt) in one go from a dedicated mailbox tab.

### Setting a recipient

```
tool.simplemailer.recipient BankAlt
```

### Protecting items from being mailed

The bag-keep list prevents specific items from being sent. Anything not on this list will be mailed.

```
tool.simplemailer.bagkeep.list
tool.simplemailer.bagkeep.add [Hearthstone]
tool.simplemailer.bagkeep.add 6948
tool.simplemailer.bagkeep.rem 1           remove entry at index 1
```

### Sending

Open the mailbox, then:

```
tool.simplemailer.send
```

All items in your bags that are not on the bag-keep list will be mailed to the recipient. The addon handles the send loop automatically.

---

## 15. Vendor Management

Vendor Management automates a companion-driven loot-and-vendor cycle. A companion NPC loots your nearby kills and a companion vendor buys what you have marked to sell.

```
tool.vendormanagement 1             enable automation
tool.vendormanagement 0             disable automation
```

### Configuration

| Setting | Default | Description |
|---------|---------|-------------|
| `tool.vendormanagement.lootername` | `Greedy Scavenger` | Name of the companion who loots |
| `tool.vendormanagement.vendorname` | `Goblin Merchant` | Name of the companion vendor |
| `tool.vendormanagement.threshold` | `5` | Free bag slots that trigger a sell cycle |

Example — lower the threshold to sell more aggressively:

```
tool.vendormanagement.threshold 3
```

---

## 16. Farm Invite

The Farm Invite module broadcasts a recruitment message to configured chat channels, with optional spam prevention cooldown.

### Enable the Module

```
tool.farminvite 1
```

When enabled, a mailbox icon appears at the edge of your minimap (if `tool.farminvite.spam.icon` is 1). Left-drag the icon to reposition it around the minimap edge.

### Sending Spam

Three ways to send the spam message:

- **Console command:** `tool.farminvite.spam.send`
- **Portrait click:** Left-click your player portrait
- **Minimap icon:** Left-click the mail icon on the minimap edge

All three trigger the same spam logic, including the cooldown check.

### Spam Prevention

A cooldown prevents accidental double-sends (default: 60 seconds):

```
tool.farminvite.spam.prevention 60
```

Set to `0` to disable the cooldown entirely.

### Testing Mode

Preview the message in your chat window (visible only to you) without sending it to any channel. The cooldown is also bypassed in this mode:

```
tool.farminvite.spam.testingonly 1
```

### Channel Configuration

Set the channels to send to as comma-separated tokens:

```
tool.farminvite.spam.channels 6,g
```

Valid tokens:

| Token | Target |
|-------|--------|
| Number (e.g. `6`) | Joined channel by index |
| `g` | Guild chat (requires guild membership) |
| `p` | Party |
| `r` | Raid |
| `s` | Say |
| `y` | Yell |

If a numbered channel is not currently joined, it is skipped with a console warning. If `g` is set but you are not in a guild, it is also skipped.

### Auto Message

When `tool.farminvite.spam.message` is `auto` (the default), the message is built from your configuration values.

With autokick enabled (`tool.farminvite.autokick 1`):

```
Farming/boosting in IC until I'm tired. Autokick at 79. Requirements: don't be 79, be in HC3 & have flying. Tipping is not needed but will redistribute profits to new players! /w with inv to get autoinvited.
```

With autokick disabled (`tool.farminvite.autokick 0`):

```
Farming/boosting in IC until I'm tired. Requirements: don't be 80 be in HC3 & have flying. Tipping is not needed but will redistribute profits to new players! /w with inv to get autoinvited.
```

Configure the variables used in the template:

```
tool.farminvite.torment 3
tool.farminvite.safeword inv
tool.farminvite.autokick 1
tool.farminvite.autokick.level 79
```

### Custom Message

To send a fixed message instead of the auto template:

```
tool.farminvite.spam.message Farming IC! /w inv for invite.
```

Set back to `auto` to resume the dynamic template:

```
tool.farminvite.spam.message auto
```

### Autokick Ignore List

Players on this list will not be autokicked (used by future autokick logic). The list is stored per-character.

```
tool.farminvite.autokick.ignoreplayerlist.add Prebble
tool.farminvite.autokick.ignoreplayerlist.list
tool.farminvite.autokick.ignoreplayerlist.rem Prebble
```

---

## 17. Temp Sell Mode

Temp Sell mode bypasses your keep list entirely. When enabled, **everything in your bags is sold or deleted** at the next vendor visit, except:

- Items protected with `--pts` on a keep rule.
- The Hearthstone (always protected).

Enable with confirmation dialog:

```
vendorprofile.tempsell 1
```

Disable immediately:

```
vendorprofile.tempsell 0
```

> **Warning:** This mode is intended for quickly clearing your bags after a session. It ignores all keep rules that do not have `--pts`. Use with care.

---

## 18. Path Discovery — Exploring Commands

Typing any prefix ending with `.` and pressing **Enter** shows everything under that path. This is the fastest way to explore what is available without memorising all commands.

| Input | What it shows |
|-------|---------------|
| `.` | All settings and profiles |
| `console.` | All console settings and commands |
| `console.theme.` | All theme/colour settings |
| `tool.` | All tool settings and commands |
| `tool.bagspace.` | All bag space settings |
| `tracker.` | Tracker settings |
| `vendorprofile.` | Global profile commands + your profiles |
| `vendorprofile.MyProfile.` | All commands for that specific profile |
| `vendorprofile.MyProfile.keep.` | Keep-related commands for that profile |
| `Prebble.console.` | Console settings for character "Prebble" |

**Tab** also works for prefix completion. Type `tool.b` and press **Tab** to jump to `tool.bagspace`, then press **Tab** again to move to the next match.

---

## 19. Tips and Tricks

### Use Arrow Up to repeat and tweak rules

When adding multiple rules of the same kind, press **Arrow Up** to recall the last command, change only the value, and press **Enter**. Saves a lot of typing.

```
vendorprofile.farm.sell.add QUALITY=0
↑ → change to QUALITY=1 AND ILVL<50
↑ → change to QUALITY=2 AND ILVL<80
```

### Shift-click items directly into sell/keep rules

With the console input focused, shift-click any item in your bags or tooltip. The item link is inserted at the cursor position. Then type the rest of the command and submit.

### Use `tool.getproperties` before writing filters

Before writing a complex filter, inspect the item first:

```
tool.getproperties [item link]
```

This shows the exact string values for `TYPE`, `SUBTYPE`, `EQUIPLOC`, and all numeric fields, so you know precisely what to match.

### Cross-character settings

Any setting can be read or written for another character by prefixing their name:

```
Prebble.console.autosell 1
Prebble.console.defaultprofile farm
```

This lets you configure an alt without logging into them.

### Use `.permclear` to clean the output

If the output is cluttered after many operations:

```
console.permclear
```

This permanently erases the stored output history. The session history (Arrow Up/Down) is not affected.

### The title bar shows your active profile

The console title bar always displays the active profile for the current character. Click the title bar text to prefill the console input with `vendorprofile.[name].` for quick rule editing.

### Profile visible to all alts

Profiles are stored account-wide. You can see and edit another character's profile from any character using `vendorprofile.list`. Only the owning character can activate their own profile.
