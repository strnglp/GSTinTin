# GSTinTin

A [TinTin++](https://tintin.mudhalla.net/) frontend for [GemStone IV](https://www.play.net/gemstone/) via [lich-5](https://github.com/elanthia-online/lich-5), inspired by [ProfanityFE](https://github.com/elanthia-online/ProfanityFE).

GSTinTin brings ProfanityFE-style UI concepts — a 3-column split layout with compass, vitals bars, body injury diagram, room info sidebar, and chat panels — into a pure TinTin++ environment.

## Quick Install

**One-line guided install for macOS and Linux:**

```bash
curl -fsSL https://raw.githubusercontent.com/strnglp/GSTinTin/master/install.sh | bash
```

The installer handles everything:
- Detects your package manager (Homebrew, apt, dnf, pacman) and installs dependencies
- Installs Ruby if needed (with special handling for macOS Homebrew keg-only packages)
- Builds or installs TinTin++ (`tt++`)
- Clones lich-5 and GSTinTin to `~/.local/share/`
- Installs Ruby gems needed by lich-5 (with macOS-specific build environment fixes)
- Installs a Nerd Font of your choice
- Creates a `gemstone` launcher in `~/.local/bin/`
- Saves your Simutronics credentials

Only prompts for `sudo` when system packages are actually missing.

**Automated install:**

```bash
curl -fsSL https://raw.githubusercontent.com/strnglp/GSTinTin/master/install.sh \
  | bash -s -- --unattended --char Mychar --port 8000 --font JetBrainsMono
```

See `install.sh --help` for all options.

### What the installer fixes automatically

The installer handles several macOS-specific issues:

1. **Homebrew keg-only packages** — Ruby and gobject-introspection are keg-only on macOS, meaning they're installed but not symlinked to PATH. The installer configures `PKG_CONFIG_PATH` so native gem builds can find them.

2. **Implicit function declaration errors** — macOS Sonoma+ (Clang 15+) treats implicit function declarations as hard errors, breaking native extensions like glib2. The installer adds `-Wno-error=implicit-function-declaration` to `CFLAGS`.

3. **Ruby gem installation** — The installer bypasses bundler's vendor/bundle (which can contain stale native gem builds) and installs gems directly to the user gem directory, then configures bundler to use that location.

4. **Interactive prompts during piped install** — When run via `curl | bash`, the installer re-execs itself from a temp file so subprocesses (like Homebrew) don't consume the script stream, preventing interactive prompts from breaking the install.

## Uninstall

```bash
curl -fsSL https://raw.githubusercontent.com/strnglp/GSTinTin/master/uninstall.sh | bash
```

Or run locally from your GSTinTin directory:

```bash
./uninstall.sh          # removes GSTinTin and launcher
./uninstall.sh --yes    # skip confirmation prompts
```

The uninstaller offers to remove lich-5 and leaves Ruby, system packages, fonts, and credentials untouched.

## Usage

After installation, just run:

```bash
gemstone YourCharName 8000
```

The launcher starts lich-5 in the background, waits for it to open the detachable client port, then launches TinTin++ and connects. When you quit TinTin++, the launcher automatically stops lich.

**Launcher environment variables:**

- **`LICH_DIR`** — path to lich-5 (default: `~/.local/share/lich-5`)
- **`GSTIN_DIR`** — path to GSTinTin (default: `~/.local/share/GSTinTin`)

**Arguments:**

- First argument: character name (default: the name you gave during install, or `YourCharName`)
- Second argument: port (default: `8000`)

### Adding credentials after install

If you skipped credential setup during installation, save them now:

```bash
cd ~/.local/share/lich-5
ruby lich.rbw --add-account YOUR_USERNAME YOUR_PASSWORD --frontend wizard
```

Or use the GUI:

```bash
cd ~/.local/share/lich-5
ruby lich.rbw
```

Tick **"Save this info for quick game entry"**, enter credentials, click **Connect**, then **Play**.

## Configuration

### Per-Character Config

Set your character name in `config/settings.tin`:

```
#variable {gstin[config][char_name]} {YourCharName}
```

Then copy `config/char/Example.tin` to `config/char/YourCharName.tin` for character-specific highlights, macros, and gags.

## Usage Tips

### Use `,` instead of `;` for lich script arguments

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
