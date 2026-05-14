# Prebbles No-Nonsense Loot Filter — Command Reference

Slash command: `/nps <command>` or type directly in the console.

---

## Console

| Command | Description |
|---------|-------------|
| `console.show` | Toggle console window |
| `console.help` | Show console usage tips |
| `console.save` | Force UI reload and save state |
| `console.permclear` | Permanently clear output history |
| `cls` / `clr` / `clear` | Clear console screen (session only) |
| `exit` | Close console |
| `help` | List all commands |

---

## Console Settings

> **Storage:** Per-character (`SavedVariablesPerCharacter`)

All settings can be read (no value), written (`key value`), or reset (`key default`).
Prefix with a character name to target another character: `Prebble.console.autosell 1`

| Key | Type | Default | Description |
|-----|------|---------|-------------|
| `console.autosell` | bool | `0` | Auto-sell at vendors |
| `console.autosell.batchsize` | posint (≥1) | `50` | Items processed per sell batch; total batches = ceil(queue / batchsize) |
| `console.graydelete` | bool | `0` | Delete gray items on bag update |
| `console.verbose` | bool | `0` | Extra output during sell/delete |
| `console.delnovalue` | bool | `0` | Delete zero-value items |
| `console.activeprofile` | string | `void` | Active vendor profile key |
| `console.defaultprofile` | string | `void` | Default profile loaded on login |
| `console.memory.linecount` | posint (10–10000) | `200` | Max stored output lines |
| `console.memory.previouscommands` | posint (5–500) | `50` | Max stored input history entries |
| `console.theme.textsize` | posint (6–30) | `14` | Console font size |
| `console.theme.textsize.title` | posint (6–30) | `14` | Title bar font size |
| `console.theme.consolecolor.bg` | hex | `000000` | Background colour |
| `console.theme.consolecolor.border` | hex | `008000` | Border colour |
| `console.theme.consolecolor.input.bg` | hex | `000000` | Input box background |
| `console.theme.consolecolor.user` | hex | `00cc00` | Prompt user colour |
| `console.theme.consolecolor.textcolor.command` | hex | `00ff00` | Command highlight colour |
| `console.theme.consolecolor.textcolor.output` | hex | `00cc00` | Output text colour |
| `console.theme.consolecolor.textcolor.error` | hex | `c70c15` | Error text colour |

---

## Tracker

> **Storage:** Session stats are volatile (lost on logout/login). Genesis totals and dashboard setting are per-character (`SavedVariablesPerCharacter`).

| Command | Description |
|---------|-------------|
| `console.tracker.show` | Print session and genesis stats |
| `console.tracker.genesis.gold.reset` | Reset genesis gold totals to 0 |
| `console.tracker.genesis.item.reset` | Reset genesis item count to 0 |
| `console.tracker.session.gold.reset` | Reset session gold totals to 0 |
| `console.tracker.session.item.reset` | Reset session item count to 0 |
| `tracker.dashboard 0\|1` | Show/hide the tracker HUD frame |
| `tracker.dashboard` | Read tracker HUD visibility setting |
| `tracker.genesis.sold` | Read/write genesis gold sold total |
| `tracker.genesis.deleted` | Read/write genesis gold deleted total |
| `tracker.genesis.item.sold` | Read/write genesis items sold count |
| `tracker.genesis.item.deleted` | Read/write genesis items deleted count |
| `tracker.genesis.time` | Read/write genesis start timestamp |

---

## Tools

> **Storage:** Per-character (`SavedVariablesPerCharacter`)

| Command | Description |
|---------|-------------|
| `tool.getproperties [itemlink\|ID]` | Print all filter-visible properties of an item |
| `tool.sortbags` | Sort bags |
| `tool.minimaprefresh 1\|0` | Enable / disable minimap refresh |
| `tool.minimaprefresh [ms]` | Set refresh interval in ms (default: 100, min: 50) |
| `tool.minimaprefresh.frequency` | Read/write minimap refresh interval (posint, min 50) |
| `tool.bagspace 0\|1` | Show/hide bag space indicator |
| `tool.bagspace.threshold.empty` | Read/write empty threshold (posint 0–100, default: 0) |
| `tool.bagspace.threshold.low` | Read/write low threshold (posint 0–100, default: 10) |
| `tool.bagspace.threshold.mid` | Read/write mid threshold (posint 0–100, default: 50) |
| `tool.bagspace.color.empty` | Read/write colour for empty state (hex, default: `ff0000`) |
| `tool.bagspace.color.mid` | Read/write colour for mid state (hex, default: `ffff00`) |
| `tool.bagspace.color.high` | Read/write colour for high state (hex, default: `00ff00`) |
| `tool.vendormanagement 0\|1` | Enable/disable vendor management automation |
| `tool.vendormanagement.lootername [name]` | Set looter NPC name (default: `Greedy Scavenger`) |
| `tool.vendormanagement.vendorname [name]` | Set vendor NPC name (default: `Goblin Merchant`) |
| `tool.vendormanagement.threshold [N]` | Free bag slots that trigger sell (posint, default: 5) |

---

## Simple Mailer

> **Storage:** Per-character (`SavedVariablesPerCharacter`)

| Command | Description |
|---------|-------------|
| `tool.simplemailer.recipient [charname]` | Set or read the mail recipient |
| `tool.simplemailer.bagkeep.list` | List items excluded from the mail send |
| `tool.simplemailer.bagkeep.add [itemlink\|ID]` | Add item to bag-keep (will not be mailed) |
| `tool.simplemailer.bagkeep.rem [index]` | Remove bag-keep entry by index |
| `tool.simplemailer.send` | Send all non-kept bag items to recipient |

---

## Vendor Profiles

> **Storage:** Account-wide but sub-divided per character (`SavedVariables` / `PNNSIM_Profiles[charName][profileKey]`). All characters can see each other's profiles.

### Global Profile Commands

| Command | Description |
|---------|-------------|
| `vendorprofile.list` | List all profiles across all characters |
| `vendorprofile.keep.list` | List profiles that have keep rules |
| `vendorprofile.sell.list` | List all profiles for the current character |
| `vendorprofile.create [name]` | Create (and activate) a new profile |
| `vendorprofile.tempsell 0\|1` | Enable/disable Temp Sell mode (sells everything) |

### Per-Profile Commands

Replace `[name]` with the actual profile name.

| Command | Description |
|---------|-------------|
| `vendorprofile.[name].activate` | Set as the active profile |
| `vendorprofile.[name].deactivate` | Clear the active profile |
| `vendorprofile.[name].delete` | Delete profile (must confirm by typing name again) |
| `vendorprofile.[name].cleanup` | Remove duplicate rules |
| `vendorprofile.[name].autosell.on` | Enable autosell for this profile |
| `vendorprofile.[name].autosell.off` | Disable autosell for this profile |
| `vendorprofile.[name].keep.list` | List keep rules |
| `vendorprofile.[name].keep.add [target] [--fs] [--pts]` | Add keep rule |
| `vendorprofile.[name].keep.rem [target]` | Remove keep rule by value |
| `vendorprofile.[name].keep.rem ID:#####` | Remove keep rule by list ID |
| `vendorprofile.[name].keep.rem --listid [ids]` | Remove keep rules by multiple list IDs |
| `vendorprofile.[name].keep.mod ID:#####` | Edit a keep rule in-place |
| `vendorprofile.[name].sell.list` | List sell rules |
| `vendorprofile.[name].sell.add [target]` | Add sell rule |
| `vendorprofile.[name].sell.rem [target]` | Remove sell rule by value |
| `vendorprofile.[name].sell.rem ID:#####` | Remove sell rule by list ID |
| `vendorprofile.[name].sell.rem --listid [ids]` | Remove sell rules by multiple list IDs |
| `vendorprofile.[name].sell.mod ID:#####` | Edit a sell rule in-place |
| `vendorprofile.[name].search [query]` | Search keep and sell rules |
| `vendorprofile.[name].zone.list` | List registered zones |
| `vendorprofile.[name].zone.register` | Register current zone |
| `vendorprofile.[name].zone.add [zone,...]` | Add zone(s) by name |
| `vendorprofile.[name].zone.delete [zone,...] \| *` | Delete zone(s) or all |
| `vendorprofile.[name].zone.enable` | Enable zone-based auto-activation |
| `vendorprofile.[name].zone.disable` | Disable zone-based auto-activation |

### Filter / Rule Input Formats

| Input | Resolved As | Example |
|-------|-------------|---------|
| Item link or bare number | `id` | `12345` |
| `[Item Name]` | `exact` (case-insensitive) | `[Linen Cloth]` |
| `*partial*` | `match` (substring) | `*Cloth*` |
| Expression with `=`, `>`, `<`, `(` | `filter` | `QUALITY>=4` |

### Filter Fields

| Field | Type | Operators |
|-------|------|-----------|
| `EQUIPLOC` | string | `=` `!=` |
| `ID` | numeric | `=` `!=` `>=` `<=` `>` `<` |
| `ILVL` | numeric | `=` `!=` `>=` `<=` `>` `<` |
| `INTOOLTIP` | string | `=` `!=` |
| `NAME` | string | `=` `!=` |
| `PRICE` | numeric | `=` `!=` `>=` `<=` `>` `<` |
| `QUALITY` | numeric | `=` `!=` `>=` `<=` `>` `<` |
| `REQLEVEL` | numeric | `=` `!=` `>=` `<=` `>` `<` |
| `STACK` | numeric | `=` `!=` `>=` `<=` `>` `<` |
| `SUBTYPE` | string | `=` `!=` |
| `TYPE` | string | `=` `!=` |

Use `NAME=*partial*` for substring matching on string fields.

### Grouping & Negation

```
(ILVL>=10 AND ILVL<50)           group sub-expressions with parentheses
!(QUALITY=0)                     negate a single condition
!(ILVL<10 AND QUALITY=0)         negate a grouped expression
```

Grouping and negation can be nested freely and combined with `AND`, `OR`, `NOT`.

### Filter Validation

Filters that are logically impossible (can never match any item) are rejected with an error message and not saved. Examples:

- `ILVL>=10 AND ILVL<10` — impossible range
- `NAME=Foo AND NAME=Bar` — two different exact values for the same field
- `QUALITY=4 AND QUALITY!=4` — value contradicts its own exclusion

### Tab Autocomplete for Filter Arguments

After a `.keep.add`, `.sell.add`, `.keep.mod.commit`, or `.sell.mod.commit` command and a space:

- **Tab** cycles through filter field names matching what you have typed so far (alphabetical order).
- Once a field name is followed by an operator character (`=`, `>`, `<`, `!`), **Tab** cycles through valid operators for that field. Operators not valid for the field type are skipped automatically.

| Example input | Tab result | Repeated Tab |
|---------------|-----------|--------------|
| `…sell.add ` | `…sell.add EQUIPLOC` | cycles all fields |
| `…sell.add n` | `…sell.add NAME` | (only match) |
| `…sell.add NAME=` | `…sell.add NAME!=` | wraps back to `NAME=` |
| `…sell.add ILVL>` | `…sell.add ILVL>=` | cycles: `<=` → `>` → `<` → `=` → `!=` → `>=` |
| `…sell.add ILVL>=10 AND na` | `…sell.add ILVL>=10 AND NAME` | (only match) |

### Keep-Rule Flags

| Flag | Meaning |
|------|---------|
| `--fs` | Force-sell even if item matches a sell rule |
| `--pts` | Protect from Temp Sell mode |

---

## Path Discovery

Type any prefix ending with `.` and press **Enter** to list everything under that path.

| Input | Lists |
|-------|-------|
| `.` | All settings and profiles |
| `console.` | All console settings and commands |
| `tool.` | All tool settings and commands |
| `tracker.` | Tracker settings and commands |
| `vendorprofile.` | Global profile commands and your profiles |
| `vendorprofile.[name].` | Commands for that specific profile |

**Tab** cycles through completions for the current prefix.
