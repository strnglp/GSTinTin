#!/usr/bin/env bash
# GSTinTin installer — macOS and Linux
#
# Usage:
#   curl -fsSL https://raw.githubusercontent.com/strnglp/GSTinTin/master/install.sh | bash
#
# Flags (pass after `bash -s --` when piping, or directly when running locally):
#   --unattended              Take all defaults, never prompt
#   --lich-dir DIR            Install lich-5 here (default: $XDG_DATA_HOME/lich-5)
#   --gstin-dir DIR           Install GSTinTin here (default: $XDG_DATA_HOME/GSTinTin)
#   --char NAME               Character name baked into the launcher
#   --port N                  Lich detachable-client port (default: 8000)
#   --font NAME               Nerd Font to install (e.g. JetBrainsMono)
#   --no-font                 Skip Nerd Font install
#   --skip-ruby               Don't install or manage Ruby; assume one is present
#   --ruby-version X.Y.Z      Force a specific Ruby version via rbenv
#   --branch NAME             Clone GSTinTin from this branch (default: master)
#   -h, --help                Show this help

set -euo pipefail

# When invoked via `curl | bash`, stdin IS the script. Any subprocess that
# inherits stdin (e.g. `brew install`) can consume the unread tail of the
# script before bash gets to it, causing the rest of the install to vanish.
# Fix: drain ourselves into a temp file and re-exec from there immediately,
# so all subsequent subprocesses get the real TTY instead of our pipe.
if [[ ! -t 0 ]]; then
    _self=$(mktemp "${TMPDIR:-/tmp}/gstintin-install.XXXXXX")
    cat > "$_self"
    export _GSTINTIN_TMPSCRIPT="$_self"
    exec bash "$_self" "$@"
fi
# Clean up the temp file we were re-exec'd from
[[ -n "${_GSTINTIN_TMPSCRIPT:-}" ]] && trap 'rm -f "$_GSTINTIN_TMPSCRIPT"' EXIT

# ---------- constants ----------
GSTINTIN_REPO_URL="https://github.com/strnglp/GSTinTin.git"
LICH_REPO_URL="https://github.com/elanthia-online/lich-5.git"
TINTIN_REPO_URL="https://github.com/scandum/tintin.git"
DEFAULT_PORT=8000
DEFAULT_FONT="JetBrainsMono"
DEFAULT_BRANCH="master"
MIN_RUBY_MAJOR=3
MIN_RUBY_MINOR=0

DATA_HOME="${XDG_DATA_HOME:-$HOME/.local/share}"
BIN_DIR="${XDG_BIN_HOME:-$HOME/.local/bin}"

LICH_DIR_DEFAULT="$DATA_HOME/lich-5"
GSTIN_DIR_DEFAULT="$DATA_HOME/GSTinTin"

# Curated Nerd Font shortlist (name => Nerd Fonts release archive)
FONT_CHOICES=(JetBrainsMono FiraCode Meslo Hack IosevkaTerm)

# ---------- flag parsing ----------
LICH_DIR="$LICH_DIR_DEFAULT"
GSTIN_DIR="$GSTIN_DIR_DEFAULT"
CHAR_NAME=""
PORT="$DEFAULT_PORT"
FONT=""
INSTALL_FONT=1
INSTALL_RUBY=1
RUBY_VERSION=""
UNATTENDED=0
GSTINTIN_BRANCH="$DEFAULT_BRANCH"

usage() {
    # Print the leading comment block (everything from line 2 up to the first non-comment line)
    awk 'NR==1 {next} /^#/ {sub(/^# ?/, ""); print; next} {exit}' "$0"
}

while [[ $# -gt 0 ]]; do
    case "$1" in
        --unattended) UNATTENDED=1; shift;;
        --lich-dir) LICH_DIR="$2"; shift 2;;
        --gstin-dir) GSTIN_DIR="$2"; shift 2;;
        --char) CHAR_NAME="$2"; shift 2;;
        --port) PORT="$2"; shift 2;;
        --font) FONT="$2"; INSTALL_FONT=1; shift 2;;
        --no-font) INSTALL_FONT=0; shift;;
        --skip-ruby) INSTALL_RUBY=0; shift;;
        --ruby-version) RUBY_VERSION="$2"; shift 2;;
        --branch) GSTINTIN_BRANCH="$2"; shift 2;;
        -h|--help) usage; exit 0;;
        *) echo "Unknown option: $1" >&2; usage >&2; exit 2;;
    esac
done

# ---------- output helpers ----------
if [[ -t 1 ]]; then
    BOLD=$'\033[1m'; DIM=$'\033[2m'; RED=$'\033[31m'
    GREEN=$'\033[32m'; YELLOW=$'\033[33m'; BLUE=$'\033[34m'
    CYAN=$'\033[36m'; RESET=$'\033[0m'
else
    BOLD=""; DIM=""; RED=""; GREEN=""; YELLOW=""; BLUE=""; CYAN=""; RESET=""
fi

say()  { printf '%s\n' "$*"; }
info() { printf '%s==>%s %s\n' "$BLUE" "$RESET" "$*"; }
ok()   { printf '%s ✓%s %s\n' "$GREEN" "$RESET" "$*"; }
warn() { printf '%s !%s %s\n' "$YELLOW" "$RESET" "$*" >&2; }
err()  { printf '%s ✗%s %s\n' "$RED" "$RESET" "$*" >&2; }
hr()   { printf '%s%s%s\n' "$DIM" "------------------------------------------------------------" "$RESET"; }

# Read from /dev/tty when stdin is a pipe (curl | bash). Falls back to default.
TTY_AVAILABLE=0
if [[ -t 0 ]]; then
    TTY_AVAILABLE=1
elif [[ -r /dev/tty ]]; then
    TTY_AVAILABLE=1
fi

prompt() {
    local question="$1" default="${2:-}" answer="" suffix=""
    [[ -n "$default" ]] && suffix=" [${default}]"
    if (( UNATTENDED )) || (( ! TTY_AVAILABLE )); then
        printf '%s%s: %s (using default)\n' "$question" "$suffix" "$default" >&2
        printf '%s' "$default"
        return
    fi
    if [[ -t 0 ]]; then
        read -r -p "$question$suffix: " answer || true
    else
        read -r -p "$question$suffix: " answer < /dev/tty || true
    fi
    printf '%s' "${answer:-$default}"
}

confirm() {
    local question="$1" default="${2:-Y}" answer
    answer="$(prompt "$question (y/n)" "$default")"
    case "$answer" in
        Y|y|yes|YES|Yes) return 0;;
        *) return 1;;
    esac
}

# ---------- detection ----------
OS=""; PM=""; SUDO=""
detect_os() {
    case "$(uname -s)" in
        Darwin) OS="macos";;
        Linux)  OS="linux";;
        *) err "Unsupported OS: $(uname -s)"; exit 1;;
    esac
}

detect_pm() {
    if [[ "$OS" == "macos" ]]; then
        if command -v brew >/dev/null 2>&1; then
            PM="brew"
        else
            err "Homebrew is required on macOS. Install from https://brew.sh and re-run."
            exit 1
        fi
    else
        if   command -v apt-get >/dev/null 2>&1; then PM="apt"
        elif command -v dnf     >/dev/null 2>&1; then PM="dnf"
        elif command -v pacman  >/dev/null 2>&1; then PM="pacman"
        elif command -v brew    >/dev/null 2>&1; then PM="brew"
        else
            err "No supported package manager found (apt, dnf, pacman, or brew)."
            err "Install dependencies manually and re-run with --skip-ruby."
            exit 1
        fi
    fi
}

detect_sudo() {
    if [[ "$PM" == "brew" ]] || [[ "$EUID" -eq 0 ]]; then
        SUDO=""
        return
    fi
    if command -v sudo >/dev/null 2>&1; then
        SUDO="sudo"
    else
        SUDO=""
    fi
}

# ---------- system package list ----------
# Map our generic deps -> per-PM package names. We only install packages that
# are missing, and we skip the system-package phase entirely if nothing is
# needed (so the user is never asked for sudo unnecessarily).
sys_pkg_list() {
    case "$PM" in
        brew)
            echo "git pkg-config gtk+3 gobject-introspection cairo pcre2 gnutls fontconfig"
            ;;
        apt)
            echo "git build-essential pkg-config libgtk-3-dev libgirepository1.0-dev libcairo2-dev libpcre2-dev libgnutls28-dev libssl-dev libsqlite3-dev fontconfig"
            ;;
        dnf)
            echo "git gcc gcc-c++ make pkgconf-pkg-config gtk3-devel gobject-introspection-devel cairo-devel pcre2-devel gnutls-devel openssl-devel sqlite-devel fontconfig"
            ;;
        pacman)
            echo "git base-devel pkgconf gtk3 gobject-introspection cairo pcre2 gnutls openssl sqlite fontconfig"
            ;;
    esac
}

# Ruby system package(s) — added separately so --skip-ruby can omit them.
sys_ruby_pkg() {
    case "$PM" in
        brew)   echo "ruby";;
        apt)    echo "ruby ruby-dev";;
        dnf)    echo "ruby ruby-devel";;
        pacman) echo "ruby";;
    esac
}

pkg_installed() {
    local pkg="$1"
    case "$PM" in
        brew)   brew list --formula --versions "$pkg" >/dev/null 2>&1;;
        apt)    dpkg -s "$pkg" >/dev/null 2>&1;;
        dnf)    rpm -q "$pkg" >/dev/null 2>&1;;
        pacman) pacman -Qi "$pkg" >/dev/null 2>&1;;
    esac
}

filter_missing() {
    local missing=()
    for pkg in "$@"; do
        pkg_installed "$pkg" || missing+=("$pkg")
    done
    printf '%s\n' "${missing[@]:-}"
}

install_pkgs() {
    local pkgs=("$@")
    [[ ${#pkgs[@]} -eq 0 ]] && return 0
    case "$PM" in
        brew)   brew install "${pkgs[@]}";;
        apt)    $SUDO apt-get update && $SUDO apt-get install -y "${pkgs[@]}";;
        dnf)    $SUDO dnf install -y "${pkgs[@]}";;
        pacman) $SUDO pacman -S --needed --noconfirm "${pkgs[@]}";;
    esac
}

# ---------- Ruby ----------
# On macOS, brew's Ruby is keg-only — installed under $(brew --prefix ruby)/bin
# but not symlinked onto the default PATH. Make it visible if present.
brew_ruby_bin() {
    [[ "$PM" == "brew" ]] || return 1
    command -v brew >/dev/null 2>&1 || return 1
    local prefix
    prefix="$(brew --prefix ruby 2>/dev/null || true)"
    [[ -n "$prefix" && -x "$prefix/bin/ruby" ]] || return 1
    printf '%s' "$prefix/bin"
}

ensure_brew_ruby_on_path() {
    local bin
    bin="$(brew_ruby_bin)" || return 0
    case ":$PATH:" in
        *":$bin:"*) ;;
        *) export PATH="$bin:$PATH";;
    esac
}

ruby_ok() {
    ensure_brew_ruby_on_path
    command -v ruby >/dev/null 2>&1 || return 1
    local v major minor
    v="$(ruby -e 'print RUBY_VERSION' 2>/dev/null)" || return 1
    major="${v%%.*}"; minor="${v#*.}"; minor="${minor%%.*}"
    if (( major > MIN_RUBY_MAJOR )); then return 0; fi
    if (( major == MIN_RUBY_MAJOR )) && (( minor >= MIN_RUBY_MINOR )); then return 0; fi
    return 1
}

# Persist the brew Ruby + user-gem bin onto PATH in the user's shell rc, so
# future shells can find ruby/gem/bundle without us being involved.
persist_brew_ruby_path() {
    local bin
    bin="$(brew_ruby_bin)" || return 0
    add_shell_line "export PATH=\"$bin:\$PATH\""

    local user_gem_bin
    user_gem_bin="$(ruby -e 'print Gem.user_dir' 2>/dev/null || true)"
    if [[ -n "$user_gem_bin" ]]; then
        user_gem_bin="$user_gem_bin/bin"
        case ":$PATH:" in
            *":$user_gem_bin:"*) ;;
            *) export PATH="$user_gem_bin:$PATH";;
        esac
        add_shell_line "export PATH=\"$user_gem_bin:\$PATH\""
    fi
}

ensure_ruby() {
    (( INSTALL_RUBY )) || { ok "Skipping Ruby (per --skip-ruby)"; return 0; }

    if [[ -n "$RUBY_VERSION" ]]; then
        info "Installing Ruby $RUBY_VERSION via rbenv (forced by --ruby-version)"
        install_rbenv_ruby "$RUBY_VERSION"
        return
    fi

    if ruby_ok; then
        ok "Found Ruby $(ruby -e 'print RUBY_VERSION') at $(command -v ruby)"
        [[ "$PM" == "brew" ]] && persist_brew_ruby_path
        return
    fi

    info "Ruby ≥${MIN_RUBY_MAJOR}.${MIN_RUBY_MINOR} not found — installing system package"
    local pkgs missing
    pkgs="$(sys_ruby_pkg)"
    # shellcheck disable=SC2086
    missing="$(filter_missing $pkgs | grep -v '^$' || true)"
    if [[ -n "$missing" ]]; then
        # shellcheck disable=SC2086
        install_pkgs $missing
    fi

    if ruby_ok; then
        ok "Ruby $(ruby -e 'print RUBY_VERSION') is good"
        [[ "$PM" == "brew" ]] && persist_brew_ruby_path
        return
    fi

    warn "System Ruby is missing or too old; falling back to rbenv"
    install_rbenv_ruby "${RUBY_VERSION:-3.3.6}"
}

install_rbenv_ruby() {
    local version="$1"
    local rbenv_root="$HOME/.rbenv"
    if [[ ! -d "$rbenv_root" ]]; then
        info "Cloning rbenv into $rbenv_root"
        git clone --depth=1 https://github.com/rbenv/rbenv.git "$rbenv_root"
        git clone --depth=1 https://github.com/rbenv/ruby-build.git "$rbenv_root/plugins/ruby-build"
    fi
    export PATH="$rbenv_root/bin:$rbenv_root/shims:$PATH"
    eval "$("$rbenv_root"/bin/rbenv init - bash)"
    info "Installing Ruby $version via rbenv (this can take several minutes)"
    rbenv install -s "$version"
    rbenv global "$version"
    # Single-quoted on purpose: these strings should be evaluated by the user's shell, not us.
    # shellcheck disable=SC2016
    add_shell_line 'export PATH="$HOME/.rbenv/bin:$PATH"'
    # shellcheck disable=SC2016
    add_shell_line 'eval "$(rbenv init - bash)"'
    ok "Ruby $(ruby -e 'print RUBY_VERSION') installed via rbenv"
}

# ---------- shell rc helper ----------
shell_rc() {
    case "${SHELL##*/}" in
        zsh)  echo "$HOME/.zshrc";;
        bash) [[ "$OS" == "macos" ]] && echo "$HOME/.bash_profile" || echo "$HOME/.bashrc";;
        fish) echo "$HOME/.config/fish/config.fish";;
        *)    echo "$HOME/.profile";;
    esac
}

add_shell_line() {
    local line="$1" rc; rc="$(shell_rc)"
    [[ -f "$rc" ]] || { mkdir -p "$(dirname "$rc")"; : > "$rc"; }
    if ! grep -Fqs "$line" "$rc"; then
        printf '\n# added by GSTinTin installer\n%s\n' "$line" >> "$rc"
        ok "Updated $rc"
    fi
}

ensure_path() {
    case ":$PATH:" in
        *":$BIN_DIR:"*) ;;
        *) add_shell_line "export PATH=\"$BIN_DIR:\$PATH\""; export PATH="$BIN_DIR:$PATH";;
    esac
}

# ---------- TinTin++ ----------
ensure_tintin() {
    if command -v tt++ >/dev/null 2>&1; then
        ok "Found tt++ at $(command -v tt++)"
        return
    fi
    case "$PM" in
        brew)   info "Installing tt++ via Homebrew"; brew install tintin;;
        apt)    info "Installing tt++ via apt"; install_pkgs tintin++;;
        pacman) info "Installing tt++ via pacman"; install_pkgs tintin++;;
        dnf)    info "tt++ has no official Fedora package; building from source"; build_tintin;;
    esac
    if ! command -v tt++ >/dev/null 2>&1; then
        warn "Package install did not place tt++ on PATH; building from source"
        build_tintin
    fi
    ok "tt++ ready at $(command -v tt++ || echo "$BIN_DIR/tt++")"
}

build_tintin() {
    local src="$DATA_HOME/tintin-src"
    mkdir -p "$src"
    if [[ ! -d "$src/.git" ]]; then
        git clone --depth=1 "$TINTIN_REPO_URL" "$src"
    else
        ( cd "$src" && git pull --ff-only )
    fi
    ( cd "$src/src" && ./configure && make )
    mkdir -p "$BIN_DIR"
    install -m 0755 "$src/src/tt++" "$BIN_DIR/tt++"
    ensure_path
}

# ---------- lich-5 ----------
ensure_lich() {
    if [[ -d "$LICH_DIR/.git" ]]; then
        info "Updating existing lich-5 at $LICH_DIR"
        ( cd "$LICH_DIR" && git pull --ff-only ) || warn "git pull failed; leaving lich-5 as-is"
    else
        info "Cloning lich-5 into $LICH_DIR"
        mkdir -p "$(dirname "$LICH_DIR")"
        git clone --depth=1 "$LICH_REPO_URL" "$LICH_DIR"
    fi

    install_lich_gems
}

# Set PKG_CONFIG_PATH so native gem builds (glib2, gobject-introspection,
# gtk3) can find Homebrew-installed libraries.
#
# Non-keg-only packages (glib, gtk+3, cairo…) live under the general brew
# prefix — add that first. Keg-only packages (gobject-introspection, libffi,
# ruby) are only in their own opt/<name> prefix — add those individually.
setup_brew_build_env() {
    [[ "$PM" == "brew" ]] || return 0
    command -v brew >/dev/null 2>&1 || return 0

    local brew_prefix f p
    brew_prefix="$(brew --prefix 2>/dev/null || true)"

    # General Homebrew pkgconfig (non-keg-only packages like glib, cairo, gtk+3)
    for p in \
        "$brew_prefix/lib/pkgconfig" \
        "$brew_prefix/share/pkgconfig"; do
        [[ -d "$p" ]] || continue
        case ":${PKG_CONFIG_PATH:-}:" in
            *":$p:"*) ;;
            *) export PKG_CONFIG_PATH="$p:${PKG_CONFIG_PATH:-}";;
        esac
    done

    # Keg-only formulae need their own opt prefix
    for f in gobject-introspection libffi ruby; do
        p="$(brew --prefix "$f" 2>/dev/null || true)"
        [[ -n "$p" && -d "$p/lib/pkgconfig" ]] || continue
        case ":${PKG_CONFIG_PATH:-}:" in
            *":$p/lib/pkgconfig:"*) ;;
            *) export PKG_CONFIG_PATH="$p/lib/pkgconfig:${PKG_CONFIG_PATH:-}";;
        esac
    done

    # Clang 15+ (macOS Sonoma+) treats implicit function declarations as hard
    # errors, which breaks native extensions like glib2. Downgrade to a warning.
    export CFLAGS="${CFLAGS:+$CFLAGS }-Wno-error=implicit-function-declaration"
}

install_lich_gems() {
    info "Installing lich-5 Ruby gem dependencies"
    setup_brew_build_env
    ensure_brew_ruby_on_path

    # lich runs as plain `ruby lich.rbw` and loads gems from Ruby's normal load
    # path — not from vendor/bundle. Installing directly (bypassing the Gemfile
    # version pins) ensures we get the latest versions compatible with the
    # current system glib.
    local gems=(terminal-table gtk3 sqlite3 sequel json nokogiri concurrent-ruby)
    for g in "${gems[@]}"; do
        if ! gem list -i "$g" >/dev/null 2>&1; then
            info "  gem install $g"
            gem install --user-install "$g" || gem install "$g" || warn "Failed to install gem: $g"
        fi
    done

    # Point bundler at the user gem dir so lich's `require 'bundler/setup'`
    # finds our working installs instead of the vendor/bundle stubs left by
    # the failed native gem build.
    local user_gem_dir
    user_gem_dir="$(ruby -e 'print Gem.user_dir' 2>/dev/null || true)"
    if [[ -n "$user_gem_dir" ]]; then
        mkdir -p "$LICH_DIR/.bundle"
        ( cd "$LICH_DIR" && bundle config set --local path "$user_gem_dir" )
        ok "Configured bundler to use user gem dir: $user_gem_dir"
    fi
}

# ---------- GSTinTin ----------
ensure_gstintin() {
    if [[ -d "$GSTIN_DIR/.git" ]]; then
        info "Updating existing GSTinTin at $GSTIN_DIR"
        ( cd "$GSTIN_DIR" && git pull --ff-only ) || warn "git pull failed; leaving GSTinTin as-is"
    else
        info "Cloning GSTinTin into $GSTIN_DIR"
        mkdir -p "$(dirname "$GSTIN_DIR")"
        git clone --depth=1 --branch "$GSTINTIN_BRANCH" "$GSTINTIN_REPO_URL" "$GSTIN_DIR"
    fi
}

# ---------- launcher ----------
write_launcher() {
    mkdir -p "$BIN_DIR"
    local target="$BIN_DIR/gemstone"

    # Resolve the ruby binary to use — prefer the one already on PATH (which
    # at this point in the install has been set to brew/rbenv ruby), then fall
    # back to the brew keg path so the launcher works even before the user
    # opens a new shell and sources their updated rc file.
    local ruby_bin
    ruby_bin="$(command -v ruby 2>/dev/null || echo ruby)"

    cat > "$target" <<EOF
#!/usr/bin/env bash
# gemstone — launch lich-5 + tt++ GSTinTin frontend
# Generated by GSTinTin installer

LICH_DIR="\${LICH_DIR:-$LICH_DIR}"
GSTIN_DIR="\${GSTIN_DIR:-$GSTIN_DIR}"
CHAR="\${1:-${CHAR_NAME:-YourCharName}}"
PORT="\${2:-$PORT}"
RUBY="${ruby_bin}"

cd "\$LICH_DIR"
"\$RUBY" lich.rbw --gtk --login "\$CHAR" --detachable-client="\$PORT" --without-frontend --gemstone &
LICH_PID=\$!

for _ in \$(seq 1 30); do
    if command -v ss >/dev/null 2>&1; then
        ss -tln | grep -q ":\$PORT " && break
    elif command -v lsof >/dev/null 2>&1; then
        lsof -iTCP:"\$PORT" -sTCP:LISTEN >/dev/null 2>&1 && break
    fi
    if ! kill -0 "\$LICH_PID" 2>/dev/null; then
        echo "lich-5 exited before opening port \$PORT."
        echo "Run manually to debug:"
        echo "  cd \"\$LICH_DIR\" && \"\$RUBY\" lich.rbw --gtk --login \"\$CHAR\" --detachable-client=\$PORT --without-frontend --gemstone"
        exit 1
    fi
    sleep 1
done

if command -v ss >/dev/null 2>&1; then
    if ! ss -tln | grep -q ":\$PORT "; then
        echo "Lich failed to start on port \$PORT."
        kill "\$LICH_PID" 2>/dev/null
        exit 1
    fi
elif command -v lsof >/dev/null 2>&1; then
    if ! lsof -iTCP:"\$PORT" -sTCP:LISTEN >/dev/null 2>&1; then
        echo "Lich failed to start on port \$PORT."
        kill "\$LICH_PID" 2>/dev/null
        exit 1
    fi
elif ! kill -0 "\$LICH_PID" 2>/dev/null; then
    echo "Lich failed to start."
    exit 1
fi

cd "\$GSTIN_DIR"
tt++ gstin.tin

kill "\$LICH_PID" 2>/dev/null || true
EOF
    chmod +x "$target"
    ensure_path
    ok "Wrote launcher: $target"
}

# ---------- Nerd Fonts ----------
pick_font() {
    if [[ -n "$FONT" ]]; then return; fi
    if (( UNATTENDED )) || (( ! TTY_AVAILABLE )); then
        FONT="$DEFAULT_FONT"
        return
    fi
    say "${BOLD}Choose a Nerd Font:${RESET}"
    local i=1
    for f in "${FONT_CHOICES[@]}"; do
        local marker=" "; [[ "$f" == "$DEFAULT_FONT" ]] && marker="*"
        printf "  [%d]%s %s\n" "$i" "$marker" "$f"
        ((i++))
    done
    printf "  [%d]  Skip font install (not recommended unless you already have a Nerd Font)\n" "$i"
    local choice
    choice="$(prompt "Selection (1-$i)" "1")"
    if [[ "$choice" == "$i" ]]; then
        INSTALL_FONT=0
        return
    fi
    if [[ "$choice" =~ ^[0-9]+$ ]] && (( choice >= 1 && choice < i )); then
        FONT="${FONT_CHOICES[$((choice-1))]}"
    else
        FONT="$DEFAULT_FONT"
    fi
}

ensure_font() {
    (( INSTALL_FONT )) || { ok "Skipping font install"; return 0; }
    pick_font
    (( INSTALL_FONT )) || { ok "Skipping font install"; return 0; }

    if [[ "$OS" == "macos" ]] && [[ "$PM" == "brew" ]]; then
        # Brew cask names don't map algorithmically from font names, so use an
        # explicit lookup. The fallback does a naive lowercase conversion which
        # may or may not match, but warns gracefully on failure.
        local cask
        case "$FONT" in
            JetBrainsMono) cask="font-jetbrains-mono-nerd-font";;
            FiraCode)       cask="font-fira-code-nerd-font";;
            Meslo)          cask="font-meslo-lg-nerd-font";;
            Hack)           cask="font-hack-nerd-font";;
            IosevkaTerm)    cask="font-iosevka-term-nerd-font";;
            *)              cask="font-$(printf '%s' "$FONT" | tr '[:upper:]' '[:lower:]')-nerd-font";;
        esac
        info "Installing Nerd Font: $cask"
        brew install --cask "$cask" || warn "Could not install $cask via brew"
        return
    fi

    # Linux — fetch from the nerd-fonts release archive
    local font_dir="$DATA_HOME/fonts/${FONT}NerdFont"
    if [[ -d "$font_dir" ]] && [[ -n "$(ls -A "$font_dir" 2>/dev/null)" ]]; then
        ok "Nerd Font already present at $font_dir"
        return
    fi
    mkdir -p "$font_dir"
    local url="https://github.com/ryanoasis/nerd-fonts/releases/latest/download/${FONT}.zip"
    info "Downloading $FONT Nerd Font from $url"
    local tmp; tmp="$(mktemp -d)"
    if ! curl -fsSL "$url" -o "$tmp/font.zip"; then
        warn "Download failed for $FONT — skipping font install"
        rm -rf "$tmp"
        return
    fi
    if ! command -v unzip >/dev/null 2>&1; then
        warn "unzip not available; install it and re-run with --font $FONT"
        rm -rf "$tmp"
        return
    fi
    unzip -q -o "$tmp/font.zip" -d "$font_dir"
    rm -rf "$tmp"
    if command -v fc-cache >/dev/null 2>&1; then
        fc-cache -f "$font_dir" >/dev/null 2>&1 || true
    fi
    ok "Installed $FONT Nerd Font into $font_dir"
}

# ---------- first-run credential setup ----------
first_run_login() {
    local ruby_bin
    ruby_bin="$(command -v ruby 2>/dev/null || echo ruby)"

    cat <<EOF

${BOLD}Save your Simutronics credentials${RESET}
This is your ${BOLD}play.net login${RESET} (username + password) — ${BOLD}not${RESET} your character name.
EOF

    if (( UNATTENDED )) || (( ! TTY_AVAILABLE )); then
        say "Skipping (unattended). Save credentials later with:"
        say "  cd $LICH_DIR && $ruby_bin lich.rbw --add-account USERNAME PASSWORD --frontend wizard"
        return
    fi

    if ! confirm "Save your Simutronics credentials now?" "Y"; then
        say "Run later:  cd $LICH_DIR && $ruby_bin lich.rbw --add-account USERNAME PASSWORD --frontend wizard"
        return
    fi

    local account=""
    account="$(prompt "Simutronics username" "")"
    if [[ -z "$account" ]]; then
        warn "No account name entered; skipping"
        return
    fi

    local password="" out
    while true; do
        if [[ -t 0 ]]; then
            read -r -s -p "Simutronics password: " password
        else
            read -r -s -p "Simutronics password: " password < /dev/tty || true
        fi
        printf '\n'

        if [[ -z "$password" ]]; then
            warn "No password entered; skipping"
            return
        fi

        info "Saving credentials to lich..."
        out="$( cd "$LICH_DIR" && "$ruby_bin" lich.rbw --add-account "$account" "$password" --frontend wizard 2>&1 )"
        if printf '%s' "$out" | grep -qi 'already exists'; then
            ok "Credentials already saved."
            return
        elif printf '%s' "$out" | grep -qi 'error'; then
            err "Authentication failed (wrong password?). Try again, or press Enter to skip."
        else
            ok "Credentials saved."
            return
        fi
    done
}

# ---------- terminal font instructions ----------
print_terminal_hints() {
    local family="$FONT Nerd Font"
    cat <<EOF

${BOLD}Set your terminal font to:${RESET} ${CYAN}${family}${RESET}

Quick reference:
  • ${BOLD}iTerm2${RESET}      Preferences → Profiles → Text → Font
  • ${BOLD}Ghostty${RESET}     ~/.config/ghostty/config:  font-family = "$family"
  • ${BOLD}WezTerm${RESET}     ~/.wezterm.lua:  font = wezterm.font("$family")
  • ${BOLD}Alacritty${RESET}   ~/.config/alacritty/alacritty.toml:
                  [font.normal]
                  family = "$family"
  • ${BOLD}Kitty${RESET}       ~/.config/kitty/kitty.conf:  font_family $family
  • ${BOLD}GNOME Terminal${RESET}  Preferences → Profile → Custom font
  • ${BOLD}Konsole${RESET}     Settings → Edit Profile → Appearance → Font
  • ${BOLD}macOS Terminal${RESET} Preferences → Profiles → Font
EOF
}

# ---------- main flow ----------
detect_os
detect_pm
detect_sudo

hr
say "${BOLD}GSTinTin installer${RESET}"
say "  OS:            $OS"
say "  Pkg manager:   $PM"
say "  lich-5 dir:    $LICH_DIR"
say "  GSTinTin dir:  $GSTIN_DIR"
say "  Launcher:      $BIN_DIR/gemstone"
say "  Port:          $PORT"
hr

# Prompt for character name if not set
if [[ -z "$CHAR_NAME" ]] && (( ! UNATTENDED )) && (( TTY_AVAILABLE )); then
    CHAR_NAME="$(prompt "Character name (used as the launcher's default; can be overridden later)" "YourCharName")"
fi
[[ -z "$CHAR_NAME" ]] && CHAR_NAME="YourCharName"

# Compute system packages we'd need
SYS_PKGS="$(sys_pkg_list)"
if (( INSTALL_RUBY )) && ! ruby_ok && [[ -z "$RUBY_VERSION" ]]; then
    SYS_PKGS="$SYS_PKGS $(sys_ruby_pkg)"
fi
# shellcheck disable=SC2086
MISSING="$(filter_missing $SYS_PKGS | grep -v '^$' || true)"

if [[ -n "$MISSING" ]]; then
    say "${BOLD}System packages to install via $PM:${RESET}"
    # shellcheck disable=SC2086
    printf '  %s\n' $MISSING
    [[ -n "$SUDO" ]] && say "(this will use ${BOLD}sudo${RESET})"
    if ! confirm "Proceed with system package install?" "Y"; then
        err "Aborted by user."; exit 1
    fi
    # shellcheck disable=SC2086
    install_pkgs $MISSING
else
    ok "All required system packages are already installed; skipping sudo phase."
fi

ensure_ruby
ensure_tintin
ensure_lich
ensure_gstintin
write_launcher
ensure_font

hr
ok "Install complete."
print_terminal_hints
first_run_login

cat <<EOF

${BOLD}Next steps${RESET}
  1. Reload your shell config:  ${CYAN}source $(shell_rc)${RESET}
  2. From now on, just run:     ${CYAN}gemstone ${CHAR_NAME} ${PORT}${RESET}

EOF
