#!/bin/sh
# curl -fsSL https://raw.githubusercontent.com/gielfeldt/ferry/main/install.sh | sh
#
#   FERRY_REPO    owner/name to install from  (default gielfeldt/ferry)
#   FERRY_PREFIX  where to put it             (default ~/.local/bin)
#   FERRY_REF     a tag or branch             (default: latest release, else main)
set -eu

REPO="${FERRY_REPO:-gielfeldt/ferry}"
PREFIX="${FERRY_PREFIX:-$HOME/.local/bin}"
REF="${FERRY_REF:-}"

command -v python3 >/dev/null 2>&1 || { echo "ferry needs python3" >&2; exit 1; }

tmp="$(mktemp)"
trap 'rm -f "$tmp"' EXIT

fetch() {
    if command -v curl >/dev/null 2>&1; then curl -fsSL "$1" -o "$tmp" 2>/dev/null
    elif command -v wget >/dev/null 2>&1; then wget -qO "$tmp" "$1" 2>/dev/null
    else echo "ferry needs curl or wget" >&2; exit 1
    fi
}

# Same, but to a destination of your choosing, for the completion files.
fetch_to() {
    dest="$1"; path="$2"
    for url in "https://raw.githubusercontent.com/$REPO/${REF:-main}/$path"; do
        if command -v curl >/dev/null 2>&1; then
            curl -fsSL "$url" -o "$dest" 2>/dev/null && return 0
        elif command -v wget >/dev/null 2>&1; then
            wget -qO "$dest" "$url" 2>/dev/null && return 0
        fi
    done
    return 1
}

if [ -n "$REF" ]; then
    fetch "https://github.com/$REPO/releases/download/$REF/ferry" ||
    fetch "https://raw.githubusercontent.com/$REPO/$REF/ferry" ||
    { echo "ferry: nothing at $REF in $REPO" >&2; exit 1; }
else
    fetch "https://github.com/$REPO/releases/latest/download/ferry" ||
    fetch "https://raw.githubusercontent.com/$REPO/main/ferry" ||
    { echo "ferry: could not download from $REPO" >&2; exit 1; }
fi

# Never install something that will not run.
python3 "$tmp" --version >/dev/null 2>&1 || {
    echo "ferry: the downloaded file does not run - not installing it" >&2
    exit 1; }

mkdir -p "$PREFIX"
chmod 755 "$tmp"
mv "$tmp" "$PREFIX/ferry"
trap - EXIT

"$PREFIX/ferry" --version

# Shell completion. Best effort: a missing completion is an inconvenience, not
# a failed install, so nothing here is allowed to abort the script.
BASHDIR="${XDG_DATA_HOME:-$HOME/.local/share}/bash-completion/completions"
ZSHDIR="${XDG_DATA_HOME:-$HOME/.local/share}/zsh/site-functions"
comp_tmp="$(mktemp)"

if fetch_to "$comp_tmp" "completions/ferry.bash"; then
    mkdir -p "$BASHDIR" && mv "$comp_tmp" "$BASHDIR/ferry" \
        && echo "  bash completion -> $BASHDIR/ferry"
fi
comp_tmp="$(mktemp)"
if fetch_to "$comp_tmp" "completions/ferry.zsh"; then
    mkdir -p "$ZSHDIR" && mv "$comp_tmp" "$ZSHDIR/_ferry" \
        && echo "  zsh completion  -> $ZSHDIR/_ferry"
    case ":${fpath:-}:" in
        *":$ZSHDIR:"*) ;;
        *) printf '    zsh needs that on its fpath:\n'
           printf '      fpath=(%s $fpath)   # before compinit\n' "$ZSHDIR" ;;
    esac
fi
rm -f "$comp_tmp"

case ":${PATH:-}:" in
    *":$PREFIX:"*) ;;
    *) printf '\n  %s is not on your PATH:\n    export PATH="%s:$PATH"\n' \
           "$PREFIX" "$PREFIX" ;;
esac
