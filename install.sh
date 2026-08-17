#!/bin/sh
# curl -fsSL https://raw.githubusercontent.com/gielfeldt/ferry/main/install.sh | sh
#
#   FERRY_REPO    owner/name to install from  (default gielfeldt/ferry)
#   FERRY_PREFIX  where to put it             (default ~/.local/bin)
#   FERRY_REF     a release tag               (default: the newest release)
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

# Which version to install, settled once, before anything is fetched.
#
# Everything then comes from that one tag. Resolving per file is the thing to
# avoid: separate lookups can straddle a release and pair one version's binary
# with another's completions. There is no fallback to a branch, deliberately -
# a fallback that quietly hands you something other than the release you asked
# for is worse than stopping, and the install script piped from main is not
# the same script that shipped with an older tag anyway.
if [ -z "$REF" ]; then
    ref_tmp="$(mktemp)"
    # Asked once, to turn "no version given" into a concrete tag. This is the
    # only mutable lookup in the script, and nothing is downloaded until it has
    # produced an answer. It settles a few seconds after a release is
    # published - sooner than the /releases/latest redirect, which takes a
    # minute or two and is why nothing here uses it.
    if _get "$ref_tmp" "https://api.github.com/repos/$REPO/releases/latest"; then
        REF="$(sed -n 's/.*"tag_name" *: *"\([^"]*\)".*/\1/p' "$ref_tmp" |
               head -1)"
    fi
    rm -f "$ref_tmp"
fi
[ -n "$REF" ] || {
    echo "ferry: could not work out which release to install from $REPO" >&2
    echo "       set one:  FERRY_REF=v1.0.0 sh install.sh" >&2
    exit 1; }

echo "installing ferry $REF"

download() {                      # download <dest> <asset>
    _get "$1" "https://github.com/$REPO/releases/download/$REF/$2"
}

download "$tmp" ferry || {
    echo "ferry: $REF has no ferry to download in $REPO" >&2; exit 1; }

# Never install something that will not run.
python3 "$tmp" --version >/dev/null 2>&1 || {
    echo "ferry: the downloaded file does not run under this python3" >&2
    echo "       ($(python3 -V 2>&1); ferry needs 3.9 or newer)" >&2
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

if download "$comp_tmp" ferry.bash; then
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
if download "$comp_tmp" ferry.zsh; then
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
