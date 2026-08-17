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

# Which version to install, decided once, before anything is fetched.
#
# Resolving it per file is the thing to avoid: three separate lookups of
# "latest" can straddle a release and give you one version's binary with
# another's completions, and a fallback to main on any single failure quietly
# does the same. So the ref is settled here, and every file then comes from
# it - a release is a version of ferry, not of one file at a time.
resolve_ref() {
    [ -n "$REF" ] && { echo "$REF"; return 0; }
    _t="$(mktemp)"
    # The API knows about a new release immediately; the /releases/latest
    # redirect can lag behind it by a minute or two.
    if _get "$_t" "https://api.github.com/repos/$REPO/releases/latest"; then
        _tag="$(sed -n 's/.*"tag_name" *: *"\([^"]*\)".*/\1/p' "$_t" | head -1)"
        [ -n "$_tag" ] && { rm -f "$_t"; echo "$_tag"; return 0; }
    fi
    rm -f "$_t"
    return 0                      # no release at all: fall back to main
}

REF="$(resolve_ref)"
FROM="${REF:-main}"

# Within one ref, the release asset and the tree at that same tag are the same
# content, so falling back between them cannot mix versions. Releases before
# 1.2.2 carry no completion assets, which is exactly what that fallback is for.
download() {                      # download <dest> <asset> <path-in-tree>
    if [ -n "$REF" ]; then
        _get "$1" "https://github.com/$REPO/releases/download/$REF/$2" ||
        _get "$1" "https://raw.githubusercontent.com/$REPO/$REF/$3"
    else
        _get "$1" "https://raw.githubusercontent.com/$REPO/main/$3"
    fi
}

echo "installing ferry from $FROM"

download "$tmp" ferry ferry || {
    echo "ferry: nothing to download at $FROM in $REPO" >&2; exit 1; }

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
