# Prebbles No-Nonsense Loot Filter

A World of Warcraft addon for **WotLK 3.3.5a** built specifically for the **Project Ebonhold** roguelite private server.

Automates bag management at vendors: keep what you want, sell or delete everything else — driven by flexible per-character vendor profiles with item filter expressions.

---

## Features

- **Vendor profiles** — define keep/sell rules per character using item IDs, exact names, substring patterns, or full filter expressions (`QUALITY>=4`, `ILVL<20 AND TYPE=Armor`, etc.)
- **Auto-sell** — sells matching items automatically when a vendor window opens
- **Gray delete** — deletes gray (no-value) items on bag update
- **Zero-value delete** — optionally removes items with no vendor price
- **Temp Sell mode** — sell everything except explicitly protected items
- **Tooltip hints** — shows KEEP/SELL rule match directly on item tooltips
- **Session & genesis trackers** — tracks gold earned and items processed across your session and lifetime
- **Tracker HUD** — on-screen dashboard showing live stats
- **Bag space indicator** — color-coded free slot counter with configurable thresholds
- **Simple Mailer** — bulk-mail bag contents to another character with an exclusion list
- **Vendor Management** — automated sell cycle triggered by looter NPC proximity and bag pressure
- **Minimap refresh** — configurable minimap polling for roguelite server integration
- **Sort bags** — one command to sort all bags
- **Tab autocomplete** — filter field and operator completion in the console
- **Filter validation** — logically impossible filters (contradictions) are rejected before saving
- **Floating terminal console** — resizable, lockable, themeable in-game terminal; minimizes to tracker

---

## Requirements

- WoW client: **3.3.5a** (Interface 30300)
- Server: **Project Ebonhold** (or compatible WotLK 3.3.5a private server)
- No external dependencies

---

## Installation

1. Copy the `src/` addon folders into your `Interface/AddOns/` directory.
2. Log in and type `/reload` (or restart the client).
3. Open the console with `/nps console.show`.

No build step required.

---

## Quick Start

```
/nps console.show                          open the terminal
vendorprofile.create myprofile             create and activate a profile
myprofile.keep.add [Hearthstone]           keep by exact name
myprofile.keep.add QUALITY>=4             keep all epic+ items
myprofile.sell.add QUALITY=0              sell all gray items
console.autosell 1                         enable auto-sell at vendors
```

---

## Documentation

- [Command Reference](/commands-reference.md) — full list of commands, settings, and filter syntax
- [Usage Guide](/usage-guide.md) — walkthrough, examples, and common workflows

---

## License

This addon is provided **AS IS**, without warranty of any kind.

You are free to use, copy, modify, and redistribute this addon in any form, for any purpose, **provided that credit is given** to the original project and contributors.

**This addon is intended for use on the Project Ebonhold roguelite server only.**

---

## Credits

- **Vendor management logic** — [Veronica-Vasilieva](https://github.com/Veronica-Vasilieva)
- **Primary development** — LLM-assisted, mainly using [claude.ai](https://claude.ai) and Gemini Pro
