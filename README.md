# GSTinTin

A [TinTin++](https://tintin.mudhalla.net/) frontend for [GemStone IV](https://www.play.net/gemstone/) via [lich-5](https://github.com/elanthia-online/lich-5), inspired by [ProfanityFE](https://github.com/elanthia-online/ProfanityFE).

GSTinTin brings ProfanityFE-style UI concepts — a 3-column split layout with compass, vitals bars, body injury diagram, room info sidebar, and chat panels — into a pure TinTin++ environment.

## Install

**One-line guided install for macOS and Linux:**

```bash
curl -fsSL https://raw.githubusercontent.com/strnglp/GSTinTin/master/install.sh | bash
```

The installer detects your system, installs dependencies (Ruby, TinTin++, GTK3, etc.), clones lich-5 and GSTinTin to `~/.local/share/`, installs a Nerd Font, creates a `gemstone` launcher, and saves your credentials. Only prompts for `sudo` when needed.

Handles macOS gotchas automatically: Homebrew keg-only packages (Ruby, gobject-introspection), implicit function declaration errors (Sonoma+), gem installation workarounds, and piped-install prompt handling.

**Flags:** `--unattended`, `--char NAME`, `--port N`, `--font NAME`. See `install.sh --help`.

**Uninstall:**

```bash
curl -fsSL https://raw.githubusercontent.com/strnglp/GSTinTin/master/uninstall.sh | bash
```

Offers to remove lich-5; leaves Ruby, packages, fonts, and credentials intact.

## Usage

Run with defaults (uses character name from install):

```bash
gemstone
```

Or specify character and port:

```bash
gemstone YourCharName 8000
```

The launcher starts lich-5 in the background, waits for the port, then launches TinTin++. When you quit, lich stops automatically.

**Add credentials after install:**

```bash
cd ~/.local/share/lich-5
ruby lich.rbw --add-account USERNAME PASSWORD --frontend wizard
```

## Hotkeys

### Window Controls

- **Ctrl+L** — Toggle familiar window on/off
- **Ctrl+S** — Toggle spells sidebar on/off

### Scrolling

**Main story window:**
- **Mouse wheel** — Scroll by 2 lines
- **PageUp/PageDown** or **Ctrl+V/Alt+V** (Emacs-style) — Page up/down
- **Home/End** or **Alt+</Alt+>** (Emacs-style) — Jump to top/bottom

**Chat sidebar:**
- **Ctrl+PageUp/PageDown** — Scroll by half-page
- **Ctrl+Up/Down** — Scroll by line
- **Ctrl+Home/End** — Jump to top/bottom

**Familiar window:**
- **Shift+PageUp/PageDown** — Scroll by half-page
- **Shift+Up/Down** — Scroll by line
- **Shift+Home/End** — Jump to top/bottom

### Navigation

Numpad (with NumLock on) sends directional commands:
- **7/8/9** — nw/n/ne
- **4/5/6** — w/out/e  
- **1/2/3** — sw/s/se
- **+** — look
- **-** — up
- **\*** — down

## Configuration

Copy `config/char/Example.tin` to `config/char/YourCharName.tin` for character-specific highlights, macros, and gags. Set your character name in `config/settings.tin`:

```
#variable {gstin[config][char_name]} {YourCharName}
```

## Tips

### Lich script arguments

TinTin++ uses `;` as a command separator for multi-command input. If you type a lich command that uses semicolons (e.g., `;script arg1;arg2`), TinTin++ will split it into separate commands. Use `,` as the delimiter instead — lich accepts commas in place of semicolons for script arguments.

### Terminal size matters

The 3-column layout divides your terminal into quadrants. At narrow widths the sidebars become unusable. 120+ columns is recommended; resize your terminal before connecting.

### XML tag matching

GemStone's XML uses both single and double quotes (`id='x'` and `id="x"`). If you add custom `#action` or `#regexp` patterns, make sure to handle both variants.

---

<details>
<summary><strong>Manual Installation (advanced users)</strong></summary>

If you prefer to install components manually or need finer control over paths and versions:

### Requirements

- [TinTin++](https://tintin.mudhalla.net/) (tt++) — make sure `tt++` is in your PATH
- [lich-5](https://github.com/elanthia-online/lich-5) with a valid GemStone IV account
- Ruby ≥3.0 (for lich)
- System libraries: GTK3, gobject-introspection, cairo, pcre2, gnutls, sqlite, fontconfig
- A [Nerd Font](https://www.nerdfonts.com/) installed and set as your terminal's font — the UI uses special glyphs for the compass, vitals bars, and body diagram
- A wide terminal — the 3-column layout works best at 120+ columns

### macOS Homebrew notes

On macOS, several packages are keg-only (installed but not symlinked to PATH):

- **Ruby**: Find it at `$(brew --prefix ruby)/bin/ruby`
- **gobject-introspection**: Add `$(brew --prefix gobject-introspection)/lib/pkgconfig` to `PKG_CONFIG_PATH` before building native gems
- **libffi**: Add `$(brew --prefix libffi)/lib/pkgconfig` to `PKG_CONFIG_PATH`

When building native Ruby gems on macOS Sonoma+, set:

```bash
export CFLAGS="-Wno-error=implicit-function-declaration"
```

This downgrades implicit function declaration from a hard error to a warning, which prevents glib2 and other gems from failing to build.

### Manual steps

1. Clone the repositories:

   ```bash
   git clone https://github.com/elanthia-online/lich-5.git ~/.local/share/lich-5
   git clone https://github.com/strnglp/GSTinTin.git ~/.local/share/GSTinTin
   ```

2. Install lich-5 Ruby gem dependencies:

   ```bash
   cd ~/.local/share/lich-5
   gem install --user-install terminal-table gtk3 sqlite3 sequel json nokogiri concurrent-ruby
   ```

   On macOS, set `PKG_CONFIG_PATH` before running the above:

   ```bash
   export PKG_CONFIG_PATH="$(brew --prefix)/lib/pkgconfig:$(brew --prefix gobject-introspection)/lib/pkgconfig:$(brew --prefix libffi)/lib/pkgconfig:$PKG_CONFIG_PATH"
   export CFLAGS="-Wno-error=implicit-function-declaration"
   ```

3. Save your Simutronics credentials:

   ```bash
   cd ~/.local/share/lich-5
   ruby lich.rbw --add-account YOUR_USERNAME YOUR_PASSWORD --frontend wizard
   ```

4. Start lich-5 in detachable mode:

   ```bash
   cd ~/.local/share/lich-5
   ruby lich.rbw --login YourCharName --detachable-client=8000 --without-frontend --gemstone &
   ```

5. Launch GSTinTin:

   ```bash
   cd ~/.local/share/GSTinTin
   tt++ gstin.tin
   ```

</details>

---

*Built with AI assistance ([Claude](https://claude.ai))*
