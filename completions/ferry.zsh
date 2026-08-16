# ferry completion for zsh
#   installed to ~/.local/share/zsh/site-functions/_ferry, which must be on fpath
#compdef ferry
_ferry() {
    local -a candidates
    candidates=(${(f)"$(ferry complete --line "$BUFFER" 2>/dev/null)"})
    compadd -S '' -a candidates
}
_ferry "$@"
