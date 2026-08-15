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

case ":${PATH:-}:" in
    *":$PREFIX:"*) ;;
    *) printf '\n  %s is not on your PATH:\n    export PATH="%s:$PATH"\n' \
           "$PREFIX" "$PREFIX" ;;
esac
