# GSTinTin

A [TinTin++](https://tintin.mudhalla.net/) frontend for [GemStone IV](https://www.play.net/gemstone/) via [lich-5](https://github.com/elanthia-online/lich-5), inspired by [ProfanityFE](https://github.com/elanthia-online/ProfanityFE).

GSTinTin brings ProfanityFE-style UI concepts — a 3-column split layout with compass, vitals bars, body injury diagram, room info sidebar, and chat panels — into a pure TinTin++ environment.

## Requirements

- [TinTin++](https://tintin.mudhalla.net/) (tt++) — after building or installing, make sure `tt++` is in your PATH (e.g., copy the executable to `~/.local/bin/` or add its install directory to your PATH)
- [lich-5](https://github.com/elanthia-online/lich-5) with a valid GemStone IV account
- Ruby (for lich)
- A [Nerd Font](https://www.nerdfonts.com/) installed and set as your terminal's font — the UI uses special glyphs for the compass, vitals bars, and body diagram
- A wide terminal — the 3-column layout works best at 120+ columns

## First-Time Setup

Before using GSTinTin, you need to log into lich-5 at least once to save your account credentials and populate the local character database:

```bash
cd /path/to/lich-5
ruby lich.rbw
```

In the login window, tick **"Save this info for quick game entry"**, enter your Simutronics account credentials, click **Connect**, and then click **Play**. This saves your credentials and populates the local character database. You can close lich after connecting — going forward you only need the detachable mode below.

### Post-Launch Setup

After your first connection, install the `effectmon` lich script. In the game input, type:

```
,repo download effectmon
```

Then start it with `,effectmon`. GSTinTin uses its output for spell effect tracking and vitals bars. To have it run automatically on each login, add it to your lich autostart with `,autostart add effectmon`.

**Note:** Use `,` instead of `;` as the argument delimiter when running lich scripts from TinTin++ — see [Gotchas](#use--instead-of--for-lich-script-arguments).

## Quick Start

1. Start lich-5 in detachable mode:

   ```bash
   cd /path/to/lich-5
   ruby lich.rbw --login YourCharName --detachable-client=8000 --without-frontend --gemstone &
   ```

2. Launch GSTinTin:

   ```bash
   cd /path/to/GSTinTin
   tt++ gstin.tin
   ```

Or use the provided launch script that handles both steps. Edit `scripts/gemstone.sh` to match your installation:

- **`LICH_DIR`** — path to your lich-5 directory (default: `$HOME/Projects/lich-5`)
- **`GSTIN_DIR`** — path to this repo (default: `$HOME/Projects/GSTinTin`)
- **`CHAR`** — your character name, passed as the first argument (default: `YourCharName`)
- **`PORT`** — lich detachable client port, passed as the second argument (default: `8000`)

Then install it to your PATH for easy access:

```bash
cp scripts/gemstone.sh ~/.local/bin/gemstone
chmod +x ~/.local/bin/gemstone
gemstone YourCharName 8000
```

## Setup

### Per-Character Config

Set your character name in `config/settings.tin`:

```
#variable {gstin[config][char_name]} {YourCharName}
```

Then copy `config/char/Example.tin` to `config/char/YourCharName.tin` for character-specific highlights, macros, and gags.

## Gotchas

### Use `,` instead of `;` for lich script arguments

TinTin++ uses `;` as a command separator for multi-command input. If you type a lich command that uses semicolons (e.g., `;script arg1;arg2`), TinTin++ will split it into separate commands. Use `,` as the delimiter instead — lich accepts commas in place of semicolons for script arguments.

### Terminal size matters

The 3-column layout divides your terminal into quadrants. At narrow widths the sidebars become unusable. 120+ columns is recommended; resize your terminal before connecting.

### XML tag matching

GemStone's XML uses both single and double quotes (`id='x'` and `id="x"`). If you add custom `#action` or `#regexp` patterns, make sure to handle both variants.

---

*Built with AI assistance ([Claude](https://claude.ai))*
