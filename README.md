# GSTinTin

A [TinTin++](https://tintin.mudhalla.net/) frontend for [GemStone IV](https://www.play.net/gemstone/) via [lich-5](https://github.com/elanthia-online/lich-5), inspired by [ProfanityFE](https://github.com/elanthia-online/ProfanityFE).

GSTinTin brings ProfanityFE-style UI concepts — a 3-column split layout with compass, vitals bars, body injury diagram, room info sidebar, and chat panels — into a pure TinTin++ environment.

## Install

One-liner for macOS and Linux:

```bash
curl -fsSL https://raw.githubusercontent.com/strnglp/GSTinTin/master/install.sh | bash
```

The installer detects your package manager (Homebrew, apt, dnf, or pacman), installs the system libraries lich-5 needs (GTK3, gobject-introspection, sqlite, etc.), installs Ruby if missing, builds or installs `tt++`, clones lich-5 and GSTinTin into XDG paths, installs a Nerd Font of your choice, and writes a personalized `gemstone` launcher onto your `PATH`.

It only asks for `sudo` if system packages are actually missing, and supports flags for unattended installs:

```bash
curl -fsSL https://raw.githubusercontent.com/strnglp/GSTinTin/master/install.sh \
  | bash -s -- --unattended --char Mychar --port 8000 --font JetBrainsMono
```

See `install.sh --help` for the full flag list. To remove things, run `uninstall.sh` from the GSTinTin clone.

## Requirements

- [TinTin++](https://tintin.mudhalla.net/) (tt++) — after building or installing, make sure `tt++` is in your PATH (e.g., copy the executable to `~/.local/bin/` or add its install directory to your PATH)
- [lich-5](https://github.com/elanthia-online/lich-5) with a valid GemStone IV account
- Ruby (for lich)
- A [Nerd Font](https://www.nerdfonts.com/) installed and set as your terminal's font — the UI uses special glyphs for the compass, vitals bars, and body diagram
- A wide terminal — the 3-column layout works best at 120+ columns

## First-Time Setup

Before using GSTinTin, lich-5 needs your Simutronics account credentials. The installer prompts for these at the end; if you skipped it, save them now:

```bash
cd "${XDG_DATA_HOME:-$HOME/.local/share}/lich-5"
ruby lich.rbw --add-account YOUR_USERNAME YOUR_PASSWORD --frontend wizard
```

If you prefer a GUI login window instead:

```bash
ruby lich.rbw
```

In the window, tick **"Save this info for quick game entry"**, enter your credentials, click **Connect**, then **Play**. You can close lich after connecting.

## Quick Start

If you used the installer, just run:

```bash
gemstone YourCharName 8000
```

To do it manually:

1. Start lich-5 in detachable mode:

   ```bash
   cd "${XDG_DATA_HOME:-$HOME/.local/share}/lich-5"
   ruby lich.rbw --login YourCharName --detachable-client=8000 --without-frontend --gemstone &
   ```

2. Launch GSTinTin:

   ```bash
   cd "${XDG_DATA_HOME:-$HOME/.local/share}/GSTinTin"
   tt++ gstin.tin
   ```

The launcher script (`scripts/gemstone.sh`) honors these env vars and arguments:

- **`LICH_DIR`** — path to your lich-5 directory (default: `$XDG_DATA_HOME/lich-5`, i.e. `~/.local/share/lich-5`)
- **`GSTIN_DIR`** — path to this repo (default: `$XDG_DATA_HOME/GSTinTin`)
- **`CHAR`** — character name, passed as the first argument (default: `YourCharName`)
- **`PORT`** — lich detachable client port, passed as the second argument (default: `8000`)

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
