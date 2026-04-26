# GSTinTin

A [TinTin++](https://tintin.mudhalla.net/) frontend for [GemStone IV](https://www.play.net/gemstone/) via [lich-5](https://github.com/elanthia-online/lich-5), inspired by [ProfanityFE](https://github.com/elanthia-online/ProfanityFE).

3-column split layout with vitals bars, body injury diagram, active spell panel, chat panels, and a top bar for room info and familiar. TinTin++ supports complex highlights and themes.

![GSTinTin Light Theme](screenshots/GSTin%20Screenshot%201.png)
![GSTinTin Dark Theme](screenshots/GSTin%20Screenshot%202.png)

## Install

macOS and Linux:

```bash
curl -fsSL https://raw.githubusercontent.com/strnglp/GSTinTin/master/install.sh | bash
```

Installs dependencies (Ruby, TinTin++, GTK3), clones lich-5 and GSTinTin to `~/.local/share/`, installs a Nerd Font, creates `gemstone` launcher, saves credentials. Handles macOS Homebrew keg-only packages and Sonoma+ compiler flags.

Flags: `--unattended`, `--char NAME`, `--port N`, `--font NAME`. See `install.sh --help`.

Uninstall:

```bash
curl -fsSL https://raw.githubusercontent.com/strnglp/GSTinTin/master/uninstall.sh | bash
```

Removes GSTinTin and optionally lich-5. Leaves Ruby, packages, fonts, and credentials.

## Usage

Default (uses character from install):

```bash
gemstone
```

Specify character and port:

```bash
gemstone YourCharName 8000
```

Starts lich-5 in background, waits for port, launches TinTin++. Stops lich on quit.

Add credentials:

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

Character-specific config: copy `config/char/Example.tin` to `config/char/YourCharName.tin` for highlights, macros, and gags. Set character name in `config/settings.tin`:

```
#variable {gstin[config][char_name]} {YourCharName}
```

## Tips

**Lich script arguments:** TinTin++ uses `;` as a command separator. Use `,` instead for lich script arguments (e.g., `;script arg1,arg2`).

**Terminal size:** 120+ columns recommended. Narrow widths make sidebars unusable.

**XML tag matching:** GemStone's XML uses both `id='x'` and `id="x"`. Handle both in custom `#action` or `#regexp` patterns.

---

<details>
<summary><strong>Manual Installation</strong></summary>

### Requirements

- [TinTin++](https://tintin.mudhalla.net/) (tt++) in PATH
- [lich-5](https://github.com/elanthia-online/lich-5) with GemStone IV account
- Ruby ≥3.0
- System libraries: GTK3, gobject-introspection, cairo, pcre2, gnutls, sqlite, fontconfig
- [Nerd Font](https://www.nerdfonts.com/) set as terminal font (for vitals bars and body diagram glyphs)
- Terminal 120+ columns wide

### macOS Homebrew notes

Keg-only packages not in PATH:

- **Ruby**: `$(brew --prefix ruby)/bin/ruby`
- **gobject-introspection**: Add `$(brew --prefix gobject-introspection)/lib/pkgconfig` to `PKG_CONFIG_PATH`
- **libffi**: Add `$(brew --prefix libffi)/lib/pkgconfig` to `PKG_CONFIG_PATH`

macOS Sonoma+ native gem builds:

```bash
export CFLAGS="-Wno-error=implicit-function-declaration"
```

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
