#!/usr/bin/env bash
# Install, uninstall, or check the claude-code-agent-ops command-line tools.
#
#   sudo ./install.sh              Install system-wide into /usr/local/bin
#   ./install.sh --user            Install for the current user into ~/.local/bin
#   ./install.sh --prefix DIR      Install into DIR/bin
#   ./install.sh --link [...]      Symlink to this checkout instead of copying
#   ./install.sh --uninstall [...] Remove a previous install (same prefix options)
#   ./install.sh --check           Show which copy of each tool your PATH runs
set -euo pipefail

TOOLS=(claude-session claude-usage claude-tools claude-ncsl)
NAME=claude-code-agent-ops
MIN_PYTHON="3.8"

SRC_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PREFIX=/usr/local
MODE=install
LINK=0

usage() {
    sed -n '2,10s/^# \{0,1\}//p' "${BASH_SOURCE[0]}"
}

die() { echo "install.sh: $*" >&2; exit 1; }

while [ $# -gt 0 ]; do
    case "$1" in
        --user)      PREFIX="$HOME/.local" ;;
        --prefix)    [ $# -ge 2 ] || die "--prefix needs a directory"; PREFIX="$2"; shift ;;
        --prefix=*)  PREFIX="${1#--prefix=}" ;;
        --link)      LINK=1 ;;
        --uninstall) MODE=uninstall ;;
        --check)     MODE=check ;;
        -h|--help)   usage; exit 0 ;;
        *)           die "unknown option: $1 (see --help)" ;;
    esac
    shift
done

PREFIX="${PREFIX%/}"
BIN_DIR="$PREFIX/bin"
SHARE_DIR="$PREFIX/share/$NAME"
MANIFEST="$SHARE_DIR/installed-files"

# Report which file each tool name resolves to on the current PATH, and
# flag any copies that shadow (come earlier than) the installed ones.
check_path() {
    local tool found first status=0
    for tool in "${TOOLS[@]}"; do
        mapfile -t found < <(type -aP "$tool" 2>/dev/null | awk '!seen[$0]++')
        if [ ${#found[@]} -eq 0 ]; then
            printf '  %-16s not on PATH\n' "$tool"
            status=1
            continue
        fi
        first="${found[0]}"
        printf '  %-16s %s\n' "$tool" "$first"
        if [ ${#found[@]} -gt 1 ]; then
            printf '  %-16s   also found (shadowed): %s\n' "" "${found[@]:1}"
            status=1
        fi
    done
    return $status
}

if [ "$MODE" = check ]; then
    echo "Tools as resolved by your PATH:"
    if check_path; then
        echo "OK: each tool resolves to a single copy."
    else
        echo
        echo "Some tools are missing or have more than one copy on your PATH;"
        echo "the first one listed is the one that runs. Remove stale copies"
        echo "(e.g. from ~/Scripts or ~/bin) if they shadow the installed ones."
        exit 1
    fi
    exit 0
fi

if [ "$MODE" = uninstall ]; then
    [ -f "$MANIFEST" ] || die "no install found under $PREFIX (missing $MANIFEST)"
    while IFS= read -r f; do
        # Only remove files inside this prefix's bin directory.
        case "$f" in
            "$BIN_DIR"/*) rm -f -- "$f" && echo "removed $f" ;;
        esac
    done < "$MANIFEST"
    rm -f -- "$MANIFEST"
    rmdir -- "$SHARE_DIR" 2>/dev/null || true
    echo "Uninstalled $NAME from $PREFIX."
    exit 0
fi

# ---- install ----
command -v python3 >/dev/null || die "python3 is required (sudo apt install python3)"
python3 -c "import sys; sys.exit(sys.version_info < tuple(map(int, '$MIN_PYTHON'.split('.'))))" \
    || die "python3 >= $MIN_PYTHON is required (found $(python3 -V 2>&1))"

mkdir -p "$BIN_DIR" "$SHARE_DIR" 2>/dev/null || true
if [ ! -w "$BIN_DIR" ] || [ ! -w "$SHARE_DIR" ]; then
    die "cannot write to $PREFIX; re-run with sudo, or use --user for ~/.local"
fi

: > "$MANIFEST"
for tool in "${TOOLS[@]}"; do
    src="$SRC_DIR/$tool"
    dest="$BIN_DIR/$tool"
    [ -f "$src" ] || die "missing $src"
    if [ "$LINK" = 1 ]; then
        ln -sfn "$src" "$dest"
        echo "linked    $dest -> $src"
    else
        rm -f -- "$dest"   # replace a previous symlink rather than writing through it
        install -m 0755 "$src" "$dest"
        echo "installed $dest"
    fi
    echo "$dest" >> "$MANIFEST"
done

echo
echo "Installed ${#TOOLS[@]} tools into $BIN_DIR."

if [ "$(id -u)" = 0 ] && [ -n "${SUDO_USER:-}" ]; then
    # sudo resets PATH, so it can't tell what the user's shell will run.
    echo "Run './install.sh --check' as $SUDO_USER to confirm no older copies shadow these."
    exit 0
fi

case ":$PATH:" in
    *":$BIN_DIR:"*) ;;
    *) echo "Note: $BIN_DIR is not on your PATH; add it in ~/.profile or ~/.bashrc."
       exit 0 ;;
esac

shadowed=0
for tool in "${TOOLS[@]}"; do
    runs="$(type -P "$tool" || true)"
    if [ "$runs" != "$BIN_DIR/$tool" ]; then
        [ "$shadowed" = 1 ] || { echo; echo "Warning: older copies come earlier on your PATH and will run instead:"; }
        printf '  %-16s %s\n' "$tool" "$runs"
        shadowed=1
    fi
done
[ "$shadowed" = 0 ] || echo "Remove them (e.g. from ~/Scripts or ~/bin), then run 'hash -r'."
