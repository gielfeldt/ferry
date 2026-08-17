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

_get() {                          # _get <dest> <url>
    if command -v curl >/dev/null 2>&1; then curl -fsSL "$2" -o "$1" 2>/dev/null
    elif command -v wget >/dev/null 2>&1; then wget -qO "$1" "$2" 2>/dev/null
    else echo "ferry needs curl or wget" >&2; exit 1
    fi
}

# One rule for every file this installs: the release if there is one, the tree
# otherwise. The binary and its completions have to resolve the same way - a
# release is a version of ferry, not just of the script, and taking one from a
# tag and the other from main installs two halves that were never tested
# together.
download() {                      # download <dest> <asset> <path-in-tree>
    if [ -n "$REF" ]; then
        _get "$1" "https://github.com/$REPO/releases/download/$REF/$2" ||
        _get "$1" "https://raw.githubusercontent.com/$REPO/$REF/$3"
    else
        _get "$1" "https://github.com/$REPO/releases/latest/download/$2" ||
        _get "$1" "https://raw.githubusercontent.com/$REPO/main/$3"
    fi
}

download "$tmp" ferry ferry || {
    if [ -n "$REF" ]; then echo "ferry: nothing at $REF in $REPO" >&2
    else echo "ferry: could not download from $REPO" >&2; fi
    exit 1; }

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

if download "$comp_tmp" ferry.bash "completions/ferry.bash"; then
    mkdir -p "$BASHDIR" && mv "$comp_tmp" "$BASHDIR/ferry" \
        && echo "  bash completion -> $BASHDIR/ferry"
    # That directory is only searched by bash-completion 2.x, which needs bash
    # 4.2+. On an older bash the file would sit there unread and completion
    # would look simply broken, so say what to add instead of leaving it.
    if [ -n "${BASH_VERSION:-}" ]; then
        case "$BASH_VERSION" in
            [123].*|4.[01].*)
                printf '    bash %s is too old to find that on its own:\n' \
                    "${BASH_VERSION%%(*}"
                printf '      echo ". %s" >> ~/.bash_profile\n' "$BASHDIR/ferry" ;;
        esac
    fi
fi
comp_tmp="$(mktemp)"
if download "$comp_tmp" ferry.zsh "completions/ferry.zsh"; then
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
